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

## Getting Started (WIP)

Setup instructions and contribution guidelines will be added as systems solidify.

---

### Reference Docs

* Game Design: `documentation/BrainLift/children_singularity_gdd.md`
* User Flow: `documentation/core_concept/user_flow.md`
* Tech Stack: `documentation/core_concept/tech_stack.md`
* Project Rules: `documentation/core_concept/project_rules.md`

---

© Children of the Singularity – All rights reserved. 