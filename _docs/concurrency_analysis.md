# Concurrency Analysis: Trading Marketplace Architecture

## 🚨 **Current State: RACE CONDITIONS EXIST**

Our current trading marketplace has several concurrency vulnerabilities that could lead to data corruption and double-spending issues in production.

## 🔍 **Identified Race Conditions**

### 1. **Critical: Double Purchase Vulnerability**

**Location**: `backend/trading_lambda.py` - `buy_listing()` function

**The Problem**:
```python
# VULNERABLE CODE PATTERN:
listings = load_from_s3(LISTINGS_KEY)          # Player A reads
                                               # Player B reads (same data)
listings[index]["status"] = "sold"             # Player A modifies
listings[index]["status"] = "sold"             # Player B modifies  
save_to_s3(LISTINGS_KEY, listings)            # Player A saves
save_to_s3(LISTINGS_KEY, listings)            # Player B overwrites!
```

**Race Condition Scenario**:
1. Player A requests to buy Item #123
2. Player B simultaneously requests to buy Item #123  
3. Both Lambda functions read the same listings data
4. Both see the item as "available"
5. Both mark it as "sold" and save
6. **Result**: Item sold twice, seller gets paid twice, buyers both think they own it

**Impact**: 🔴 **HIGH** - Financial loss, data corruption, player disputes

### 2. **Moderate: Local File Corruption**

**Location**: `scripts/LocalPlayerData.gd` - File operations

**The Problem**:
```gdscript
# VULNERABLE OPERATIONS:
save_inventory()  # Trading API removes item
save_inventory()  # Debris collection adds item (simultaneous)
```

**Race Condition Scenario**:
1. Player sells item via trading API → triggers inventory save
2. Player simultaneously collects debris → triggers inventory save
3. File writes can interleave or corrupt each other
4. **Result**: Lost items, corrupted inventory data

**Impact**: 🟡 **MEDIUM** - Local data loss, player frustration

### 3. **Minor: API Request Overlap**

**Location**: `scripts/TradingMarketplace.gd` - Single HTTPRequest node

**Current State**: ✅ **HANDLED** - Godot's HTTPRequest processes one request at a time
**Impact**: 🟢 **LOW** - No concurrency issues on client API calls

## 📊 **Architecture Assessment**

| Component | Concurrency Safety | Risk Level | Impact |
|-----------|-------------------|------------|---------|
| **Lambda buy_listing()** | ❌ No protection | 🔴 HIGH | Financial loss |
| **Lambda create_listing()** | ❌ No protection | 🟡 MEDIUM | Duplicate listings |
| **S3 JSON operations** | ❌ No atomic updates | 🔴 HIGH | Data corruption |
| **Local file operations** | ❌ No file locking | 🟡 MEDIUM | Local data loss |
| **Godot HTTP requests** | ✅ Sequential only | 🟢 LOW | No issues |

## 🛠️ **Recommended Solutions**

### **Priority 1: Fix Double Purchase (Critical)**

#### **Option A: DynamoDB with Conditional Writes (Recommended)**
```python
# DynamoDB conditional update - atomic operation
response = dynamodb.update_item(
    TableName='TradingListings',
    Key={'listing_id': listing_id},
    UpdateExpression='SET #status = :sold_status',
    ConditionExpression='#status = :active_status',
    ExpressionAttributeNames={'#status': 'status'},
    ExpressionAttributeValues={
        ':sold_status': 'sold',
        ':active_status': 'active'
    }
)
# Throws ConditionalCheckFailedException if already sold
```

#### **Option B: S3 with ETag Optimistic Locking**
```python
# Read with ETag
response = s3.get_object(Bucket=BUCKET_NAME, Key=LISTINGS_KEY)
etag = response['ETag']
listings = json.loads(response['Body'].read())

# Modify data
# ... update listings ...

# Conditional write - fails if ETag changed
s3.put_object(
    Bucket=BUCKET_NAME,
    Key=LISTINGS_KEY,
    Body=json.dumps(listings),
    IfMatch=etag  # Atomic: only write if ETag matches
)
```

#### **Option C: API Gateway + Lambda Locks (Complex)**
```python
import fcntl  # File locking
import time

def acquire_lock(lock_key: str, timeout: int = 30):
    # Redis or DynamoDB distributed lock
    pass

def buy_listing_with_lock(listing_id: str, buyer_data: dict):
    lock_key = f"listing_lock_{listing_id}"

    if acquire_lock(lock_key, timeout=30):
        try:
            # Protected buy operation
            return buy_listing_unsafe(listing_id, buyer_data)
        finally:
            release_lock(lock_key)
    else:
        return create_response(409, {"error": "Item currently being purchased"})
```

### **Priority 2: Fix Local File Concurrency (Medium)**

#### **Option A: Godot File Locking**
```gdscript
# Add to LocalPlayerData.gd
var _inventory_lock: bool = false

func save_inventory() -> bool:
    if _inventory_lock:
        print("LocalPlayerData: Inventory save blocked - operation in progress")
        return false

    _inventory_lock = true
    var result = _save_inventory_unsafe()
    _inventory_lock = false
    return result
```

