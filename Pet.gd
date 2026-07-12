extends Node2D

# State definitions
enum State {
    IDLE,
    WANDER,
    CHASE_CURSOR,
    CHASE_ITEM,
    EATING,
    SLEEPING,
    AGITATED,
    SICK,
    RETURNING_TO_DISPENSER,
    EMERGING_FROM_DISPENSER,
    RELIEVING_SELF,
    SELF_DISPENSE,
    WINDOW_SIT
}

signal returned_to_box(breed_name)

# Settings
export(Resource) var breed_data = null
export(float) var spring_k = 280.0
export(float) var damping = 14.0
export(float) var bounce_damping = 0.6
export(float) var gravity = 300.0
export(int) var num_points = 16

var active_breed = null
var base_radius = 20.0
var segment_positions = []

# Stats & AI
const PetStats = preload("res://PetStats.gd")
var stats = null
var current_state = State.IDLE
var state_timer = 0.0
var decay_enabled = true

# Physics variables for outer points
var point_positions = PoolVector2Array()
var point_velocities = PoolVector2Array()
var target_relative_offsets = PoolVector2Array()

# Kinematics for center
var center_vel = Vector2.ZERO
var is_dragging = false
var drag_positions = []
var prev_mouse_pos = Vector2.ZERO

# Interaction targets
var target_item = null
var target_wander_pos = Vector2.ZERO

# Transition & Toilet variables
var transition_nozzle_pos = Vector2.ZERO
var pending_breed_res = null
var transition_scale = 1.0
var relieve_corner_pos = Vector2.ZERO

# Foot stepping variables
var foot_positions = []
var foot_step_progress = []
var foot_step_start = []
var foot_step_target = []
var facing_dir = 1.0
var is_falling = false

# Eyes and face features (relative to center)
var eye_left_pos = Vector2.ZERO
var eye_right_pos = Vector2.ZERO
var mouth_pos = Vector2.ZERO
var look_dir = Vector2.RIGHT

# Colors
var outline_color = Color("ffffff") # White glow

# Shape drift reset
var shape_reset_timer = 0.0

# Head shake reaction
var head_shake_timer = 0.0
var head_shake_intensity = 0.0

# Ball hit tracking for anger escalation
var ball_hit_times = []   # timestamps of recent ball hits
var ball_hit_window = 10.0  # seconds within which hits are counted

# Toy play tracking — sustained play near toy
var toy_play_time = 0.0

# Poop proximity sickness
var poop_proximity_timer = 0.0

# Sick auto-return timer
var sick_auto_return_timer = 0.0

# State-restore from dispenser (breed switch state save/restore)
var pending_restore_stats = null  # Dictionary or null

# Window interaction
var window_border_targets = []   # Array of Vector2
var window_query_timer = 0.0
var window_sit_duration = 0.0

func _ready():
    # Initialize PetStats if not provided
    if stats == null:
        stats = PetStats.new()
        
    randomize()
    
    # Load default breed if none assigned
    if breed_data == null:
        breed_data = load("res://breeds/grubby.tres")
    active_breed = breed_data
    base_radius = active_breed.head_radius
    
    # Initialize segment trail positions
    segment_positions.clear()
    for i in range(active_breed.num_segments):
        segment_positions.append(global_position + Vector2.LEFT * (i * active_breed.segment_spacing))
        
    # Initialize foot arrays
    foot_positions.clear()
    foot_step_progress.clear()
    foot_step_start.clear()
    foot_step_target.clear()
    if active_breed.has_limbs:
        for _i in range(active_breed.num_limbs):
            foot_positions.append(global_position)
            foot_step_progress.append(1.0)
            foot_step_start.append(global_position)
            foot_step_target.append(global_position)
    
    # Initialize outer points in circle shape
    for i in range(num_points):
        var angle = i * 2.0 * PI / num_points
        var offset = Vector2(cos(angle), sin(angle)) * base_radius
        point_positions.append(global_position + offset)
        point_velocities.append(Vector2.ZERO)
        target_relative_offsets.append(offset)
        
    _change_state(State.IDLE)

