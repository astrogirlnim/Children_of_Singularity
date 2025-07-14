# Children of the Singularity

A 2D / 2.5D multiplayer sci-fi salvage simulation inspired by Moebius, Planetes, and Nausicaä. Players explore cluttered orbital zones, collect and trade space debris, upgrade their ships (or themselves), and gradually uncover an unsettling AI-controlled ecosystem.

---

## Core Gameplay Loop

1. **Explore Zones** – Navigate dense debris fields in stylized 2D / 2.5D space.
2. **Collect Trash** – Harvest satellites, biotech waste, derelict AI components, and more.
3. **Trade / Upgrade** – Sell salvage at NPC hubs; purchase ship, tool, and AI augment upgrades.
4. **Expand & Progress** – Unlock deeper zones, narrative milestones, and philosophical paths (Rogue, Corporate, or AI Integration).

> For a detailed flow, see `documentation/core_concept/user_flow.md`.

---

## Tech Stack (Client & Backend)

| Layer        | Technology / Notes                             |
|--------------|-----------------------------------------------|
| Game Engine  | **Godot 4.x** – Strict typing, signals for decoupling, composition-first design |
| Networking   | **ENet (Godot)** – Server-authoritative, small (<32) player zones |
| Backend API  | **FastAPI / Flask** – REST persistence to **PostgreSQL** |
| Audio AI     | Whisper-generated voice clips triggered in-game |
| Hosting      | VPS / Container clusters, environment separation (Dev / Stage / Prod) |

Details live in `documentation/core_concept/tech_stack.md`.

---

## Project Structure & Naming Conventions

```text
/scenes          Godot scenes (Zone, Player, UI)
/scenes/zones    Zone grids and screens
/scenes/ui       HUD, Inventory, Mission Panel
/scripts         GDScript (InventoryManager.gd, AICommunicator.gd)
/assets          Art, audio, shaders
/audio/ai        Pre-generated AI voice files
/data/postgres   Database storage
/logs            Server logs
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
* Server-authoritative networking – validate all state server-side.
* Atmospheric feedback – audio/visual cues for every player action.
* Modular progress – Phase-based roadmap with playable milestones.

See phase breakdown in `_docs/phases/`.

---

## Quick Setup & Run

### Prerequisites
- **Godot 4.4+** – [Download here](https://godotengine.org/download)
- **Python 3.11+** – For backend API services
- **Git** – For version control

### 🚀 One-Command Development Setup

```bash
# Clone and run the full development environment
git clone <repository-url>
cd Children_of_Singularity
./dev_start.sh
```

**What this does:**
- ✅ Sets up Python virtual environment automatically
- ✅ Installs backend dependencies (FastAPI, etc.)
- ✅ Starts backend API server on port 8000
- ✅ Launches Godot game window
- ✅ Handles process management and cleanup (Ctrl+C to stop)

### 🔍 Testing API Connection

```bash
# Test backend connectivity
./test_connection.sh
```

### Manual Setup (Alternative)

If you prefer step-by-step control:

```bash
# 1. Backend setup
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -m uvicorn app:app --host 0.0.0.0 --port 8000 &

# 2. Launch game
godot --run-project .
```

### 🎮 Game Controls

- **Arrow Keys / WASD** – Move salvage ship
- **Mouse** – Aim collection claw
- **Space** – Collect debris
- **Tab** – Toggle inventory
- **ESC** – Pause menu

### 🛠️ Development Tools

- **Backend API**: `http://localhost:8000/docs` (FastAPI auto-docs)
- **Health Check**: `http://localhost:8000/api/v1/health`
- **Game Logs**: Console output shows real-time system status
- **Database**: PostgreSQL schema in `data/postgres/schema.sql`

### Troubleshooting

**"Port 8000 already in use"**
```bash
# Kill existing processes
lsof -ti :8000 | xargs kill -9
```

**"Godot not found"**
```bash
# Add Godot to PATH or use full path
export PATH="/Applications/Godot.app/Contents/MacOS:$PATH"
```

**"Python venv issues"**
```bash
# Clean virtual environment
rm -rf backend/venv
python3 -m venv backend/venv
```

---

### Reference Docs

* Game Design: `documentation/BrainLift/children_singularity_gdd.md`
* User Flow: `documentation/core_concept/user_flow.md`
* Tech Stack: `documentation/core_concept/tech_stack.md`
* Project Rules: `documentation/core_concept/project_rules.md`

---

© Children of the Singularity – All rights reserved.
