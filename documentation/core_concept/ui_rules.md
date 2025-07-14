# `ui-rules.md`

## UI / UX Principles for Children of the Singularity (Updated)

### 📐 Core Principles

1. **Clarity Over Complexity**\
   Navigation, collection, trading, and upgrading must be clear at all times. Avoid clutter, favor simplicity.

2. **Player Feedback First**\
   UI must reinforce actions with clear visual/audio cues: collection progress, inventory updates, AI communications.

3. **Atmosphere Supports Function**\
   UI design complements the Moebius-inspired, wacky dystopian world—UI elements should not break immersion but reflect the universe's decayed, bureaucratic tone.

4. **Minimal Dependency Between Systems**\
   UI components (HUD, Inventory, Map, Trading, Mission Panel) should operate independently to reduce coupling and support modular development.

---

## 🖥️ UI Patterns & Components

### HUD

- Minimalist indicators: inventory slots, credits, upgrade status.
- Persistent radar / mini-map in corners.
- AI broadcast overlay appears as intrusive but polite pop-up.

### Inventory

- Grid-based with rarity / type color coding.
- Max capacity clearly indicated.

### Trading / Upgrading

- Simple transactional screens with clear "sell / buy" feedback.
- Upgrade categories: Ship, Tools, AI Augments.

### AI Communications

- Overlay voice subtitles.
- Optional log history accessible via tab.

### Screen View Panel (New)

- Dedicated central viewport for zone-specific screens.
- Player interacts via UI buttons: `Arm`, `Scan`, `Upgrade Slot`, `Thrust`.
- Reflects environmental storytelling (e.g., derelict ships, NPCs).

### Mission Panel (New)

- Persistent side panel for narrative progression, objectives, AI messages.
- Ties directly into AI Broadcast system and player progression path.

### Zone Map (New Clarification)

- Grid-based overview of connected zones.
- Labels for PoI (Point of Interest), Distress, Shop.
- Matches visual mockups provided.

---

## ⚙️ Implementation Conventions

- Godot 4.x `Control` nodes hierarchy.
- Use Signals to decouple UI updates from gameplay logic.
- Avoid complex animations—favor slight UI distortions, flickers in line with the corporate/AI tone.
- Integrate Mission Panel and Screen View as distinct, reusable components.

---

## ✨ Environmental Storytelling Support

- Use Screen View Panel for contextual narrative moments.
- Trigger AI Broadcasts through actions (e.g., scanning derelicts, finding data).
- Reinforce via Mission Panel updates.

---

## 📑 Summary Visual Schema

```
+-------------------------------------------------+
| Status: Life Support, Stabilizers, Nav           |
|-------------------------------------------------|
| +------------------+  +-----------------------+ |
| |   Screen View    |  |      Mission Panel     | |
| |    (Scene)       |  | - Objectives           | |
| |                  |  | - AI Messages          | |
| +------------------+  +-----------------------+ |
|                                                     |
| Arm | Scan | Upgrade Slot | Thrust                   |
| Map | Inventory | Trading |                          |
+-------------------------------------------------+
```