func _physics_process(delta):
    # 1. Decay drives if enabled
    if decay_enabled:
        stats.decay(delta)
        
    # Check for state transitions based on drives
    _evaluate_states(delta)
    
    # 2. Update state behaviors
    _update_state_behavior(delta)
    
    # 3. Calculate target deformation offsets based on current drives & states
    var spring_params = _update_deformed_targets(delta)
    var k = spring_params.k
    var dmp = spring_params.damping

    # 3.5. Update head shake and hit tracking
    if head_shake_timer > 0.0:
        head_shake_timer = max(0.0, head_shake_timer - delta)
        head_shake_intensity = lerp(head_shake_intensity, 0.0, delta * 6.0)
    # Expire old ball hits outside the window
    var now = OS.get_ticks_msec() * 0.001
    var i_clean = 0
    while i_clean < ball_hit_times.size():
        if now - ball_hit_times[i_clean] > ball_hit_window:
            ball_hit_times.remove(i_clean)
        else:
            i_clean += 1

    # 4. Center node movement
    var bounds = _get_viewport_bounds()
    if is_dragging:
        # Dragging physics
        var mouse_pos = get_global_mouse_position()
        global_position = mouse_pos
        center_vel = Vector2.ZERO
        
        # Track drag speed for throwing
        drag_positions.append(mouse_pos)
        if drag_positions.size() > 5:
            drag_positions.remove(0)
            
        # Agitation increases if dragged rapidly
        if prev_mouse_pos != Vector2.ZERO:
            var dist_moved = mouse_pos.distance_to(prev_mouse_pos)
            if dist_moved > 40.0:
                stats.agitation = clamp(stats.agitation + dist_moved * 0.15, 0.0, 100.0)
        prev_mouse_pos = mouse_pos
    else:
        # Physics movement
        var apply_grav = is_falling or current_state == State.EMERGING_FROM_DISPENSER
        
        if apply_grav:
            center_vel.y += gravity * delta
            
        # Apply friction
        center_vel *= 0.98
        
        # Apply velocity
        global_position += center_vel * delta
        
        # Center bounds collision
        var radius = base_radius
        if global_position.x < bounds.position.x + radius:
            global_position.x = bounds.position.x + radius
            center_vel.x = -center_vel.x * bounce_damping
            stats.agitation += 2.0
        elif global_position.x > bounds.end.x - radius:
            global_position.x = bounds.end.x - radius
            center_vel.x = -center_vel.x * bounce_damping
            stats.agitation += 2.0
            
        if global_position.y < bounds.position.y + radius:
            global_position.y = bounds.position.y + radius
            center_vel.y = -center_vel.y * bounce_damping
            stats.agitation += 2.0
        elif global_position.y > bounds.end.y - radius:
            global_position.y = bounds.end.y - radius
            center_vel.y = -center_vel.y * bounce_damping
            # If vertical velocity becomes very small, stop falling
            if abs(center_vel.y) < 30.0:
                center_vel.y = 0.0
                is_falling = false
            # Friction on floor
            center_vel.x *= 0.8
            
    # 5. Simulate outer points (Spring-Mass System)
    for i in range(num_points):
        var p_pos = point_positions[i]
        var p_vel = point_velocities[i]
        
        var target_global = global_position + target_relative_offsets[i]
        
        # Spring force towards target
        var force = -k * (p_pos - target_global)
        # Damping force
        force -= dmp * p_vel
        
        # Update point physics
        p_vel += force * delta
        p_pos += p_vel * delta
        
        # Outer point boundary collisions
        if p_pos.x < bounds.position.x:
            p_pos.x = bounds.position.x
            p_vel.x = -p_vel.x * bounce_damping
        elif p_pos.x > bounds.end.x:
            p_pos.x = bounds.end.x
            p_vel.x = -p_vel.x * bounce_damping
            
        if p_pos.y < bounds.position.y:
            p_pos.y = bounds.position.y
            p_vel.y = -p_vel.y * bounce_damping
        elif p_pos.y > bounds.end.y:
            p_pos.y = bounds.end.y
            p_vel.y = -p_vel.y * bounce_damping
            # Floor friction for point
            p_vel.x *= 0.8
            
        point_positions[i] = p_pos
        point_velocities[i] = p_vel
        
    # 5.4 Shape drift: soft-reset points toward target each frame + periodic hard-reset timer
    shape_reset_timer += delta
    var do_hard_reset = shape_reset_timer >= 30.0
    if do_hard_reset:
        shape_reset_timer = 0.0
    for ri in range(num_points):
        var ideal = global_position + target_relative_offsets[ri]
        if current_state == State.SLEEPING or do_hard_reset:
            # Hard snap toward clean position when sleeping or on timer
            point_positions[ri] = lerp(point_positions[ri], ideal, 0.12)
            point_velocities[ri] = point_velocities[ri] * 0.5
        else:
            # Soft continuous correction to prevent drift over time
            point_positions[ri] = lerp(point_positions[ri], ideal, 0.003)

    # 5.5 Simulate trailing body segments
    if center_vel.x < -15.0:
        facing_dir = -1.0
    elif center_vel.x > 15.0:
        facing_dir = 1.0
        
    if segment_positions.size() > 0:
        segment_positions[0] = global_position
        if active_breed.breed_name == "Slinky" and segment_positions.size() >= 3:
            # Horizontal quadruped spine for Slinky
            var target_chest = global_position + Vector2(-facing_dir * active_breed.segment_spacing, 8.0)
            var target_hips = segment_positions[1] + Vector2(-facing_dir * active_breed.segment_spacing, 0.0)
            
            segment_positions[1] = lerp(segment_positions[1], target_chest, 0.22)
            segment_positions[2] = lerp(segment_positions[2], target_hips, 0.22)
            
            for i in range(1, 3):
                segment_positions[i].x = clamp(segment_positions[i].x, 0.0, bounds.end.x)
                segment_positions[i].y = clamp(segment_positions[i].y, 0.0, bounds.end.y)
        else:
            # Default trailing tail / caterpillar follow — with max-distance constraint
            for i in range(1, segment_positions.size()):
                var target = segment_positions[i-1]
                var diff = segment_positions[i] - target
                var dist = diff.length()
                
                var dir = Vector2.DOWN  # default fallback
                if dist > 0.001:
                    dir = diff / dist
                
                # Max distance constraint: segment can't be further than spacing*1.3
                var max_dist = active_breed.segment_spacing * 1.3
                if dist > max_dist:
                    segment_positions[i] = target + dir * max_dist
                    dist = max_dist

                var movement_dir = dir
                var perp = Vector2(-movement_dir.y, movement_dir.x)
                
                var speed_factor = clamp(center_vel.length() / 80.0, 0.1, 1.5)
                if current_state == State.SLEEPING:
                    speed_factor = 0.0
                    
                var wobble_phase = OS.get_ticks_msec() * 0.001 * active_breed.wobble_speed - i * 0.8
                var wobble = sin(wobble_phase) * active_breed.wobble_amplitude * speed_factor
                # Scale wobble down when segment is near max distance (prevents spinning)
                wobble *= clamp(1.0 - dist / max_dist, 0.0, 1.0)
                
                segment_positions[i] = target + dir * active_breed.segment_spacing + perp * wobble
                
                # Keep segments within boundaries
                segment_positions[i].x = clamp(segment_positions[i].x, 0.0, bounds.end.x)
                segment_positions[i].y = clamp(segment_positions[i].y, 0.0, bounds.end.y)
                
    # 5.7 Simulate procedural step-locking for limbs
    if active_breed.has_limbs and foot_positions.size() == active_breed.num_limbs:
        for l_idx in range(active_breed.num_limbs):
            var seg_idx = 1
            var is_left = (l_idx % 2 == 0)
            var side_sign = -1.0 if is_left else 1.0
            
            if active_breed.num_limbs == 4 and l_idx >= 2:
                seg_idx = 2
                
            if seg_idx >= segment_positions.size():
                seg_idx = segment_positions.size() - 1
                
            if seg_idx < 0:
                continue
                
            var seg_pos = segment_positions[seg_idx]
            var seg_scale = active_breed.segment_scales[seg_idx] if seg_idx < active_breed.segment_scales.size() else 0.5
            var seg_rad = active_breed.head_radius * seg_scale
            
            # Attachment point
            var attachment = seg_pos + Vector2(side_sign * seg_rad * 0.75, 0.0)
            if active_breed.breed_name == "Glub":
                attachment = seg_pos + Vector2(side_sign * seg_rad * 0.75, -5.0)
                
            # Desired rest foot position
            var desired_foot = attachment
            if active_breed.breed_name == "Glub":
                desired_foot += Vector2(side_sign * 15.0, 5.0)
            else:
                desired_foot += Vector2(side_sign * 12.0, 18.0)
                
            # Clamp desired position within floor boundary
            if desired_foot.y > bounds.end.y - 2.0:
                desired_foot.y = bounds.end.y - 2.0
                
            # Check step trigger
            if foot_step_progress[l_idx] >= 1.0:
                var d = foot_positions[l_idx].distance_to(desired_foot)
                # Trigger a step if foot is too far and body is moving
                if d > 16.0 and center_vel.length() > 15.0:
                    var alt_idx = 0
                    if active_breed.num_limbs == 4:
                        alt_idx = 1 - l_idx if l_idx < 2 else 5 - l_idx
                    else:
                        alt_idx = 1 - l_idx
                        
                    # Alternating foot gating
                    if alt_idx >= foot_step_progress.size() or foot_step_progress[alt_idx] >= 0.5:
                        foot_step_progress[l_idx] = 0.0
                        foot_step_start[l_idx] = foot_positions[l_idx]
                        
                        # Overshoot target in walking direction
                        var overshoot = center_vel.normalized() * 18.0
                        foot_step_target[l_idx] = desired_foot + overshoot
                        if foot_step_target[l_idx].y > bounds.end.y - 2.0:
                            foot_step_target[l_idx].y = bounds.end.y - 2.0
                            
            # Process active step
            if foot_step_progress[l_idx] < 1.0:
                foot_step_progress[l_idx] += delta / 0.12 # snappier steps
                var p = clamp(foot_step_progress[l_idx], 0.0, 1.0)
                var current_pos = lerp(foot_step_start[l_idx], foot_step_target[l_idx], p)
                var lift = sin(p * PI) * 8.0
                foot_positions[l_idx] = current_pos + Vector2.UP * lift
            else:
                # Planted foot: remains locked to global floor position or slowly drifts to rest if stopped
                if center_vel.length() < 10.0:
                    foot_positions[l_idx] = lerp(foot_positions[l_idx], desired_foot, 0.15)
            
    # 6. Update eye tracking and face positions
    _update_face_logic(delta)
    
    # 6.5 Check item collisions (ball/pet physics, food bounce)
    _check_item_collisions()
    
    # 7. Redraw vector shapes
    update()

func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if event.pressed:
                # Check if click is inside the pet's current shape
                var local_click = event.global_position
                var poly = get_click_polygon()
                if Geometry.is_point_in_polygon(local_click, poly):
                    is_dragging = true
                    drag_positions.clear()
                    drag_positions.append(local_click)
                    prev_mouse_pos = local_click
                    _change_state(State.AGITATED)
            else:
                if is_dragging:
                    is_dragging = false
                    prev_mouse_pos = Vector2.ZERO
                    # Calculate throwing velocity
                    if drag_positions.size() > 1:
                        var start_pos = drag_positions[0]
                        var end_pos = drag_positions[drag_positions.size() - 1]
                        var throw_vector = (end_pos - start_pos) / (0.016 * drag_positions.size())
                        center_vel = throw_vector.clamped(1200.0) # Speed limit
                        is_falling = true
                    _change_state(State.WANDER)

