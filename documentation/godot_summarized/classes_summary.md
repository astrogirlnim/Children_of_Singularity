# Summary of `classes/` Subdirectory in Godot Documentation

## Purpose
The `classes` subdirectory is the authoritative API reference for every built-in type that ships with the Godot game engine. Each reStructuredText (`.rst`) file maps **one-to-one** with a Godot engine class and documents:

* A short high-level description of what the class represents or does.
* The inheritance chain and implemented interfaces.
* Signals, Enumerations, Constants.
* Properties (with setters/getters), Methods, and Usage Notes.
* Relevant code examples and best-practice tips.

Together these files form the single source of truth for engine scripting, tooling, and editor integrations.

---

## Core Principles Surfacing Across the Class Docs
1. **Scene-Tree Architecture** – Almost every runtime object is a `Node`; classes inherit behaviour and are composed into trees/scenes that can be instanced and reused.
2. **Resource-Oriented Design** – Data containers (`Resource` derivatives) are serialisable, shareable, and drive editor tooling. Reuse over duplication is emphasised.
3. **Signals over Tight Coupling** – Observer pattern is built-in. Classes emit strongly-typed signals to decouple game logic.
4. **Deterministic Lifecycle** – `_ready()`, `_process()`, `_physics_process()`, etc., define clear execution hooks. Docs highlight where in the lifecycle each method is valid.
5. **Extensibility & Inheritance** – Every class is designed for extension via GDScript/C#/C++ with well-documented virtual methods.
6. **Editor Integration First** – Many classes expose `tool` functionality, custom inspectors, and gizmos, encouraging workflow-driven development.

---

## High-Level Taxonomy of Classes
| Category | Example Classes | Key Practices |
|---|---|---|
| **Node (System)** | `Node`, `Node2D`, `Node3D`, `Control`, `Window` | Keep nodes lightweight; prefer composition; utilise groups & scene instancing |
| **Rendering** | `Camera3D`, `Viewport`, `Light3D`, `VisualShader*` | Use visual shader nodes for no-code material logic; leverage `Viewport` for dynamic textures |
| **Physics** | `RigidBody3D`, `Area2D`, `CollisionShape3D`, `World*` | Separate physics & render layers; follow fixed-timestep callbacks |
| **Audio** | `AudioStreamPlayer`, `AudioBusLayout`, `AudioEffect*` | Route through buses; use `AudioStreamPlayer3D` for spatial sound |
| **Animation** | `AnimationPlayer`, `Skeleton3D`, `StateMachine` | Reuse animation resources; prefer AnimationTree for complex blends |
| **UI (Control)** | `Button`, `Label`, `VBoxContainer`, `Popup` | Use containers for responsive layouts; theme via `Theme` resources |
| **XR / AR** | `XRInterface`, `XRCamera3D`, `XRController3D`, `XRServer` | Abstract hardware via `XRInterface`; process input in local tracking space |
| **Networking** | `MultiplayerPeer`, `WebSocketPeer`, `WebRTCPeerConnection` | Use Scene Replication API; keep RPCs deterministic |
| **Data / Utility** | `Resource`, `Image`, `JSON`, `FileAccess` | Employ resources for data-driven workflows; avoid synchronous IO in main thread |
| **Concurrency** | `Thread`, `WorkerThreadPool` | Offload heavy tasks; use `call_deferred` for main-thread sync |

> **Tip:** The docs consistently encourage leveraging built-in classes before rolling custom solutions, ensuring maximum editor tooling support and cross-platform stability.

---

## Notable Implementation Details Captured in Docs
* **Virtual Method Tables** – Each class lists overridable callbacks (_input, _notification) and specifies threading constraints.
* **Performance Notes** – Files such as `class_window.rst` and `class_workerthreadpool.rst` include warnings on expensive operations.
* **Compatibility Layers** – Some classes highlight differences between Godot versions (e.g., deprecated properties, renamed enums).
* **Signals & Threads Safety** – Docs stress emitting signals only from the main thread unless marked thread-safe.
* **Example-Driven Learning** – Complex classes (e.g., `VisualShaderNode*`) ship with ready-to-paste GDScript snippets.

---

## Key Takeaways for Practitioners
1. **Master the Node Hierarchy** – Understanding parent/child relationships and scene instancing is foundational.
2. **Exploit Resources** – Reuse data via `Resource` to minimise memory and accelerate workflows.
3. **Harness Signals** – They are the idiomatic way to communicate between scenes without coupling.
4. **Use Editor Tools** – Many engine systems expose editors (AnimationTree, VisualShader). They are production-ready and scriptable.
5. **Read Lifecycle Notes** – Mis-ordering physics/render logic is a common pitfall; docs outline the correct callbacks.
6. **Stay Version-Aware** – Always check migration notes inside each class doc when upgrading engine versions.

