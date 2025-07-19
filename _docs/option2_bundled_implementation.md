# Option 2: Bundled Backend Implementation Guide

## 🎯 Complete Implementation for Bundled Backend

This guide shows exactly how to package the Python backend with game releases.

---

## 📦 **Phase 1: Backend Packaging**

### **1.1 Create Standalone Backend Executable**

```bash
# scripts/build_backend.sh
#!/bin/bash

echo "🔧 Building standalone backend executable..."

cd backend

# Install packaging tools
pip install pyinstaller nuitka

# Option A: PyInstaller (easier, larger)
pyinstaller \
    --onefile \
    --name "game-backend" \
    --add-data "migrations:migrations" \
    --add-data "../data/postgres:data" \
    --hidden-import uvicorn.workers \
    --hidden-import uvicorn.lifespan.on \
    --hidden-import sqlalchemy.dialects.sqlite \
    --hidden-import sqlalchemy.pool \
    --exclude-module tkinter \
    --exclude-module matplotlib \
    app.py

# Option B: Nuitka (faster, smaller, but more complex)
# nuitka --onefile --include-data-dir=migrations=migrations app.py

echo "✅ Backend executable created: dist/game-backend"
```

### **1.2 SQLite Database Migration**

```python
# backend/bundled_mode.py
import os
import sqlite3
from sqlalchemy import create_engine, text
from pathlib import Path

def setup_bundled_database():
    """Initialize SQLite database for bundled mode"""

    # Determine if we're in bundled mode
    bundled_mode = getattr(sys, 'frozen', False)

    if bundled_mode:
        # Running as PyInstaller bundle
        app_dir = Path(sys.executable).parent
        db_path = app_dir / "game_data.db"
    else:
        # Development mode
        db_path = Path("game_data.db")

    print(f"🗄️  Database location: {db_path}")

    # Create database if it doesn't exist
    if not db_path.exists():
        print("📝 Creating new game database...")
        create_fresh_database(db_path)

    return f"sqlite:///{db_path}"

def create_fresh_database(db_path: Path):
    """Create SQLite database with game schema"""

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Create tables
    cursor.executescript("""
        CREATE TABLE players (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            credits INTEGER DEFAULT 100,
            progression_path TEXT,
            position_x REAL DEFAULT 0,
            position_y REAL DEFAULT 0,
            position_z REAL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE inventory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id TEXT NOT NULL,
            item_type TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            metadata TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (player_id) REFERENCES players (id)
        );

        CREATE TABLE upgrades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id TEXT NOT NULL,
            upgrade_type TEXT NOT NULL,
            level INTEGER NOT NULL DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (player_id) REFERENCES players (id)
        );

        CREATE INDEX idx_inventory_player ON inventory(player_id);
        CREATE INDEX idx_upgrades_player ON upgrades(player_id);
    """)

    conn.commit()
    conn.close()
    print("✅ Database schema created")
```

### **1.3 Modified App for Bundled Mode**

```python
# backend/app.py (modified for bundling)
import sys
import os
from pathlib import Path
from bundled_mode import setup_bundled_database

# Determine database configuration
if getattr(sys, 'frozen', False):
    # Running as bundled executable
    DATABASE_URL = setup_bundled_database()
    print(f"🎮 Game Backend starting in BUNDLED mode")
    print(f"📦 Executable location: {sys.executable}")
else:
    # Development mode
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://...")
    print(f"💻 Game Backend starting in DEVELOPMENT mode")

# Rest of FastAPI app remains the same...
app = FastAPI(
    title="Children of the Singularity - Bundled API",
    description="Embedded REST API for local gameplay",
    version="1.0.0-bundled",
)

# Add special bundled mode endpoint
@app.get("/api/v1/bundled-info")
async def bundled_info():
    """Information about bundled mode"""
    return {
        "mode": "bundled",
        "executable": sys.executable if hasattr(sys, 'frozen') else None,
        "database": DATABASE_URL,
        "version": "1.0.0-bundled"
    }
```

---

## 🚀 **Phase 2: Game Integration**

### **2.1 Backend Launcher Script**

