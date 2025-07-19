# Local-First Data Considerations & Lifecycle Management

## 🎯 Overview

The local-first implementation stores all player data on the user's computer using Godot's `user://` directory system. This document analyzes data storage, cleanup requirements, privacy implications, and best practices for data lifecycle management.

---

## 📁 **Current Data Storage Analysis**

### **Files Created by the Game:**

Based on the current implementation, the game creates these local files:

```
user://
├── player_save.json              # Core player data (credits, name, progress)
├── player_settings.json          # Game settings (audio, graphics, controls)
├── player_inventory.json         # Player inventory items
├── player_upgrades.json          # Ship and player upgrades
├── trading_config.json           # Trading API configuration
├── local_database.json          # Alternative database storage
├── local_inventory.json         # Alternative inventory storage
├── local_upgrades.json          # Alternative upgrades storage
└── local_settings.json          # Alternative settings storage
```

### **Platform-Specific Storage Locations:**

Godot's `user://` directory resolves to different locations per platform:

| Platform | Location | Full Path Example |
|----------|----------|-------------------|
| **Windows** | `%APPDATA%/Godot/app_userdata/` | `C:\Users\Username\AppData\Roaming\Godot\app_userdata\Children of the Singularity\` |
| **macOS** | `~/Library/Application Support/Godot/app_userdata/` | `/Users/Username/Library/Application Support/Godot/app_userdata/Children of the Singularity/` |
| **Linux** | `~/.local/share/godot/app_userdata/` | `/home/username/.local/share/godot/app_userdata/Children of the Singularity/` |

---

## 📊 **Data Size & Content Analysis**

### **Typical Data Footprint:**

```
player_save.json          ~1-5 KB    (player stats, credits, progress)
player_settings.json      ~0.5-1 KB  (audio/video preferences)  
player_inventory.json     ~1-10 KB   (depends on items collected)
player_upgrades.json      ~0.5-2 KB  (upgrade levels)
trading_config.json       ~0.5 KB    (API endpoints)
local_database.json       ~1-5 KB    (if using LocalDatabase)
local_inventory.json      ~1-10 KB   (duplicate data)
local_upgrades.json       ~0.5-2 KB  (duplicate data)
local_settings.json       ~0.5-1 KB  (duplicate data)

TOTAL: 5-35 KB per player (negligible disk space)
```

### **Data Content & Sensitivity:**

| File | Contains | Sensitive? | Shareable? |
|------|----------|------------|------------|
| `player_save.json` | Credits, progress, generated player ID | No | Yes (save file sharing) |
| `player_settings.json` | Audio/graphics preferences | No | Yes |
| `player_inventory.json` | Game items collected | No | Yes |
| `player_upgrades.json` | Upgrade progression | No | Yes |
| `trading_config.json` | API endpoints only | No | Yes |

**Privacy Assessment:** ✅ **No personally identifiable information stored**

---

## 🗑️ **Uninstallation & Cleanup Considerations**

### **Current Behavior:**

❌ **Problem:** Standard game uninstallation does NOT remove player data
- Uninstalling via Steam/App Store/Package Manager removes game files only
- Player data persists in `user://` directory indefinitely
- Data accumulates over multiple installs/uninstalls

### **Industry Standards & User Expectations:**

| Uninstall Method | User Expectation | Current Reality |
|------------------|------------------|-----------------|
| **Steam/Epic/GOG** | Game files removed, saves optional | ❌ Saves always remain |
| **macOS App Store** | Complete removal including data | ❌ Data remains |
| **Windows Add/Remove** | Game files removed | ❌ Data remains |
| **Linux Package Manager** | Package removed, configs remain | ✅ Expected behavior |

### **Legal & Privacy Implications:**

**GDPR Compliance:**
- ✅ **Good:** No personal data stored (no real names, emails, etc.)
- ✅ **Good:** Player controls their own data (local storage)
- ⚠️ **Consider:** Right to erasure requires manual action by user

**Platform Requirements:**
- **Steam:** No specific requirements for save data cleanup
- **App Store (iOS/macOS):** Encourages automatic cleanup
- **Google Play:** No specific requirements
- **Console Stores:** Varies by platform

---

## 🛠️ **Recommended Solutions**

### **Option 1: In-Game Data Management (Recommended)**

Add data management features within the game:

```gd
# scripts/DataManager.gd
extends Node

signal data_deleted()
signal export_completed(file_path: String)

func show_data_management_dialog():
    # Create UI for data management
    var dialog = preload("res://scenes/ui/DataManagementDialog.tscn").instantiate()
    get_tree().current_scene.add_child(dialog)
    dialog.show_data_options()

func get_data_size() -> String:
    var total_size = 0
    var data_files = [
        "user://player_save.json",
        "user://player_settings.json",
        "user://player_inventory.json",
        "user://player_upgrades.json",
        "user://trading_config.json"
    ]

    for file_path in data_files:
        if FileAccess.file_exists(file_path):
            var file = FileAccess.open(file_path, FileAccess.READ)
            total_size += file.get_length()
            file.close()

    return _format_bytes(total_size)

func export_save_data() -> String:
    # Create exportable save file
    var export_data = {
        "player_data": LocalPlayerData.player_data,
        "inventory": LocalPlayerData.player_inventory,
        "upgrades": LocalPlayerData.player_upgrades,
        "settings": LocalPlayerData.player_settings,
        "export_date": Time.get_datetime_string_from_system(),
        "game_version": "1.0.0"
    }

    var export_path = "user://save_export_%s.json" % Time.get_unix_time_from_system()
    var file = FileAccess.open(export_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(export_data, "\t"))
    file.close()

    export_completed.emit(export_path)
    return export_path

func delete_all_data():
    # Confirm with user first
    var confirmation = await _show_confirmation_dialog(
        "Delete All Data",
        "This will permanently delete all your progress, settings, and game data. This cannot be undone. Are you sure?"
    )

    if not confirmation:
        return

    # Delete all game data files
    var data_files = [
        "user://player_save.json",
        "user://player_settings.json",
        "user://player_inventory.json",
        "user://player_upgrades.json",
        "user://trading_config.json",
        "user://local_database.json",
        "user://local_inventory.json",
        "user://local_upgrades.json",
        "user://local_settings.json"
    ]

    for file_path in data_files:
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(file_path)

    print("DataManager: All player data deleted")
    data_deleted.emit()

    # Show completion message and restart game
    _show_info_dialog("Data Deleted", "All game data has been removed. The game will now restart.")
    get_tree().quit()
```