---

*Generated automatically to serve as a quick-reference. For exhaustive details consult the individual `.rst` files under `godot-docs/classes/`.*

---

## Detailed File Summaries

### `class_node.rst` (Node)
The fundamental building block for the Godot scene-tree. It handles:
* **Hierarchy & Ownership** – parent/child relationships, `add_child()`, `remove_child()`, groups, and ownership for freeing.
* **Lifecycle Callbacks** – `_ready()`, `_enter_tree()`, `_exit_tree()`, and `notification` system.
* **Scene Instancing & Duplication** – how to instance packed scenes and duplicate nodes with `duplicate()`.
* **Groups & Messaging** – dynamic runtime grouping (`add_to_group()`, `has_group()`) and group method calls.
* **Deferred Calls** – `call_deferred()` / `set_deferred()` for thread-safe modifications.
* **Tree Traversal** – methods for finding nodes (`get_node()`, `get_children()`, `find_child()`).
* **Signals** – `tree_entered`, `tree_exited`, `ready`, etc., enabling decoupled communication.

### `class_node2d.rst` (Node2D)
2D spatial node adding position, rotation, scale:
* **Transform2D** – Provides `position`, `rotation`, `scale`, and `global_position` helpers.
* **Drawing Order** – `z_index` and `z_as_relative` for layering within the canvas.
* **Coordinate Utilities** – conversion between global/local, angle helpers, move/rotate toward.
* **Edit Helpers** – gizmos in the 2D editor for intuitive manipulation.

### `class_node3d.rst` (Node3D)
3D spatial analogue of Node2D:
* **Transform3D** – position, basis (rotation), scale, and conversion helpers.
* **Visibility** – `visible` flag, `visible_in_tree` read-only, and culling options.
* **Orientation Utilities** – `look_at()`, `rotate()`, `rotate_object_local()`, etc.
* **Gizmos** – editor visual aids, can be extended via `EditorNode3DGizmo` plugins.

### `class_control.rst` (Control)
Root of UI system:
* **Anchors & Margins** – flexible layout using anchors (0-1) and pixel offsets.
* **Theme Properties** – styleboxes, fonts, colours inherited through tree.
* **Focus & Keyboard Navigation** – focus modes, tab order, shortcut handling.
* **Input Handling** – `_gui_input(event)` for UI-specific events, automatic mouse filtering.
* **Size Flags & Containers** – grow/shrink behaviour inside layout containers.

### `class_window.rst` (Window)
Top-level OS window (or sub-window):
* **OS-Level Controls** – resize, fullscreen, borderless, minimised, etc.
* **Content Management** – houses a root `Control` node for UI.
* **Pop-up API** – centre, pop-up modal, transient parents.
* **Platform Specifics** – multiple window support varies per platform; docs outline limitations.

### `class_camera3d.rst` (Camera3D)
Defines a perspective or orthographic camera in 3D:
* **Projection Modes** – perspective, orthographic, frustum.
* **Culling Masks & Layers** – selective rendering via visibility layers.
* **Post-processing Effects** – environment overrides, exposure, DOF.
* **Controls** – current active camera, smoothing, FOV animation.

### `class_viewport.rst` (Viewport)
Rendering target that can display a scene or render to texture:
* **Render Buffers** – size, usage, HDR, MSAA, scaling 2D.
* **Input Forwarding** – handles input focus and propagation.
* **Texture Output** – renders to `ViewportTexture` for in-game screens, mirrors, minimaps.
* **World Overrides** – separate 2D/3D world for split-screen or picture-in-picture.

### `class_light3d.rst` (Light3D)
Abstract base for 3D lights:
* **Types** – Omni, Spot, Directional via subclasses.
* **Shadows** – shadow map size, bias, contact hardening.
* **Colour & Energy** – physical light units support, temperature.
* **Bake Mode** – dynamic, static, mixed for lightmapper.

### `class_visualshader*.rst` (Visual Shader Nodes)
Family of nodes under `VisualShaderNode*`:
* **Node-Graph Shader Authoring** – create materials via nodes rather than code.
* **Uniform & Constant Nodes** – expose parameters to the inspector.
* **Flow Control** – reroute, if, switch nodes provide logic.
* **Preview & Debugging** – real-time preview of outputs.

