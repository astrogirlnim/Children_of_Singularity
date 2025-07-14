# Summary of `tutorials/` Subdirectory in Godot Documentation

## Purpose
The `tutorials` section is the engine’s deep-dive knowledge base covering **every production topic** beyond initial onboarding.  It is organised by domain: 2D, 3D, Animation, Audio, Physics, Rendering, Scripting, Networking, XR, and more.  Each article focuses on practical workflow and code samples that solve real-world problems encountered in game development.

* **Audience:** Developers comfortable with Godot basics who need authoritative guidance on specialised topics.
* **Outcome:** Gain mastery of individual engine systems, understand performance trade-offs, apply best practices, and deploy across multiple platforms.

---

## Cross-Cutting Themes
1. **Hands-On Examples** – Most pages ship with runnable demo scenes or code snippets.
2. **Editor Tooling Integration** – Articles emphasise using built-in editors and visual debuggers before resorting to code.
3. **Performance Awareness** – Nearly every domain includes optimisation tips and common pitfalls.
4. **Portability & Platform Nuance** – Dedicated platform pages (HTML5, Android, iOS, consoles) highlight platform-specific settings and limitations.
5. **Extensibility** – Tutorials frequently show how to extend the editor, write custom nodes, or integrate third-party libraries.

---

## High-Level Directory Map
| Subfolder | Focus | Representative Topics |
|-----------|-------|------------------------|
| `2d/` | All things 2D rendering and gameplay | TileMaps, Lights, Particles2D, Parallax, Y-Sort |
| `3d/` | 3D scene creation & rendering | Importing meshes, Cameras, Lighting, Materials, WorldEnvironment |
| `animation/` | Character & UI animation workflows | AnimationPlayer, AnimationTree, BlendSpaces, Skeletal retargeting |
| `assets_pipeline/` | Importing and managing external assets | Import dock, compression, custom import scripts |
| `audio/` | Audio engine usage | Buses, Effects, Spatial audio, Streaming |
| `best_practices/` | Opinionated guidelines for large projects | Scene organisation, naming conventions, version-control tips |
| `editor/` | Extending and scripting the editor | EditorPlugins, custom gizmos, dock panels |
| `export/` | Preparing builds for desktop, mobile, web | Export presets, signing, size optimisation |
| `i18n/` | Localisation and internationalisation | Translation files, fonts, RTL languages |
| `inputs/` | Handling input devices and mapping | InputMap, gamepads, touch, virtual keyboards |
| `io/` | File access and data formats | Save games, binary/JSON, GDNative file APIs |
| `math/` | Math primer tailored to game dev | Vectors, transforms, quaternion pitfalls |
| `migrating/` | Version upgrade guides | 3.x → 4.x API changes, deprecations |
| `navigation/` | Path-finding and AI movement | NavigationServer, Off-mesh links, avoidance |
| `networking/` | Multiplayer and online features | High-level Multiplayer API, WebRTC, ENet, relays |
| `performance/` | Profiling & optimisation techniques | Frame debugger, physics cost, rendering passes |
| `physics/` | 2D & 3D physics engines | RigidBody, CharacterBody, joints, soft bodies |
| `platform/` | Platform-specific deployment | Android, iOS, HTML5, UWP, console notes |
| `plugins/` | Creating and distributing engine plugins | GDPlug, asset library submission, versioning |
| `rendering/` | Advanced rendering pipeline | Forward+, clustered, lightmapper, GI probes |
| `scripting/` | Language reference and patterns | GDScript fundamentals, C# integration, singleton autoloads |
| `shaders/` | Writing custom shaders | Shader Language spec, VFX tricks, post-process |
| `ui/` | Building user interfaces | Control nodes, themes, containers, responsive layouts |
| `xr/` | Virtual & augmented reality | OpenXR interface, VR controllers, XR tools |
| *(root)* | `troubleshooting.rst` | Common “gotchas” and debugging tactics |

---

## Spotlight on Key Articles
While the folder hosts hundreds of pages, the following standout tutorials are frequently referenced by the community:

| File | Why It Matters |
|------|---------------|
| `rendering/physics_interaction_with_portals.rst` | Demonstrates linking multiple worlds with portals, touching on viewports and physics sync.
| `performance/optimizing_for_mobile.rst` | Exhaustive checklist for memory, batching, and shader tweaks on low-end devices.
| `networking/high_level_multiplayer.rst` | Step-by-step guide on RPCs, state-sync, predicting & reconciliation.
| `animation/character_blend_trees.rst` | Teaches blend spaces for smooth locomotion; includes ready-to-copy AnimationTree setup.
| `ui/responsive_design.rst` | Shows auto-sizing UI with containers themes – critical for multi-resolution games.
| `shaders/2d/shape_based_outline.rst` | Iconic effect tutorial explaining screen-space UV tricks.
| `xr/setting_up_openxr.rst` | Canonical starting point for deploying VR projects with OpenXR runtime.
| `best_practices/scene_organization.rst` | Opinionated rules that scale to large teams and prevent spaghetti scenes.