func get_click_polygon() -> PoolVector2Array:
    var polygons = []
    polygons.append(point_positions)
    
    if active_breed and segment_positions.size() > 1:
        for i in range(1, segment_positions.size()):
            var seg_pos = segment_positions[i]
            var scale_idx = i
            var scale = active_breed.segment_scales[scale_idx] if scale_idx < active_breed.segment_scales.size() else 0.5
            var seg_rad = active_breed.head_radius * scale
            
            var octagon = PoolVector2Array()
            for j in range(8):
                var angle = j * 2.0 * PI / 8.0
                octagon.append(seg_pos + Vector2(cos(angle), sin(angle)) * seg_rad)
            polygons.append(octagon)
            
    return combine_polygons_local(polygons)

func combine_polygons_local(polygons_list: Array) -> PoolVector2Array:
    var combined = PoolVector2Array()
    if polygons_list.empty():
        combined.append(Vector2(-10, -10))
        combined.append(Vector2(-9, -10))
        combined.append(Vector2(-9, -9))
        return combined
        
    for i in range(polygons_list.size()):
        var poly = polygons_list[i]
        if poly.empty():
            continue
        for pt in poly:
            combined.append(pt)
        combined.append(poly[0])
    return combined

func set_drive_value(drive_name: String, value: float):
    if stats:
        stats.set(drive_name, value)

func set_decay_enabled(enabled: bool):
    decay_enabled = enabled

func cure():
    stats.wellness = 100.0
    _change_state(State.WANDER)

func on_food_spawned(food):
    if current_state != State.SLEEPING:
        target_item = food
        _change_state(State.CHASE_ITEM)

func on_toy_spawned(toy):
    if current_state != State.SLEEPING and current_state != State.CHASE_ITEM:
        target_item = toy
        _change_state(State.CHASE_ITEM)

func on_toy_thrown(toy):
    if current_state != State.SLEEPING and stats.boredom < 90.0:
        target_item = toy
        _change_state(State.CHASE_ITEM)

func _find_closest_item(is_food: bool) -> Node2D:
    var main = get_parent()
    if not main or not ("active_items" in main):
        return null
        
    var closest = null
    var min_dist = 999999.0
    for item in main.active_items:
        if is_instance_valid(item):
            # Use explicit type tags for reliable food/toy detection
            var item_is_food = item.get("is_food") == true
            var item_is_toy = item.get("is_toy") == true
            var matches = false
            if is_food and item_is_food:
                matches = true
            elif not is_food and item_is_toy:
                matches = true
            if matches:
                var d = global_position.distance_to(item.global_position)
                if d < min_dist:
                    min_dist = d
                    closest = item
    return closest


# State Machine Evaluation
func _evaluate_states(delta):
    state_timer += delta
    
    if current_state == State.RETURNING_TO_DISPENSER or current_state == State.EMERGING_FROM_DISPENSER or current_state == State.SELF_DISPENSE:
        return
        
    # Self-Dispense override (steal food if neglected and hungry)
    if stats.hunger < 20.0 and current_state != State.EATING and current_state != State.CHASE_ITEM:
        var food = _find_closest_item(true)
        if not is_instance_valid(food):
            _change_state(State.SELF_DISPENSE)
            return
            
    # Begging override: actively chase cursor if hungry
    if stats.hunger < 35.0 and (current_state == State.IDLE or current_state == State.WANDER):
        _change_state(State.CHASE_CURSOR)
        return
        
    # Global state overrides
    # Sleep override
    if stats.energy < 15.0 and current_state != State.SLEEPING:
        _change_state(State.SLEEPING)
        return
        
    if current_state == State.SLEEPING:
        if stats.energy >= 100.0:
            _change_state(State.IDLE)
        return
        
    # Sickness override: only get sick if wellness is low (caused by moldy food or poop proximity)
    var is_sick_trigger = stats.wellness < 40.0
    if is_sick_trigger and current_state != State.SICK:
        _change_state(State.SICK)
        return
        
    if current_state == State.SICK:
        # Sick auto-return timer: returns to box if sick for > 30 seconds and not dragged
        if not is_dragging:
            sick_auto_return_timer += delta
            if sick_auto_return_timer > 30.0:
                # Triggers auto-return behavior
                var main = get_parent()
                var nozzle_pos = Vector2(OS.window_size.x / 2.0, 150.0)
                if main and "dispenser_device" in main and is_instance_valid(main.dispenser_device):
                    nozzle_pos = main.dispenser_device.get_nozzle_global_position()
                return_to_dispenser(nozzle_pos, active_breed)
                # Mark to fully heal when it finishes returning
                pending_restore_stats = { "heal_on_arrive": true }
                return
        else:
            sick_auto_return_timer = 0.0

        if stats.wellness >= 70.0:
            sick_auto_return_timer = 0.0
            _change_state(State.IDLE)
        return


    # Agitation override
    if stats.agitation > 50.0 and current_state != State.AGITATED:
        _change_state(State.AGITATED)
        return
        
    if current_state == State.AGITATED:
        if stats.agitation < 10.0:
            _change_state(State.IDLE)
        return

    # Toilet override
    if stats.toilet > 85.0 and current_state != State.RELIEVING_SELF:
        _change_state(State.RELIEVING_SELF)
        return
        
    if current_state == State.RELIEVING_SELF:
        return

    # State specific transitions
    match current_state:
        State.IDLE:
            var food = _find_closest_item(true)
            var toy = _find_closest_item(false)
            if stats.hunger < 50.0 and is_instance_valid(food):
                target_item = food
                _change_state(State.CHASE_ITEM)
            elif (stats.boredom < 60.0 or (randf() < 0.003 and stats.boredom < 90.0)) and is_instance_valid(toy):
                target_item = toy
                _change_state(State.CHASE_ITEM)
            elif stats.affection < 50.0:
                _change_state(State.CHASE_CURSOR)
            elif stats.curiosity < 30.0 or (randf() < 0.02 and stats.curiosity < 70.0):
                # Try to sit on a window border!
                var spots = _query_window_borders()
                if spots.size() > 0:
                    target_wander_pos = spots[randi() % spots.size()]
                    _change_state(State.WINDOW_SIT)
                else:
                    _find_curiosity_boundary_target()
                    _change_state(State.WANDER)
            elif state_timer > rand_range(2.0, 5.0):
                _change_state(State.WANDER)
                
        State.WANDER:
            var food = _find_closest_item(true)
            var toy = _find_closest_item(false)
            if stats.hunger < 50.0 and is_instance_valid(food):
                target_item = food
                _change_state(State.CHASE_ITEM)
            elif (stats.boredom < 60.0 or (randf() < 0.003 and stats.boredom < 90.0)) and is_instance_valid(toy):
                target_item = toy
                _change_state(State.CHASE_ITEM)
            elif stats.affection < 50.0:
                _change_state(State.CHASE_CURSOR)
            elif state_timer > rand_range(5.0, 10.0):
                _change_state(State.IDLE)
                
        State.WINDOW_SIT:
            # Let it sit for a random duration between 8 and 20 seconds, or until dragged/disturbed
            if state_timer > window_sit_duration:
                stats.curiosity = 100.0 # satisfied
                _change_state(State.WANDER)

                
        State.CHASE_CURSOR:
            # Petting mechanics
            var dist = global_position.distance_to(get_global_mouse_position())
            if dist < base_radius + 20.0:
                # Petting restores affection
                stats.affection = clamp(stats.affection + delta * 25.0, 0.0, 100.0)
                if stats.affection >= 95.0:
                    _change_state(State.IDLE)
            elif stats.affection >= 80.0 or state_timer > 8.0:
                _change_state(State.IDLE)
                
        State.CHASE_ITEM:
            if not is_instance_valid(target_item):
                _change_state(State.IDLE)
                
        State.EATING:
            if state_timer > 2.0: # Eat sequence duration
                if is_instance_valid(target_item):
                    stats.hunger = 100.0
                    
                    # Handle spoiling/sickness
                    if target_item.get("is_spoiled") == true:
                        stats.wellness = 15.0 # drops wellness below 40%, triggers sickness
                        
                    # Handle treats vs regular food
                    if target_item.get("is_treat") == true:
                        stats.affection = clamp(stats.affection + 45.0, 0.0, 100.0)
                        stats.energy = clamp(stats.energy + 25.0, 0.0, 100.0)
                        stats.toilet = clamp(stats.toilet + 40.0, 0.0, 100.0)
                    else:
                        stats.toilet = clamp(stats.toilet + 25.0, 0.0, 100.0)
                        
                    var main = get_parent()
                    if main and main.has_method("remove_item"):
                        main.call("remove_item", target_item)
                target_item = null
                _change_state(State.IDLE)

