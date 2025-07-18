# Game Data Persistence Fix Implementation Plan
**Children of the Singularity - Complete Backend Integration Phase**

## Overview

This document outlines the implementation plan to fix game data persistence issues where player inventory, upgrades, credits, and progress reset upon game restart. The plan addresses both the immediate UUID format mismatch and the missing startup data loading functionality.

## Problem Statement

### Current Issues
1. **Primary Issue**: Game never loads existing data from database during startup
   - Inventory resets to empty (0/10 items)
   - Upgrades reset to "No upgrades purchased"
   - Credits reset to 0
   - All progress is lost
2. **Secondary Issue**: UUID format mismatch prevents database operations
3. **Result**: Players lose ALL progress when restarting the game

### Root Cause Analysis
- **Missing Startup Loading**: Game initializes with defaults but never loads from database
  - `current_inventory.clear()` but never calls `load_inventory()`
  - `upgrades = {...}` hardcoded defaults, never calls `load_player_data()`
  - `credits = 0` default, never restored from database
- **UUID Mismatch**: Game uses `"player_001"` string, database expects UUID format
- **No Error Recovery**: Failed database operations have no fallback mechanism
- **No Loading Integration**: Zone initialization doesn't include data loading step

### Evidence
```
ERROR: invalid input syntax for type uuid: "player_001"
```

### What Currently Works
✅ **Saving**: Upgrades and inventory ARE saved to database correctly  
✅ **Purchase Flow**: All transactions work and persist to database  
✅ **API Endpoints**: Backend correctly stores all player data  
✅ **Immediate Effects**: Phase 4B upgrade effects apply instantly after purchase  
✅ **Visual Feedback**: All upgrade visual effects work (speed particles, capacity indicators)  
❌ **Loading**: Game never retrieves saved data on startup  
❌ **Persistence**: All progress lost on game restart

### Connection to Phase 4B Implementation
**Phase 4B: Real-time Effect Application** is COMPLETE and working perfectly. The issue you're experiencing is the **missing next step**: Phase 4B+ (Upgrade Effect Persistence).

The current situation:
- ✅ **Within Session**: Upgrades work perfectly, effects apply immediately
- ❌ **Between Sessions**: All progress is lost because game doesn't load from database

This plan implements the missing persistence layer that makes Phase 4B effects survive game restarts.

## Implementation Plan

---

## **Phase 1: Critical Database Connection Fix**
**Timeline**: 1-2 days  
**Priority**: Critical - Blocking all database operations

### Features

#### 1.1 Player ID Format Standardization
**Files**: `PlayerShip3D.gd`, `PlayerShip.gd`, `APIClient.gd`

- **Update player ID system** to use existing test UUIDs
- **Create ID mapping function** for backward compatibility
- **Add UUID validation** to prevent format errors

**Implementation Details**:
```gdscript
# Replace hardcoded string IDs with valid UUIDs
var player_id: String = "550e8400-e29b-41d4-a716-446655440000"

# Add validation function
func _is_valid_uuid(id: String) -> bool:
    var uuid_pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    return id.length() == 36 and id.match(uuid_pattern)
```

#### 1.2 Database Connection Testing
- **Verify upgrade purchase endpoint** works with UUID fix
- **Test inventory add/retrieve operations**
- **Validate all API endpoints** return 200 status codes

**Success Criteria**:
- ✅ All API endpoints accept UUID player IDs
- ✅ No more "invalid input syntax for type uuid" errors
- ✅ Database operations complete successfully

---

## **Phase 2: Complete Game Data Loading System**
**Timeline**: 2-3 days  
**Priority**: High - Core persistence functionality

### Features

