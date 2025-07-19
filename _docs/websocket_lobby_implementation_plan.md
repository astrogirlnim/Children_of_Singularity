# WebSocket Lobby Implementation Plan
## Serverless Real-Time Player Presence System

### 🎯 Executive Summary

This plan implements a **lightweight, fully serverless WebSocket lobby system** using AWS API Gateway + Lambda + DynamoDB. The system provides real-time "who's in the lobby and where they're standing" functionality while keeping all trading transactions on the existing REST marketplace.

**Architecture**: Game Client (Godot) → API Gateway WebSocket → Lambda Function → DynamoDB → Broadcast to all clients

**Key Benefits**:
- 🚀 **Serverless**: No EC2, auto-scaling from 1→10,000 players
- 💰 **Ultra-low cost**: <$2/month even with 50 players 24/7
- ⚡ **Real-time**: Live player positions with <100ms latency
- 🔧 **Simple**: Single Lambda function handles all routes
- 🏗️ **Minimal**: Uses existing infrastructure (S3 bucket, IAM roles)

---

## 📊 Current Architecture Integration

### ✅ Existing Systems (Leverage These)
```
LocalPlayerData.gd     → Player ID and local data management
TradingMarketplace.gd  → AWS integration patterns and HTTP clients  
NetworkManager.gd      → Multiplayer networking stubs (extend for WebSocket)
ZoneMain3D.gd         → 3D scene coordination and player management
PlayerShip3D.gd       → Player movement and position tracking
```

### 🆕 New WebSocket System (Add These)
```
Game Client → WSS API Gateway → Lambda Function → DynamoDB
     ↓              ↓               ↓            ↓
LobbyController  WebSocket API  trading_lobby_ws  LobbyConnections
   (New)         (New AWS)       (New Lambda)     (New Table)
```

### 🔗 Integration Points
- **Player ID**: Use `LocalPlayerData.player_id` for consistent identity
- **Position Sync**: Integrate with existing `PlayerShip3D` movement system  
- **UI Integration**: Extend existing UI systems in `ZoneUIManager.gd`
- **Error Handling**: Follow patterns from `TradingMarketplace.gd`

---

## 🏗️ Implementation Phases

### Phase 1: AWS Infrastructure Setup
**Duration**: 1-2 days  
**Goal**: Create serverless WebSocket infrastructure

#### 📋 Tasks
1. **DynamoDB Table Creation**
   - Table: `LobbyConnections`
   - Primary Key: `connectionId` (String)
   - Attributes: `player_id`, `x`, `y`, `ttl`
   - TTL enabled for auto-cleanup

2. **Lambda Function Development**
   - File: `backend/trading_lobby_ws.py`
   - Routes: `$connect`, `$disconnect`, `pos`, `$default`
   - Implement broadcast system for real-time updates

3. **API Gateway WebSocket Setup**
   - Create WebSocket API with route integrations
   - Configure CORS and rate limiting
   - Set up custom domain (optional)

4. **IAM Permissions**
   - Lambda execution role with DynamoDB access
   - `execute-api:ManageConnections` for broadcasting
   - S3 access (reuse existing trading permissions)

#### 🎯 Success Metrics
- [ ] DynamoDB table created and accessible
- [ ] Lambda function deploys without errors
- [ ] API Gateway WebSocket accepts connections
- [ ] Basic connect/disconnect events logged
- [ ] Broadcasting works between test connections

#### 🔧 Files Modified/Created
```
NEW: backend/trading_lobby_ws.py           # Main Lambda function
NEW: infrastructure/lobby-trust-policy.json  # IAM trust policy
NEW: infrastructure/lobby-s3-policy.json     # S3 access policy  
MODIFY: infrastructure_setup.env             # Add lobby environment variables
```

---

### Phase 2: Godot Client Integration
**Duration**: 2-3 days  
**Goal**: Create WebSocket client and integrate with existing game systems

#### 📋 Tasks
1. **LobbyController Autoload Creation**
   - File: `scripts/LobbyController.gd`
   - WebSocket connection management
   - Auto-reconnection and error handling
   - Integration with `LocalPlayerData.player_id`

2. **Player Position Synchronization**
   - Modify `scripts/PlayerShip3D.gd`
   - Send position updates every 200ms to lobby
   - Throttle updates to prevent spam

3. **Remote Player Visualization**
   - Create `scripts/RemoteLobbyPlayer.gd`
   - Spawn/despawn remote players in lobby
   - Show player nameplate and position

