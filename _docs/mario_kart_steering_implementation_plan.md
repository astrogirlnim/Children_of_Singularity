# Mario Kart Style Steering Implementation Plan

## Project Overview

Converting Children of the Singularity from the current strafe-based movement system to a true Mario Kart 8 style steering system where:
- **A/D Keys**: Steer left/right (rotate ship and camera)
- **W/S Keys**: Accelerate forward/backward in the direction the ship is facing
- **No Lateral Movement**: Ship can only move forward/backward and rotate, no strafing

## Current System Analysis

### ✅ What Works Currently
- 3D ship and camera system with perspective projection
- Ship rotation animation frames (127 frames for smooth rotation)
- Camera follows ship smoothly from behind
- Debris collection and zone boundaries working
- Mouse wheel zoom functionality

### ❌ Current Problems
- A/D keys cause lateral strafing instead of steering
- W/S moves in world space instead of ship-relative space
- Mouse rotation system has bugs (constantly setting rotation to 0)
- Movement feels arcade-like, not vehicle-like

### 🎯 Target Mario Kart Features
- **Steering Controls**: A/D rotate ship direction (like turning a steering wheel)
- **Momentum Physics**: Ship accelerates/decelerates in facing direction
- **Smooth Turning**: Ship rotation is smooth and predictable
- **Camera Following**: Camera smoothly follows behind ship as it turns
- **Ship Animation**: Visual ship rotation matches movement direction

## Technical Implementation Details

### Phase 1: Input System Redesign (Priority 1)

#### Current Input Mapping
```gdscript
# Current problematic system:
if Input.is_action_pressed("move_right"):
    input_vector.x += 1  # Lateral strafe right
if Input.is_action_pressed("move_left"):
    input_vector.x -= 1  # Lateral strafe left
if Input.is_action_pressed("move_down"):
    input_vector.y += 1  # Move backward in world space
if Input.is_action_pressed("move_up"):
    input_vector.y -= 1  # Move forward in world space
```

#### Target Mario Kart Input System
```gdscript
# New steering-based system:
var steering_input: float = 0.0
var acceleration_input: float = 0.0

# Steering (A/D keys)
if Input.is_action_pressed("move_right"):
    steering_input += 1.0  # Steer right
if Input.is_action_pressed("move_left"):
    steering_input -= 1.0  # Steer left

# Acceleration (W/S keys)
if Input.is_action_pressed("move_up"):
    acceleration_input += 1.0  # Accelerate forward
if Input.is_action_pressed("move_down"):
    acceleration_input -= 1.0  # Reverse/brake
```

### Phase 2: Ship Rotation System (Priority 1)

#### Steering-Based Rotation
- Replace mouse rotation with keyboard steering
- A/D keys control ship rotation speed, not position
- Rotation speed depends on current velocity (slower turning at high speed)
- Ship animation frames match rotation direction

#### Implementation
```gdscript
# In PlayerShip3D.gd
@export var max_turn_speed: float = 90.0  # degrees per second
@export var turn_speed_at_max_velocity: float = 45.0  # slower turning at high speed
@export var reverse_turn_multiplier: float = 0.7  # slower turning in reverse

func _apply_steering(delta: float, steering_input: float) -> void:
    if abs(steering_input) > 0.1:
        # Calculate turn speed based on current velocity
        var velocity_factor = clamp(current_velocity / max_speed, 0.2, 1.0)
        var effective_turn_speed = lerp(max_turn_speed, turn_speed_at_max_velocity, velocity_factor)

        # Apply steering
        var turn_amount = steering_input * effective_turn_speed * delta
        target_rotation += deg_to_rad(turn_amount)

        # Update ship animation to show turning
        _update_turning_animation(steering_input)
```

### Phase 3: Movement Physics System (Priority 2)

#### Forward/Backward Movement Only
- Ship only moves in its facing direction
- No lateral movement at all
- Acceleration and deceleration curves for space feel
- Momentum physics with inertia

