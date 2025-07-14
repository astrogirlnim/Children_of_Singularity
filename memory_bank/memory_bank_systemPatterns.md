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

## Networking Architecture
```
Client (Godot) <--ENet--> Server (Godot) <--HTTP--> Backend (FastAPI) <--> Database (PostgreSQL)
```

## Data Flow Patterns
1. **Input Processing**: Client → Server → Validation → State Update → Broadcast
2. **Persistence**: Server → Backend API → Database
3. **AI Interactions**: Game Events → Backend → AI Processing → Voice Synthesis → Client

## Error Handling Strategy
- Graceful degradation for network issues
- Comprehensive logging at all system levels
- Fallback mechanisms for missing resources
- User-friendly error messages 