func _change_state(new_state: int):
    current_state = new_state
    state_timer = 0.0
    
    # State initialization actions
    match new_state:
        State.IDLE:
            center_vel = Vector2.ZERO
        State.WANDER:
            _pick_random_wander_target()
        State.CHASE_CURSOR:
            pass
        State.SLEEPING:
            center_vel = Vector2.ZERO
        State.EATING:
            center_vel = Vector2.ZERO
        State.SICK:
            center_vel = Vector2.ZERO
            var bounds = _get_viewport_bounds()
            var hide_x = bounds.position.x + 60.0
            if randf() < 0.5:
                hide_x = bounds.end.x - 60.0
            var hide_y = bounds.end.y - base_radius - 10.0
            
            var main = get_parent()
            if main and "dispenser_device" in main and is_instance_valid(main.dispenser_device):
                var disp_rect = main.dispenser_device.get_panel_rect()
                hide_x = disp_rect.position.x + disp_rect.size.x / 2.0
                hide_y = disp_rect.end.y + 40.0
                
            target_wander_pos = Vector2(hide_x, hide_y)
        State.RETURNING_TO_DISPENSER:
            pass
        State.EMERGING_FROM_DISPENSER:
            global_position = transition_nozzle_pos
            center_vel = Vector2(0, 150.0)
            transition_scale = 0.1
        State.RELIEVING_SELF:
            var screen_w = OS.window_size.x
            var screen_h = OS.window_size.y
            if randf() < 0.5:
                relieve_corner_pos = Vector2(50.0, screen_h - 40.0)
            else:
                relieve_corner_pos = Vector2(screen_w - 50.0, screen_h - 40.0)
        State.SELF_DISPENSE:
            center_vel = Vector2.ZERO
        State.WINDOW_SIT:
            center_vel = Vector2.ZERO
            window_sit_duration = rand_range(8.0, 20.0)


func _update_state_behavior(delta):
    match current_state:
        State.WANDER:
            # Walk towards wander target
            var dir = (target_wander_pos - global_position).normalized()
            var speed = 80.0
            if stats.wellness < 40.0:
                speed = 30.0 # move slow when sick
            center_vel = dir * speed
            
            # Check if reached target
            if global_position.distance_to(target_wander_pos) < 20.0 or state_timer > 6.0:
                if stats.curiosity < 30.0:
                    # Curiosity satisfied by reaching boundary
                    stats.curiosity = 100.0
                _change_state(State.IDLE)
                
        State.CHASE_CURSOR:
            # Float/Chase cursor
            var mouse_pos = get_global_mouse_position()
            var dir = (mouse_pos - global_position).normalized()
            var speed = 180.0
            # Track mouse
            center_vel = lerp(center_vel, dir * speed, 0.1)
            
            # Hungry cursor begging: nudge cursor towards dispenser
            if stats.hunger < 35.0 and global_position.distance_to(mouse_pos) < 60.0:
                var nozzle_pos = Vector2(OS.window_size.x / 2.0, 150.0)
                var main_node = get_parent()
                if main_node and "dispenser_device" in main_node and is_instance_valid(main_node.dispenser_device):
                    nozzle_pos = main_node.dispenser_device.get_nozzle_global_position()
                var to_nozzle = (nozzle_pos - mouse_pos).normalized()
                Input.warp_mouse_position(get_viewport().get_mouse_position() + to_nozzle * 2.0)
            
        State.CHASE_ITEM:
            if is_instance_valid(target_item):
                var dir = (target_item.global_position - global_position).normalized()
                var speed = 200.0
                center_vel = lerp(center_vel, dir * speed, 0.1)
                
                # Check arrival at item
                var dist_to_item = global_position.distance_to(target_item.global_position)
                if target_item.has_method("apply_impulse"):
                    # --- TOY PLAY ---
                    if dist_to_item < base_radius + 20.0:
                        # Kick the toy!
                        var kick_dir = dir.rotated(rand_range(-0.5, 0.5))
                        target_item.call("apply_impulse", kick_dir * rand_range(200.0, 380.0))
                        # Boredom gain per kick
                        stats.boredom = clamp(stats.boredom + 15.0, 0.0, 100.0)
                        # Bounce back slightly
                        center_vel = -dir * 100.0
                    elif dist_to_item < 90.0:
                        # Near toy: passive boredom restore while playing together
                        toy_play_time += delta
                        stats.boredom = clamp(stats.boredom + 1.5 * delta, 0.0, 100.0)
                    
                    # Only stop when fully satisfied
                    if stats.boredom >= 100.0:
                        toy_play_time = 0.0
                        target_item = null
                        _change_state(State.IDLE)
                elif dist_to_item < base_radius + 15.0:
                    # --- FOOD ---
                    _change_state(State.EATING)
            else:
                toy_play_time = 0.0
                _change_state(State.IDLE)
                
        State.SLEEPING:
            # Wake up slowly
            stats.energy = clamp(stats.energy + delta * 12.0, 0.0, 100.0)
            
        State.EATING:
            # Eat animation vibration
            var shake = Vector2(rand_range(-2, 2), rand_range(-2, 2))
            global_position += shake
            
        State.SICK:
            # Walk slowly to hiding spot
            var dir = (target_wander_pos - global_position).normalized()
            var dist = global_position.distance_to(target_wander_pos)
            if dist > 20.0:
                center_vel = dir * 40.0
            else:
                center_vel = lerp(center_vel, Vector2.ZERO, 0.2)
            
        State.RETURNING_TO_DISPENSER:
            var dir = (transition_nozzle_pos - global_position).normalized()
            var dist = global_position.distance_to(transition_nozzle_pos)
            center_vel = dir * 180.0
            
            # Squeeze scale
            transition_scale = clamp(dist / 140.0, 0.05, 1.0)
            
            # Arrived at nozzle
            if dist < 6.0:
                var old_breed_name = ""
                if active_breed:
                    old_breed_name = active_breed.breed_name
                emit_signal("returned_to_box", old_breed_name)
                
                change_breed(pending_breed_res)
                
                # Re-setup debug panel if visible
                var main = get_parent()
                if main and "debug_panel" in main and is_instance_valid(main.debug_panel) and main.debug_panel.visible:
                    main.debug_panel.call("setup", self)
                    
                _change_state(State.EMERGING_FROM_DISPENSER)

                
        State.EMERGING_FROM_DISPENSER:
            # Drop down from nozzle
            center_vel.y += gravity * delta
            # Walk wiggles and scale up
            transition_scale = lerp(transition_scale, 1.0, 0.05)
            
            # Floor bounce/landing
            var bounds = _get_viewport_bounds()
            var floor_y = bounds.end.y - base_radius
            if global_position.y >= floor_y:
                global_position.y = floor_y
                center_vel = Vector2.ZERO
                transition_scale = 1.0
                _change_state(State.IDLE)
                
        State.RELIEVING_SELF:
            var dir = (relieve_corner_pos - global_position).normalized()
            var dist = global_position.distance_to(relieve_corner_pos)
            center_vel = dir * 90.0
            
            # Arrived at corner, play digging/relieving animation
            if dist < 20.0:
                center_vel = Vector2.ZERO
                var vibe = Vector2(sin(OS.get_ticks_msec() * 0.08) * 1.5, cos(OS.get_ticks_msec() * 0.04) * 1.0)
                global_position += vibe
                
                if state_timer > 3.0:
                    # Spawn Poop!
                    var PoopScene = preload("res://Poop.tscn")
                    var poop = PoopScene.instance()
                    poop.global_position = global_position + Vector2.DOWN * 8.0
                    get_parent().add_child(poop)
                    
                    var main = get_parent()
                    if main and "active_items" in main:
                        main.active_items.append(poop)
                        
                    stats.toilet = 0.0
                    _change_state(State.WANDER)
                    
        State.SELF_DISPENSE:
            var nozzle_pos = Vector2(OS.window_size.x / 2.0, 150.0)
            var main = get_parent()
            if main and "dispenser_device" in main and is_instance_valid(main.dispenser_device):
                nozzle_pos = main.dispenser_device.get_nozzle_global_position()
                
            var dir = (nozzle_pos - global_position).normalized()
            var dist = global_position.distance_to(nozzle_pos)
            center_vel = dir * 120.0
            
            # Arrived at nozzle, jump-bump it!
            if dist < 25.0:
                center_vel = Vector2.ZERO
                if main and main.has_method("spawn_food"):
                    main.call("spawn_food", nozzle_pos, false)
                    
                # Back away and start falling
                center_vel.y = 80.0
                is_falling = true
                
                # Try to immediately target the food
                var food = _find_closest_item(true)
                if is_instance_valid(food):
                    target_item = food
                    _change_state(State.CHASE_ITEM)
                else:
                    _change_state(State.IDLE)
        State.WINDOW_SIT:
            var dist = global_position.distance_to(target_wander_pos)
            if dist > 15.0:
                # Walk towards the window border perch point
                var dir = (target_wander_pos - global_position).normalized()
                var speed = 75.0
                center_vel = dir * speed
                is_falling = false
            else:
                # Arrived: Perch comfortably and look around
                center_vel = Vector2.ZERO
                is_falling = false


