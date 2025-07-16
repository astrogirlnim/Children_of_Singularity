# Skybox-Based Background Revamp Plan

> This document replaces the "flat-plane" background system with a multi-layer rotating skybox that provides richer parallax and eliminates clipping artifacts.

## Overview
* Total budget: **≈ 5 developer-hours**  
* Core goal: centric, concentric skybox shells that rotate at different speeds to imply depth.  
* Deliverable: in-game skybox rendering at **≥60 FPS** on mid-range hardware.

---

## Phase 0 – Audit & Preparation (0.5 h)
| # | Milestone | Verification |
|---|-----------|--------------|
| 0-1 | Enumerate existing background textures (layers, objects, particles). | Markdown list committed to repo. |
| 0-2 | Confirm import settings: `Repeat = On`, `Filter = Linear`, `Compression = VRAM`. | Godot import panel screenshots or inspector logs show flags set. |
| 0-3 | Remove/disable BackgroundManager3D from test scene branch. | Scene diff shows node removed. |

### Checklist
1. [x] Enumerate current background textures and document in `_docs/background_revamp/asset_inventory.md`.
2. [x] Open each texture in Godot importer and set `Repeat`, `Filter`, `Compression` flags then re-import.
3. [x] In `ZoneMain3D.tscn`, disable or delete `BackgroundManager3D` node and verify scene runs.

## Phase 1 – Core Code Scaffolding (1.0 h)
| # | Milestone | Verification |
|---|-----------|--------------|
| 1-1 | `SkyboxLayer.gd` created ➜ builds inside-out SphereMesh (flipped normals). | Script exists; running unit-test prints "Sphere generated". |
| 1-2 | `SkyboxManager3D.gd` created with exported `camera_reference`, loads `layers_config`. | Godot autoload or scene instantiation compiles with no errors. |
| 1-3 | Pivot node follows camera each frame. | Debug print matches camera.position every 0.5 sec. |

### Checklist
1. [x] Create `scripts/SkyboxLayer.gd` with SphereMesh creation and flipped normals.
2. [x] Create `scripts/SkyboxManager3D.gd`, define `layers_config` array and export `camera_reference`.
3. [x] Add a Pivot `Node3D` inside manager that updates to camera position each `_process`.
4. [x] Instantiate one test layer in a temp scene, run, and observe debug logs.

**CURRENT STATUS**: All 3 skybox layers successfully created and integrated into main game. Textures loading correctly, UV tiling working (0.8x-2.0x), materials configured. Issue: Skybox not visible despite perfect technical implementation - likely camera far plane or environment interference.

## Phase 2 – Visual Bring-Up (1.0 h)
| # | Milestone | Verification |
|---|-----------|--------------|
| 2-1 | Five concentric shells (radii 320→230) instance successfully. | In-editor scene tree shows `Shell_0…Shell_4`. |
| 2-2 | Textures correctly mapped; no seams or stretching. | Manual 360° spin of camera exhibits seamless wrap. |
| 2-3 | Individual shell rotation speeds produce visible differential motion. | Video/GIF capture shows parallax.

### Checklist
1. [ ] Define five dictionaries inside `layers_config` with texture_path, radius, rotation_speed, alpha.
2. [ ] Loop through `layers_config` in `SkyboxManager3D._ready()` and add shells as SkyboxLayer children.
3. [ ] Verify UVs and patch seams by tweaking SphereMesh `radial_segments` if needed.
4. [ ] Set distinct `rotation_speed` values (+1.0, +0.5, -0.8, +1.5, -2.0) and test.

## Phase 3 – Scene Integration (0.5 h)
| # | Milestone | Verification |
|---|-----------|--------------|
| 3-1 | ZoneMain3D.tscn contains SkyboxManager3D instead of BackgroundManager3D. | Scene diff + Godot inspector. |
| 3-2 | Game runs end-to-end with new skybox, no runtime errors. | Godot console clean start-up log. |

### Checklist
1. [ ] Add SkyboxManager3D instance to `ZoneMain3D.tscn`, assign Camera3D in Inspector.
2. [ ] Remove BackgroundManager3D script and node references.
3. [ ] Run game, confirm no errors and Skybox visible.

## Phase 4 – Tuning & QA (1.0 h)
| # | Milestone | Verification |
|---|-----------|--------------|
| 4-1 | Frame-rate ≥60 FPS with ≥5 shells on target hardware. | Godot profiler screenshot. |
| 4-2 | No clipping at extreme zoom/angles. | QA checklist signed off. |
| 4-3 | Optional LOD switch halts rotation when camera idle >5 s. | Debug log: "Rotation paused". |
| 4-4 | Alpha blending of shells doesn’t darken scene (>0.85 combined). | Histogram comparison before/after. |

### Checklist
1. [ ] Profile scene with Godot debugger; record baseline FPS.
2. [ ] Optimize SphereMesh polygon count or material if FPS <60.
3. [ ] Implement idle timer in SkyboxManager3D to pause rotations after 5 s inactivity.
4. [ ] Adjust alpha values and blending modes to reach target brightness.
5. [ ] Stress-test rapid camera pans and zoom to ensure shells stay centered and unclipped.

## Phase 5 – Deployment & Cleanup (1.0 h)
| # | Milestone | Verification |
|---|-----------|--------------|
| 5-1 | All obsolete background scripts/assets flagged for removal or archived. | Git PR shows deletions. |
| 5-2 | Documentation updated (`README` + this file marked **COMPLETED**). | PR merged; doc version-tagged. |

### Checklist
1. [ ] Move `BackgroundManager3D.gd`, `BackgroundLayer3D.gd`, and plane textures to `legacy/` or delete.
2. [ ] Update high-level README and this plan marking completed phases.
3. [ ] Open pull request with all changes and ensure CI passes.

---

### Success Criteria
* Skybox visually surrounds play-area with at least **5 depth layers**.
* Differential rotation yields convincing parallax from every camera pan.
* Performance: **<15 % GPU overhead, <200 MB VRAM increase**.
* No visual artefacts (seams, z-fighting, over-brightness).

_Created on {{date}}.  Update as each milestone checks off._