4. **UI Integration**
   - Extend `scripts/ZoneUIManager.gd`
   - Add lobby player list display
   - Connection status indicator

#### 🎯 Success Metrics  
- [ ] WebSocket connects successfully on game start
- [ ] Player positions sync in real-time (<200ms latency)
- [ ] Remote players visible when others join
- [ ] Graceful disconnect handling (no crashes)
- [ ] UI shows connected player count

#### 🔧 Files Modified/Created
```
NEW: scripts/LobbyController.gd              # WebSocket client autoload
NEW: scripts/RemoteLobbyPlayer.gd           # Remote player representation
NEW: scenes/lobby/RemoteLobbyPlayer.tscn    # Remote player scene
MODIFY: scripts/PlayerShip3D.gd              # Add position broadcasting  
MODIFY: scripts/ZoneUIManager.gd             # Add lobby UI elements
MODIFY: project.godot                        # Add LobbyController autoload
```

---

### Phase 3: Lobby Scene Implementation  
**Duration**: 2-3 days
**Goal**: Create dedicated lobby space with visual player representation

#### 📋 Tasks
1. **Lobby Scene Creation**
   - File: `scenes/zones/LobbyZone3D.tscn`
   - Lobby environment (space station interior)
   - Player spawn points and movement boundaries

2. **Trading Hub Integration**
   - Extend existing `scripts/TradingHub3D.gd`
   - Add lobby access point from main game
   - Seamless transition between lobby and trading

3. **Player Management System**
   - Handle player join/leave animations
   - Position validation and collision prevention
   - Graceful handling of disconnections

4. **Visual Polish**
   - Player indicator overlays (names, status)
   - Lobby ambient lighting and atmosphere
   - Smooth player movement interpolation

#### 🎯 Success Metrics
- [ ] Lobby scene loads without errors
- [ ] Players can enter/exit lobby seamlessly  
- [ ] Visual representation of all connected players
- [ ] Smooth position interpolation (no jitter)
- [ ] Trading computer accessible from lobby

#### 🔧 Files Modified/Created
```
NEW: scenes/zones/LobbyZone3D.tscn          # Main lobby scene
NEW: scripts/LobbyZone3D.gd                 # Lobby scene controller
MODIFY: scripts/TradingHub3D.gd              # Add lobby entrance
MODIFY: scenes/objects/TradingHub3D.tscn     # Add lobby portal
```

---

### Phase 4: Production Optimization
**Duration**: 1-2 days  
**Goal**: Optimize for production deployment and monitoring

#### 📋 Tasks
1. **Performance Optimization**
   - Implement position update throttling
   - Add connection pooling and retry logic
   - Optimize DynamoDB queries with pagination

2. **Monitoring and Logging**
   - CloudWatch dashboard for lobby metrics
   - Error tracking and alerting
   - Performance monitoring (latency, throughput)

3. **Security Hardening**
   - Rate limiting per connection
   - Input validation and sanitization
   - DDoS protection configuration

4. **Deployment Automation**
   - Infrastructure as Code (CloudFormation/CDK)
   - CI/CD pipeline for Lambda updates
   - Environment separation (dev/staging/prod)

#### 🎯 Success Metrics
- [ ] <100ms average message latency
- [ ] Supports 50+ concurrent players
- [ ] Zero security vulnerabilities
- [ ] Automated deployment pipeline
- [ ] Comprehensive monitoring dashboards

#### 🔧 Files Modified/Created
```
NEW: infrastructure/lobby-cloudformation.yaml  # Infrastructure as Code
NEW: scripts/monitoring/lobby-metrics.py       # Custom metrics
MODIFY: backend/trading_lobby_ws.py            # Add performance optimizations
NEW: .github/workflows/deploy-lobby.yml       # CI/CD pipeline
```

---

## 🔌 Technical Integration Details

### WebSocket Message Protocol
```json
// Client → Server (Position Update)
{
  "action": "pos",
  "x": 12.5,
  "y": 8.3
}

// Server → Client (Player Position)  
{
  "type": "pos",
  "id": "player_123",
  "x": 12.5,
  "y": 8.3
}

// Server → Client (Player Join)
{
  "type": "join",
  "id": "player_456"
}
```

### Position Sync Integration
```gdscript
# In PlayerShip3D.gd - Add position broadcasting
func _physics_process(delta):
    # ... existing movement code ...

    # Broadcast position to lobby every 200ms
    if position_timer <= 0.0:
        LobbyController.send_position(global_position.x, global_position.z)
        position_timer = 0.2
    position_timer -= delta
```

