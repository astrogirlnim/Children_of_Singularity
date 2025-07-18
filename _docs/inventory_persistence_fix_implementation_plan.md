# Game Data Persistence Fix - Implementation Checklist
**Children of the Singularity - Complete Backend Integration Phase**

## Overview
This checklist addresses game data persistence issues where player inventory, upgrades, credits, and progress reset upon game restart. The core issue is missing startup data loading functionality.

## Problem Summary
- ✅ **Saving**: All data saves correctly to database
- ❌ **Loading**: Game never loads existing data on startup
- **Result**: Players lose ALL progress when restarting the game

---

## **Phase 1: Critical Database Connection Fix** ⚡
**Priority**: Critical | **Timeline**: 1-2 days | **Status**: ✅ COMPLETED

### 1.1 Player ID Format Standardization
**Files**: `PlayerShip3D.gd`, `PlayerShip.gd`, `APIClient.gd`

- [x] Verify UUID format in PlayerShip3D.gd (`"550e8400-e29b-41d4-a716-446655440000"`)
- [x] Verify UUID format in PlayerShip.gd (`"550e8400-e29b-41d4-a716-446655440000"`)
- [x] Add UUID validation function to APIClient.gd
- [x] Remove any remaining `"player_001"` fallback references

### 1.2 Database Connection Testing
- [x] Start backend server (`python backend/app.py`)
- [x] Test upgrade purchase endpoint with UUID format
- [x] Test inventory add/retrieve operations
- [x] Validate all API endpoints return 200 status codes
- [x] Verify no "invalid input syntax for type uuid" errors in logs

**Success Criteria**:
- [x] All API endpoints accept UUID player IDs
- [x] No UUID format errors in console
- [x] Database operations complete successfully

---

## **Phase 2: Complete Game Data Loading System** 🔄
**Priority**: High | **Timeline**: 2-3 days | **Status**: ✅ COMPLETED

### 2.1 Zone Initialization Data Loading
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`

- [x] Add `_load_complete_player_data_from_backend()` method to ZoneMain3D.gd
- [x] Add `_load_complete_player_data_from_backend()` method to ZoneMain.gd (2D version)
- [x] Call loading function in `_initialize_3d_zone()` BEFORE other initialization
- [x] Connect API client signals for data reception
- [x] Implement loading state management with flags

**Implementation**:
```gdscript
func _initialize_3d_zone() -> void:
    # ... existing initialization ...

    # NEW: Load existing player data BEFORE applying defaults
    if api_client and player_ship:
        _load_complete_player_data_from_backend()

func _load_complete_player_data_from_backend() -> void:
    _log_message("Loading player data from backend...")

    # Connect signals for all data types
    api_client.player_data_loaded.connect(_on_player_data_loaded)
    api_client.inventory_updated.connect(_on_inventory_loaded)

    # Load all player data
    api_client.load_player_data(player_ship.player_id)  # Credits, upgrades, position
    api_client.load_inventory(player_ship.player_id)    # Inventory items
```

### 2.2 Player Data Reception and Application
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`

- [x] Add `_on_player_data_loaded(data: Dictionary)` handler
- [x] Process loaded credits and update player_ship.credits
- [x] Process loaded upgrades dictionary
- [x] Apply loaded upgrades using existing upgrade system
- [x] Restore upgrade effects (speed boosts, inventory capacity, etc.)
- [x] Update UI displays with loaded data immediately

**Implementation**:
```gdscript
func _on_player_data_loaded(data: Dictionary) -> void:
    _log_message("Applying loaded player data: %s" % data)

    if player_ship and data.has("credits"):
        player_ship.credits = data.credits
        _log_message("Restored credits: %d" % data.credits)

    if player_ship and data.has("upgrades"):
        # Apply each upgrade and its effects
        for upgrade_type in data.upgrades:
            var level = data.upgrades[upgrade_type]
            player_ship.upgrades[upgrade_type] = level

            # CRITICAL: Reapply upgrade effects
            if level > 0:
                player_ship._apply_upgrade_effects(upgrade_type, level)
                _log_message("Restored %s upgrade level %d with effects" % [upgrade_type, level])

    # Update UI immediately
    _update_credits_display()
    _populate_upgrade_catalog()  # Refresh to show loaded upgrades
```

