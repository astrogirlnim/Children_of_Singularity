# Children of the Singularity

A 2D / 2.5D multiplayer sci-fi salvage simulation inspired by Moebius, Planetes, and Nausicaa. Players explore cluttered orbital zones, collect and trade space debris, upgrade their ships (or themselves), and gradually uncover an unsettling AI-controlled ecosystem.

---

## Core Gameplay Loop

1. **Explore Zones** – Navigate dense debris fields in stylized 2D / 2.5D space.
2. **Collect Trash** – Harvest satellites, biotech waste, derelict AI components, and more.
3. **Trade / Upgrade** – Sell salvage locally; purchase ship, tool, and AI augment upgrades.
4. **Expand & Progress** – Unlock deeper zones, narrative milestones, and philosophical paths (Rogue, Corporate, or AI Integration).
5. **Marketplace Trading** – Trade items with other players via AWS serverless marketplace.

> For a detailed flow, see `documentation/core_concept/user_flow.md`.

---

## Tech Stack (Local-Only + Cloud Trading)

| Layer        | Technology / Notes                             |
|--------------|-----------------------------------------------|
| Game Engine  | **Godot 4.x** – Strict typing, signals for decoupling, composition-first design |
| Local Data   | **JSON Files** – LocalPlayerData.gd manages all personal data locally |
| Trading API  | **AWS Lambda + S3** – Serverless player-to-player marketplace |
| Audio AI     | Whisper-generated voice clips triggered in-game |
| Distribution | **Local Executables** – No server dependencies for core gameplay |

Details live in `documentation/core_concept/tech_stack.md`.

---

## Project Structure & Naming Conventions

```text
/scenes          Godot scenes (Zone, Player, UI)
/scenes/zones    Zone grids and screens
/scenes/ui       HUD, Inventory, Mission Panel
/scripts         GDScript (LocalPlayerData.gd, TradingMarketplace.gd)
/assets          Art, audio, shaders
/audio/ai        Pre-generated AI voice files
/backend         AWS Lambda functions for trading
/data/postgres   AWS RDS schema for trading marketplace
/logs            Game logs
```

Key guidelines (see `documentation/core_concept/project_rules.md`):

* **Strict typing** in GDScript, explicit `super()` calls in lifecycle methods.
* Use **@onready** for node references and **Signals** for loose coupling.
* File naming: `snake_case.gd` for scripts, `PascalCase.tscn` for scenes.
* Keep files < 500 lines; split large systems into modules.
* Comment every function with GDScript docstrings.

---

## Development Principles

* Clarity over complexity – maintain small, focused scripts.
* Local-first approach – all personal data stored locally.
* Atmospheric feedback – audio/visual cues for every player action.
* Modular progress – Phase-based roadmap with playable milestones.

See phase breakdown in `_docs/phases/`.

---

## Quick Setup & Run

### Prerequisites
- **Godot 4.4+** – [Download here](https://godotengine.org/download)
- **Git** – For version control

### 🚀 One-Command Development Setup

```bash
# Clone and run the local-only game
git clone <repository-url>
cd Children_of_Singularity
./dev_start.sh
```

**What this does:**
- ✅ Launches Godot game in local-only mode
- ✅ All data stored locally in user:// directory
- ✅ Complete offline functionality
- ✅ AWS Trading Marketplace available (when configured)

### 🎮 Game Controls

- **Arrow Keys / WASD** – Move salvage ship
- **Mouse** – Aim collection claw
- **Space** – Collect debris
- **Tab** – Toggle inventory
- **F** – Interact with trading hubs
- **ESC** – Pause menu

### 🛠️ Development Tools

- **Local Data**: Stored in user:// directory as JSON files
- **AWS Trading**: Optional cloud marketplace for player-to-player trading
- **Game Logs**: Comprehensive logging for all operations

---

## Architecture Overview

### **Local-Only Core Game:**
```
Godot Game → LocalPlayerData.gd → JSON Files (user://)
                ↓
    Complete offline functionality
```

### **Optional Cloud Trading:**
```
TradingMarketplace.gd → AWS API Gateway → Lambda Functions → S3/RDS
                ↓
    Player-to-player item marketplace
```

### **Key Benefits:**
- **Offline Capable:** Game works completely without internet
- **Zero Dependencies:** No server setup required for core gameplay
- **Fast Performance:** Local JSON operations are instant
- **Privacy Focused:** Personal data stays on player's computer
- **Cloud Trading:** Optional marketplace for enhanced multiplayer experience

---

## Data Management

### **Local Data (Personal):**
```
user://
├── player_save.json              # Credits, progress, player ID
├── player_inventory.json         # Items and quantities
├── player_upgrades.json          # Upgrade levels
├── player_settings.json          # Game preferences
└── trading_config.json           # AWS marketplace configuration (optional)
```

### **Cloud Data (Trading Only):**
```
AWS Infrastructure:
├── Lambda Functions              # Trading API endpoints
├── S3 Storage                   # Trade listings data
└── RDS PostgreSQL              # Transaction history (optional)
```

---

## Development Features

- **Comprehensive Logging**: Every operation logged with timestamps
- **Data Persistence**: Automatic saving to JSON files with atomic writes
- **Upgrade System**: 6 upgrade types with visual effects
- **Inventory Management**: Full item collection and selling system
- **Trading Interface**: Complete UI for marketplace interactions
- **Offline Mode**: Game works completely without internet connection

### 🔍 Development Monitoring

- **Local Data**: `user://` directory contains all save files
- **Game State**: Real-time logging in console
- **Performance**: Optimized for local file operations
- **Error Handling**: Graceful fallbacks for all operations

### 📊 Project Status

- ✅ **Core Gameplay**: Complete offline functionality
- ✅ **Data Persistence**: Local JSON storage system
- ✅ **Upgrade System**: 6 upgrade types with effects
- ✅ **Trading Interface**: Local item selling and upgrade purchasing
- ✅ **AWS Trading**: Serverless marketplace infrastructure
- ✅ **Cross-Platform**: Windows, macOS, Linux support

### 🚀 Distribution

- **Game Executables**: Single file distribution with no dependencies
- **Local Data**: Automatic user directory creation
- **AWS Trading**: Optional configuration for marketplace features
- **Update System**: Simple executable replacement

---

## Contributing

The game uses a local-first architecture for maximum accessibility and performance. All personal player data is managed locally, while optional cloud features enhance the multiplayer experience without creating dependencies.

For detailed architecture information, see `documentation/core_concept/` and `memory_bank/` directories.