#### 2.1 Game Initialization Data Loading
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`, `PlayerShip3D.gd`, `PlayerShip.gd`

- **Add loading logic** to zone initialization
- **Connect API signals** for data reception
- **Implement loading state management**
- **Load ALL player data**: inventory, upgrades, credits, position

**Implementation Details**:
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

#### 2.2 Player Data Reception and Application
- **Process player data** (credits, upgrades, position)
- **Apply loaded upgrades** using existing upgrade system
- **Restore upgrade effects** (speed boosts, inventory capacity, etc.)
- **Update UI displays** with loaded data

**Enhanced Implementation**:
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

#### 2.3 Inventory Data Reception and Application
- **Convert inventory format** from backend to game format
- **Restore inventory items** to player ship
- **Update inventory UI** with correct counts

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

#### 2.4 Loading State Management
- **Track loading progress** for all data types
- **Handle loading completion** when all data is received
- **Manage loading timeouts** and error states
- **Show loading UI** during data retrieval

**Data Flow**:
```
Database → Backend API → APIClient → ZoneMain3D → PlayerShip3D → UpgradeSystem → UI
```

#### 2.5 PlayerShip Initialization Order Fix
**Files**: `PlayerShip3D.gd`, `PlayerShip.gd`

- **Modify `_initialize_player_state()`** to NOT clear data if loading
- **Add loading flag** to prevent premature defaults
- **Ensure upgrade effects apply** after loading

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

**Success Criteria**:
- ✅ Game loads existing inventory from database on startup
- ✅ Player credits are restored correctly
- ✅ All purchased upgrades are restored with their effects active
- ✅ Upgrade catalog shows correct levels ("Level 2/5" instead of "Level 0/5")
- ✅ Ship speed, inventory capacity, and other upgrade effects work immediately
- ✅ UI displays correct data immediately without requiring user action

---

## **Phase 3: Error Handling and Resilience**
**Timeline**: 1-2 days  
**Priority**: Medium - System robustness

### Features

#### 3.1 Database Connection Error Handling
**Files**: `APIClient.gd`, `ZoneMain3D.gd`

- **Detect connection failures** and timeout scenarios
- **Implement retry logic** with exponential backoff
- **Log detailed error information** for debugging

#### 3.2 Graceful Degradation System
- **Fallback to default values** when backend is unavailable
- **Continue game functionality** without database connection
- **Notify player** of offline mode status

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

#### 3.3 Data Integrity Validation
- **Validate loaded data** format and ranges
- **Detect corrupted inventory** items
- **Clean invalid data** before application

**Success Criteria**:
- ✅ Game starts successfully even when backend is down
- ✅ Players can continue playing in offline mode
- ✅ No crashes from malformed data

---

## **Phase 4: User Experience Enhancements**
**Timeline**: 1 day  
**Priority**: Medium - Player feedback

### Features

#### 4.1 Loading Status Display
**Files**: `ZoneMain3D.gd`, UI components

- **Show loading message** during data fetch
- **Display progress indicators** for loading states
- **Hide loading UI** when complete

#### 4.2 Connection Status Indicators
- **Visual indicators** for online/offline mode
- **Error messages** for failed connections
- **Success confirmations** for data loading

#### 4.3 Debug Information Enhancement
- **Detailed logging** for loading process
- **Debug panel** showing loading status
- **Performance metrics** for load times

**Success Criteria**:
- ✅ Players see clear feedback during loading
- ✅ Connection status is always visible
- ✅ Debug information helps with troubleshooting

---

## **Phase 5: Enhanced Persistence Features**
**Timeline**: 2-3 days  
**Priority**: Low - Advanced functionality

### Features

#### 5.1 Auto-Save System
**Files**: `ZoneMain3D.gd`, `PlayerShip3D.gd`

- **Periodic auto-save** every 30 seconds
- **Event-triggered saves** on inventory changes
- **Position sync** with backend

#### 5.2 Session Recovery
- **Detect abnormal shutdowns** using session tracking
- **Restore unsaved progress** where possible
- **Conflict resolution** for simultaneous sessions

#### 5.3 Data Synchronization
- **Real-time sync** for multiplayer readiness
- **Conflict detection** for concurrent modifications
- **Merge strategies** for inventory conflicts

**Success Criteria**:
- ✅ Minimal data loss during unexpected shutdowns
- ✅ Smooth transition between game sessions
- ✅ Foundation ready for multiplayer features

---

## Technical Implementation Details

### File Modification Summary

| File | Changes | Phase |
|------|---------|-------|
| `scripts/PlayerShip3D.gd` | Update player_id to UUID, fix initialization order, add loading flag | 1, 2 |
| `scripts/PlayerShip.gd` | Update player_id to UUID, fix initialization order, add loading flag | 1, 2 |
| `scripts/APIClient.gd` | Add UUID validation, error handling | 1, 3 |
| `scripts/ZoneMain3D.gd` | Add complete data loading logic, upgrade restoration, state management | 2, 4 |
| `scripts/ZoneMain.gd` | Add complete data loading logic, upgrade restoration (2D version) | 2 |
| `scripts/UpgradeSystem.gd` | Ensure upgrade effects apply correctly after loading | 2 |

### Database Schema Dependencies
- **Current**: Uses UUID primary keys (correct)
- **Sample Data**: Existing test UUIDs available
- **No Changes Needed**: Database schema is properly designed

### API Endpoint Verification
- `GET /api/v1/players/{player_id}` - Load player data
- `GET /api/v1/players/{player_id}/inventory` - Load inventory
- `POST /api/v1/players/{player_id}` - Save player data
- `POST /api/v1/players/{player_id}/inventory` - Add inventory item

## Testing Strategy

### Phase 1 Testing
1. **Start backend server**
2. **Test upgrade purchase** with new UUID format
3. **Verify no UUID errors** in logs
4. **Test all API endpoints** manually

### Phase 2 Testing
1. **Collect debris and earn credits**
2. **Purchase multiple upgrades** (speed boost, inventory expansion)
3. **Add items to inventory**
4. **Note all current stats** (credits, upgrade levels, inventory count, ship speed)
5. **Save game data** (should happen automatically)
6. **Restart game completely**
7. **Verify ALL data persists**:
   - ✅ Credits match previous session
   - ✅ Upgrades show correct levels in BUY tab
   - ✅ Upgrade effects are active (ship speed boosted, inventory capacity expanded)
   - ✅ Inventory items are restored
   - ✅ UI shows correct data immediately

### Phase 3 Testing
1. **Start game with backend down**
2. **Verify graceful fallback**
3. **Test with corrupted data**
4. **Verify error handling**

### Integration Testing
1. **Full play session** with saves and loads
2. **Network interruption scenarios**
3. **Multiple restart cycles**
4. **Performance testing** for load times

## Success Metrics

### Primary Goals
- **Complete Data Persistence**: 100% of progress persists across restarts
  - Inventory items persist (0% data loss)
  - Upgrade levels persist with effects active
  - Credits persist accurately
  - All UI displays correct data immediately
- **Error Elimination**: 0 UUID format errors
- **Load Success Rate**: >95% successful data loads

### Secondary Goals
- **Load Time**: <2 seconds for complete data loading
- **User Experience**: Clear feedback during all operations
- **System Resilience**: Graceful handling of all error scenarios
- **Upgrade Effect Integrity**: All upgrade effects (speed, capacity, etc.) work immediately after loading

## Risk Assessment

### High Risk
- **Database Connection Issues**: Could block all progress
- **Data Format Incompatibility**: Could corrupt existing saves

### Medium Risk
- **Performance Impact**: Loading could slow game startup
- **UI Complexity**: Loading states could confuse players

### Low Risk
- **Feature Scope Creep**: Auto-save features are nice-to-have
- **Testing Coverage**: May miss edge cases

## Rollout Strategy

### Development Environment
1. **Implement Phase 1** (UUID fix)
2. **Test thoroughly** with existing database
3. **Implement Phase 2** (loading system)
4. **Validate full cycle** works

### Quality Assurance
1. **Test all scenarios** from testing strategy
2. **Performance validation** for load times
3. **Error scenario testing**

### Production Deployment
1. **Deploy backend changes** first
2. **Deploy client changes** second
3. **Monitor error logs** closely
4. **Have rollback plan** ready

## Dependencies

### Internal Dependencies
- **Backend API** must be running and accessible
- **Database** must have valid test data
- **Game scenes** must be properly configured

### External Dependencies
- **PostgreSQL database** connection
- **Network connectivity** for API calls
- **Godot 4.4** HTTP request capabilities

## Timeline Summary

| Phase | Duration | Dependencies | Deliverables |
|-------|----------|--------------|--------------|
| Phase 1 | 1-2 days | None | UUID format fix |
| Phase 2 | 2-3 days | Phase 1 | Loading system |
| Phase 3 | 1-2 days | Phase 2 | Error handling |
| Phase 4 | 1 day | Phase 2 | UI enhancements |
| Phase 5 | 2-3 days | Phase 3 | Auto-save features |

**Total Estimated Duration**: 7-11 days

## Conclusion

This implementation plan addresses the root causes of inventory persistence issues through a systematic, phased approach. The plan prioritizes critical database connection fixes first, then builds robust loading and error handling systems. The final phases add user experience enhancements and advanced features that prepare the system for future multiplayer functionality.

The plan balances immediate problem resolution with long-term system architecture improvements, ensuring both quick fixes and sustainable solutions.