```gd
# scripts/BackendLauncher.gd
extends Node

signal backend_ready()
signal backend_failed(error: String)

var backend_process: int = -1
var backend_port: int = 8000
var max_startup_time: float = 30.0
var health_check_interval: float = 0.5

func _ready():
    print("🔧 BackendLauncher: Initializing...")

func start_bundled_backend() -> void:
    print("🚀 Starting bundled backend...")

    # Find backend executable
    var backend_path = _find_backend_executable()
    if backend_path.is_empty():
        backend_failed.emit("Backend executable not found")
        return

    # Find available port
    backend_port = _find_available_port()

    # Start backend process
    var args = [
        "--port", str(backend_port),
        "--host", "127.0.0.1",
        "--no-access-log"  # Reduce console spam
    ]

    print("🎮 Launching: %s %s" % [backend_path, " ".join(args)])

    backend_process = OS.create_process(backend_path, args)

    if backend_process == -1:
        backend_failed.emit("Failed to start backend process")
        return

    print("✅ Backend process started (PID: %d)" % backend_process)

    # Wait for backend to be ready
    _wait_for_backend_ready()

func _find_backend_executable() -> String:
    # Look for backend executable in various locations
    var possible_paths = [
        "backend/game-backend",      # Linux/macOS
        "backend/game-backend.exe",  # Windows
        "./game-backend",            # Same directory
        "./game-backend.exe"         # Same directory Windows
    ]

    for path in possible_paths:
        if FileAccess.file_exists(path):
            print("📍 Found backend at: %s" % path)
            return path

    print("❌ Backend executable not found in expected locations")
    return ""

func _find_available_port() -> int:
    # Try ports 8000-8010 to avoid conflicts
    for port in range(8000, 8011):
        if _is_port_available(port):
            print("🔌 Using port: %d" % port)
            return port

    print("⚠️  No available ports found, using default 8000")
    return 8000

func _is_port_available(port: int) -> bool:
    # Simple port check - try to connect
    var tcp = TCPServer.new()
    var result = tcp.listen(port)
    tcp.stop()
    return result == OK

func _wait_for_backend_ready():
    print("⏳ Waiting for backend to be ready...")

    var start_time = Time.get_time_dict_from_system()
    var http_request = HTTPRequest.new()
    add_child(http_request)

    var check_timer = Timer.new()
    add_child(check_timer)
    check_timer.wait_time = health_check_interval
    check_timer.timeout.connect(_check_backend_health.bind(http_request, start_time))
    check_timer.start()

func _check_backend_health(http_request: HTTPRequest, start_time: Dictionary):
    var current_time = Time.get_time_dict_from_system()
    var elapsed = _time_diff(start_time, current_time)

    if elapsed > max_startup_time:
        backend_failed.emit("Backend startup timeout")
        return

    # Test health endpoint
    var url = "http://127.0.0.1:%d/api/v1/health" % backend_port
    http_request.request(url)

    await http_request.request_completed

    var response_code = http_request.get_http_client_status()
    if response_code == HTTPClient.STATUS_CONNECTED:
        print("✅ Backend is ready!")
        backend_ready.emit()
        get_child(1).stop()  # Stop timer
    else:
        print("⏳ Backend not ready yet... (%.1fs elapsed)" % elapsed)

func stop_backend():
    if backend_process != -1:
        print("🛑 Stopping backend process...")
        OS.kill(backend_process)
        backend_process = -1

func _time_diff(start: Dictionary, end: Dictionary) -> float:
    # Simple time difference calculation
    var start_seconds = start.hour * 3600 + start.minute * 60 + start.second
    var end_seconds = end.hour * 3600 + end.minute * 60 + end.second
    return end_seconds - start_seconds
```

### **2.2 Modified Main Scene**

```gd
# scripts/ZoneMain3D.gd (modified)
extends Node3D

@onready var backend_launcher: Node = $BackendLauncher
@onready var api_client: Node = $APIClient

var backend_ready: bool = false

func _ready():
    print("🎮 ZoneMain3D: Starting game initialization...")

    # Check if we need to start bundled backend
    if _is_bundled_release():
        _start_bundled_mode()
    else:
        _start_development_mode()

func _is_bundled_release() -> bool:
    # Check if backend executable exists (indicates bundled release)
    return FileAccess.file_exists("backend/game-backend") or \
           FileAccess.file_exists("backend/game-backend.exe")

func _start_bundled_mode():
    print("📦 Detected bundled release mode")

    backend_launcher.backend_ready.connect(_on_backend_ready)
    backend_launcher.backend_failed.connect(_on_backend_failed)

    # Show loading screen while backend starts
    _show_loading_screen("Starting game systems...")

    backend_launcher.start_bundled_backend()

func _start_development_mode():
    print("💻 Detected development mode")
    backend_ready = true
    _initialize_game_systems()

func _on_backend_ready():
    print("✅ Backend ready, starting game...")
    backend_ready = true

    # Update API client with correct port
    api_client.base_url = "http://127.0.0.1:%d/api/v1" % backend_launcher.backend_port

    _hide_loading_screen()
    _initialize_game_systems()

func _on_backend_failed(error: String):
    print("❌ Backend failed to start: %s" % error)

    # Fallback to local-only mode
    _show_error_dialog(
        "Game Backend Error",
        "Could not start game systems. The game will run in offline mode with limited functionality."
    )

    # Switch API client to local mode
    api_client.use_local_storage = true
    _initialize_game_systems()

func _exit_tree():
    # Clean shutdown
    if backend_launcher and backend_ready:
        backend_launcher.stop_backend()
```

