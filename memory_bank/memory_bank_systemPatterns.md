# System Patterns & Architecture

## Core Architecture Pattern
**Client-Server with Authoritative Backend**
- Godot clients handle rendering, input, and UI
- FastAPI server manages game state, validation, and persistence
- PostgreSQL database stores persistent player data
- ENet networking for real-time multiplayer communication

## Directory Structure Pattern
```
/scenes/          # Godot scene files (.tscn)
  /zones/         # Zone-specific scenes (ZoneMain.tscn)
  /ui/            # User interface scenes
/scripts/         # GDScript files (.gd)
/assets/          # Game assets (textures, models, sounds)
/audio/ai/        # AI-generated voice clips
/backend/         # FastAPI application
/data/postgres/   # Database schema and migrations
/logs/            # Application logs
```

## Key Design Patterns

### Signal-Based Architecture (Godot)
- All inter-node communication uses Godot signals
- Loose coupling between game systems
- Event-driven programming model

### Server Authority Pattern
- Server validates all game actions
- Clients send input, receive authoritative state updates
- Anti-cheat through server-side validation

### Component-Based Entity System
- PlayerShip: Movement, collision, inventory
- ZoneMain: Camera management, debris spawning, UI coordination
- NetworkManager: Client-server communication
- InventoryManager: Item storage and manipulation
- AICommunicator: Narrative system integration

## New Architectural Patterns (Phase 2)

### APIClient Pattern
**Central HTTP Communication Hub**
- `scripts/APIClient.gd` - Extends HTTPRequest for backend communication
- **Signal-Based Responses**: Async operations with signal callbacks
- **Comprehensive Error Handling**: Network failures, timeout management
- **Method Coverage**: Player data, inventory, credits, health checks
- **Integration Pattern**: Single instance shared across game systems

```gdscript
# Usage Pattern
api_client.get_player_data(player_id)
api_client.player_data_received.connect(_on_player_data_received)
```

### Upgrade System Architecture
**Modular Progression System**
- `scripts/UpgradeSystem.gd` - Comprehensive upgrade mechanics
- **6 Upgrade Types**: Movement, Inventory, Collection, Exploration, Utility
- **Exponential Cost Scaling**: Base costs with configurable multipliers
- **Effect Application**: Real-time upgrade effects on target nodes
- **Purchase Validation**: Credit checking, level limits, prerequisites

```gdscript
# Upgrade Types Pattern
enum UpgradeType {
    SPEED_BOOST,           # Movement enhancement
    INVENTORY_EXPANSION,   # Capacity increase
    COLLECTION_EFFICIENCY, # Faster debris pickup
    ZONE_ACCESS,          # Unlock new areas
    DEBRIS_SCANNER,       # Enhanced detection
    CARGO_MAGNET          # Auto-collection
}
```

### Trading Integration Pattern
**Server-Authoritative Economy**
- Real-time credit synchronization between client and server
- Backend API integration for transaction validation
- Inventory transaction persistence and error handling
- Signal-based response handling for async operations

```gdscript
# Trading Pattern
func _on_sell_all_pressed():
    var total_value = calculate_inventory_value()
    api_client.add_credits(player_id, total_value)
    api_client.credits_updated.connect(_on_credits_updated)
```

### Enhanced System Integration Pattern
**Cross-System Communication**
- ZoneMain coordinates between PlayerShip, APIClient, and UpgradeSystem
- Signal chains for complex operations (collect → inventory → backend sync)
- Centralized error handling and logging
- State synchronization across multiple systems

## Networking Architecture
```
Client (Godot) <--ENet--> Server (Godot) <--HTTP--> Backend (FastAPI) <--> Database (PostgreSQL)
```

## Data Flow Patterns

### Phase 2 Enhanced Data Flow
1. **Input Processing**: Client → Server → Validation → State Update → Broadcast
2. **Persistence**: Server → APIClient → Backend API → Database
3. **AI Interactions**: Game Events → Backend → AI Processing → Voice Synthesis → Client
4. **Upgrade Flow**: Purchase Request → Validation → Credit Deduction → Effect Application → Persistence
5. **Trading Flow**: Inventory → Value Calculation → Credit Addition → Backend Sync → UI Update

