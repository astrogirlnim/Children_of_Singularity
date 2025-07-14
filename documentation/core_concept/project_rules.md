# `project-rules.md`

## Project Structure & Conventions for Children of the Singularity (Updated)

---

## 🗂️ Directory Structure

```
/scenes          # Godot scenes (Zone, Player, NPCs, UI)
/scenes/zones    # Zone grids and screens
/scenes/ui       # UI scenes and Control nodes (HUD, Inventory, Mission Panel)
/scripts         # GDScript files (InventoryManager.gd, AICommunicator.gd)
/assets          # Art, audio, shaders
/audio/ai        # Pre-generated AI voice files
/data/postgres   # DB storage
/logs            # Server logs
```

---

## 📄 File Naming Conventions

- **Scenes:** `ZoneMain.tscn`, `PlayerShip.tscn`, `NPCHub.tscn`, `ZoneGrid.tscn`, `ZoneScreen.tscn`, `MissionPanel.tscn`
- **Scripts:** `PlayerShip.gd`, `InventoryManager.gd`, `AICommunicator.gd`
- **UI:** `HUD.tscn`, `InventoryUI.tscn`, `MissionPanel.tscn`
- **Audio Files:** `/audio/ai/milestone01.ogg`
- **Database:** Use lowercase with underscores: `players`, `inventory`, `zones`
- **API Routes:** RESTful, `/api/v1/players/{uuid}`

---

## 🧑‍💻 Code Documentation & Commenting

- Every script file begins with a brief description of its purpose.
- Functions must be documented using **GDScript’s docstring style**.
- Parameters and returns should be clearly stated.

```gdscript
# InventoryManager.gd
# Manages player inventory sync with server.

## Adds item to inventory.
# @param item_id: String - ID of the item.
# @param quantity: int - Quantity to add.
func add_item(item_id: String, quantity: int) -> void:
    pass
```

---

## 📏 File Size Limits

- **Soft limit:** 500 lines per file for maintainability and AI tool compatibility.
- Split large systems (Inventory, AI, Trading) into smaller modules.

---

## 🔄 System Decoupling

- Use **Signals** to communicate between UI and core systems.
- Avoid hard-coded dependencies between gameplay and UI.
- `Autoload Singletons` only for global state (Inventory, AI Broadcasts).

---

## ⚙️ Networking & Persistence

- **Server-authoritative ENet networking.**
- API persistence handled via **FastAPI** with **PostgreSQL**.
- Player data, progression, and inventory sync server-side.

---

## 🎨 UI & Theme Guidelines (Summary from `ui-rules.md` and `theme-rules.md`)

- Minimalist HUD, brutalist UI with glitch elements.
- Moebius-inspired visuals: cluttered, pastel decay.
- Audio: Ambient synths, polite AI voice, mechanical hums.
- Player feedback is paramount (clear inventory, progress, AI cues).
- **Screen View Panel:** Main viewport for zone-specific interactions.
- **Mission Panel:** Dedicated side panel for narrative prompts, status updates.
- **Zone Map:** Grid-based, matches existing map mockup.
- **Action Buttons:** `Arm`, `Scan`, `Upgrade Slot`, `Thrust`.

---

## 🚨 Common Pitfalls to Avoid

- Over-reliance on Singletons.
- Coupling UI tightly to gameplay logic.
- Poorly documented functions leading to future confusion.
- Unstructured node hierarchies.
- Neglecting server-authoritative checks on state.

---

## 📑 Persistence Schema Summary

```sql
players (id, name, credits, progression_path)
inventory (player_id, item_id, quantity)
upgrades (player_id, upgrade_type, level)
zones (zone_id, player_id, access_level)
```

---

## ✅ Development Principles

- Clarity > Complexity.
- Maintain isolation between systems.
- Prioritize player feedback and world atmosphere.
- Reflect thematic consistency (bureaucratic decay, eerie corporate tone).
- Small, modular files for AI tools and maintainability.

---

