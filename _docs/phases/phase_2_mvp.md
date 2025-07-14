# Phase 2: MVP (Minimal Viable Product)

## Scope
Deliver a playable, networked game with the core gameplay loop: explore, collect, trade, upgrade. The MVP is usable, fun, and demonstrates the project’s unique value, but lacks polish and advanced features.

## Deliverables
- Multiplayer zone with basic networking (ENet)
- Player can navigate, collect trash, and see inventory
- Trading at NPC hub for credits
- Simple upgrade system (speed, capacity, zone access)
- Static AI text messages at milestones
- Persistent player state (credits, inventory, upgrades)
- Minimal UI (HUD, inventory, trading, upgrade screens)

---

## Features & Actionable Steps

### 1. Multiplayer Zone (ENet)
- [ ] Implement server-authoritative ENet networking for a single shared zone
- [ ] Sync player positions and basic state
- [ ] Handle player join/leave events
- [ ] Add basic logging for network events

### 2. Player Navigation & Trash Collection
- [ ] Implement player movement controls (2D/2.5D)
- [ ] Spawn collectible trash objects in the zone
- [ ] Add collection mechanic (minigame, skill-check, or auto)
- [ ] Update inventory on collection
- [ ] Provide visual/audio feedback for collection

### 3. Inventory & Trading
- [ ] Implement inventory system (client + server sync)
- [ ] Add NPC hub scene for trading
- [ ] Allow selling trash for credits
- [ ] Update credits and clear inventory on sale
- [ ] Log all trade actions

### 4. Upgrades & Progression
- [ ] Implement upgrade system (speed, capacity, zone access)
- [ ] Deduct credits and apply upgrade effects
- [ ] Unlock deeper zone access with upgrades
- [ ] Track progression state per player
- [ ] Log upgrade purchases

### 5. AI Messaging (Static)
- [ ] Trigger static AI text messages at key milestones (first upgrade, sale, new zone)
- [ ] Display messages via UI overlay
- [ ] Log all AI message triggers

### 6. Minimal UI
- [ ] Implement HUD (inventory, credits, upgrade status)
- [ ] Add inventory and trading screens
- [ ] Add upgrade selection UI
- [ ] Display AI messages in overlay
- [ ] Ensure all UI is functional and clear

### 7. Persistence
- [ ] Save player state (credits, inventory, upgrades, zone access) server-side
- [ ] Restore state on reconnect
- [ ] Add error handling/logging for persistence

---

## Completion Criteria
- Players can join a shared zone, move, collect trash, trade, and upgrade
- All core systems are networked and persistent
- Minimal UI is present and functional
- Static AI messages trigger at milestones
- Logs confirm all major actions
