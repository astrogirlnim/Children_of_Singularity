# WebSocket Lobby Implementation Plan
## Retro 2D Trading Floor - Real-Time Multiplayer Scene

### 🎯 Executive Summary

This plan implements a **separate 2D retro lobby scene** that players transition to from the 3D world. When players press F at any TradingHub3D, they enter a pixel art "trading floor" where they can see other players as 2D sprites and interact with trading computers.

**Architecture**: 3D World → Scene Transition → 2D Lobby → WebSocket → Real-time player positions → Trading Interface

**Key Benefits**:
- 🎨 **Retro Contrast**: Beautiful pixel art lobby contrasts with 3D gameplay
- 🚀 **Serverless**: AWS API Gateway + Lambda + DynamoDB (<$2/month)
- ⚡ **Real-time**: Live player positions in 2D lobby with <100ms latency
- 🔧 **Simple Scope**: WebSocket only handles 2D lobby positions
- 🏗️ **Existing Assets**: All pixel art assets already created

---

## 📊 Current Architecture Integration

### ✅ Existing Systems (Leverage These)
```
TradingHub3D.gd         → F-key interaction detection
LocalPlayerData.gd      → Player ID and local data management
TradingMarketplace.gd   → Trading interface and AWS patterns
SceneTree              → Scene change management (get_tree().change_scene_to_file)
```

### 🆕 New 2D Lobby System (Add These)
```
3D World → TradingHub3D (Press F) → Scene Transition
    ↓              ↓                      ↓
PlayerShip3D → open_lobby_interface → LobbyZone2D.tscn
                                         ↓
                               WebSocket Connection
                                         ↓  
                              Real-time 2D positions
```

### 🎨 **Existing Assets** (Ready to Use)
```
documentation/design/trading_hub/
├── trading_hub_pixel_horizontal.png    # Lobby background (full screen)
├── schlorp_guy_sprite.png             # Player sprite in lobby  
└── computer_trading_hub_sprite.png    # Trading computer interaction
```

### 🔗 Integration Points
- **Player ID**: Use `LocalPlayerData.player_id` for consistent identity
- **Scene Transition**: Extend `TradingHub3D.gd` F-key interaction
- **Trading Interface**: Reuse existing `TradingMarketplace.gd` patterns
- **Exit Handling**: Off-screen movement with confirmation dialog

---

## 🏗️ Implementation Phases

### Phase 1: 2D Lobby Scene Creation
**Duration**: 1-2 days  
**Goal**: Create functional 2D lobby scene with local player movement

#### 📋 Tasks
1. **LobbyZone2D Scene Creation**
   - File: `scenes/zones/LobbyZone2D.tscn`
   - Background: `trading_hub_pixel_horizontal.png`
   - Player: `schlorp_guy_sprite.png` with WASD movement
   - Trading computer: `computer_trading_hub_sprite.png` with F-key interaction

2. **Scene Transition System**
   - Modify `scripts/TradingHub3D.gd`
   - Replace trading interface call with scene change
   - Add lobby entry/exit management

3. **2D Player Controller**
   - File: `scripts/LobbyPlayer2D.gd`
   - WASD movement matching 3D controls
   - Collision detection and boundaries
   - Off-screen exit detection

4. **Trading Computer Interaction**
   - File: `scripts/LobbyTradingComputer.gd`
   - F-key interaction like 3D hubs
   - Opens existing trading interface overlay

#### 🎯 Success Metrics
- [ ] LobbyZone2D scene loads without errors
- [ ] Player sprite moves smoothly with WASD
- [ ] Scene transitions work (3D ↔ 2D lobby)
- [ ] Trading computer interaction functional
- [ ] Off-screen exit with confirmation dialog

#### 🔧 Files Modified/Created
```
NEW: scenes/zones/LobbyZone2D.tscn           # Main 2D lobby scene
NEW: scripts/LobbyZone2D.gd                  # Lobby scene controller
NEW: scripts/LobbyPlayer2D.gd                # Local player movement in lobby
NEW: scripts/LobbyTradingComputer.gd         # Computer interaction
MODIFY: scripts/TradingHub3D.gd              # Add scene transition
```

---

### Phase 2: AWS WebSocket Infrastructure  
**Duration**: 1-2 days
**Goal**: Set up serverless WebSocket for 2D lobby positions only

#### 📋 Tasks
1. **DynamoDB Table Creation**
   - Table: `LobbyConnections`
   - Primary Key: `connectionId` (String)
   - Attributes: `player_id`, `x`, `y`, `ttl`
   - TTL enabled for auto-cleanup

2. **Lambda Function Development**
   - File: `backend/trading_lobby_ws.py`
   - Routes: `$connect`, `$disconnect`, `pos`, `$default`
   - Handles only 2D lobby position broadcasting

3. **API Gateway WebSocket Setup**
   - Create WebSocket API with route integrations
   - Configure CORS and rate limiting
   - Set up custom domain (optional)