#### Implementation
```gdscript
# In PlayerShip3D.gd
@export var max_forward_speed: float = 15.0
@export var max_reverse_speed: float = 8.0
@export var acceleration_force: float = 20.0
@export var brake_force: float = 30.0
@export var friction_force: float = 5.0

var current_velocity: float = 0.0  # Forward/backward velocity
var current_direction: Vector3 = Vector3.FORWARD

func _apply_acceleration(delta: float, acceleration_input: float) -> void:
    if acceleration_input > 0:
        # Forward acceleration
        current_velocity = move_toward(current_velocity, max_forward_speed, acceleration_force * delta)
    elif acceleration_input < 0:
        # Reverse/braking
        if current_velocity > 0:
            # Braking while moving forward
            current_velocity = move_toward(current_velocity, 0, brake_force * delta)
        else:
            # Reverse acceleration
            current_velocity = move_toward(current_velocity, -max_reverse_speed, acceleration_force * delta)
    else:
        # No input - apply friction
        current_velocity = move_toward(current_velocity, 0, friction_force * delta)

    # Apply movement in ship's facing direction
    current_direction = -transform.basis.z.normalized()
    velocity = current_direction * current_velocity
```

### Phase 4: Camera Following System (Priority 2)

#### Enhanced Camera Following
- Camera follows ship rotation smoothly
- Banking effect when turning (optional)
- Maintains optimal distance and angle
- No manual mouse rotation needed

#### Implementation
```gdscript
# In CameraController3D.gd
func _update_mario_kart_camera_position(delta: float) -> void:
    if not target:
        return

    # Get ship's current facing direction
    var ship_forward = -target.transform.basis.z.normalized()

    # Calculate camera position behind ship
    var behind_offset = ship_forward * current_distance
    var height_offset = Vector3.UP * camera_height
    var desired_position = target.global_position - behind_offset + height_offset

    # Smooth camera movement
    global_position = global_position.lerp(desired_position, follow_speed * delta)

    # Look ahead of ship for better feel
    var look_target = target.global_position + ship_forward * look_ahead_distance
    look_target.y = target.global_position.y + (camera_height * 0.5)

    # Apply banking based on turning input
    var banking_roll = 0.0
    if target.has_method("get_current_steering_input"):
        var steering = target.get_current_steering_input()
        banking_roll = steering * banking_amount

    # Apply smooth banking
    current_banking = lerp(current_banking, banking_roll, banking_speed * delta)

    # Apply banking to up vector
    var up_vector = Vector3.UP
    if abs(current_banking) > 0.01:
        up_vector = up_vector.rotated(ship_forward.normalized(), deg_to_rad(current_banking))

    look_at(look_target, up_vector)
```

### Phase 5: Ship Visual Animation (Priority 3)

#### Frame-Based Rotation Animation
- Use existing 127 animation frames
- Map ship rotation to appropriate frame
- Smooth frame transitions for fluid animation

#### Implementation
```gdscript
# In PlayerShip3D.gd
func _update_ship_visual_rotation() -> void:
    # Convert rotation to frame index (0-126)
    var normalized_rotation = fmod(rotation.y + PI, 2 * PI) / (2 * PI)  # 0-1
    var target_frame = int(normalized_rotation * 127) + 1  # 1-127

    # Clamp to valid range
    target_frame = clamp(target_frame, 1, 127)

    # Update sprite frame if different
    if target_frame != current_frame:
        _set_ship_frame(target_frame)
```

## Implementation Phases

### Phase 1: Core Steering System (Day 1)
**Goal**: Replace strafe movement with steering controls

1. **Input System Redesign**
   - Modify `_handle_input()` to use steering/acceleration model
   - Remove lateral movement completely
   - Add steering input processing

2. **Basic Ship Rotation**
   - Implement A/D steering rotation
   - Add turn speed limits and velocity-based scaling
   - Remove mouse rotation system entirely

3. **Forward/Backward Movement**
   - Implement ship-relative movement only
   - Add acceleration/deceleration physics
   - Remove all lateral movement

### Phase 2: Polish and Integration (Day 2)
**Goal**: Smooth integration with existing systems

1. **Camera Following Enhancement**
   - Update camera to follow ship rotation
   - Add banking effect for turns
   - Ensure smooth camera transitions

2. **Ship Animation Integration**
   - Connect rotation to animation frames
   - Ensure smooth frame transitions
   - Test visual consistency

3. **Physics Tuning**
   - Balance turn speeds and acceleration
   - Adjust for Mario Kart feel
   - Test with debris collection

### Phase 3: Testing and Refinement (Day 3)
**Goal**: Ensure gameplay quality and compatibility

1. **Gameplay Testing**
   - Test debris collection with new movement
   - Verify zone boundary interactions
   - Test NPC hub approach

2. **Performance Optimization**
   - Ensure smooth frame rates
   - Optimize rotation calculations
   - Test on various hardware

3. **Final Polish**
   - Fine-tune physics parameters
   - Adjust camera following
   - Balance turn speeds