### 2.3 Inventory Data Reception and Application
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`

- [x] Add `_on_inventory_loaded(inventory_data: Array)` handler
- [x] Convert inventory format from backend to game format
- [x] Restore inventory items to player ship
- [x] Update inventory UI with correct counts
- [x] Clear loading states when inventory is loaded

**Implementation**:
```gdscript
func _on_inventory_loaded(inventory_data: Array) -> void:
    _log_message("Applying loaded inventory: %d items" % inventory_data.size())

    if player_ship:
        player_ship.current_inventory.clear()
        player_ship.current_inventory = inventory_data.duplicate()

        _log_message("Restored inventory: %d/%d items" % [player_ship.current_inventory.size(), player_ship.inventory_capacity])

        # Update UI immediately
        _update_grouped_inventory_display(player_ship.current_inventory)
```

### 2.4 PlayerShip Initialization Order Fix
**Files**: `PlayerShip3D.gd`, `PlayerShip.gd`

- [x] Add `is_loading_from_backend: bool = false` flag to PlayerShip3D
- [x] Add `is_loading_from_backend: bool = false` flag to PlayerShip
- [x] Modify `_initialize_player_state()` to NOT clear data if loading
- [x] Set loading flag before data loading begins
- [x] Clear loading flag after data is applied
- [x] Ensure upgrade effects apply after loading

**Critical Fix**:
```gdscript
func _initialize_player_state() -> void:
    _log_message("PlayerShip3D: Initializing player state")

    # Don't clear data if we're loading from backend
    if not is_loading_from_backend:
        current_inventory.clear()
        credits = 0
        upgrades = {
            "speed_boost": 0,
            "inventory_expansion": 0,
            "collection_efficiency": 0,
            "zone_access": 1
        }
        _log_message("PlayerShip3D: Initialized with default values")
    else:
        _log_message("PlayerShip3D: Waiting for backend data load...")
```

### 2.5 Loading State Management
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`

- [x] Track loading progress for all data types (player data, inventory)
- [x] Handle loading completion when all data is received
- [x] Manage loading timeouts (30 second fallback)
- [x] Show loading UI during data retrieval
- [x] Hide loading UI when complete

**Success Criteria**:
- [x] Game loads existing inventory from database on startup
- [x] Player credits are restored correctly (275 credits successfully restored)
- [x] All purchased upgrades are restored with their effects active
- [x] Upgrade catalog shows correct levels ("Level 2/5" instead of "Level 0/5")
- [x] Ship speed, inventory capacity, and other upgrade effects work immediately (speed boosted from 150 to 300)
- [x] UI displays correct data immediately without requiring user action

---

## **Phase 3: Error Handling and Resilience** 🛡️
**Priority**: Medium | **Timeline**: 1-2 days

### 3.1 Database Connection Error Handling
**Files**: `APIClient.gd`, `ZoneMain3D.gd`

- [ ] Detect connection failures and timeout scenarios
- [ ] Implement retry logic with exponential backoff
- [ ] Log detailed error information for debugging
- [ ] Add connection status monitoring

### 3.2 Graceful Degradation System
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`

- [ ] Fallback to default values when backend is unavailable
- [ ] Continue game functionality without database connection
- [ ] Notify player of offline mode status
- [ ] Enable offline mode indicator in UI

**Implementation Strategy**:
```gdscript
func _handle_loading_failure() -> void:
    _log_message("Backend unavailable, starting with defaults")

    if player_ship:
        player_ship.credits = 100  # Default starting credits
        player_ship.current_inventory.clear()

    # Continue game initialization
    _enable_offline_mode()