---

## 🔧 **Phase 3: Build System Integration**

### **3.1 Enhanced Build Script**

```bash
# build.sh (enhanced for bundled backend)

build_bundled_release() {
    print_status "INFO" "Building bundled release with embedded backend..."

    # Step 1: Build backend executable
    print_status "INFO" "Building backend executable..."
    cd backend

    # Install Python dependencies
    pip install -r requirements.txt pyinstaller

    # Create backend executable
    pyinstaller \
        --onefile \
        --name "game-backend" \
        --distpath "../builds/backend" \
        --workpath "../builds/temp" \
        --add-data "migrations:migrations" \
        --hidden-import uvicorn.workers \
        --hidden-import sqlalchemy.dialects.sqlite \
        app.py

    cd ..

    if [ ! -f "builds/backend/game-backend" ]; then
        print_status "ERROR" "Backend build failed"
        exit 1
    fi

    print_status "SUCCESS" "Backend executable created"

    # Step 2: Export Godot game with backend
    mkdir -p builds/bundled

    # Copy backend to game directory
    cp builds/backend/game-backend* builds/bundled/

    # Export Godot game
    if godot --headless --export-release "macOS" builds/bundled/Children_of_Singularity.app; then
        print_status "SUCCESS" "Bundled macOS build completed"
    else
        print_status "ERROR" "Godot export failed"
        exit 1
    fi

    # Step 3: Package everything together
    cd builds/bundled

    # Create app bundle structure for macOS
    mkdir -p "Children_of_Singularity.app/Contents/MacOS/backend"
    cp game-backend "Children_of_Singularity.app/Contents/MacOS/backend/"

    # Create final distribution
    tar -czf "../Children_of_Singularity_Bundled_macOS.tar.gz" Children_of_Singularity.app

    print_status "SUCCESS" "Bundled release package created: builds/Children_of_Singularity_Bundled_macOS.tar.gz"
}

# Add bundled option to build commands
case $1 in
    "bundled")
        build_bundled_release
        ;;
    "dev"|"run")
        dev_run
        ;;
    # ... existing cases
esac
```

### **3.2 Distribution Structure**

```
Final Distribution:
Children_of_Singularity.app/
├── Contents/
│   ├── MacOS/
│   │   ├── Children_of_Singularity     # Main game executable
│   │   └── backend/
│   │       └── game-backend           # Bundled Python backend
│   └── Resources/
│       └── # Game assets, data files
├── README.txt                         # Installation instructions
└── LICENSE.txt
```

---

## 📊 **Comparison Summary**

| Aspect | Option 1 (Local-First) | Option 2 (Bundled Backend) |
|--------|-------------------------|------------------------------|
| **Implementation Time** | 1-2 weeks | 3-4 weeks |
| **Complexity** | Medium | High |
| **Performance** | Excellent (local files) | Good (local API) |
| **Distribution Size** | ~50MB | ~80-100MB |
| **Startup Time** | 2-3 seconds | 5-8 seconds |
| **Maintenance** | Medium | High |
| **Debugging** | Easy | Complex |
| **Consistency** | Different storage modes | Same API everywhere |
| **Cloud Sync Ready** | Requires additional work | Easy to add |
| **Analytics** | Limited | Full capability |
| **Offline Capability** | Yes | No (needs local backend) |

---

## 🎯 **Final Recommendation**

**Start with Option 1 (Local-First) because:**
1. ✅ **Immediate fix** for broken releases  
2. ✅ **Lower complexity** and faster to implement
3. ✅ **Better performance** for players
4. ✅ **Easier maintenance** and debugging
5. ✅ **True offline capability**

**Later consider Option 2 for:**
- Advanced analytics needs
- Cloud save synchronization
- Multiplayer features
- Complex data relationships

**"Quick to fix, Option 1 is. Complex but powerful, Option 2 becomes. Choose wisely, based on priorities you must."** 🎭