func _pick_random_wander_target():
    var bounds = _get_viewport_bounds()
    var x = rand_range(bounds.position.x + 100.0, bounds.end.x - 100.0)
    var y = rand_range(bounds.position.y + 100.0, bounds.end.y - 100.0)
    target_wander_pos = Vector2(x, y)

func _find_curiosity_boundary_target():
    var bounds = _get_viewport_bounds()
    # Pick a random point on screen edges
    var edge = randi() % 4
    var x = 0.0
    var y = 0.0
    match edge:
        0: # Left
            x = bounds.position.x + 50.0
            y = rand_range(bounds.position.y + 100.0, bounds.end.y - 100.0)
        1: # Right
            x = bounds.end.x - 50.0
            y = rand_range(bounds.position.y + 100.0, bounds.end.y - 100.0)
        2: # Top
            x = rand_range(bounds.position.x + 100.0, bounds.end.x - 100.0)
            y = bounds.position.y + 50.0
        3: # Bottom
            x = rand_range(bounds.position.x + 100.0, bounds.end.x - 100.0)
            y = bounds.end.y - 50.0
    target_wander_pos = Vector2(x, y)

func _query_window_borders() -> Array:
    var targets = []
    # Gracefully check for wmctrl
    var output = []
    var exit_code = OS.execute("which", ["wmctrl"], true, output)
    if exit_code != 0:
        return targets # Return empty list, we will fall back to screen edges
        
    output.clear()
    exit_code = OS.execute("wmctrl", ["-lG"], true, output)
    if exit_code != 0 or output.empty():
        return targets
        
    var lines = output[0].split("\n")
    for line in lines:
        if line.strip_edges().empty():
            continue
        var parts = line.split(" ", false)
        if parts.size() >= 7:
            # wmctrl -lG columns:
            # 0: window id, 1: desktop id, 2: x, 3: y, 4: width, 5: height, 6+: window title
            var wx = float(parts[2])
            var wy = float(parts[3])
            var ww = float(parts[4])
            var wh = float(parts[5])
            
            # Skip fullscreen window overlays, panels, or negative geometries
            if ww > OS.window_size.x * 0.95 and wh > OS.window_size.y * 0.95:
                continue
            if ww < 40.0 or wh < 40.0:
                continue
            if wx < 0.0 or wy < 0.0:
                continue
                
            # Place sitting spots along top border of this window (X range: wx + 20 to wx + ww - 20)
            if ww > 40.0:
                var sit_x = wx + rand_range(20.0, ww - 20.0)
                var sit_y = wy - base_radius + 4.0 # offset so pet appears to sit right on border
                targets.append(Vector2(sit_x, sit_y))
                
    return targets


func _update_deformed_targets(_delta) -> Dictionary:
    var current_radius = base_radius
    var current_k = spring_k
    var current_damping = damping
    
    # 1. Wellness effects: lower wellness -> damp spring stiffness
    if stats.wellness < 40.0:
        var wellness_pct = stats.wellness / 40.0
        current_k = lerp(90.0, spring_k, wellness_pct)
        current_damping = lerp(5.0, damping, wellness_pct)

    # 2. Hunger effects: lower hunger -> deflate
    if stats.hunger < 30.0:
        var hunger_pct = stats.hunger / 30.0
        current_radius = lerp(base_radius * 0.7, base_radius, hunger_pct)
        current_k = lerp(current_k * 0.5, current_k, hunger_pct)

    # Base circle target calculations
    var temp_targets = []
    for i in range(num_points):
        var angle = i * 2.0 * PI / num_points
        var offset = Vector2(cos(angle), sin(angle)) * current_radius
        temp_targets.append(offset)
        
    # Apply deformations:
    
    # A. Wellness sagging (sag left/right asymmetrically)
    if stats.wellness < 40.0:
        var sag_factor = (1.0 - stats.wellness / 40.0) * 25.0
        for i in range(num_points):
            if temp_targets[i].x < 0:
                temp_targets[i].y += sag_factor

    # B. Hunger drooping
    if stats.hunger < 30.0:
        var droop_factor = (1.0 - stats.hunger / 30.0) * 18.0
        for i in range(num_points):
            temp_targets[i].y += droop_factor
            if temp_targets[i].y > 0:
                temp_targets[i].y -= droop_factor * 0.25

    # C. Curiosity periscope shape (tall, thin)
    if current_state == State.WANDER and stats.curiosity < 30.0:
        var cur_factor = (1.0 - stats.curiosity / 30.0)
        var scale_x = lerp(1.0, 0.65, cur_factor)
        var scale_y = lerp(1.0, 1.5, cur_factor)
        for i in range(num_points):
            temp_targets[i].x *= scale_x
            temp_targets[i].y *= scale_y
            
    # D. Affection elongation (stretch towards cursor)
    if current_state == State.CHASE_CURSOR or stats.affection < 50.0:
        var aff_factor = 1.0
        if current_state != State.CHASE_CURSOR:
            aff_factor = (1.0 - stats.affection / 50.0)
        var scale_x = lerp(1.0, 0.75, aff_factor)
        var scale_y = lerp(1.0, 1.4, aff_factor)
        for i in range(num_points):
            temp_targets[i].x *= scale_x
            if temp_targets[i].y < 0:
                temp_targets[i].y *= scale_y

    # E. Boredom vibration and stretching
    if current_state == State.WANDER and stats.boredom < 40.0:
        var bored_factor = (1.0 - stats.boredom / 40.0)
        var vibration = sin(OS.get_ticks_msec() * 0.04) * 6.0 * bored_factor
        var stretch_angle = OS.get_ticks_msec() * 0.003
        var stretch_dir = Vector2(cos(stretch_angle), sin(stretch_angle))
        for i in range(num_points):
            var dot = temp_targets[i].dot(stretch_dir)
            temp_targets[i] += stretch_dir * dot * 0.35 * bored_factor
            temp_targets[i] += Vector2(randf() - 0.5, randf() - 0.5) * vibration

    # F. Agitation jagged edges (sawtooth)
    if stats.agitation > 10.0:
        var agi_factor = stats.agitation / 100.0
        for i in range(num_points):
            var mag = 20.0 * agi_factor
            if i % 2 == 0:
                temp_targets[i] += temp_targets[i].normalized() * mag
            else:
                temp_targets[i] -= temp_targets[i].normalized() * mag
                
    # G. Energy Sleep State (collapses into perfect sphere)
    if current_state == State.SLEEPING or stats.energy < 15.0:
        var sleep_pct = 1.0
        if current_state != State.SLEEPING:
            sleep_pct = (1.0 - stats.energy / 15.0)
        for i in range(num_points):
            var angle = i * 2.0 * PI / num_points
            var perfect_circle_offset = Vector2(cos(angle), sin(angle)) * base_radius
            temp_targets[i] = lerp(temp_targets[i], perfect_circle_offset, sleep_pct)
            
    # Apply targets
    for i in range(num_points):
        target_relative_offsets[i] = temp_targets[i]
        
    return {
        "k": current_k,
        "damping": current_damping
    }