```

### 3.3 Data Integrity Validation
**Files**: `APIClient.gd`

- [ ] Validate loaded data format and ranges
- [ ] Detect corrupted inventory items
- [ ] Clean invalid data before application
- [ ] Sanitize upgrade levels and credit amounts

**Success Criteria**:
- [ ] Game starts successfully even when backend is down
- [ ] Players can continue playing in offline mode
- [ ] No crashes from malformed data

---

## **Phase 4: User Experience Enhancements** 💫
**Priority**: Medium | **Timeline**: 1 day

### 4.1 Loading Status Display
**Files**: `ZoneMain3D.gd`, UI components

- [ ] Show loading message during data fetch ("Loading player data...")
- [ ] Display progress indicators for loading states
- [ ] Hide loading UI when complete
- [ ] Add loading spinner or progress bar

### 4.2 Connection Status Indicators
**Files**: UI components

- [ ] Visual indicators for online/offline mode
- [ ] Error messages for failed connections
- [ ] Success confirmations for data loading
- [ ] Connection status icon in HUD

### 4.3 Debug Information Enhancement
**Files**: `ZoneMain3D.gd`, debug systems

- [ ] Detailed logging for loading process
- [ ] Debug panel showing loading status
- [ ] Performance metrics for load times
- [ ] Data validation logs

**Success Criteria**:
- [ ] Players see clear feedback during loading
- [ ] Connection status is always visible
- [ ] Debug information helps with troubleshooting

---

## **Phase 5: Enhanced Persistence Features** 🚀
**Priority**: Low | **Timeline**: 2-3 days

### 5.1 Auto-Save System
**Files**: `ZoneMain3D.gd`, `PlayerShip3D.gd`

- [ ] Periodic auto-save every 30 seconds
- [ ] Event-triggered saves on inventory changes
- [ ] Position sync with backend
- [ ] Auto-save indicator in UI

### 5.2 Session Recovery
**Files**: Session management

- [ ] Detect abnormal shutdowns using session tracking
- [ ] Restore unsaved progress where possible
- [ ] Conflict resolution for simultaneous sessions
- [ ] Recovery notification system

### 5.3 Data Synchronization
**Files**: Network systems

- [ ] Real-time sync for multiplayer readiness
- [ ] Conflict detection for concurrent modifications
- [ ] Merge strategies for inventory conflicts
- [ ] Sync status monitoring

**Success Criteria**:
- [ ] Minimal data loss during unexpected shutdowns
- [ ] Smooth transition between game sessions
- [ ] Foundation ready for multiplayer features

---

## **Phase 6: Inventory Stacking System Refactor** 🔄
**Priority**: Critical | **Timeline**: 4-5 days | **Status**: 📋 PLANNED

### **Critical Problem Identified**
During Phase 2 testing, a fundamental inventory architecture flaw was discovered:
- **Current System**: Each debris item stored individually (177 items for 25-item inventory!)
- **Backend Issue**: Individual database rows per item instead of stacking by type
- **Trading Bug**: Items accumulate forever because backend sync only clears locally
- **Result**: Database bloat, performance issues, inventory count mismatches

### 6.1 Frontend Inventory Architecture Refactor
**Files**: `PlayerShip3D.gd`, `PlayerShip.gd`, `ZoneMain3D.gd`, `ZoneMain.gd`

#### 6.1.1 Replace Individual Item Storage with Type-Based Stacking
- [ ] Replace `current_inventory: Array[Dictionary]` with `inventory_stacks: Dictionary`
- [ ] Implement stack-based inventory data structure:
```gdscript
# NEW: Type-based stacking system
var inventory_stacks: Dictionary = {
    # item_type: {quantity: int, value_per_unit: int, total_value: int}
    "scrap_metal": {"quantity": 25, "value_per_unit": 5, "total_value": 125},
    "bio_waste": {"quantity": 8, "value_per_unit": 8, "total_value": 64},
    "ai_component": {"quantity": 2, "value_per_unit": 500, "total_value": 1000}
}
var inventory_count: int = 0  # Total individual items across all stacks
var inventory_capacity: int = 25  # Maximum individual items allowed
```

#### 6.1.2 Refactor Collection System
**Files**: `PlayerShip3D.gd`, `PlayerShip.gd`
- [ ] Modify `_collect_debris_object()` to use stacking:
```gdscript
func _collect_debris_object(debris_object) -> void:
    var debris_type = debris_object.get_debris_type()
    var debris_value = debris_object.get_debris_value()

    # Check inventory capacity (count individual items, not stacks)
    if inventory_count >= inventory_capacity:
        _show_inventory_full_message()
        return

    # Add to existing stack or create new stack
    if inventory_stacks.has(debris_type):
        inventory_stacks[debris_type].quantity += 1
        inventory_stacks[debris_type].total_value += debris_value
    else:
        inventory_stacks[debris_type] = {
            "quantity": 1,
            "value_per_unit": debris_value,
            "total_value": debris_value
        }

    inventory_count += 1
    # Sync individual item to backend (for immediate persistence)
    _sync_item_collection_to_backend(debris_type, debris_value)
```

#### 6.1.3 Refactor Trading System
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`
- [ ] Update trading interface to work with stacks:
```gdscript
func _populate_debris_selection_ui() -> void:
    # Display each item type with quantity selector
    for item_type in inventory_stacks:
        var stack_data = inventory_stacks[item_type]
        var quantity = stack_data.quantity
        var value_per_unit = stack_data.value_per_unit
        var total_value = stack_data.total_value

        # Create UI row: "Scrap Metal x25 (5 credits each, 125 total)"
        _create_stack_selection_row(item_type, quantity, value_per_unit, total_value)
```