4. **IAM Permissions**
   - Lambda execution role with DynamoDB access
   - `execute-api:ManageConnections` for broadcasting
   - Reuse existing S3 permissions pattern

#### 🎯 Success Metrics
- [ ] DynamoDB table created and accessible
- [ ] Lambda function deploys without errors
- [ ] WebSocket accepts connections from Godot
- [ ] Position broadcasting works between clients
- [ ] Automatic cleanup when players disconnect

#### 🔧 Files Modified/Created
```
NEW: backend/trading_lobby_ws.py             # Main Lambda function
NEW: infrastructure/lobby-trust-policy.json  # IAM trust policy
NEW: infrastructure/lobby-s3-policy.json     # S3 access policy
MODIFY: infrastructure_setup.env             # Add lobby environment variables
```

---

### Phase 3: WebSocket Client Integration
**Duration**: 2-3 days
**Goal**: Connect 2D lobby to WebSocket for real-time multiplayer

#### 📋 Tasks
1. **LobbyController Integration**
   - File: `scripts/LobbyController.gd`
   - WebSocket connection on lobby scene entry
   - Auto-disconnect on lobby scene exit
   - Position broadcast every 200ms

2. **Remote Player System**
   - File: `scripts/RemoteLobbyPlayer2D.gd`
   - Spawn/despawn remote players in lobby
   - Smooth position interpolation
   - Visual representation using `schlorp_guy_sprite.png`

3. **Connection Management**
   - Connect WebSocket when LobbyZone2D loads
   - Disconnect WebSocket when exiting lobby
   - Graceful handling of connection failures

4. **Position Synchronization**
   - Send local player position updates
   - Receive and apply remote player positions
   - Smooth interpolation for network lag

#### 🎯 Success Metrics  
- [ ] WebSocket connects automatically on lobby entry
- [ ] Player positions sync in real-time (<200ms latency)
- [ ] Remote players appear/disappear correctly
- [ ] Smooth movement interpolation (no jitter)
- [ ] Graceful disconnect on lobby exit

#### 🔧 Files Modified/Created
```
NEW: scripts/LobbyController.gd              # WebSocket client management
NEW: scripts/RemoteLobbyPlayer2D.gd         # Remote player representation  
MODIFY: scripts/LobbyZone2D.gd               # Add WebSocket integration
MODIFY: scripts/LobbyPlayer2D.gd             # Add position broadcasting
MODIFY: project.godot                        # Add LobbyController autoload
```

---

### Phase 4: Polish & Production Ready
**Duration**: 1-2 days
**Goal**: Polish experience and prepare for production deployment

#### 📋 Tasks
1. **Visual Polish**
   - Player sprite animations (walking/idle)
   - Trading computer interaction feedback
   - Lobby atmosphere (lighting, effects)
   - Smooth scene transitions with loading

2. **User Experience**
   - Loading indicator during scene transitions
   - Connection status display in lobby
   - Error handling for WebSocket failures
   - Confirmation dialog for lobby exit

3. **Performance Optimization**
   - Position update throttling
   - Connection pooling and retry logic
   - Optimize for 10+ concurrent players

4. **Production Deployment**
   - CloudWatch monitoring setup
   - Error tracking and alerting
   - CI/CD pipeline for updates

#### 🎯 Success Metrics
- [ ] Smooth scene transitions (<1 second)
- [ ] Supports 10+ concurrent lobby players
- [ ] Professional user experience
- [ ] Production monitoring dashboards
- [ ] Zero-downtime deployment capability

#### 🔧 Files Modified/Created
```
NEW: infrastructure/lobby-cloudformation.yaml  # Infrastructure as Code
NEW: scripts/monitoring/lobby-metrics.py       # Custom metrics
MODIFY: scripts/LobbyZone2D.gd                # Add polish and effects
NEW: .github/workflows/deploy-lobby.yml       # CI/CD pipeline
```

---

## 🔌 Technical Integration Details

### Scene Transition Flow
```gdscript
# In TradingHub3D.gd - Replace trading interface
func _attempt_interaction() -> void:
    if not can_interact or not current_npc_hub:
        return

    # Instead of opening trading interface overlay
    _transition_to_lobby()

func _transition_to_lobby() -> void:
    # Store 3D world state for return
    LobbyController.set_return_scene("res://scenes/zones/ZoneMain3D.tscn")
    LobbyController.set_return_position(player_ship.global_position)

    # Transition to 2D lobby
    get_tree().change_scene_to_file("res://scenes/zones/LobbyZone2D.tscn")
```

### WebSocket Message Protocol (2D Only)
```json
// Client → Server (2D Position Update)
{
  "action": "pos",
  "x": 156.5,
  "y": 240.3
}

// Server → Client (Remote Player Position)  
{
  "type": "pos",
  "id": "player_123",
  "x": 156.5,
  "y": 240.3
}

// Server → Client (Player Join/Leave)
{
  "type": "join",
  "id": "player_456"
}
```

