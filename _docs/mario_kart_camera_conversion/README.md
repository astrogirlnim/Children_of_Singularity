# Mario Kart 8 Style Camera Conversion Plan

## Project Overview

Converting Children of the Singularity from the current 2.5D orthogonal camera system to a Mario Kart 8 style perspective camera with behind-the-ship following and constrained movement controls.

## Current State Assessment

### ✅ Already Implemented
- **3D Infrastructure**: Complete 3D scene with PlayerShip3D, debris system, and zone boundaries
- **Camera System**: CameraController3D with orthogonal projection and zoom functionality
- **Movement**: Free X-Z plane movement with gravity on Y-axis
- **Physics**: RigidBody3D debris with collection areas
- **Zone Boundaries**: Invisible collision walls constraining play area
- **Debris Collection**: Working 3D collection system with 5 debris types

### 🎯 Target Mario Kart 8 Features
- **Perspective Camera**: Behind-the-ship camera with perspective projection
- **Smooth Following**: Camera follows ship rotation with configurable lag
- **Zoomable Viewport**: Maintain current zoom functionality (critical requirement)
- **Camera Tilt**: Optional banking effect when turning upward
- **Constrained Movement**: Forward/backward + steering instead of free movement
- **Momentum Physics**: Space-appropriate momentum and inertia
- **Ship Rotation**: Use rotating gif frames for directional facing

## Technical Requirements

### Ship Rotation Animation
- **Source Asset**: `documentation/design/sprite_assets/ship_animation/ship_sprite_concept_vibrant.gif`
- **Implementation**: Extract frames and create rotation-based sprite switching
- **Orientation**: Ship faces movement direction for Mario Kart feel

### Camera Specifications
- **Projection**: Perspective (75-90 degree FOV, Mario Kart style)
- **Position**: Behind ship at configurable distance
- **Following**: Smooth lag for cinematic feel
- **Zoom**: Keep current zoom system (min/max/mouse wheel controls)
- **Tilt**: Camera can bank when ship turns upward

### Movement System
- **Forward/Backward**: Accelerate/decelerate along ship's facing direction  
- **Steering**: Left/right turn ship orientation, not immediate lateral movement
- **Momentum**: Physics-based momentum for space environment
- **Boundaries**: Respect existing zone boundary collision system

## Implementation Phases

### Phase 1: Camera Perspective Conversion (Day 1)
**Goal**: Convert from orthogonal to perspective camera positioned behind ship

#### 1.1 Camera Projection Update
- Convert `CameraController3D` from orthogonal to perspective projection
- Set appropriate FOV (75-90 degrees) for Mario Kart feel
- Maintain zoom functionality by adjusting camera distance instead of ortho size
- Update near/far clipping planes for 3D depth

#### 1.2 Behind-Ship Positioning
- Position camera behind ship at configurable distance
- Implement smooth following with rotation tracking
- Add camera offset configuration for optimal view angle
- Test camera collision with zone boundaries

#### 1.3 Zoom System Adaptation
- Convert orthogonal zoom (size) to perspective zoom (distance)
- Maintain mouse wheel and keyboard zoom controls
- Preserve zoom min/max limits with distance-based system
- Ensure smooth zoom transitions

### Phase 2: Movement System Overhaul (Day 2)
**Goal**: Replace free XZ movement with forward/steering controls

#### 2.1 Input System Redesign
- Map movement inputs to forward/backward acceleration
- Map turn inputs to ship rotation (yaw)
- Remove direct lateral movement (no strafing)
- Preserve interaction inputs (collect, interact)

#### 2.2 Physics-Based Movement
- Implement momentum system for space environment
- Add acceleration/deceleration curves
- Implement steering with configurable turn rate
- Maintain collision with zone boundaries and debris

#### 2.3 Movement Feel Tuning
- Balance acceleration vs max speed for space feel
- Tune turning responsiveness for Mario Kart-like handling
- Add friction/drag for realistic space physics
- Test movement with debris collection gameplay

### Phase 3: Ship Rotation & Animation (Day 3)
**Goal**: Implement ship rotation using rotating gif frames

#### 3.1 Animation Frame Extraction
- Extract individual frames from `ship_sprite_concept_vibrant.gif`
- Create texture array for rotation animation
- Determine optimal frame count for smooth rotation
- Import frames with consistent scaling (pixel_size: 0.0055)

#### 3.2 Rotation System Implementation
- Create ship rotation controller based on movement direction
- Implement frame switching based on ship orientation
- Add smooth interpolation between frames
- Maintain billboard mode for camera-facing

#### 3.3 Movement-Rotation Coupling
- Link ship visual rotation to movement direction
- Implement turn anticipation for responsive feel
- Add rotation speed limits for realistic physics
- Test visual consistency with debris collection

### Phase 4: Camera Following & Effects (Day 4)
**Goal**: Implement smooth camera following with optional effects

#### 4.1 Advanced Following System
- Implement configurable camera lag for cinematic feel
- Add smooth rotation following without jitter
- Implement position prediction for responsive tracking
- Add camera distance adjustment based on speed