### **Option 2: Uninstaller Integration**

Create optional uninstaller script:

```bash
#!/bin/bash
# uninstall_cleanup.sh
# Optional cleanup script for complete data removal

echo "🗑️  Children of the Singularity - Data Cleanup"
echo "============================================="

# Detect platform and show data location
case "$(uname -s)" in
    Darwin)
        DATA_DIR="$HOME/Library/Application Support/Godot/app_userdata/Children of the Singularity"
        ;;
    Linux)
        DATA_DIR="$HOME/.local/share/godot/app_userdata/Children of the Singularity"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        DATA_DIR="$APPDATA/Godot/app_userdata/Children of the Singularity"
        ;;
    *)
        echo "❌ Unsupported platform"
        exit 1
        ;;
esac

if [ -d "$DATA_DIR" ]; then
    echo "📁 Found game data at: $DATA_DIR"
    echo "📊 Data size: $(du -sh "$DATA_DIR" | cut -f1)"
    echo

    read -p "🗑️  Delete all game data? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
        echo "✅ All game data deleted"
    else
        echo "❌ Data cleanup cancelled"
    fi
else
    echo "✅ No game data found"
fi
```

### **Option 3: Automatic Cleanup (Advanced)**

Implement automatic cleanup logic:

```gd
# scripts/CleanupManager.gd  
extends Node

# Check if game should clean up old data
func check_cleanup_needed():
    var settings_file = "user://cleanup_settings.json"
    var cleanup_settings = _load_cleanup_settings(settings_file)

    # Check if user opted for auto-cleanup
    if cleanup_settings.get("auto_cleanup_enabled", false):
        var days_to_keep = cleanup_settings.get("days_to_keep", 90)
        _cleanup_old_data(days_to_keep)

func _cleanup_old_data(days_to_keep: int):
    # Remove data older than specified days
    var cutoff_time = Time.get_unix_time_from_system() - (days_to_keep * 24 * 60 * 60)

    # Check each data file's modification time
    var data_files = _get_all_data_files()
    for file_path in data_files:
        if FileAccess.file_exists(file_path):
            var file_time = FileAccess.get_modified_time(file_path)
            if file_time < cutoff_time:
                print("CleanupManager: Removing old data file: %s" % file_path)
                DirAccess.remove_absolute(file_path)
```

---

## 📋 **Best Practices & Recommendations**

### **1. Implement In-Game Data Management**
```gd
# Add to main menu
Settings Menu > Data Management
├── 📊 View Data Size: "Your game data: 12.5 KB"
├── 📤 Export Save Data: "Create backup file"  
├── 📥 Import Save Data: "Restore from backup"
├── 🗑️ Delete All Data: "Remove all progress"
└── 📁 Open Data Folder: "Show files in explorer"
```

### **2. User Education**
- **In-game tooltip:** "Your progress is saved locally on your computer"
- **Help section:** Explain where data is stored per platform
- **Uninstall warning:** "Note: Game progress will remain on your computer"

### **3. Data Portability**
- ✅ **Export/Import functions** for save file sharing
- ✅ **JSON format** makes data human-readable and portable
- ✅ **Version compatibility** checks for save file imports

### **4. Privacy by Design**
- ✅ **No personal data collection** (no names, emails, etc.)
- ✅ **Local-only storage** (user controls their data)
- ✅ **Transparent data location** (user can find/delete files)
- ✅ **Optional analytics** (if ever added, make it opt-in)

---

## 🔧 **Implementation Priority**

### **Phase 1: Essential (Immediate)**
- [ ] Add data size reporting to settings menu
- [ ] Add "Delete All Data" option with confirmation
- [ ] Document data locations in help/about section

### **Phase 2: Enhanced (Next Update)**
- [ ] Add export/import save data functionality
- [ ] Create optional cleanup script for distribution
- [ ] Add "Open Data Folder" button (opens file explorer)

### **Phase 3: Advanced (Future)**
- [ ] Automatic cleanup options with user control
- [ ] Cloud save backup integration (optional)
- [ ] Save file versioning and migration tools

---

## ⚖️ **Legal Compliance Summary**

| Regulation | Compliance Status | Notes |
|------------|-------------------|--------|
| **GDPR** | ✅ Compliant | No personal data stored, user controls data |
| **CCPA** | ✅ Compliant | No personal data collection |
| **COPPA** | ✅ Compliant | No personal data from children |
| **Platform Terms** | ✅ Compliant | Standard save data behavior |

---

## 🎯 **Key Takeaways**

1. **Current State:** Game leaves data on user's computer after uninstall (standard behavior)
2. **User Impact:** Minimal (5-35 KB), no personal data, easily removable
3. **Recommended Solution:** Add in-game data management tools
4. **Privacy Status:** Excellent (local-only, no personal data)
5. **Compliance:** Meets all major privacy regulations

**Bottom Line:** The local-first approach is privacy-friendly and compliant, but we should add user-friendly data management tools for transparency and control.

**"Store locally you must, but give control to users, essential it is."** 🎭