- [ ] Update selling logic to remove from stacks:
```gdscript
func _sell_selected_items(selected_stacks: Dictionary) -> void:
    var total_credits_earned = 0
    var total_items_sold = 0

    for item_type in selected_stacks:
        var quantity_to_sell = selected_stacks[item_type]
        if inventory_stacks.has(item_type):
            var stack = inventory_stacks[item_type]
            var quantity_available = min(quantity_to_sell, stack.quantity)

            # Calculate earnings
            var credits_earned = quantity_available * stack.value_per_unit
            total_credits_earned += credits_earned
            total_items_sold += quantity_available

            # Remove from stack
            stack.quantity -= quantity_available
            stack.total_value -= credits_earned
            inventory_count -= quantity_available

            # Remove empty stacks
            if stack.quantity <= 0:
                inventory_stacks.erase(item_type)

    # Update credits and sync to backend
    player_ship.add_credits(total_credits_earned)
    _sync_partial_sale_to_backend(selected_stacks, total_credits_earned)
```

### 6.2 Backend Database Schema Refactor
**Files**: `backend/app.py`, `data/postgres/schema.sql`

#### 6.2.1 New Inventory Table Schema
- [ ] Create new inventory table optimized for stacking:
```sql
-- NEW: Type-based inventory storage
CREATE TABLE inventory_stacks (
    player_id UUID REFERENCES players(id) ON DELETE CASCADE,
    item_type VARCHAR(50) NOT NULL,
    total_quantity INTEGER NOT NULL DEFAULT 0,
    value_per_unit INTEGER NOT NULL,
    total_value INTEGER NOT NULL,
    first_collected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_id, item_type),
    CONSTRAINT positive_quantity CHECK (total_quantity >= 0),
    CONSTRAINT positive_value CHECK (value_per_unit > 0)
);

-- Index for performance
CREATE INDEX idx_inventory_stacks_player_type ON inventory_stacks(player_id, item_type);
```

#### 6.2.2 Migration Strategy
- [ ] Create migration script to convert existing individual items to stacks:
```sql
-- Migration: Convert individual items to stacks
INSERT INTO inventory_stacks (player_id, item_type, total_quantity, value_per_unit, total_value)
SELECT
    player_id,
    item_type,
    COUNT(*) as total_quantity,
    AVG(value)::INTEGER as value_per_unit,  -- Use average if values differ
    SUM(value) as total_value
FROM inventory
GROUP BY player_id, item_type;

-- Backup old table, then drop
ALTER TABLE inventory RENAME TO inventory_individual_backup;
```

#### 6.2.3 New API Endpoints
- [ ] Implement stack-based inventory endpoints:
```python
@app.get("/api/v1/players/{player_id}/inventory/stacks")
async def get_player_inventory_stacks(player_id: str):
    """Get player inventory as stacks by type"""
    # Return: {"scrap_metal": {"quantity": 25, "value_per_unit": 5, "total_value": 125}}

@app.post("/api/v1/players/{player_id}/inventory/stacks/add")
async def add_to_inventory_stack(player_id: str, item_data: InventoryStackItem):
    """Add items to stack (or create new stack)"""
    # UPSERT: Add to existing quantity or create new stack

@app.post("/api/v1/players/{player_id}/inventory/stacks/remove")
async def remove_from_inventory_stack(player_id: str, removal_data: InventoryStackRemoval):
    """Remove specific quantities from stacks"""
    # Support partial removal: remove 10 scrap_metal from stack of 25

@app.delete("/api/v1/players/{player_id}/inventory/stacks")
async def clear_all_inventory_stacks(player_id: str):
    """Clear all inventory stacks (sell all)"""
```

### 6.3 API Client Integration
**Files**: `APIClient.gd`

#### 6.3.1 New Stack-Based Methods
- [ ] Replace individual item methods with stack methods:
```gdscript
func load_inventory_stacks() -> void:
    # GET /inventory/stacks - returns stacks by type

func add_to_inventory_stack(item_type: String, quantity: int, value_per_unit: int) -> void:
    # POST /inventory/stacks/add - add to existing stack

func remove_from_inventory_stack(item_type: String, quantity: int) -> void:
    # POST /inventory/stacks/remove - remove from stack

func sell_inventory_stacks(selected_stacks: Dictionary) -> void:
    # POST /inventory/stacks/remove + POST /credits (atomic transaction)
```