#### 4.2 Camera Tilt System
- Implement optional banking when ship turns upward
- Add configurable tilt amount and smoothing
- Link tilt to ship's Y-axis movement or turn rate
- Ensure tilt doesn't interfere with gameplay clarity

#### 4.3 Camera Polish
- Add smooth transitions between camera states
- Implement camera bounds checking to prevent wall clipping
- Add optional camera shake for impacts (disabled initially)
- Fine-tune camera responsiveness for Mario Kart feel

### Phase 5: Integration & Testing (Day 5)
**Goal**: Full system integration and gameplay testing

#### 5.1 Debris Collection Testing
- Verify collection system works with new movement
- Test collection areas with momentum-based movement
- Ensure collection feedback is clear with perspective camera
- Balance collection difficulty with new controls

#### 5.2 Zone Boundary Integration
- Test boundary collision with momentum physics
- Verify boundary warnings work with perspective camera
- Ensure smooth collision response doesn't break immersion
- Test boundary visibility from behind-ship camera

#### 5.3 Performance & Polish
- Profile camera and movement system performance
- Optimize rotation frame switching for smooth animation
- Balance visual quality vs performance for target framerate
- Final tuning of camera distance, FOV, and movement feel

## Configuration Parameters

### Camera Settings
```gdscript
@export var camera_distance: float = 15.0        # Distance behind ship
@export var camera_height: float = 5.0           # Height above ship
@export var camera_fov: float = 80.0             # Field of view (degrees)
@export var follow_speed: float = 5.0            # Camera follow responsiveness
@export var rotation_lag: float = 0.3            # Rotation following lag
@export var zoom_min_distance: float = 8.0       # Closest zoom
@export var zoom_max_distance: float = 25.0      # Furthest zoom
@export var enable_camera_tilt: bool = false     # Banking on turns
@export var tilt_amount: float = 10.0            # Max tilt angle (degrees)
```

### Movement Settings
```gdscript
@export var acceleration: float = 15.0           # Forward acceleration
@export var max_speed: float = 25.0              # Maximum speed
@export var turn_speed: float = 120.0            # Degrees per second
@export var friction: float = 5.0                # Space friction/drag
@export var momentum_factor: float = 0.8         # Momentum preservation
@export var reverse_speed_factor: float = 0.5    # Reverse speed multiplier
```

### Animation Settings
```gdscript
@export var rotation_frames: int = 16            # Number of rotation frames
@export var frame_switch_threshold: float = 22.5 # Degrees per frame
@export var rotation_smoothing: bool = true      # Smooth frame transitions
```

## Success Criteria

### Functional Requirements
- [ ] Camera follows ship from behind with perspective projection
- [ ] Zoom system works with mouse wheel and maintains min/max limits
- [ ] Ship movement uses forward/steering controls only
- [ ] Ship visually rotates to face movement direction
- [ ] Momentum physics feel appropriate for space environment
- [ ] Debris collection system remains fully functional
- [ ] Zone boundaries properly constrain movement

### Quality Requirements
- [ ] Movement feels responsive and Mario Kart-like
- [ ] Camera following is smooth without jitter
- [ ] Ship rotation animation is fluid and natural
- [ ] Performance remains stable at target framerate
- [ ] Visual consistency maintained with existing debris/station systems

### Optional Enhancements
- [ ] Camera tilt on upward turns (if time permits)
- [ ] Speed-based camera distance adjustment
- [ ] Advanced momentum effects for space realism
- [ ] Rotation anticipation for improved responsiveness

## Risk Mitigation

### Technical Risks
- **Performance Impact**: Monitor framerate during perspective rendering
- **Camera Clipping**: Ensure camera doesn't clip through zone boundaries
- **Movement Feel**: Balance realism vs responsiveness for fun gameplay
- **Animation Smoothness**: Optimize frame switching for fluid rotation

### Gameplay Risks
- **Collection Difficulty**: New movement may make debris collection harder
- **Learning Curve**: Players need to adapt to steering-based movement
- **Spatial Awareness**: Behind-camera view may reduce field awareness

### Mitigation Strategies
- Incremental testing after each phase
- Configurable parameters for easy tuning
- Backup current 3D system before major changes
- Performance profiling throughout development

## Dependencies

### Assets Required
- Ship rotation frames extracted from `ship_sprite_concept_vibrant.gif`
- No new art assets needed beyond existing sprites

### Systems Integration
- Must maintain compatibility with existing debris collection
- Zone boundary system integration required
- API client and upgrade system compatibility
- Network manager integration for multiplayer

## Timeline

**Total Estimated Time**: 5 days
- **Phase 1**: 1 day (Camera conversion)
- **Phase 2**: 1 day (Movement system)
- **Phase 3**: 1 day (Ship rotation)
- **Phase 4**: 1 day (Camera polish)
- **Phase 5**: 1 day (Integration & testing)

This plan prioritizes getting the core Mario Kart 8 feel established quickly, then adding polish and effects. Each phase builds on the previous while maintaining the existing debris collection gameplay that's already working well.
