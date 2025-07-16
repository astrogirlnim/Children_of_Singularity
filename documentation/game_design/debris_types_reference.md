# Debris Types Reference
*Children of the Singularity - Game Design Documentation*

## Overview

Debris collection is the core gameplay mechanic in Children of the Singularity. Players explore space zones to collect various types of space debris, each with different values, rarity levels, and spawn rates.

## Core Debris Types (Active Spawning)

These 5 debris types actively spawn in the game world and can be collected by players:

### 1. Scrap Metal
- **Value**: 5 credits per unit
- **Rarity**: Common
- **Category**: Materials
- **Spawn Weight**: 40 (highest spawn rate)
- **Color**: Gray
- **Description**: Common metallic debris from destroyed spacecraft. The most abundant debris type, providing steady but modest income.

### 2. Bio Waste
- **Value**: 25 credits per unit
- **Rarity**: Common
- **Category**: Organics
- **Spawn Weight**: 25 (moderate spawn rate)
- **Color**: Green
- **Description**: Biological waste materials with potential research value. More valuable than scrap metal but still commonly found.

### 3. Broken Satellite
- **Value**: 150 credits per unit
- **Rarity**: Uncommon
- **Category**: Technology
- **Spawn Weight**: 10 (low spawn rate)
- **Color**: Silver
- **Description**: Damaged satellite containing salvageable components. Significantly more valuable than common debris.

### 4. AI Component
- **Value**: 500 credits per unit
- **Rarity**: Rare
- **Category**: Technology
- **Spawn Weight**: 5 (very low spawn rate)
- **Color**: Cyan
- **Description**: Advanced AI processing units with high market value. Rare finds that provide substantial income.

### 5. Unknown Artifact
- **Value**: 1000 credits per unit
- **Rarity**: Legendary
- **Category**: Artifacts
- **Spawn Weight**: 1 (extremely rare)
- **Color**: Purple
- **Description**: Mysterious artifact of unknown origin. The most valuable debris type, extremely rare to find.

## Future Debris Types (Defined but Not Spawning)

These debris types are implemented in the inventory system but not yet spawning in the game world:

### 6. Energy Cell
- **Value**: 75 credits per unit
- **Rarity**: Uncommon
- **Category**: Power
- **Description**: High-capacity energy storage device. Planned for future implementation.

### 7. Quantum Core
- **Value**: 2500 credits per unit
- **Rarity**: Epic
- **Category**: Technology
- **Description**: Quantum processing core with reality-bending properties. Highest value debris planned.

### 8. Nano Material
- **Value**: 800 credits per unit
- **Rarity**: Rare
- **Category**: Materials
- **Description**: Self-assembling nanomaterial with multiple applications.

## Spawn Rate Analysis

The spawn system uses weighted probabilities:

| **Debris Type** | **Spawn Weight** | **Probability** | **Expected Frequency** |
|-----------------|------------------|-----------------|------------------------|
| Scrap Metal | 40 | ~49.4% | Every 2-3 spawns |
| Bio Waste | 25 | ~30.9% | Every 3-4 spawns |
| Broken Satellite | 10 | ~12.3% | Every 8-10 spawns |
| AI Component | 5 | ~6.2% | Every 16-20 spawns |
| Unknown Artifact | 1 | ~1.2% | Every 80-100 spawns |

**Total Weight**: 81 entries in weighted spawn table

## Value Progression

The debris values follow an exponential progression pattern:

```
Scrap Metal:      5 credits   (baseline)
Bio Waste:        25 credits  (5x multiplier)
Broken Satellite: 150 credits (6x multiplier)
AI Component:     500 credits (3.3x multiplier)
Unknown Artifact: 1000 credits (2x multiplier)
```

## Rarity Color Coding

The inventory UI uses color-coded borders to indicate rarity:

- **Common** (Gray): Scrap Metal, Bio Waste
- **Uncommon** (Green): Broken Satellite, Energy Cell
- **Rare** (Blue): AI Component, Nano Material
- **Epic** (Purple): Quantum Core
- **Legendary** (Gold): Unknown Artifact

## Technical Implementation

### File Locations
- **Core Definitions**: `scripts/ZoneDebrisManager.gd`, `scripts/ZoneDebrisManager3D.gd`
- **Extended Definitions**: `scripts/InventoryManager.gd`
- **Sprite Assets**: `assets/sprites/debris/`
- **3D Implementation**: `scripts/DebrisObject3D.gd`

### Data Structure
```gdscript
# Example debris type definition
{
    "type": "scrap_metal",
    "value": 5,
    "spawn_weight": 40,
    "color": Color.GRAY,
    "texture_path": "res://assets/sprites/debris/scrap_metal.png"
}
```

## Game Balance Notes

### Early Game (0-10 items collected)
- Players primarily collect Scrap Metal and Bio Waste
- Average value per item: ~12 credits
- Focus on learning collection mechanics

### Mid Game (10-50 items collected)
- Occasional Broken Satellites provide value spikes
- Average value per item: ~20 credits
- Players can afford basic upgrades

### Late Game (50+ items collected)
- Rare AI Components and Artifacts drive progression
- Average value per item: ~35 credits
- High-tier upgrades and zone access unlocked

## Future Expansion

The system is designed to easily accommodate new debris types:

1. Add new entry to `debris_types` array
2. Create corresponding sprite asset
3. Add rarity information to `InventoryManager.gd`
4. Update color coding in UI system

The modular design allows for seasonal events, special debris types, and gameplay variations without core system changes.
