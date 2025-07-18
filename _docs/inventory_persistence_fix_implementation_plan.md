# Inventory Persistence Fix Implementation Plan
**Children of the Singularity - Backend Integration Phase**

## Overview

This document outlines the implementation plan to fix inventory persistence issues where player inventory resets to zero upon game restart. The plan addresses both the immediate UUID format mismatch and the missing startup data loading functionality.

## Problem Statement

### Current Issues
1. **Primary Issue**: Game never loads existing inventory from database during startup
2. **Secondary Issue**: UUID format mismatch prevents database operations
3. **Result**: Players lose all collected items when restarting the game

### Root Cause Analysis
- **Missing Startup Loading**: Game initializes with `current_inventory.clear()` but never calls `load_inventory()`
- **UUID Mismatch**: Game uses `"player_001"` string, database expects UUID format
- **No Error Recovery**: Failed database operations have no fallback mechanism

### Evidence
```
ERROR: invalid input syntax for type uuid: "player_001"
```

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

## **Phase 2: Startup Inventory Loading System**
**Timeline**: 2-3 days  
**Priority**: High - Core persistence functionality

### Features

#### 2.1 Game Initialization Data Loading
**Files**: `ZoneMain3D.gd`, `ZoneMain.gd`

- **Add loading logic** to zone initialization
- **Connect API signals** for data reception
- **Implement loading state management**

**Implementation Details**:
```gdscript
func _initialize_3d_zone() -> void:
    # ... existing initialization ...

    # NEW: Load existing player data
    if api_client and player_ship:
        _load_player_data_from_backend()

func _load_player_data_from_backend() -> void:
    # Connect signals
    api_client.player_data_loaded.connect(_on_player_data_loaded)
    api_client.inventory_updated.connect(_on_inventory_loaded)

    # Load data
    api_client.load_player_data()
    api_client.load_inventory()
```

#### 2.2 Data Reception and Application
- **Process player data** (credits, upgrades, position)
- **Convert inventory format** from backend to game format
- **Update UI displays** with loaded data

**Data Flow**:
```
Database → Backend API → APIClient → ZoneMain3D → PlayerShip3D → UI
```

#### 2.3 Loading State Management
- **Track loading progress** for both player data and inventory
- **Handle loading completion** when all data is received
- **Manage loading timeouts** and error states

**Success Criteria**:
- ✅ Game loads existing inventory from database on startup
- ✅ Player credits and upgrades are restored
- ✅ UI displays correct inventory counts immediately

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
| `scripts/PlayerShip3D.gd` | Update player_id to UUID format | 1 |
| `scripts/PlayerShip.gd` | Update player_id to UUID format | 1 |
| `scripts/APIClient.gd` | Add UUID validation, error handling | 1, 3 |
| `scripts/ZoneMain3D.gd` | Add loading logic, state management | 2, 4 |
| `scripts/ZoneMain.gd` | Add loading logic (2D version) | 2 |

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
1. **Add items to inventory**
2. **Save game data**
3. **Restart game completely**
4. **Verify inventory persists**

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
- **Inventory Persistence**: 100% of items persist across restarts
- **Error Elimination**: 0 UUID format errors
- **Load Success Rate**: >95% successful data loads

### Secondary Goals
- **Load Time**: <2 seconds for data loading
- **User Experience**: Clear feedback during all operations
- **System Resilience**: Graceful handling of all error scenarios

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