func _update_face_logic(_delta):
    # Determine looking direction
    var target_look = Vector2.RIGHT
    if current_state == State.CHASE_CURSOR:
        target_look = (get_global_mouse_position() - global_position).normalized()
    elif current_state == State.CHASE_ITEM and is_instance_valid(target_item):
        target_look = (target_item.global_position - global_position).normalized()
    elif center_vel.length() > 10.0:
        target_look = center_vel.normalized()
    else:
        target_look = look_dir # keep looking same way
        
    look_dir = lerp(look_dir, target_look, 0.15).normalized()
    
    # Calculate face element offsets
    # Base eye separation
    var eye_sep = base_radius * 0.35
    var face_center = look_dir * base_radius * 0.3
    
    # Adjust face center if drooping or deflated
    if stats.hunger < 30.0:
        face_center.y += 10.0
        
    var right_angle = look_dir.angle() + PI / 2.0
    var perp = Vector2(cos(right_angle), sin(right_angle))
    
    eye_left_pos = face_center - perp * eye_sep
    eye_right_pos = face_center + perp * eye_sep
    # Mouth: offset slightly below face center along look direction, clamped to stay inside head
    var raw_mouth = face_center + look_dir * (base_radius * 0.25) + Vector2.DOWN * 8.0
    var mouth_dist = raw_mouth.length()
    var mouth_max = base_radius * 0.65
    if mouth_dist > mouth_max:
        mouth_pos = raw_mouth.normalized() * mouth_max
    else:
        mouth_pos = raw_mouth


func _calculate_limbs(speed_factor: float) -> Array:
    var limbs_data = []
    if not active_breed or not active_breed.has_limbs or active_breed.num_limbs == 0:
        return limbs_data
        
    var walk_time = OS.get_ticks_msec() * 0.001 * active_breed.wobble_speed
    var num_l = active_breed.num_limbs
    
    for l_idx in range(num_l):
        # Determine attachment segment and side
        var seg_idx = 1 # Default front limbs attachment (chest)
        var is_left = (l_idx % 2 == 0)
        var side_sign = -1.0 if is_left else 1.0
        
        if num_l == 4 and l_idx >= 2:
            seg_idx = 2 # Back limbs (hips)
            
        if seg_idx >= segment_positions.size():
            seg_idx = segment_positions.size() - 1
            
        if seg_idx < 0:
            continue
            
        var seg_pos = segment_positions[seg_idx]
        var seg_scale = active_breed.segment_scales[seg_idx] if seg_idx < active_breed.segment_scales.size() else 0.5
        var seg_rad = active_breed.head_radius * seg_scale
        
        # Attachment point offset
        var attachment = seg_pos + Vector2(side_sign * seg_rad * 0.75, 0.0)
        if active_breed.breed_name == "Glub":
            attachment = seg_pos + Vector2(side_sign * seg_rad * 0.75, -5.0)
            
        # Target position of foot/hand (read from active IK foot_positions)
        var target_foot = attachment
        if l_idx < foot_positions.size():
            target_foot = foot_positions[l_idx]
        else:
            var phase = 0.0 if is_left else PI
            var step_x = cos(walk_time + phase) * active_breed.wobble_amplitude * 0.95
            var step_y = sin(walk_time * 2.0 + phase) * active_breed.wobble_amplitude * 0.45
            if active_breed.breed_name == "Glub":
                target_foot += Vector2(side_sign * 15.0, 5.0) + Vector2(step_x, step_y) * speed_factor
            else:
                target_foot += Vector2(side_sign * 12.0, 18.0) + Vector2(step_x, step_y) * speed_factor
                
        # Ground clamp
        var bounds = _get_viewport_bounds()
        if target_foot.y > bounds.end.y - 2.0:
            target_foot.y = bounds.end.y - 2.0
            
        # Knee bend joint math
        var L1 = active_breed.limb_lengths[0]
        var L2 = active_breed.limb_lengths[1]
        var total_len = L1 + L2
        var V = target_foot - attachment
        var dist = V.length()
        
        var knee = Vector2.ZERO
        if dist >= total_len:
            knee = attachment + V.normalized() * L1
        else:
            var perp = Vector2(-V.y, V.x).normalized() * side_sign
            var midpoint = (attachment + target_foot) / 2.0
            var bend = sqrt(max(0.0, total_len * total_len * 0.25 - dist * dist * 0.25))
            knee = midpoint + perp * bend * 0.85
            
        limbs_data.append({
            "attachment": attachment,
            "knee": knee,
            "foot": target_foot,
            "side": side_sign
        })
        
    return limbs_data

