# Children of the Singularity — Expanded Tech Stack & Best Practices (Godot 4.x)

## Overview
This expanded tech stack guide details **best practices, limitations, conventions, and common pitfalls** for each core technology. It is aligned with the game's Moebius-inspired sci-fi salvage simulation design.

---

## 1️⃣ Godot 4.x (Client)

### Best Practices
- Structure node hierarchies cleanly: Zone → Debris → Player → UI.
- Decouple systems with **Signals** (AI triggers, Inventory updates).
- Use **Autoload Singletons** only for global states (PlayerInventory, AIBroadcastManager).
- Leverage **Groups** for category management (collectibles, NPCs).
- Optimize **Lighting / Shaders**: Limit Light2D and complex shaders.

### Limitations
- 2.5D layering requires careful depth management.
- ENet integration is solid but lacks AAA robustness.
- PostFX pipelines in 2D are less mature than 3D counterparts.

### Conventions
- Folder Structure: `/scenes`, `/scripts`, `/ui`, `/assets`
- Scene Naming: `ZoneMain.tscn`, `PlayerShip.tscn`
- Script Naming: `PlayerShip.gd`, `InventoryManager.gd`
- Avoid heavy logic in `_process()` unless essential.

### Common Pitfalls
- Over-reliance on Singletons causing tangled dependencies.
- Tight coupling of UI and gameplay logic.
- Signal misuse causing hard-to-trace bugs.

---

## 2️⃣ ENet Networking (Dedicated Zones)

### Best Practices
- Server-authoritative: All inventories, positions, progression validated server-side.
- Small Zones (< 32 players) to reduce complexity.
- Use RPC sparingly; minimize state syncing traffic.
- Regularly checkpoint player state server-side.

### Limitations
- No built-in matchmaking.
- Debugging desyncs requires robust logs.

### Conventions
- `MultiplayerSynchronizer` for sync-critical objects.
- Separate server-only and client-only logic clearly.

### Common Pitfalls
- Client-side authority opens exploits.
- Poor latency handling causes jank (rubber-banding).

---

## 3️⃣ Backend (PostgreSQL via FastAPI / Flask)

### Best Practices
- REST API for persistence, not real-time.
- Normalized schemas for players, inventory, upgrades.
- Idempotent endpoints; PATCH for updates.

### Limitations
- Not suitable for high-frequency updates.
- Flask/FastAPI scale within VPS limits.

### Conventions
- Endpoint structure: `/api/v1/players/{uuid}`
- JWT for authentication (if future sessions expand).
- DB migrations via Alembic.

### Common Pitfalls
- Overfetching data unnecessarily.
- Lack of transactional safety (credits, inventory updates).

---

## 4️⃣ Audio & AI (Whisper TTS Integration)

### Best Practices
- Pre-generate AI voice clips for milestones.
- Integrate via `AudioStreamPlayer` + Signals.
- AI voice tied to progression, not random triggers.

### Limitations
- Real-time Whisper infeasible; prebuild pipeline required.
- Sparing use enhances narrative effect.

### Conventions
- Store clips in `/audio/ai/`
- Trigger via `AICommunicator.gd`

### Common Pitfalls
- Overuse diminishes impact.
- Poor mix against SFX / ambience.

---

## 5️⃣ Hosting / Infrastructure

### Best Practices
- VPS per Zone Cluster or scalable containers.
- Logging, monitoring, regular DB backups.
- Snapshot strategy for persistent storage.

### Limitations
- Self-hosted limits scalability without investment.

### Conventions
- Environments: Dev / Stage / Prod
- Data directories: `/data/postgres`, `/logs`

### Common Pitfalls
- No error recovery strategy.
- Unsecured API endpoints.

---

# 🎨 Design Principles & Style Recommendations

## Core Design Principles
- **Clarity of Intent:** Clear navigation, collection, trade flows.
- **Player Feedback:** Responsive audio/visual feedback.
- **Atmospheric Progression:** Evolve visuals and audio as depth increases.
- **Maintained Isolation:** Solo-friendly, non-reliant multiplayer.

## Recommended Visual Style: **Moebius**

| Style               | Why It Fits                                      |
|---------------------|-------------------------------------------------|
| **Moebius**         | Core visual influence: timeless surreal sci-fi. |
| **Retro-futurism**  | Reinforces decayed corporate AI aesthetic.     |
| **Brutalist UI**    | Cold, bureaucratic interface design.           |
| **Pastel Dystopia** | Contrast soft palette with harsh realities.    |
| **Cluttercore Industrial** | Matches salvage and debris themes.     |

---

## 📂 Summary Tech Stack Table

| Category    | Technology                            |
|-------------|---------------------------------------|
| Engine      | Godot 4.x                              |
| Networking  | ENet (Godot)                           |
| Backend     | PostgreSQL via REST (FastAPI / Flask)  |
| Audio AI    | Whisper (TTS) Integration              |
| Hosting     | Self-hosted (VPS / DigitalOcean)       |
| Art Tools   | Aseprite / Krita / Blender (2.5D)      |
| Audio Tools | Godot Audio / Audacity                 |

---

## ☑️ Development Phases

### Phase 1 — Core Loop Prototype
- Navigation, Collection, Trading, AI Broadcast Proof-of-Concept

### Phase 2 — Expansion
- Persistent Progression, Zones, Visual Narrative Changes, AI Effects

### Phase 3 — Stretch Goals
- PvP Cargo Theft, Player-to-Player Trading, Deeper AI Systems