### `class_rigidbody3d.rst` (RigidBody3D)
Physics body affected by forces:
* **Modes** – Rigid, Static, Character, Kinematic.
* **Integration Callback** – `_integrate_forces(state)` for custom physics.
* **Collision Layers & Masks** – filtering collisions.
* **Sleeping & Damp** – performance optimisations.

### `class_area2d.rst` (Area2D)
Detection & influence area in 2D:
* **Monitoring** – body/area entered/exited signals.
* **Gravity & Damp** – can override physics in region.
* **Audio Bus & Reverb** – 2D reverb zones.

### `class_collisionshape3d.rst` (CollisionShape3D)
Holds a `Shape3D` resource for collision:
* **Disabled Flag** – toggle collision at runtime without freeing.
* **One-Way Collision** – optional for platforms.

### `class_world*.rst` (World2D / World3D)
Containers for physics and rendering state:
* **Direct Access** – physics spaces, navigation maps, environment.
* **Multiple Worlds** – split-screen / portals.

### `class_audiostreamplayer.rst` (AudioStreamPlayer)
Plays 2D audio streams:
* **Stream Types** – Ogg, WAV, `AudioStreamRandomPitch`, etc.
* **Bus & Volume** – route to bus, dB control, attenuation.
* **Playback Controls** – seek, pitch scale.

### `class_audiobuslayout.rst` (AudioBusLayout)
Resource defining mixer buses:
* **Graph Topology** – bus order, sends, effects chain.
* **Serialization** – saved into `.tres` files for reuse.

### `class_audioeffect*.rst` (AudioEffect reverb/eq/etc.)
* **Modular Effects** – stackable DSP processing per bus.
* **Realtime Parameters** – can tweak via script for dynamics.

### `class_animationplayer.rst` (AnimationPlayer)
Timeline player for `Animation` resources:
* **Key Track Types** – property, method, signal, bezier.
* **Blend & Sync** – fade, transition, layer mixing.
* **Callback Tracks** – drive gameplay at keyframes.

### `class_skeleton3d.rst` (Skeleton3D)
Hierarchical bone system:
* **Skinning** – meshes reference bones.
* **IK & Constraints** – built-in solvers.
* **Bone Attachment** – attach nodes to moving bones.

### `class_statemachine.rst` (StateMachine)
Graph-based animation state engine:
* **Blend Trees** – linear, crossfade, mix.
* **Transition Rules** – time, signals, parameters.

### `class_button.rst` (Button)
Clickable UI component:
* **Themes & Styles** – normal, pressed, hover, disabled.
* **Toggle Mode** – acts as checkbox.
* **Shortcut Keys** – `Shortcut` resource support.

### `class_label.rst` (Label)
Text display control:
* **BBCode & RichText** – limited markup.
* **Autowrap & Ellipsis** – fit content.

### `class_vboxcontainer.rst` (VBoxContainer)
Vertical UI layout container that auto-stacks children.

### `class_popup.rst` (Popup)
Base for pop-up windows/dialogs:
* **Modal Handling** – blocks input, emits close signals.
* **Size & Position Helpers** – `popup_centered_ratio()`, etc.

### `class_xrinterface.rst` (XRInterface)
Abstraction layer for XR runtimes:
* **Session Lifecycle** – initialise, start, end.
* **Tracking Spaces** – local, stage.
* **Input Profiles** – controllers, hands.

### `class_xrcamera3d.rst` (XRCamera3D)
Camera that follows HMD pose.

### `class_xrcontroller3d.rst` (XRController3D)
Represents a tracked controller with buttons & pose.

### `class_xrserver.rst` (XRServer)
Singleton managing all XR interfaces and devices.

### `class_multiplayerpeer.rst` (MultiplayerPeer)
Abstract networking peer used by `MultiplayerAPI`:
* **Packet Handling** – send, poll.
* **Connection Status** – signals for join/leave.

### `class_websocketpeer.rst` (WebSocketPeer)
WebSocket implementation of `PacketPeer`.

### `class_webrtcpeerconnection.rst` (WebRTCPeerConnection)
WebRTC transport enabling P2P connections.

### `class_resource.rst` (Resource)
Base for serialisable engine data.

### `class_image.rst` (Image)
2D pixel buffer with manipulation, compression.

### `class_json.rst` (JSON)
Parsing/printing JSON with error reporting.

### `class_fileaccess.rst` (FileAccess)
Abstracted file IO with platform back-ends.

### `class_thread.rst` (Thread)
Wrapper around OS threads; start, wait_to_finish.

### `class_workerthreadpool.rst` (WorkerThreadPool)
