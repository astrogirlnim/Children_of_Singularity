# `user-flow.md`

## Children of the Singularity — Core User Flow

### Overview

This document outlines the player's journey through the core gameplay loop and how primary systems interconnect. It focuses on the expected user interactions from session start to progression, reflecting the Phase 1+ design goals.

---

## 1️⃣ Session Start / Entry Flow

### States:

- New Player
- Returning Player

### Actions:

- Select a Zone to Enter (from small multiplayer zone list)
- Connect to Zone Instance (persistent small multiplayer space)

**Outcome:** Player enters an active zone, sees their ship or avatar in a debris field.

---

## 2️⃣ Core Gameplay Loop

### 2.1 Zone Exploration

**User Actions:**

- Navigate 2D/2.5D debris field
- Identify collectible trash via UI highlights / proximity / cues

**System Feedback:**

- Visual / Audio cues for collectible objects
- Zone map / radar for orientation

---

### 2.2 Trash Collection

**User Actions:**

- Trigger collection (minigame, automated action, or skill-check interaction)
- Inventory fills over time

**System Feedback:**

- Progress bar / inventory indicator
- Different trash types shown (rarity, type)

---

### 2.3 Trading & Upgrading

**Location:** NPC Hub within Zone

**User Actions:**

- Dock / approach NPC Hub
- Sell collected trash for credits
- Purchase upgrades (ship, tools, AI augments)

**System Feedback:**

- Inventory clears post-sale
- Credits updated
- Upgrade effects applied (speed, capacity, new zone access)

---

### 2.4 Progression & Expansion

**Triggers:**

- Credits milestones
- Upgrade purchases
- Specific trash types found

**User Actions:**

- Access deeper zone layers / new zones
- Unlock narrative milestones (AI messages, broadcasts)
- Choose philosophical progression: Rogue / Corporate / AI Integration

**System Feedback:**

- New zones accessible
- AI communications trigger (broadcasts, private messages)
- Visual / audio changes reflect progression

---

## 3️⃣ Optional Interactions

### 3.1 Player-to-Player Interaction

**Available in Shared Zones:**

- Light Bartering (Phase 3 stretch)
- Cargo Theft / Light PvP (toggle per instance)
- Indirect Competition (shared resource depletion)

---

## 4️⃣ Narrative Unfolding

### Milestones:

- First AI Broadcast (trigger: first upgrade or sale)
- Private AI Messages (trigger: specific trash types, zones)
- Environmental Clues (visual storytelling, deeper zones)

**User Feedback:**

- Voice / text messages from AI
- Visual shifts in environment per progression
- Optional exploration for lore

---

## 5️⃣ Session End / Persistence

### States Saved:

- Inventory (pre-trade)
- Credits / Resources
- Upgrades owned
- Zone access unlocked
- Progression path alignment

### Exit Options:

- Return to main zone selection
- Quit session (state saved)

---

## User Flow Diagram (Textual)

```plaintext
[Enter Zone] → [Explore] → [Collect Trash] → [Trade / Upgrade] → [Access New Zones]
                      ➣            ➣                          ➣
                 [AI Broadcast]   [Progression Path]     [Narrative Milestones]
```

---

## Notes for Architecture & UI Planning

- Navigation, Collection, and Inventory should be tightly integrated with HUD
- Trading and Upgrades require simple, stylized UI (credits, inventory, upgrade list)
- AI communications tied to system triggers, presented via audio + UI overlay
- Persistent data: user inventory, credits, upgrades, zone unlocks, progression path
- Networking model: small zone instances, persistence per player state, optional PvP toggle
