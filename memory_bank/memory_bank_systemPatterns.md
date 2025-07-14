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