### Error Handling Pattern
```gdscript
# In LobbyController.gd - Follow TradingMarketplace.gd patterns
func _on_websocket_error(error: String):
    print("[LobbyController] WebSocket error: ", error)
    # Attempt reconnection after delay
    await get_tree().create_timer(5.0).timeout
    _attempt_reconnection()
```

---

## 📈 Success Metrics & KPIs

### Phase 1 (Infrastructure)
- ✅ Lambda cold start time <1 second
- ✅ DynamoDB read/write latency <50ms  
- ✅ API Gateway connection success rate >99%

### Phase 2 (Client Integration)  
- ✅ WebSocket connection time <2 seconds
- ✅ Position update frequency: 5 updates/second
- ✅ Zero client crashes from WebSocket errors

### Phase 3 (Lobby Scene)
- ✅ Scene transition time <1 second
- ✅ Visual position sync accuracy within 0.1 units
- ✅ Support 10+ concurrent lobby players

### Phase 4 (Production)
- ✅ 99.9% uptime SLA
- ✅ <$5/month operating costs
- ✅ Auto-scaling to 100+ players

---

## 💰 Cost Analysis

### Monthly Operating Costs (50 players, 8 hours/day)
```
API Gateway WebSocket: $1.00 (1M messages)
Lambda Invocations:    $0.20 (400K requests)  
Lambda Duration:       $0.15 (GB-seconds)
DynamoDB:             $0.30 (reads/writes)
CloudWatch Logs:      $0.10 (monitoring)
─────────────────────────────────────────
Total:                $1.75/month
```

**Scaling**: Even at 200 players 24/7 = ~$8/month

---

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] AWS CLI configured with appropriate permissions
- [ ] S3 bucket exists (reuse existing `children-of-singularity-releases`)
- [ ] Domain name configured (optional)
- [ ] Load testing completed

### Deployment Steps
```bash
# 1. Deploy AWS infrastructure
aws cloudformation deploy --template-file lobby-cloudformation.yaml

# 2. Deploy Lambda function
zip -r lobby-function.zip backend/trading_lobby_ws.py
aws lambda update-function-code --function-name lobby-websocket

# 3. Update Godot configuration
# Edit user://lobby_config.json with WebSocket endpoint

# 4. Test connection
wscat -c wss://your-api-id.execute-api.region.amazonaws.com/prod
```

### Post-Deployment Verification
- [ ] WebSocket endpoint responds to connections
- [ ] DynamoDB table receiving player data
- [ ] CloudWatch logs showing activity
- [ ] Game client connects successfully

---

## 🔧 Integration with Existing Systems

### Leverage Current Infrastructure
- **S3 Bucket**: Reuse `children-of-singularity-releases` for deployment artifacts
- **IAM Roles**: Extend existing Lambda execution role for DynamoDB access
- **Monitoring**: Integrate with existing CloudWatch setup
- **CI/CD**: Extend current deployment pipeline

### Godot Integration Patterns
- **Autoload Pattern**: Follow `TradingMarketplace.gd` and `LocalPlayerData.gd` patterns
- **Signal Architecture**: Use existing signal-based communication
- **Error Handling**: Match error handling patterns from trading system
- **Configuration**: Use `user://` directory pattern for WebSocket endpoints

### Minimal Code Changes
- **Zero changes** to existing trading REST API
- **Minimal changes** to `PlayerShip3D.gd` (just position broadcasting)
- **Additive changes** to UI systems (extend, don't replace)
- **Optional feature** (game works without lobby if WebSocket fails)

---

## 📝 Implementation Notes

### Phase Dependencies
```
Phase 1 → Phase 2 → Phase 3 → Phase 4
   ↓         ↓         ↓         ↓
 AWS       Godot     Lobby     Polish
Setup    Integration Scene   & Deploy
```

### Risk Mitigation
- **Fallback**: Game functions fully without lobby (graceful degradation)
- **Testing**: Each phase has isolated testing before integration
- **Rollback**: Infrastructure changes are reversible
- **Monitoring**: Early warning systems for production issues

### Development Best Practices
- **Logging**: Comprehensive logging at every integration point
- **Error Handling**: Never crash game due to lobby failures
- **Configuration**: All endpoints configurable via JSON files
- **Testing**: Unit tests for Lambda function, integration tests for client

---

*"Simple in concept, powerful in execution - a lobby that brings players together you will build. Serverless and swift, the path to connection it is."*
