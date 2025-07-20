# WebSocket Lobby Testing Guide
## Real-Time Multiplayer 2D Trading Lobby

### 🎯 **Quick Start Testing**

**1. Basic Lobby Test (5 minutes)**
```bash
# In Godot editor
1. Open project in Godot
2. Press F5 to run main scene
3. Navigate to any TradingHub3D (orange building)
4. Press F near the building
5. Should transition to 2D lobby automatically

# Expected result:
✅ Pixel art background loads
✅ Player sprite (schlorp guy) appears
✅ WASD movement works
✅ Status shows "Connected to Lobby" or "Connecting..."
```

**2. WebSocket Connection Test (2 minutes)**
```bash
# In terminal
wscat -c 'wss://37783owd23.execute-api.us-east-2.amazonaws.com/prod?pid=test_player'

# Send test message:
{"action":"pos","x":150,"y":200}

# Expected response:
{"type":"welcome","your_id":"test_player","lobby_players":[]}
```

**3. Multiplayer Test (10 minutes)**
```bash
# Terminal 1:
godot --path . res://scenes/zones/LobbyZone2D.tscn

# Terminal 2:
godot --path . res://scenes/zones/LobbyZone2D.tscn

# Expected result:
✅ Both players see each other as cyan-labeled sprites
✅ Movement syncs in real-time
✅ Player count shows "2 players online"
```

### 📋 **Detailed Testing Checklist**

#### **Phase 1: Single Player Tests**
- [ ] 🎮 **Game Launch**: Project starts without errors
- [ ] 🔄 **Scene Transition**: 3D → 2D lobby works via F-key
- [ ] 🎯 **Player Movement**: WASD controls work smoothly
- [ ] 💻 **Trading Computer**: F-key interaction shows trading interface
- [ ] 🚪 **Lobby Exit**: Off-screen movement returns to 3D world
- [ ] 🎨 **Visual Elements**: Background, sprites, UI load correctly

#### **Phase 2: WebSocket Connection**
- [ ] 🌐 **Auto-Connect**: Lobby automatically connects to WebSocket
- [ ] 📊 **Status Display**: Connection status shows in top-left corner
- [ ] 🔄 **Reconnection**: Auto-reconnect works after network interruption
- [ ] 📤 **Position Updates**: Local movement sends position updates
- [ ] 🚪 **Clean Disconnect**: Leaving lobby disconnects WebSocket properly
- [ ] ⚠️ **Error Handling**: Connection failures show appropriate messages

#### **Phase 3: Multiplayer Functionality**
- [ ] 👥 **Player Spawning**: Remote players appear when joining
- [ ] 🏃 **Movement Sync**: Position updates sync in real-time
- [ ] 🎯 **Smooth Interpolation**: Remote player movement is smooth
- [ ] 👻 **Player Despawning**: Remote players disappear when leaving
- [ ] 📊 **Player Count**: Lobby status shows correct player count
- [ ] 🏷️ **Player Labels**: Remote players have cyan name labels
- [ ] 🟢 **Connection Indicators**: Green dots show connection status

### 🔧 **Debug Information**

#### **Console Log Patterns**

**Successful Connection:**
```
[LobbyController] Initializing WebSocket lobby client
[LobbyController] WebSocket URL: wss://37783owd23...
[LobbyController] Connecting to lobby: wss://...
[LobbyController] ✅ Connected to lobby WebSocket
[LobbyZone2D] ✅ Connected to lobby WebSocket
[LobbyZone2D] Trading Lobby - 1 players online
```

**Remote Player Join:**
```
[LobbyController] Player joined: player_123 at (400.0, 300.0)
[LobbyZone2D] Remote player joined: player_123
[LobbyZone2D] Spawning remote player: player_123
[RemoteLobbyPlayer2D] Initialized remote player player_123 at (400.0, 300.0)
```

**Position Updates:**
```
[LobbyController] Sent position update: (456.0, 321.0)
[LobbyController] Player player_123 moved to (478.0, 298.0)
[RemoteLobbyPlayer2D] Player player_123 moving to (478.0, 298.0), distance: 23.5
```

