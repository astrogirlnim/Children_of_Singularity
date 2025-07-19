# Children of the Singularity - Current Architecture

## 🎯 Architecture Overview (Updated - Local-First Implementation)

**Children of the Singularity** is now implemented with a **Local-First Architecture** that provides full offline functionality with optional backend connectivity for enhanced features.

## 🏗️ **Core Architecture: Dual-Mode System**

### **Development Mode:**
```
Godot Game → localhost:8000 → Python FastAPI → PostgreSQL
                ↓
         Full backend features
```

### **Release Mode (Local-First):**
```
Godot Game → LocalPlayerData.gd → JSON Files (user://)
                ↓
        Complete offline functionality
```

### **Production Mode (Future):**
```
Godot Game → AWS API Gateway → Lambda Functions → RDS PostgreSQL
                ↓
         Cloud-based trading only
```

---

## 📊 **Current System Status**

### ✅ **Working Components:**

1. **APIClient.gd (Dual-Mode)**
   - Auto-detects backend availability (2-second timeout)
   - Seamlessly falls back to local storage
   - Provides unified interface for all data operations
   - Supports: player data, inventory, credits, upgrades, zones

2. **LocalPlayerData.gd (Enhanced)**
   - Complete feature parity with backend API
   - JSON-based persistence to `user://` directory  
   - Handles: credits, inventory, upgrades, zone progression
   - Automatic saving with file operation locks

3. **Game Systems (Fully Functional)**
   - 3D space exploration with Mario Kart-style controls
   - Debris collection and inventory management
   - Credit system and upgrade purchasing
   - Zone progression and space station interactions
   - **Works completely offline in release builds**

4. **Backend Integration (Optional)**
   - FastAPI backend for development
   - PostgreSQL database with proper migrations
   - RESTful API endpoints for all game operations
   - Only used when explicitly available

### 🔄 **Planned Components:**

5. **AWS Serverless Trading (Future)**
   - API Gateway + Lambda for trading marketplace
   - RDS PostgreSQL for shared trading data
   - Local-first + cloud trading hybrid

---

## 📁 **Data Flow & Storage**

### **Local Storage (Primary):**
```
user://
├── player_save.json              # Credits, progress, player ID
├── player_inventory.json         # Items and quantities
├── player_upgrades.json          # Upgrade levels
├── player_settings.json          # Game preferences
└── trading_config.json           # API endpoints (when available)
```

### **Backend Storage (Development Only):**
```
PostgreSQL Database:
├── players                       # Player accounts
├── player_inventory              # Inventory items
├── player_upgrades              # Upgrade data
├── game_zones                   # Zone definitions
└── trading_marketplace          # Shared trading (future)
```

---

## 🔧 **Technical Implementation**

### **Dual-Mode Detection Logic:**
```gdscript
func _check_backend_availability() -> void:
    var test_request = HTTPRequest.new()
    add_child(test_request)
    test_request.timeout = 2.0
    test_request.request("http://localhost:8000/health")

    var response = await test_request.request_completed
    if response[1] == 200:
        use_local_storage = false  # Backend available
    else:
        use_local_storage = true   # Use local storage
```

### **Unified Interface Pattern:**
```gdscript
func load_player_data():
    if use_local_storage:
        _load_from_local_storage()
    else:
        _load_from_backend_api()
```

---

## 🚀 **Deployment Status**

### **✅ Current State:**
- **Development builds:** ✅ Working (with backend)
- **Release builds:** ✅ Working (offline-first)
- **Script compilation:** ✅ All errors fixed
- **Export templates:** ✅ Configured for Windows/macOS/Linux
- **Data persistence:** ✅ Local JSON + optional backend

### **🔄 Next Phase:**
- AWS serverless trading marketplace
- Multi-player trading features  
- Cloud save synchronization (optional)

---

## 💾 **Data Lifecycle Management**

### **Local Data:**
- **Size:** ~5-35 KB total (small JSON files)
- **Location:** Platform-specific `user://` directory
- **Cleanup:** Automatic removal on game uninstall
- **Privacy:** All data stored locally, no telemetry
- **Backup:** Users can manually copy JSON files

### **Cloud Data (Future):**
- **Trading only:** Marketplace listings and transactions
- **Optional:** Local-first remains primary data store
- **Sync:** Manual or automatic (user preference)

---

## 📋 **Key Features Implemented**

1. **🎮 Core Gameplay:**
   - Space exploration with 3D movement
   - Debris collection and inventory management
   - Credits system and upgrade progression
   - Zone-based world structure

2. **💾 Data Management:**
   - Local-first architecture (no internet required)
   - Optional backend integration for development
   - Automatic fallback system
   - File-based persistence

3. **🔧 Development Tools:**
   - `dev_start.sh` for full development environment
   - Hot-reload backend development
   - PostgreSQL database with migrations
   - RESTful API for testing

4. **📦 Release Ready:**
   - Complete offline functionality
   - Cross-platform export support
   - No external dependencies required
   - Self-contained JSON data storage

---

## 🎯 **Architecture Benefits**

### **For Players:**
- ✅ Works offline completely
- ✅ Fast, responsive local data
- ✅ No account required
- ✅ Privacy-focused (local storage)
- ✅ Reliable (no network dependencies)

### **For Developers:**  
- ✅ Simple deployment (no backend required)
- ✅ Easy testing and development
- ✅ Gradual cloud migration path
- ✅ Cost-effective (no server costs)
- ✅ Scalable architecture