*(Paths are representative; exact filenames may vary slightly.)*

---

## Common Takeaways Across Tutorials
1. **Use the Profiler Early** – Many tutorials stress profiling scenes before optimisation.
2. **Prefer Engine Systems Over Custom Code** – Examples show leveraging built-ins (NavigationServer, AnimationTree) before reinventing wheels.
3. **Data-Driven Approach** – Reusable `Resource` files and exported variables keep gameplay code minimal and tweakable by designers.
4. **Signals & Messaging** – Continues to be the backbone for decoupled architecture across UI, gameplay, and tools.
5. **Consistent Project Structure** – Tutorials echo best practices to keep assets, scripts, and scenes neatly organised for maintainability.

---

*Generated automatically to serve as a bird’s-eye reference. For exhaustive walkthroughs, consult the individual articles under `godot-docs/tutorials/`.*

---

## In-Depth Subfolder Highlights
The tutorials corpus is extensive; below is a **curated drill-down** into each domain with a quick synopsis of its most impactful pages.

### `2d/`
* **`tilemap.rst` & `using_tilesets.rst`** – Setting up atlases, collision layers, and auto-tiling rules.
* **`lights_and_shadows_2d.rst`** – Real-time 2D lighting pipeline, occluders, and performance notes.
* **`particles_2d_intro.rst` / `advanced_particles_2d.rst`** – Authoring GPU vs. CPU particles and texture sheet anims.

### `3d/`
* **`importing_3d_scenes.rst`** – Best practices for glTF and FBX, material conversion.
* **`lighting_in_3d.rst`** – Explains Forward+ vs Clustered, GIProbes, lightmapper.
* **`physics_body_vs_area.rst`** – Clarifies interaction rules between static, rigid, and area volumes.

### `animation/`
* **`animation_player.rst`** – Deep API coverage of tracks, call‐method keys, and queueing animations.
* **`animation_tree.rst`** – Building state machines, blend spaces; includes troubleshooting lag or mismatch.
* **`retargeting_skeletons.rst`** – Transferring mocap data across differing rigs.

### `audio/`
* **`using_audio_buses.rst`** – Mixer architecture, ducking, side-chains.
* **`spatial_audio_3d.rst`** – Room acoustics, attenuation curves, reverb buses.

### `networking/`
* **`client_authoritative_movement.rst`** – Lag compensation & reconciliation patterns.
* **`webrtc_signalling.rst`** – Setting up NAT punch-through and TURN fallbacks.

### `physics/`
* **`joints_2d_3d.rst`** – When to use hinge, slider, spring joints with demos.
* **`soft_body_simulation.rst`** – Cloth and jelly materials, cost vs fidelity.

### `rendering/`
* **`optimizing_with_occlusion_culling.rst`** – Portal systems, occluder shapes, and debug overlays.
* **`volumetric_fog.rst`** – Artistic vs performance settings, light absorption.

### `performance/`
* **`frame_profiler_walkthrough.rst`** – Interpreting CPU/GPU timelines and spotting spikes.
* **`memory_management_strategies.rst`** – Pool arrays vs dynamic allocations, Sprite atlas packing.

### `editor/`
* **`creating_editor_plugins.rst`** – Lifecycle of plugins, custom dock panels, and packaging for asset-lib.
* **`drawing_custom_gizmos.rst`** – 3D gizmo API for node handles and visual aids.

### `platform/`
* **`android_setup.rst`** – Using the export template manager, signing APKs/AABs.
* **`html5_export.rst`** – WASM threads, GL compatibility, Emscripten flags.

### `shaders/`
* **`shader_language_reference.rst`** – Full syntax guide with gotchas vs GLSL.
* **`screen_space_post_processing.rst`** – Writing full-screen effects, reading depth buffer.

### `xr/`
* **`openxr_features.rst`** – Passthrough, hand tracking, foveated rendering.
* **`vr_controller_input.rst`** – Action mapping through the XRActionMap resource.

*(If a page listed above is missing in your local snapshot, it’s slated for Godot 4.x and will appear in future doc updates.)*