func _draw():
    if active_breed == null:
        return
        
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(transition_scale, transition_scale))
        
    # Generate colors based on state
    var p_col = active_breed.primary_color
    var s_col = active_breed.secondary_color
    if current_state == State.SLEEPING:
        p_col = Color("90a4ae") # Blue grey
        s_col = Color("546e7a")
    elif current_state == State.SICK:
        p_col = Color("8d6e63") # Sickness brown
        s_col = Color("4e342e")
    elif stats.agitation > 50.0:
        p_col = Color("e53935") # Aggressive red
        s_col = Color("b71c1c")
    elif stats.hunger < 30.0:
        p_col = Color("f57c00") # Hunger orange
        s_col = Color("e65100")
    elif current_state == State.CHASE_CURSOR:
        p_col = Color("ba68c8") # Affectionate pinkish-purple
        s_col = Color("7b1fa2")
        
    var speed_factor = clamp(center_vel.length() / 80.0, 0.1, 1.5)
    if current_state == State.SLEEPING:
        speed_factor = 0.0
        
    # Calculate limbs data
    var limbs = _calculate_limbs(speed_factor)
    
    # 0.5. Draw limbs first (so they go in the back)
    for limb in limbs:
        var attach_local = limb.attachment - global_position
        var knee_local = limb.knee - global_position
        var foot_local = limb.foot - global_position

        # Shadow under foot (ground shadow)
        draw_circle(foot_local + Vector2(2, 4), 4.0, Color(0, 0, 0, 0.18))

        # --- Upper limb segment (attachment -> knee) ---
        var upper_dir = (knee_local - attach_local)
        var upper_len = upper_dir.length()
        if upper_len > 0.001:
            var up_n = upper_dir / upper_len
            var up_perp = Vector2(-up_n.y, up_n.x)
            var uw = 4.5   # upper limb half-width
            # Outline
            var up_pts_out = PoolVector2Array([
                attach_local + up_perp * (uw + 1.5),
                knee_local   + up_perp * (uw + 1.0),
                knee_local   - up_perp * (uw + 1.0),
                attach_local - up_perp * (uw + 1.5)
            ])
            draw_colored_polygon(up_pts_out, outline_color)
            # Fill (darker on edges, lighter in center for 3D look)
            var up_pts = PoolVector2Array([
                attach_local + up_perp * uw,
                knee_local   + up_perp * (uw * 0.85),
                knee_local   - up_perp * (uw * 0.85),
                attach_local - up_perp * uw
            ])
            draw_colored_polygon(up_pts, s_col)
            # Highlight strip (top 1/3)
            var hl_pts = PoolVector2Array([
                attach_local + up_perp * uw,
                knee_local   + up_perp * (uw * 0.85),
                knee_local   + up_perp * (uw * 0.2),
                attach_local + up_perp * (uw * 0.2)
            ])
            draw_colored_polygon(hl_pts, Color(s_col.r + 0.18, s_col.g + 0.18, s_col.b + 0.18, 0.6))
            # Joint circle at knee
            draw_circle(knee_local, uw - 0.5, outline_color)
            draw_circle(knee_local, uw - 2.0, s_col)

        # --- Lower limb segment (knee -> foot) ---
        var lower_dir = (foot_local - knee_local)
        var lower_len = lower_dir.length()
        if lower_len > 0.001:
            var lo_n = lower_dir / lower_len
            var lo_perp = Vector2(-lo_n.y, lo_n.x)
            var lw = 3.5   # lower limb half-width (slightly thinner)
            var lo_pts_out = PoolVector2Array([
                knee_local  + lo_perp * (lw + 1.5),
                foot_local  + lo_perp * (lw * 0.6),
                foot_local  - lo_perp * (lw * 0.6),
                knee_local  - lo_perp * (lw + 1.5)
            ])
            draw_colored_polygon(lo_pts_out, outline_color)
            var lo_pts = PoolVector2Array([
                knee_local  + lo_perp * lw,
                foot_local  + lo_perp * (lw * 0.5),
                foot_local  - lo_perp * (lw * 0.5),
                knee_local  - lo_perp * lw
            ])
            draw_colored_polygon(lo_pts, p_col)
            var lo_hl = PoolVector2Array([
                knee_local  + lo_perp * lw,
                foot_local  + lo_perp * (lw * 0.5),
                foot_local  + lo_perp * 0.0,
                knee_local  + lo_perp * (lw * 0.3)
            ])
            draw_colored_polygon(lo_hl, Color(p_col.r + 0.2, p_col.g + 0.2, p_col.b + 0.2, 0.55))

        # Foot / hand ball
        draw_circle(foot_local, 4.5, outline_color)
        draw_circle(foot_local, 3.5, p_col)
        draw_circle(foot_local + Vector2(-1, -1), 1.5, Color(p_col.r + 0.3, p_col.g + 0.3, p_col.b + 0.3, 0.7))

    # 1. Draw body segments tail-to-head (so tail is in the background)
    if segment_positions.size() > 1:
        # Ground shadow under body
        for i in range(segment_positions.size() - 1, 0, -1):
            var seg_pos = segment_positions[i]
            var local_pos = seg_pos - global_position
            var scale_idx = i
            var scale = active_breed.segment_scales[scale_idx] if scale_idx < active_breed.segment_scales.size() else 0.5
            var r = active_breed.head_radius * scale
            draw_circle(local_pos + Vector2(3, 5), r * 0.7, Color(0, 0, 0, 0.12))

        for i in range(segment_positions.size() - 1, 0, -1):
            var seg_pos = segment_positions[i]
            var local_pos = seg_pos - global_position
            
            var scale_idx = i
            var scale = active_breed.segment_scales[scale_idx] if scale_idx < active_breed.segment_scales.size() else 0.5
            var r = active_breed.head_radius * scale
            
            var t = float(i) / float(active_breed.num_segments)
            var seg_col = p_col.linear_interpolate(s_col, t)
            
            # Draw segment outline (slightly larger white circle)
            draw_circle(local_pos, r + 2.5, outline_color)
            # Draw segment color fill
            draw_circle(local_pos, r, seg_col)
            # Highlight (top-left lighter spot for 3D look)
            draw_circle(local_pos + Vector2(-r * 0.28, -r * 0.28), r * 0.38,
                Color(seg_col.r + 0.22, seg_col.g + 0.22, seg_col.b + 0.22, 0.55))

    # 2. Draw head polygon (with head shake offset)
    var shake_offset = Vector2.ZERO
    if head_shake_timer > 0.0:
        shake_offset = Vector2(sin(head_shake_timer * 40.0) * head_shake_intensity, 0.0)

    var local_poly = PoolVector2Array()
    for i in range(num_points):
        local_poly.append(point_positions[i] - global_position + shake_offset)

    # Head shadow
    var shadow_poly = PoolVector2Array()
    for pt in local_poly:
        shadow_poly.append(pt + Vector2(4, 6))
    draw_colored_polygon(shadow_poly, Color(0, 0, 0, 0.12))

    # Draw head outline glow
    draw_polyline(local_poly, outline_color, 4.0, true)
    # Draw head color fill
    draw_colored_polygon(local_poly, p_col)
    # Head highlight (top-left crescent for 3D depth)
    var hl_poly = PoolVector2Array()
    var hl_count = num_points / 3
    for i in range(hl_count):
        var angle = (i * 2.0 * PI / num_points) + PI * 1.2
        hl_poly.append(shake_offset + Vector2(cos(angle), sin(angle)) * base_radius * 0.6)
    if hl_poly.size() >= 3:
        draw_colored_polygon(hl_poly, Color(p_col.r + 0.2, p_col.g + 0.2, p_col.b + 0.2, 0.35))
    
    # Draw face elements on the head (offset by shake)
    draw_set_transform(shake_offset, 0.0, Vector2(transition_scale, transition_scale))
    _draw_eyes()
    _draw_mouth()
    # Restore base transform
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(transition_scale, transition_scale))


func _draw_eyes():
    var eye_color = Color("ffffff")
    var pupil_color = Color("000000")
    var radius = base_radius * 0.12
    
    if current_state == State.SLEEPING:
        if active_breed.eye_type == "cyclops":
            var eye_center = (eye_left_pos + eye_right_pos) / 2.0
            draw_line(eye_center - Vector2(8, 0), eye_center + Vector2(8, 0), pupil_color, 3.0)
        else:
            draw_line(eye_left_pos - Vector2(6, 0), eye_left_pos + Vector2(6, 0), pupil_color, 3.0)
            draw_line(eye_right_pos - Vector2(6, 0), eye_right_pos + Vector2(6, 0), pupil_color, 3.0)
    elif stats.agitation > 50.0:
        if active_breed.eye_type == "cyclops":
            var eye_center = (eye_left_pos + eye_right_pos) / 2.0
            draw_line(eye_center - Vector2(8, -4), eye_center + Vector2(8, 4), eye_color, 4.0)
        else:
            draw_line(eye_left_pos - Vector2(6, -3), eye_left_pos + Vector2(6, 3), eye_color, 3.0)
            draw_line(eye_right_pos - Vector2(-6, -3), eye_right_pos + Vector2(-6, 3), eye_color, 3.0)
    elif current_state == State.SICK:
        if active_breed.eye_type == "cyclops":
            var eye_center = (eye_left_pos + eye_right_pos) / 2.0
            draw_circle(eye_center, radius * 1.3, eye_color)
            draw_rect(Rect2(eye_center - Vector2(radius*1.3+2, radius*1.3+2), Vector2((radius*1.3+2)*2, radius*1.3 + 2)), Color(0, 0, 0, 0.4))
        else:
            draw_circle(eye_left_pos, radius, eye_color)
            draw_circle(eye_right_pos, radius, eye_color)
            draw_rect(Rect2(eye_left_pos - Vector2(radius+2, radius+2), Vector2((radius+2)*2, radius + 2)), Color(0, 0, 0, 0.4))
            draw_rect(Rect2(eye_right_pos - Vector2(radius+2, radius+2), Vector2((radius+2)*2, radius + 2)), Color(0, 0, 0, 0.4))
    else:
        if active_breed.eye_type == "cyclops":
            var eye_center = (eye_left_pos + eye_right_pos) / 2.0
            var big_rad = radius * 1.5
            draw_circle(eye_center, big_rad, eye_color)
            var pupil_offset = look_dir * 3.0
            draw_circle(eye_center + pupil_offset, big_rad * 0.5, pupil_color)
        elif active_breed.eye_type == "slanted":
            draw_circle(eye_left_pos, radius * 0.9, eye_color)
            draw_circle(eye_right_pos, radius * 0.9, eye_color)
            var pupil_offset = look_dir * 2.0
            draw_line(eye_left_pos + pupil_offset - Vector2(5, -1), eye_left_pos + pupil_offset + Vector2(5, -1), pupil_color, 2.0)
            draw_line(eye_right_pos + pupil_offset - Vector2(5, 1), eye_right_pos + pupil_offset + Vector2(5, 1), pupil_color, 2.0)
        else:
            draw_circle(eye_left_pos, radius, eye_color)
            draw_circle(eye_right_pos, radius, eye_color)
            var pupil_offset = look_dir * 3.0
            draw_circle(eye_left_pos + pupil_offset, radius * 0.5, pupil_color)
            draw_circle(eye_right_pos + pupil_offset, radius * 0.5, pupil_color)
            
    # Draw tears if hungry/stealing food
    if active_breed and (stats.hunger < 35.0 or current_state == State.SELF_DISPENSE):
        var tear_offset = Vector2(0, radius + 4.0)
        if active_breed.eye_type == "cyclops":
            var eye_center = (eye_left_pos + eye_right_pos) / 2.0
            draw_circle(eye_center + tear_offset, 3.0, Color("4fc3f7"))
        else:
            draw_circle(eye_left_pos + tear_offset, 2.5, Color("4fc3f7"))
            draw_circle(eye_right_pos + tear_offset, 2.5, Color("4fc3f7"))