#### 6.3.2 Signal Updates
- [ ] Update signals to work with stacks:
```gdscript
signal inventory_stacks_loaded(stacks_data: Dictionary)
signal inventory_stack_updated(item_type: String, new_quantity: int, total_value: int)
signal inventory_stacks_cleared(total_items_cleared: int, total_value: int)
```

### 6.4 UI System Updates
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`, UI components

#### 6.4.1 Inventory Display Refactor
- [ ] Update inventory UI to show stacks instead of individual items:
```gdscript
func _update_grouped_inventory_display(inventory_stacks: Dictionary) -> void:
    # Clear existing displays
    _clear_inventory_ui()

    # Create stack-based display
    for item_type in inventory_stacks:
        var stack = inventory_stacks[item_type]
        var display_text = "%s x%d (%d each)" % [
            item_type.replace("_", " ").capitalize(),
            stack.quantity,
            stack.value_per_unit
        ]
        _create_inventory_stack_ui_element(item_type, display_text, stack.total_value)

    # Update inventory count display
    var total_items = _calculate_total_item_count(inventory_stacks)
    inventory_status.text = "%d/%d Items" % [total_items, player_ship.inventory_capacity]
```

#### 6.4.2 Trading Interface Refactor
- [ ] Update trading interface for stack-based selection:
```gdscript
func _create_stack_selection_row(item_type: String, available_quantity: int, value_per_unit: int, total_value: int) -> Control:
    # Create: [Scrap Metal] [Quantity Spinner: 1-25] [Value: 5 each] [Total: 125] [Select All]
    # Allow partial selection from stacks
```

### 6.5 Data Migration and Compatibility
**Files**: Migration scripts, `ZoneMain3D.gd`

#### 6.5.1 Automatic Migration on Load
- [ ] Detect legacy individual inventory format and migrate:
```gdscript
func _migrate_legacy_inventory_to_stacks(legacy_inventory: Array) -> Dictionary:
    var migrated_stacks = {}

    for item in legacy_inventory:
        var item_type = item.get("type", "unknown")
        var value = item.get("value", 0)

        if migrated_stacks.has(item_type):
            migrated_stacks[item_type].quantity += 1
            migrated_stacks[item_type].total_value += value
        else:
            migrated_stacks[item_type] = {
                "quantity": 1,
                "value_per_unit": value,
                "total_value": value
            }

    return migrated_stacks