## Configuration Parameters

### Ship Steering Settings
```gdscript
@export_group("Steering Controls")
@export var max_turn_speed: float = 90.0           # Max degrees/second at low speed
@export var turn_speed_at_max_velocity: float = 45.0  # Degrees/second at max speed
@export var reverse_turn_multiplier: float = 0.7    # Turn speed when reversing
@export var turn_smoothing: float = 8.0             # Rotation interpolation speed
```

### Movement Physics Settings
```gdscript
@export_group("Movement Physics")
@export var max_forward_speed: float = 15.0         # Maximum forward velocity
@export var max_reverse_speed: float = 8.0          # Maximum reverse velocity
@export var acceleration_force: float = 20.0        # Forward acceleration rate
@export var brake_force: float = 30.0               # Braking force
@export var friction_force: float = 5.0             # Natural friction when no input
@export var momentum_factor: float = 0.9            # Momentum preservation
```

### Camera Following Settings
```gdscript
@export_group("Camera Following")
@export var camera_distance: float = 12.0           # Distance behind ship
@export var camera_height: float = 4.0              # Height above ship
@export var follow_speed: float = 6.0               # Position following speed
@export var rotation_follow_speed: float = 4.0      # Rotation following speed
@export var look_ahead_distance: float = 25.0       # How far ahead to look
@export var banking_on_turns: bool = true           # Enable camera banking
@export var banking_amount: float = 12.0            # Maximum banking angle
```

## Key Files to Modify

### 1. `scripts/PlayerShip3D.gd`
- Replace `_handle_input()` with steering-based input
- Replace `_apply_3d_movement()` with forward/backward physics
- Add `_apply_steering()` method for rotation
- Remove mouse rotation interface methods
- Add steering input tracking for camera banking

### 2. `scripts/CameraController3D.gd`
- Remove mouse rotation system entirely
- Enhance ship following to track rotation
- Modify banking to use steering input instead of velocity
- Improve look-ahead targeting for better feel

### 3. `project.godot`
- Remove `mouse_rotate` input action
- Keep existing WASD input actions
- Update control documentation

### 4. `scenes/zones/ZoneMain3D.tscn`
- Update control help text to reflect steering controls
- Remove mouse rotation references

## Expected User Experience

### Before (Current System)
- WASD moves ship in world directions (strafe-like)
- Right-click + mouse rotates camera and ship
- Movement feels arcade-like, not vehicle-like
- Can move laterally without turning

### After (Mario Kart System)
- A/D steers the ship left/right (like a steering wheel)
- W/S accelerates forward/backward in ship's facing direction
- Ship must turn to change direction (no strafing)
- Camera smoothly follows behind ship as it turns
- Movement feels like driving a space vehicle

## Risk Mitigation

### Technical Risks
- **Movement Feel**: New physics might feel too different from current system
- **Turning Radius**: Ship might feel too sluggish or too twitchy
- **Camera Following**: Camera might lag or jitter during turns

### Mitigation Strategies
- Extensively tunable parameters for all movement aspects
- Gradual rollout with A/B testing capability
- Backup current movement system before changes
- Performance profiling during development

### Gameplay Risks
- **Learning Curve**: Players need to adapt to steering controls
- **Collection Difficulty**: Debris collection might become harder
- **Spatial Awareness**: Behind-camera view might reduce awareness

### Mitigation Strategies
- Clear control instructions in UI
- Balanced collection areas for new movement
- Optional camera distance adjustment
- Tutorial or practice mode

## Success Criteria

### Functional Requirements
- [ ] A/D keys rotate ship smoothly without strafing
- [ ] W/S keys move forward/backward in ship's facing direction
- [ ] Camera follows ship rotation smoothly
- [ ] Ship animation matches rotation direction
- [ ] No lateral movement possible
- [ ] Debris collection remains functional
- [ ] Zone boundaries work with new movement

### Quality Requirements
- [ ] Movement feels responsive and Mario Kart-like
- [ ] Turning feels natural and predictable
- [ ] Camera following is smooth without jitter
- [ ] Performance remains stable
- [ ] Controls are intuitive and learnable

### Optional Enhancements
- [ ] Camera banking on turns for immersion
- [ ] Speed-based turn rate for realism
- [ ] Momentum physics for space feel
- [ ] Visual effects for acceleration/deceleration

This plan transforms the game from an arcade-style movement system to a true vehicle-based steering system that matches Mario Kart 8's feel while maintaining the unique space exploration gameplay.