### API Communication Pattern
- **Request/Response**: HTTPRequest with signal-based callbacks
- **Error Handling**: Comprehensive error checking with fallback mechanisms
- **State Management**: Client-side state synchronized with server authority
- **Async Operations**: Non-blocking API calls with signal notifications

## Error Handling Strategy
- Graceful degradation for network issues
- Comprehensive logging at all system levels
- Fallback mechanisms for missing resources
- User-friendly error messages
- **Backend Fallback**: System operational without database connection
- **API Timeout Handling**: Proper timeout management for HTTP requests
- **State Recovery**: Automatic state synchronization on reconnection

## Performance Optimization Patterns

### API Efficiency
- **Batched Operations**: Multiple inventory updates in single API call
- **Caching Strategy**: Client-side caching of frequently accessed data
- **Async Processing**: Non-blocking API calls with proper error handling
- **Connection Pooling**: Efficient HTTP connection management

### Godot Optimization
- **Node Pooling**: Reuse of debris objects for memory efficiency
- **Signal Optimization**: Proper signal disconnection on node cleanup
- **Resource Management**: Efficient loading and unloading of assets
- **State Machines**: Efficient state management for complex systems

## Inventory Validation Patterns (NEW)

### Multi-Layer Validation Architecture
**Prevents over-listing through comprehensive validation stack**

#### Layer 1: Active Listings Cache Pattern
```gdscript
# Real-time tracking of player's marketplace listings
var cached_listings: Array[Dictionary] = []         # All marketplace listings
var player_active_listings: Array[Dictionary] = []  # Player's own listings only
var listings_cache_timestamp: float = 0.0           # Cache freshness tracking
```

#### Layer 2: Enhanced Validation Pattern
```gdscript
# Compares inventory vs already-listed quantities
func can_sell_item_enhanced(item_type: String, quantity: int) -> Dictionary:
    var inventory_quantity = _get_inventory_quantity(inventory, item_type)
    var listed_quantity = get_player_listed_quantity(item_type)
    var available_to_list = inventory_quantity - listed_quantity
    return {"success": available_to_list >= quantity, "available_to_list": available_to_list}
```

#### Layer 3: Request Debouncing Pattern
```gdscript
# Prevents spam-clicking during API calls
var last_listing_request_time: float = 0.0
var listing_request_cooldown: float = 2.0
func can_make_listing_request() -> Dictionary:
    var time_since_last = Time.get_unix_time_from_system() - last_listing_request_time
    return {"success": time_since_last >= listing_request_cooldown}
```

#### Layer 4: Auto-Cache Update Pattern
```gdscript
# Ensures cache stays current after operations
func _handle_api_response(data: Dictionary, _response_code: int):
    if success:
        refresh_listings_for_validation()  # Auto-refresh cache
```

#### Layer 5: Server-Side Validation Pattern
```python
# Final safety check on backend
MAX_LISTED_QUANTITY_PER_ITEM = 50
existing_quantity = sum(listing["quantity"] for listing in current_listings
                       if listing["seller_id"] == seller_id and
                          listing["item_type"] == item_type)
if existing_quantity + quantity_to_list > MAX_LISTED_QUANTITY_PER_ITEM:
    return error_response()
```

### Enhanced UI Feedback Pattern
```gdscript
# Real-time display of available quantities
"AI Component (8 in inventory, 3 listed, 5 available)"
# Clear error messages with specific numbers
"Insufficient broken_satellite available for listing. Have 3 in inventory, 3 already listed, 0 available to list (need 1)"
```

## Code Quality Patterns

### Logging Strategy
- **Comprehensive Logging**: All major operations logged with context
- **Error Tracking**: Detailed error information for debugging
- **Performance Monitoring**: API call timing and response tracking
- **State Logging**: System state changes logged for troubleshooting

### Type Safety
- **Strict Typing**: All variables and function parameters typed
- **Validation**: Input validation at all system boundaries
- **Error Checking**: Comprehensive error checking throughout
- **Documentation**: Extensive inline documentation and comments