```

#### 6.5.2 Backward Compatibility Support
- [ ] Support loading both formats during transition period
- [ ] Automatic conversion from individual items to stacks
- [ ] Data validation and cleanup for migrated data

### **6.6 Performance Optimizations**

#### 6.6.1 Database Performance
- [ ] Implement proper indexing on inventory_stacks table
- [ ] Use UPSERT operations for efficient stack updates
- [ ] Batch operations for multiple stack modifications
- [ ] Connection pooling for high-frequency updates

#### 6.6.2 Memory Optimization
- [ ] Reduce memory footprint from Array[Dictionary] to Dictionary
- [ ] Efficient UI updates (only refresh changed stacks)
- [ ] Lazy loading for large inventories

### **Success Criteria**:
- [ ] **Storage Efficiency**: Max 6 stacks instead of 177+ individual items
- [ ] **Database Performance**: 10x reduction in inventory table rows
- [ ] **UI Responsiveness**: Stack-based display loads instantly
- [ ] **Backend Sync**: Proper add/remove operations instead of clear-all
- [ ] **Inventory Limits**: Accurate count enforcement (25 items max)
- [ ] **Migration Success**: Existing player data converted without loss
- [ ] **Backward Compatibility**: System handles both old and new formats during transition

**Timeline Breakdown**:
- **Day 1**: Frontend inventory architecture refactor (6.1)
- **Day 2**: Backend schema and API endpoints (6.2-6.3)
- **Day 3**: UI system updates and trading interface (6.4)
- **Day 4**: Data migration and testing (6.5)
- **Day 5**: Performance optimization and validation (6.6)

---

## **Testing Protocol** 🧪

### Phase 1 Testing
- [ ] Start backend server
- [ ] Test upgrade purchase with UUID format
- [ ] Verify no UUID errors in logs
- [ ] Test all API endpoints manually
- [ ] Monitor database connections

### Phase 2 Testing (Critical End-to-End Test)
- [x] Collect debris and earn credits
- [x] Purchase multiple upgrades (speed boost, inventory expansion)
- [x] Add items to inventory
- [x] Note all current stats (credits, upgrade levels, inventory count, ship speed)
- [x] Save game data (should happen automatically)
- [x] **Restart game completely**
- [x] **Verify ALL data persists**:
  - [x] Credits match previous session (275 credits restored)
  - [x] Upgrades show correct levels in BUY tab (Speed Boost Level 2, Zone Access Level 1)
  - [x] Upgrade effects are active (ship speed boosted from 150 to 300)
  - [x] Inventory items are restored (loading system functional)
  - [x] UI shows correct data immediately (credits display updated)

### Phase 3 Testing
- [ ] Start game with backend down
- [ ] Verify graceful fallback
- [ ] Test with corrupted data
- [ ] Verify error handling

### Integration Testing
- [ ] Full play session with saves and loads
- [ ] Network interruption scenarios
- [ ] Multiple restart cycles
- [ ] Performance testing for load times

---

## **File Modification Summary**

| File | Changes | Phase |
|------|---------|-------|
| `scripts/PlayerShip3D.gd` | Add loading flag, fix initialization order, inventory stacking system | 1, 2, 6 |
| `scripts/PlayerShip.gd` | Add loading flag, fix initialization order, inventory stacking system | 1, 2, 6 |
| `scripts/APIClient.gd` | Add UUID validation, error handling, stack-based API methods | 1, 3, 6 |
| `scripts/ZoneMain3D.gd` | Add complete data loading logic, upgrade restoration, stack-based trading | 2, 4, 6 |
| `scripts/ZoneMain.gd` | Add complete data loading logic (2D version), stack-based trading | 2, 6 |
| `scripts/UpgradeSystem.gd` | Ensure upgrade effects apply correctly after loading | 2 |
| `backend/app.py` | Add stack-based inventory endpoints, migration logic | 6 |
| `data/postgres/schema.sql` | Create inventory_stacks table, migration scripts | 6 |

---

## **Success Metrics**

### Primary Goals
- [ ] **Complete Data Persistence**: 100% of progress persists across restarts
- [ ] **Error Elimination**: 0 UUID format errors
- [ ] **Load Success Rate**: >95% successful data loads
- [ ] **Inventory Architecture**: Max 6 stacks instead of 177+ individual items (Phase 6)
- [ ] **Database Efficiency**: 10x reduction in inventory table rows (Phase 6)

### Secondary Goals
- [ ] **Load Time**: <2 seconds for complete data loading
- [ ] **User Experience**: Clear feedback during all operations
- [ ] **System Resilience**: Graceful handling of all error scenarios
- [ ] **Upgrade Effect Integrity**: All upgrade effects work immediately after loading
- [ ] **Inventory Limits**: Accurate count enforcement (25 items max) (Phase 6)
- [ ] **Backend Sync**: Proper add/remove operations instead of clear-all (Phase 6)

---

## **Rollout Strategy**

### Development Environment
- [ ] Implement Phase 1 (UUID fix) ✅ COMPLETED
- [ ] Test thoroughly with existing database ✅ COMPLETED
- [ ] Implement Phase 2 (loading system) ✅ COMPLETED
- [ ] Validate full cycle works ✅ COMPLETED
- [ ] Implement Phase 6 (inventory stacking refactor) 📋 PLANNED
- [ ] Test migration from individual items to stacks
- [ ] Validate stack-based operations work correctly

### Quality Assurance
- [ ] Test all scenarios from testing strategy
- [ ] Performance validation for load times
- [ ] Error scenario testing
- [ ] **Phase 6 Specific Testing**:
  - [ ] Migration testing with existing player data
  - [ ] Stack-based trading interface testing
  - [ ] Backend performance testing with stacks
  - [ ] Backward compatibility testing

### Production Deployment
- [ ] Deploy backend changes first
- [ ] Deploy client changes second
- [ ] Monitor error logs closely
- [ ] Have rollback plan ready
- [ ] **Phase 6 Deployment**:
  - [ ] Deploy database migration scripts
  - [ ] Deploy new stack-based backend APIs
  - [ ] Deploy frontend stack-based inventory system
  - [ ] Monitor inventory data integrity

---

**Total Estimated Duration**: 12-16 days
**Critical Path**: Phase 1 → Phase 2 → Phase 6 → Testing
**Immediate Priority**: Phase 6.1 (Frontend Inventory Architecture Refactor)
**Current Status**: Phase 2 completed, Phase 6 planned and ready for implementation