func return_to_dispenser(nozzle_pos: Vector2, breed_res):
    if current_state == State.RETURNING_TO_DISPENSER or current_state == State.EMERGING_FROM_DISPENSER:
        return
    transition_nozzle_pos = nozzle_pos
    pending_breed_res = breed_res
    _change_state(State.RETURNING_TO_DISPENSER)

func change_breed(new_breed):
    breed_data = new_breed
    active_breed = new_breed
    base_radius = active_breed.head_radius
    
    segment_positions.clear()
    for i in range(active_breed.num_segments):
        segment_positions.append(global_position + Vector2.LEFT * (i * active_breed.segment_spacing))
        
    # Reinitialize foot arrays
    foot_positions.clear()
    foot_step_progress.clear()
    foot_step_start.clear()
    foot_step_target.clear()
    if active_breed.has_limbs:
        for _i in range(active_breed.num_limbs):
            foot_positions.append(global_position)
            foot_step_progress.append(1.0)
            foot_step_start.append(global_position)
            foot_step_target.append(global_position)
            
    point_positions.clear()
    point_velocities.clear()
    target_relative_offsets.clear()
    for i in range(num_points):
        var angle = i * 2.0 * PI / num_points
        var offset = Vector2(cos(angle), sin(angle)) * base_radius
        point_positions.append(global_position + offset)
        point_velocities.append(Vector2.ZERO)
        target_relative_offsets.append(offset)
        
    # Re-apply stats if we have a restore pending
    if pending_restore_stats != null:
        if pending_restore_stats.get("heal_on_arrive") == true:
            stats.wellness = 100.0
            stats.hunger = 100.0
            stats.energy = 100.0
            stats.affection = 100.0
            stats.boredom = 100.0
            stats.agitation = 0.0
        else:
            stats.hunger = pending_restore_stats.get("hunger", stats.hunger)
            stats.boredom = pending_restore_stats.get("boredom", stats.boredom)
            stats.energy = pending_restore_stats.get("energy", stats.energy)
            stats.affection = pending_restore_stats.get("affection", stats.affection)
            stats.curiosity = pending_restore_stats.get("curiosity", stats.curiosity)
            stats.agitation = pending_restore_stats.get("agitation", stats.agitation)
            stats.wellness = pending_restore_stats.get("wellness", stats.wellness)
            stats.toilet = pending_restore_stats.get("toilet", stats.toilet)
        pending_restore_stats = null
        
    update()


func _draw_mouth():
    var m_color = Color("000000")
    
    if current_state == State.SLEEPING:
        # Sleeping: Draw a small line "z" or tiny circle
        draw_arc(mouth_pos, 4.0, 0, PI, 8, m_color, 2.0)
    elif current_state == State.EATING:
        # Eating: Large open circle animation
        var eat_rad = lerp(4.0, 12.0, sin(OS.get_ticks_msec() * 0.03) * 0.5 + 0.5)
        draw_circle(mouth_pos, eat_rad, m_color)
    elif stats.agitation > 50.0:
        # Angry squiggly line
        draw_line(mouth_pos - Vector2(10, 0), mouth_pos + Vector2(10, 0), m_color, 3.0)
    elif stats.hunger < 30.0:
        # Sad droopy mouth
        draw_arc(mouth_pos, 8.0, PI, 2*PI, 12, m_color, 3.0)
    elif current_state == State.CHASE_CURSOR:
        # Happy smile
        draw_arc(mouth_pos, 8.0, 0, PI, 12, m_color, 3.0)
    else:
        # Normal simple mouth line
        draw_line(mouth_pos - Vector2(6, 0), mouth_pos + Vector2(6, 0), m_color, 2.0)

func _get_viewport_bounds() -> Rect2:
    return Rect2(Vector2.ZERO, OS.window_size)

func _check_item_collisions():
    var main = get_parent()
    if not main or not ("active_items" in main):
        return

    for item in main.active_items:
        if not is_instance_valid(item):
            continue

        var item_radius = item.get("radius")
        if item_radius == null:
            continue

        var item_vel = item.get("velocity")
        if item_vel == null:
            continue  # Not a physics object

        var dist = global_position.distance_to(item.global_position)
        var min_dist = base_radius + item_radius

        if dist < min_dist and dist > 0.001:
            var normal = (item.global_position - global_position).normalized()

            # --- Ball vs Pet collision ---
            if item.get("is_toy") == true:
                # Separate positions
                var overlap = min_dist - dist
                item.global_position += normal * overlap * 0.6
                global_position -= normal * overlap * 0.4

                # Reflect ball velocity off pet surface
                var speed_in = item_vel.dot(normal)
                if speed_in < 0:  # approaching
                    var reflect = item_vel - 2.0 * speed_in * normal
                    item.velocity = reflect * 0.65
                    item.velocity = item.velocity.clamped(600.0)

                # Was the ball moving fast enough to count as a hit?
                if item_vel.length() > 100.0:
                    # Only register hit if ball arrived from outside (not kicked by us)
                    var ball_came_from_outside = item_vel.dot(normal) < -60.0
                    if ball_came_from_outside:
                        var now = OS.get_ticks_msec() * 0.001
                        ball_hit_times.append(now)

                        # Head shake reaction
                        head_shake_timer = 0.5
                        head_shake_intensity = 7.0

                        # Count recent hits and escalate agitation
                        if ball_hit_times.size() >= 3:
                            stats.agitation = clamp(stats.agitation + 25.0, 0.0, 100.0)
                        else:
                            stats.agitation = clamp(stats.agitation + 5.0, 0.0, 100.0)

            # --- Ball vs Food collision ---
            elif item.get("is_food") == true and item.get("is_toy") != true:
                # Check if a toy is also nearby and colliding with this food
                for toy_item in main.active_items:
                    if not is_instance_valid(toy_item) or toy_item.get("is_toy") != true:
                        continue
                    var toy_food_dist = toy_item.global_position.distance_to(item.global_position)
                    var toy_food_min = toy_item.get("radius") + item_radius if toy_item.get("radius") != null else 0.0
                    if toy_food_dist < toy_food_min and toy_food_dist > 0.001:
                        var fn = (item.global_position - toy_item.global_position).normalized()
                        var toy_vel = toy_item.get("velocity")
                        if toy_vel != null:
                            var s_in = toy_vel.dot(fn)
                            if s_in < 0:
                                var r = toy_vel - 2.0 * s_in * fn
                                toy_item.velocity = r * 0.5
                                toy_item.velocity = toy_item.velocity.clamped(600.0)
                        item.velocity = fn * 120.0

    # Poop proximity sickness check
    var poop_nearby = false
    for item in main.active_items:
        if is_instance_valid(item) and not item.get("is_food") and not item.get("is_toy") and item.filename.match("*Poop*"):
            var poop_dist = global_position.distance_to(item.global_position)
            if poop_dist < 80.0:
                poop_nearby = true
                break
                
    if poop_nearby:
        poop_proximity_timer += get_physics_process_delta_time()
        if poop_proximity_timer >= 20.0:
            # Wellness drains rapidly when sitting near poop for too long
            stats.wellness = clamp(stats.wellness - 0.5 * get_physics_process_delta_time(), 0.0, 100.0)
    else:
        # Cool down/reset the proximity timer when away from poop
        poop_proximity_timer = max(0.0, poop_proximity_timer - get_physics_process_delta_time() * 2.0)