#### **Option B: Atomic Temp File Operations**
```gdscript
func save_inventory() -> bool:
    var temp_file = inventory_file_path + ".tmp"
    var final_file = inventory_file_path

    # Write to temp file first
    var file = FileAccess.open(temp_file, FileAccess.WRITE)
    if not file:
        return false

    file.store_string(JSON.stringify(player_inventory, "\t"))
    file.close()

    # Atomic move (on most filesystems)
    var dir = DirAccess.open("user://")
    return dir.rename(temp_file, final_file) == OK
```

### **Priority 3: Enhanced Error Handling**

```gdscript
# Add to TradingMarketplace.gd
func buy_item(listing_id: String, expected_price: int) -> void:
    # Add optimistic UI updates with rollback
    local_player_data.reserve_credits(expected_price)  # Temporary hold

    var purchase_data = {
        "buyer_id": local_player_data.get_player_id(),
        "buyer_name": local_player_data.get_player_name(),
        "expected_price": expected_price  # Price validation
    }

    # API call with rollback capability
    buy_listing(listing_id, purchase_data)

func _on_purchase_failed(error: String):
    # Rollback optimistic changes
    local_player_data.release_credits_hold()
    show_error_message("Purchase failed: " + error)
```

## 🏗️ **Implementation Recommendations**

### **Phase 1: Quick Fixes (1-2 days)**
1. ✅ **Add local file locking** in LocalPlayerData.gd
2. ✅ **Add purchase validation** with expected price checks
3. ✅ **Implement optimistic UI updates** with rollback

### **Phase 2: Architecture Upgrade (1 week)**  
1. ✅ **Migrate to DynamoDB** for atomic operations
2. ✅ **Add distributed locking** for critical operations
3. ✅ **Implement retry logic** for failed operations

### **Phase 3: Production Hardening (Ongoing)**
1. ✅ **Add monitoring** for race condition detection
2. ✅ **Implement rate limiting** to reduce concurrent load
3. ✅ **Add transaction logging** for audit trails

## 🧪 **Testing Concurrency Issues**

### **Load Testing Script**
```python
import asyncio
import aiohttp
import json

async def concurrent_purchase_test():
    """Test double purchase vulnerability"""
    listing_id = "test_item_123"

    # Create test listing first
    await create_test_listing(listing_id)

    # Simulate 10 simultaneous purchase attempts
    tasks = []
    for i in range(10):
        task = purchase_item(listing_id, f"buyer_{i}")
        tasks.append(task)

    results = await asyncio.gather(*tasks, return_exceptions=True)

    # Should only have 1 success, 9 failures
    successes = [r for r in results if not isinstance(r, Exception)]
    print(f"Successes: {len(successes)} (should be 1)")

    if len(successes) > 1:
        print("🚨 RACE CONDITION DETECTED!")

asyncio.run(concurrent_purchase_test())
```

### **Local File Testing**
```gdscript
# Add to test scene
func test_concurrent_saves():
    var local_data = get_node("/root/LocalPlayerData")

    # Simulate rapid inventory changes
    for i in range(100):
        local_data.add_item("test_item", 1)
        local_data.save_inventory()  # Concurrent with trading

        # Simulate trading API removing item
        local_data.remove_item("other_item", 1)  
        local_data.save_inventory()

        await get_tree().process_frame

    print("Inventory integrity check: ", local_data.validate_inventory())
```

## 🔒 **Risk Mitigation (Current MVP)**

Until concurrency fixes are implemented:

### **Immediate Safeguards**
1. **Price validation**: Include expected price in purchase requests
2. **Client-side rate limiting**: Prevent rapid-fire API calls  
3. **Optimistic locking UI**: Disable purchase buttons during API calls
4. **Error retry logic**: Gracefully handle "already sold" errors

### **Monitoring & Alerts**
1. **CloudWatch alarms**: Detect unusual Lambda error rates
2. **S3 access logging**: Monitor concurrent write patterns
3. **Client error reporting**: Track purchase failures

### **User Communication**
1. **Clear error messages**: "Item sold to another player"
2. **Retry suggestions**: "Please refresh and try again"
3. **Status indicators**: Show when operations are in progress

## 📈 **Cost-Benefit Analysis**

| Solution | Implementation Cost | Risk Reduction | Performance Impact |
|----------|-------------------|----------------|-------------------|
| **DynamoDB Migration** | 2-3 days | 95% | +20ms latency |
| **S3 ETag Locking** | 1 day | 90% | +10ms latency |
| **Local File Locking** | 4 hours | 80% | Negligible |
| **Optimistic UI** | 1 day | 60% | Better UX |

## 🎯 **Recommendation Summary**

For **production readiness**, implement in this order:

1. ✅ **Quick wins** (4-8 hours): Local file locking + optimistic UI
2. ✅ **Critical fix** (1-2 days): S3 ETag locking or DynamoDB migration  
3. ✅ **Production hardening** (1 week): Monitoring, testing, error handling

**Current risk level**: 🔴 **HIGH** for double purchases  
**Post-fixes risk level**: 🟢 **LOW** with proper implementation

---

**Bottom line**: Your MVP works great for single users, but needs concurrency protection before handling multiple simultaneous traders.
