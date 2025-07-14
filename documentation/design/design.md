# design.md

## 🎨 Visual & Thematic Design Overview

### Core Visual Style
- **Primary Influence:** Moebius (Jean Giraud)
- **Inspirations:** Planetes, Nausicaa, Bakaarts, Hardspace Shipbreaker
- **Tone:** Wacky dystopian sci-fi with eerie corporate AI undertones.
- **Mood:** Friendly corporate politeness masking decay and manipulation. Sparse, lonely, cluttered environments rich with absurd bureaucracy.

### Key Style Elements
| Aspect           | Direction                         |
|------------------|-----------------------------------|
| **Palette**      | Soft pastels, muted neons, faded greys, desaturated blues. |
| **Shapes**       | Cluttered, worn, organic-mechanical. |
| **Linework**     | Clean but imperfect; worn textures.  |
| **Textures**     | Flat with light grain, subtle vignette. |
| **Environment**  | Busy, layered spacefields; surreal debris orbits. |
| **UI Style**     | Brutalist, cold bureaucracy with glitch elements. |

## 🎨 Color Guidelines
- **Backgrounds:** Desaturated greys, faded blues.
- **Objects:** Muted primaries, soft neon highlights.
- **UI:** Cold neutrals with glitch neon for AI feedback elements.

## 🖌️ Texture & Detail Principles
- Emphasis on flat color fields with light grain and wear.
- Depth through layer contrast, not heavy shading.
- Vignette edges to reinforce a decayed, analog feel.

## 🔊 Audio Design
- **Music:** Ambient synth, glitchy, distant.
- **SFX:** Static, mechanical hums, broken signals.
- **Voice:** Polite AI TTS, eerie, formal tone. Broadcasts tied to progression.

## 📐 UI / UX Principles

### Core UX Rules
1. **Clarity Over Complexity:** Simple, legible navigation and systems.
2. **Player Feedback Priority:** Visual/audio cues on all key actions.
3. **Atmosphere First:** UI supports immersion in the world’s decayed tone.
4. **Independent Systems:** UI elements modular and decoupled from core logic.

### Key UI Components
| Component     | Purpose                                         |
|---------------|-------------------------------------------------|
| HUD           | Inventory, credits, upgrades; minimalist.        |
| Inventory     | Grid-based, clear rarity/type indicators.        |
| Trading       | Simple, clear transactional flows.               |
| AI Comms      | Subtitles overlay, intrusive but polite popups.  |
| Mission Panel | Persistent goals, AI messages, progression path. |
| Zone Map      | Grid-based overview with PoI markers.            |
| Screen View   | Environmental storytelling & interaction focus.  |

## 💡 Game Systems Integration with Design

| Feature             | Design Role                                  |
|----------------------|-----------------------------------------------|
| Trash Collection     | Core loop anchor; visual/audio feedback critical. |
| Upgrades             | Visual changes to ship/UI to reflect progress. |
| AI Broadcasts        | Eerie UI overlays, reinforcing narrative tone.  |
| Trading Systems      | Cold, bureaucratic transaction screens.        |
| Player Progression   | Visual unlocks (zones, abilities, upgrades).   |

## 🛠️ Implementation Guidelines (Godot 4.x)
- Use `Control` nodes for all UI.
- Favor slight distortions/flickers in UI (corporate decay aesthetic).
- Rely on Signals to keep UI and game logic decoupled.
- Minimal animations; static with light imperfections preferred.

## 🌌 Narrative Visual Integration
- **Environmental Storytelling:** Debris, derelicts, and subtle changes in the environment reflect progress.
- **Screen View Panel:** Dedicated viewport for narrative clues and interactions.
- **Mission Panel:** Ties narrative progression to game systems visibly and consistently.

## 📑 Summary Reference
- **Visual:** Moebius-inspired pastel dystopia.
- **Audio:** Synths, static, eerie politeness.
- **UI:** Brutalist, functional, bureaucratic.
- **Narrative:** Ambient, slow-burn, AI-driven through design artifacts.