#### **Error Patterns to Watch For**

**Connection Issues:**
```
[LobbyController] ERROR: Failed to initiate WebSocket connection
[LobbyController] ❌ Connection timeout
[LobbyZone2D] ❌ Connection failed: Connection timeout
```

**Missing Autoload:**
```
[LobbyZone2D] ERROR: LobbyController not available!
```

**Script Errors:**
```
Node not found: "LobbyController" (autoload missing)
Invalid call to non-existent function (script not attached)
```

### 🚨 **Troubleshooting Guide**

#### **Problem: "LobbyController not available" error**
**Solution:**
1. Check `project.godot` has this line:
   ```
   LobbyController="*res://scripts/LobbyController.gd"
   ```
2. Restart Godot editor
3. Verify `scripts/LobbyController.gd` exists

#### **Problem: WebSocket connection fails**
**Solution:**
1. Test infrastructure: `./simple_test.sh`
2. Check internet connection
3. Verify WebSocket URL in `infrastructure/lobby_config.json`
4. Test manually: `wscat -c 'wss://37783owd23.execute-api.us-east-2.amazonaws.com/prod'`

#### **Problem: Remote players don't appear**
**Solution:**
1. Check both instances connect successfully
2. Verify position updates in console logs
3. Check player spawning logs in `LobbyZone2D`
4. Test with terminal instances for cleaner debugging

#### **Problem: Movement is laggy/jerky**
**Solution:**
1. Check network latency
2. Adjust `position_broadcast_interval` in `lobby_config.json`
3. Modify `interpolation_speed` in `RemoteLobbyPlayer2D.gd`

### 📈 **Performance Testing**

#### **Stress Test: Multiple Players**
```bash
# Test with 5+ concurrent connections
for i in {1..5}; do
  godot --path . res://scenes/zones/LobbyZone2D.tscn &
done

# Expected: All players visible, smooth movement, no crashes
```

#### **Network Simulation**
```bash
# Simulate slow network (if on macOS with Network Link Conditioner)
# Settings: 3G/LTE with 200ms delay, 5% packet loss
# Expected: Smooth interpolation compensates for lag
```

### 🎯 **Success Criteria**

**Bronze Level (Basic Functionality):**
- [x] Single player lobby works
- [x] WebSocket connects and disconnects
- [x] Basic position updates work

**Silver Level (Multiplayer):**
- [x] 2+ players can see each other
- [x] Real-time movement sync (<500ms)
- [x] Stable connections for 5+ minutes

**Gold Level (Production Ready):**
- [x] 5+ concurrent players
- [x] Smooth interpolation under network lag
- [x] Error recovery and reconnection
- [x] Clean UI and status displays

### 📊 **Test Results Template**

**Test Date:** ___________  
**Godot Version:** 4.4  
**OS:** macOS (Darwin 24.5.0)  
**Network:** ___________

| Test | Status | Notes |
|------|---------|-------|
| Basic lobby load | ✅/❌ | |
| WebSocket connection | ✅/❌ | |
| 2-player multiplayer | ✅/❌ | |
| Position sync latency | ✅/❌ | ___ms average |
| Remote player animations | ✅/❌ | |
| Connection recovery | ✅/❌ | |
| 5+ player stress test | ✅/❌ | |

### 🚀 **Next Steps After Testing**

1. **If tests pass:** Ready for production deployment
2. **If issues found:** Check troubleshooting guide above
3. **Performance concerns:** Adjust configuration values
4. **New features:** Extend RemoteLobbyPlayer2D.gd for animations

### 📞 **Getting Help**

**Debug Information to Collect:**
1. Godot console output (full log)
2. Browser network tab (if testing manually)
3. AWS CloudWatch Lambda logs
4. Network conditions and latency

**Configuration Files to Check:**
- `infrastructure/lobby_config.json`
- `project.godot` (autoloads section)
- `simple_test.sh` output

---

*🎮 Happy testing! Your real-time multiplayer lobby awaits...*