### 2D Movement Integration
```gdscript
# In LobbyPlayer2D.gd - WASD movement like 3D
func _physics_process(delta):
    var input_vector = Vector2.ZERO

    if Input.is_action_pressed("move_right"):
        input_vector.x += 1
    if Input.is_action_pressed("move_left"):
        input_vector.x -= 1
    if Input.is_action_pressed("move_down"):
        input_vector.y += 1
    if Input.is_action_pressed("move_up"):
        input_vector.y -= 1

    # Apply movement
    velocity = input_vector.normalized() * speed
    move_and_slide()

    # Broadcast position to lobby
    if position_timer <= 0.0:
        LobbyController.send_position(global_position.x, global_position.y)
        position_timer = 0.2
    position_timer -= delta
```

### Off-Screen Exit Detection
```gdscript
# In LobbyZone2D.gd - Handle off-screen movement
func _process(delta):
    if player and _is_player_off_screen():
        _show_exit_confirmation()

func _is_player_off_screen() -> bool:
    var screen_size = get_viewport().get_visible_rect().size
    var pos = player.global_position
    return pos.x < 0 or pos.x > screen_size.x or pos.y < 0 or pos.y > screen_size.y

func _show_exit_confirmation():
    # Show dialog: "Exit lobby and return to space?"
    # On yes: return to 3D world
    # On no: move player back to lobby bounds
```

---

## 📈 Success Metrics & KPIs

### Phase 1 (2D Lobby Scene)
- ✅ Scene loads in <1 second
- ✅ WASD controls feel responsive
- ✅ Scene transitions work flawlessly

### Phase 2 (WebSocket Infrastructure)
- ✅ Lambda cold start time <1 second
- ✅ DynamoDB read/write latency <50ms
- ✅ WebSocket connection success rate >99%

### Phase 3 (Real-time Multiplayer)
- ✅ Position sync latency <200ms
- ✅ Support 10+ concurrent lobby players
- ✅ Zero crashes from network errors

### Phase 4 (Production Polish)
- ✅ Professional user experience
- ✅ 99.9% uptime SLA
- ✅ <$5/month operating costs

---

## 💰 Cost Analysis

### Monthly Operating Costs (20 players, 4 hours/day average)
```
API Gateway WebSocket: $0.50 (500K messages)
Lambda Invocations:    $0.10 (200K requests)  
Lambda Duration:       $0.08 (GB-seconds)
DynamoDB:             $0.15 (reads/writes)
CloudWatch Logs:      $0.05 (monitoring)
─────────────────────────────────────────
Total:                $0.88/month
```

**Scaling**: Even at 100 players with 8 hours/day = ~$4/month

---

## 🚀 Implementation Timeline

### Week 1: Foundation
- **Day 1-2**: Phase 1 - 2D Lobby Scene Creation
- **Day 3-4**: Phase 2 - AWS WebSocket Infrastructure  

### Week 2: Integration & Polish
- **Day 5-7**: Phase 3 - WebSocket Client Integration
- **Day 8-9**: Phase 4 - Polish & Production Ready
- **Day 10**: Testing & Deployment

---

## 🔧 Asset Integration

### Lobby Background Setup
```gdscript
# In LobbyZone2D.tscn
@onready var background: Sprite2D = $Background
func _ready():
    background.texture = preload("res://documentation/design/trading_hub/trading_hub_pixel_horizontal.png")
    # Set to screen size - background image defines lobby dimensions
```

### Player Sprite Configuration
```gdscript
# In LobbyPlayer2D.gd
@onready var sprite: Sprite2D = $Sprite2D
func _ready():
    sprite.texture = preload("res://documentation/design/trading_hub/schlorp_guy_sprite.png")
```

### Trading Computer Setup
```gdscript  
# In LobbyTradingComputer.gd
@onready var computer_sprite: Sprite2D = $ComputerSprite
func _ready():
    computer_sprite.texture = preload("res://documentation/design/trading_hub/computer_trading_hub_sprite.png")
```

---

## 📝 Development Best Practices

### Scope Management
- **WebSocket ONLY handles 2D lobby positions** (simplest approach)
- **No 3D/2D synchronization** - clean separation of concerns
- **Reuse existing patterns** from TradingMarketplace.gd
- **Graceful degradation** - lobby works offline, WebSocket adds multiplayer

### Error Handling
- **Scene transition failures** - fallback to trading interface overlay
- **WebSocket connection issues** - show offline mode in lobby
- **Network lag** - smooth interpolation for remote players
- **Asset loading** - proper error handling for missing sprites

### Testing Strategy  
- **Local testing** - 2D lobby works without WebSocket
- **Integration testing** - WebSocket with multiple clients
- **Performance testing** - 10+ concurrent players
- **Fallback testing** - Offline mode functionality

---

*"From 3D depths to 2D trading floors, connection across dimensions you will build. Retro and real-time, the perfect balance it is."*
