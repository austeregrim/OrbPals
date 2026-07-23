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
	WINDOW_SIT,
	PLAY_WITH_PET,
	DIGGING,
	BEGGING,
	DANCING
}

signal returned_to_box(breed_name)

# Voice Customization (0..3 versions, 0..2 pitches)
var voice_version: int = 0
var voice_pitch: int = 1
var footstep_timer: float = 0.0
var guarded_toy: Node = null


# Pet Identity & Custom Data
var pet_id: String = "grubby"
var pet_name: String = "Grubby"
var genetic_seed: int = 123456
var life_stage: String = "adult" # hatchling, juvenile, adult, senior, deceased
var age_seconds: float = 0.0
var time_outside_dispenser_seconds: float = 0.0
var will_dig_on_arrival: bool = false
var self_dispense_phase: int = 0

# Procedural Features
var has_fur: bool = false
var fur_length: float = 7.0
var fur_color: Color = Color("ff6f61")
var has_antennae: bool = false
var antenna_length: float = 18.0
var antenna_color: Color = Color("ffff00")
var foot_shape: String = "circle" # "circle" or "oval"
var element_type_idx: int = 0
var ability_cooldown_timer: float = 0.0

# 6 New Procedural Anatomy Features
var wing_type: String = "none" # "none", "angel", "bat", "butterfly", "fin"
var wing_color: Color = Color("ffffff")
var tail_type: String = "none" # "none", "fox_fluff", "devil_fork", "beaver_paddle", "dragon_spikes"
var tail_color: Color = Color("ff7700")
var head_feature: String = "none" # "none", "unicorn_horn", "ram_horns", "dino_frill", "crown_spikes"
var horn_color: Color = Color("ffffaa")
var pattern_type: String = "solid" # "solid", "tiger_stripes", "leopard_spots", "galaxy_swirl", "belly_patch"
var pattern_color: Color = Color("333333")
var pupil_shape: String = "circle" # "circle", "cat_slit", "star", "heart", "plus"
var has_cheeks: bool = true
var cheek_color: Color = Color("ff6688")
var weight: float = 1.0 # 0.7 (lean) to 1.3 (chubby)
var bored_eater: bool = false # genetic trait causing pet to eat when bored

# Multi-pet social & digging

var partner_pet = null
var social_timer: float = 0.0
var dig_timer: float = 0.0
var heart_emote_timer: float = 0.0

# Settings
export(Resource) var breed_data = null
export(float) var spring_k = 280.0
export(float) var damping = 14.0
export(float) var bounce_damping = 0.6
export(float) var gravity = 300.0
export(int) var num_points = 16
export(bool) var show_debug_stuffie_spot: bool = false


var active_breed = null

var base_radius = 20.0
var segment_positions = []

# 3D Depth coordinates
var x_pos: float = 0.0
var z_depth: float = 0.0
var y_height: float = 0.0
var z_vel: float = 0.0

func get_depth_scale(z: float) -> float:
	return lerp(1.0, 0.85, z)

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
var stuffed_animal_spot: Vector2 = Vector2.ZERO
var drag_history: Array = []
var stuffie_carry_timer: float = 0.0



# Interaction targets
var target_item = null
var target_wander_pos = Vector2.ZERO

# Transition & Toilet variables
var transition_nozzle_pos = Vector2.ZERO
var pending_breed_res = null
var transition_scale = 1.0
var relieve_corner_pos = Vector2.ZERO
var relieve_had_accident: bool = false

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
		
	x_pos = global_position.x
	y_height = 0.0
	var horizon_y_ready = OS.window_size.y * 0.35
	var floor_max_y_ready = OS.window_size.y - base_radius
	z_depth = clamp((floor_max_y_ready - global_position.y) / max(floor_max_y_ready - horizon_y_ready, 1.0), 0.0, 1.0)

	_change_state(State.IDLE)

func _is_spot_reachable_and_valid(spot: Vector2) -> bool:
	var bounds = _get_viewport_bounds()
	var margin_x = base_radius + 50.0
	var margin_y = base_radius + 25.0
	if spot.x < bounds.position.x + margin_x or spot.x > bounds.end.x - margin_x:
		return false
	if spot.y < bounds.position.y + margin_y or spot.y > bounds.end.y - margin_y:
		return false
		
	var main_ref = get_parent()
	if main_ref and "desktop_window_manager" in main_ref and is_instance_valid(main_ref.desktop_window_manager):
		var rects = main_ref.desktop_window_manager.get_window_rects()
		for r in rects:
			if r.grow(base_radius + 20.0).has_point(spot):
				return false
	return true

func _get_or_create_stuffed_animal_spot() -> Vector2:
	var bounds = _get_viewport_bounds()
	
	if stuffed_animal_spot != Vector2.ZERO and _is_spot_reachable_and_valid(stuffed_animal_spot):
		return stuffed_animal_spot
		
	if is_instance_valid(guarded_toy) and _is_spot_reachable_and_valid(guarded_toy.global_position):
		stuffed_animal_spot = guarded_toy.global_position
		return stuffed_animal_spot
		
	var margin_x = clamp(base_radius + 65.0, 70.0, bounds.size.x * 0.25)
	var margin_y = base_radius + 30.0
	
	var spot_x = bounds.position.x + margin_x
	if int(genetic_seed) % 2 == 1:
		spot_x = bounds.end.x - margin_x
	var spot_y = bounds.end.y - margin_y
	
	var candidate = Vector2(spot_x, spot_y)
	if not _is_spot_reachable_and_valid(candidate):
		candidate = Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.end.y - margin_y)
		
	stuffed_animal_spot = candidate
	return stuffed_animal_spot


func _process_stuffed_animal_retrieval(delta, bounds) -> bool:
	var main_ref = get_parent()
	if main_ref and ("active_items" in main_ref):
		for item in main_ref.active_items:
			if is_instance_valid(item) and item.get("toy_type") == "stuffed_animal":
				var o_id = item.get("owner_pet_id")
				if o_id == "" or o_id == pet_id:
					item.set("owner_pet_id", pet_id)
					item.set("owner_pet", self)
					item.set("is_being_guarded", true)
					guarded_toy = item

	if not is_instance_valid(guarded_toy) or guarded_toy.get("is_dragging"):
		stuffie_carry_timer = 0.0
		return false
		
	var target_spot = _get_or_create_stuffed_animal_spot()
	var dist_from_spot = guarded_toy.global_position.distance_to(target_spot)
	
	# Guard against intruders
	var intruder = _find_closest_other_pet()
	if is_instance_valid(intruder):
		var dist_to_stuffie = intruder.global_position.distance_to(guarded_toy.global_position)
		if dist_to_stuffie < 68.0:
			if AudioManager and randf() < 0.08:
				AudioManager.play_pet_emotion(self, "growl")
			var shove_dir = (intruder.global_position - guarded_toy.global_position).normalized()
			intruder.center_vel += shove_dir * 180.0

	# Check if stuffed animal needs returning
	if dist_from_spot > 40.0 and current_state != State.SICK and current_state != State.SLEEPING and current_state != State.RELIEVING_SELF:
		var dist_to_toy = global_position.distance_to(guarded_toy.global_position)
		if dist_to_toy > base_radius + 25.0:
			stuffie_carry_timer = 0.0
			var nav_dir = (guarded_toy.global_position - global_position).normalized()
			center_vel = nav_dir * 110.0
		else:
			stuffie_carry_timer += delta
			var side_offset = Vector2((1.0 if center_vel.x >= 0 else -1.0) * (base_radius + 8.0), 0.0)
			guarded_toy.global_position = lerp(guarded_toy.global_position, global_position + side_offset, 0.4)
			
			var nav_dir = (target_spot - global_position).normalized()
			center_vel = nav_dir * 95.0
			
			var dist_to_target = global_position.distance_to(target_spot)
			if dist_to_target < 45.0 or stuffie_carry_timer > 2.5:
				var place_pos = global_position + side_offset
				place_pos.x = clamp(place_pos.x, bounds.position.x + 30.0, bounds.end.x - 30.0)
				place_pos.y = clamp(place_pos.y, bounds.position.y + 30.0, bounds.end.y - 30.0)
				
				guarded_toy.global_position = place_pos
				guarded_toy.velocity = Vector2.ZERO
				stuffed_animal_spot = place_pos
				stuffie_carry_timer = 0.0
				
				if AudioManager and randf() < 0.2:
					AudioManager.play_pet_emotion(self, "giggle")
		return true
	return false

func _physics_process(delta):
	var bounds = _get_viewport_bounds()

	# 1. Decay drives if enabled
	if decay_enabled:
		var is_moving = (center_vel.length() > 10.0 or current_state == State.WANDER or current_state == State.CHASE_ITEM or current_state == State.PLAY_WITH_PET or current_state == State.DIGGING)
		stats.decay(delta, is_moving)
		
	# 1.2 Elemental Energy Charge & Discharge (Juvenile/Adult/Senior only)
	if can_use_ability() and stats != null:
		if stats.elemental_energy >= 100.0 and (current_state == State.WANDER or current_state == State.IDLE):
			stats.elemental_energy = 0.0
			_manifest_elemental_power()
		elif stats.agitation > 60.0 and stats.elemental_energy >= 30.0:
			stats.elemental_energy = max(0.0, stats.elemental_energy - 35.0)
			_manifest_elemental_power()
		
	# Check stuffed animal retrieval before general state evaluation
	var is_retrieving_stuffie = _process_stuffed_animal_retrieval(delta, bounds)
	if not is_retrieving_stuffie:
		_evaluate_states(delta)
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
	bounds = _get_viewport_bounds()
	if is_dragging:

		var mouse_pos = prev_mouse_pos if prev_mouse_pos != Vector2.ZERO else get_global_mouse_position()
		global_position = mouse_pos
		center_vel = Vector2.ZERO
		
		drag_history.append({"pos": mouse_pos, "time": now})
		while drag_history.size() > 0 and (now - drag_history[0].time) > 0.14:
			drag_history.remove(0)

			
		var dist_moved = mouse_pos.distance_to(prev_mouse_pos) if prev_mouse_pos != Vector2.ZERO else 0.0
		if stats:
			if dist_moved > 15.0:
				stats.affection = clamp(stats.affection - 0.05, 0.0, 100.0)
				stats.agitation = clamp(stats.agitation + dist_moved * 0.008, 0.0, 100.0)
			else:
				stats.affection = clamp(stats.affection + 0.05, 0.0, 100.0)
				stats.agitation = clamp(stats.agitation - 0.1, 0.0, 100.0)
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
		
		# Track time outside dispenser and progress life stages
		if current_state != State.RETURNING_TO_DISPENSER and current_state != State.EMERGING_FROM_DISPENSER:
			time_outside_dispenser_seconds += delta
			if life_stage == "infant" or life_stage == "hatchling":
				if time_outside_dispenser_seconds >= 600.0: # 10 minutes real time
					life_stage = "child"
			elif life_stage == "child" or life_stage == "juvenile":
				if time_outside_dispenser_seconds >= 2700.0: # 45 minutes total (35 mins as child)
					life_stage = "adult"

			if center_vel.length() > 20.0:
				weight = clamp(weight - delta * 0.00005, 0.7, 1.3)
		
		# Calculate floor / platform landing
		var platform_y = bounds.end.y - base_radius
		var main = get_parent()
		if main and "desktop_window_manager" in main and is_instance_valid(main.desktop_window_manager):
			var window_rects = main.desktop_window_manager.get_window_rects()
			for rect in window_rects:
				if global_position.x >= rect.position.x - base_radius and global_position.x <= rect.end.x + base_radius:
					var top_y = rect.position.y - base_radius
					if global_position.y <= rect.position.y + 25 and top_y < platform_y:
						platform_y = top_y
						
		if global_position.y >= platform_y:
			global_position.y = platform_y
			if center_vel.y > 0:
				center_vel.y = -center_vel.y * bounce_damping
				if abs(center_vel.y) < 30.0:
					center_vel.y = 0.0
					is_falling = false
				center_vel.x *= 0.8
				
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
			
		# Pet-to-Pet collision avoidance (prevent clipping unless mating)
		var is_mating = (current_state == State.EATING or current_state == State.SLEEPING) # Placeholder until full mating state is active
		if not is_mating and main and ("active_pets" in main):
			for other in main.active_pets:
				if is_instance_valid(other) and other != self:
					var p_diff = global_position - other.global_position
					var p_dist = p_diff.length()
					var min_p_dist = (base_radius + other.base_radius) * 0.95
					if p_dist < min_p_dist and p_dist > 0.001:
						var push_dir = p_diff / p_dist
						var overlap = min_p_dist - p_dist
						global_position += push_dir * (overlap * 0.5)
						other.global_position -= push_dir * (overlap * 0.5)
						# Soft velocity nudge
						var rel_vel = center_vel - other.center_vel
						if rel_vel.dot(push_dir) < 0:
							center_vel += push_dir * 15.0
							other.center_vel -= push_dir * 15.0

	# 5. Simulate outer points (Spring-Mass System)
	var current_floor_y = bounds.end.y

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
		elif p_pos.y > current_floor_y:
			p_pos.y = current_floor_y
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

	# Motion footstep SFX timer for smooth movement & non-limbed breeds
	if center_vel.length() > 25.0 and current_state != State.SLEEPING and current_state != State.SICK:
		footstep_timer += delta
		var interval = 0.32 if center_vel.length() < 110.0 else 0.16
		if footstep_timer >= interval:
			footstep_timer = 0.0
			if AudioManager:
				if center_vel.length() < 110.0:
					AudioManager.play_footstep_walk()
				else:
					AudioManager.play_footstep_run()

		
	if segment_positions.size() > 0:


		segment_positions[0] = global_position
		for i in range(1, segment_positions.size()):
			var p_target = segment_positions[i - 1]
			var diff = p_target - segment_positions[i]
			var dist = diff.length()
			
			var spacing = active_breed.segment_spacing
			var max_dist = spacing * 1.25
			var min_dist = spacing * 0.75
			
			# If segment has fallen too far behind (e.g. initial emergence or sharp turn), pull it immediately to spacing
			if dist > max_dist or dist < 0.001:
				var pull_dir = diff.normalized() if dist > 0.001 else Vector2(-facing_dir, 0.0)
				segment_positions[i] = p_target - pull_dir * spacing
			else:
				# Smooth organic trailing towards target segment
				var desired_pos = p_target - diff.normalized() * spacing
				segment_positions[i] = lerp(segment_positions[i], desired_pos, 0.4)
				
				# Strict distance clamping relative to target segment
				var new_diff = p_target - segment_positions[i]
				var new_dist = new_diff.length()
				if new_dist > max_dist and new_dist > 0.001:
					segment_positions[i] = p_target - new_diff.normalized() * max_dist
				elif new_dist < min_dist and new_dist > 0.001:
					segment_positions[i] = p_target - new_diff.normalized() * min_dist

			# Keep within screen bounds
			segment_positions[i].x = clamp(segment_positions[i].x, bounds.position.x + 5.0, bounds.end.x - 5.0)
			segment_positions[i].y = clamp(segment_positions[i].y, bounds.position.y + 5.0, current_floor_y)
				
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
				
			current_floor_y = bounds.end.y - 2.0

			# Clamp desired position within floor boundary
			if desired_foot.y > current_floor_y:
				desired_foot.y = current_floor_y
				
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
						
						# Play footstep audio on step start
						if AudioManager:
							if center_vel.length() > 110.0:
								AudioManager.play_footstep_run()
							else:
								AudioManager.play_footstep_walk()

						# Overshoot target in walking direction
						var overshoot = center_vel.normalized() * 18.0
						foot_step_target[l_idx] = desired_foot + overshoot
						if foot_step_target[l_idx].y > current_floor_y:
							foot_step_target[l_idx].y = current_floor_y
							
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
	var touch_pos = Vector2.ZERO
	var is_press = false
	var is_release = false

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		touch_pos = event.global_position
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventScreenTouch:
		touch_pos = event.position
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventScreenDrag and is_dragging:
		touch_pos = event.position
		drag_positions.append(touch_pos)
		prev_mouse_pos = touch_pos
		return

	if is_press:
		var poly = get_click_polygon()
		if Geometry.is_point_in_polygon(touch_pos, poly):
			is_dragging = true
			drag_positions.clear()
			drag_positions.append(touch_pos)
			prev_mouse_pos = touch_pos
	elif is_release and is_dragging:
		is_dragging = false
		prev_mouse_pos = Vector2.ZERO
		if drag_history.size() >= 2:
			var oldest = drag_history[0]
			var newest = drag_history[drag_history.size() - 1]
			var dt = newest.time - oldest.time
			if dt > 0.005:
				var toss_vel = (newest.pos - oldest.pos) / dt
				center_vel = toss_vel * 1.15
				center_vel = center_vel.clamped(900.0)
		drag_history.clear()
		is_falling = false
		_change_state(State.WANDER)


func get_click_polygon() -> PoolVector2Array:
	var polygons = []
	var s = 1.0
	
	var scaled_points = PoolVector2Array()
	for i in range(point_positions.size()):
		var offset = point_positions[i] - global_position
		scaled_points.append(global_position + offset * transition_scale * s)
	polygons.append(scaled_points)
	
	if active_breed and segment_positions.size() > 1:
		for i in range(1, segment_positions.size()):
			var seg_pos = segment_positions[i]
			var scale_idx = i
			var scale = active_breed.segment_scales[scale_idx] if scale_idx < active_breed.segment_scales.size() else 0.5
			var seg_rad = active_breed.head_radius * scale
			
			var seg_local = seg_pos - global_position
			var octagon = PoolVector2Array()
			for j in range(8):
				var angle = j * 2.0 * PI / 8.0
				var offset = Vector2(cos(angle), sin(angle)) * seg_rad
				octagon.append(global_position + (seg_local + offset) * transition_scale * s)
			polygons.append(octagon)
			
	return combine_polygons_local(polygons)

func combine_polygons_local(polygons_list: Array) -> PoolVector2Array:
	var combined = PoolVector2Array()
	if polygons_list.empty():
		combined.append(Vector2(-10, -10))
		combined.append(Vector2(-9, -10))
		combined.append(Vector2(-9, -9))
		return combined
		
	# Filter out empty polygons
	var valid_polys = []
	for p in polygons_list:
		if p.size() >= 3:
			valid_polys.append(p)
			
	if valid_polys.empty():
		combined.append(Vector2(-10, -10))
		combined.append(Vector2(-9, -10))
		combined.append(Vector2(-9, -9))
		return combined

	# Merge overlapping polygons to avoid even-odd winding holes
	var merged = [valid_polys[0]]
	for i in range(1, valid_polys.size()):
		var to_merge = valid_polys[i]
		var next_merged = []
		for existing in merged:
			var res = Geometry.merge_polygons_2d(existing, to_merge)
			if res.size() == 1:
				to_merge = res[0]
			else:
				next_merged.append(existing)
		next_merged.append(to_merge)
		merged = next_merged

	# Traverse disjoint polygons with zero-width bridge paths
	for i in range(merged.size()):
		var poly = merged[i]
		for pt in poly:
			combined.append(pt)
		combined.append(poly[0]) # Close the loop
		
		# Bridge to the next polygon if one exists
		if i < merged.size() - 1:
			combined.append(merged[i + 1][0])
			
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
	if current_state == State.SLEEPING or current_state == State.SICK or current_state == State.RETURNING_TO_DISPENSER:
		return
	if stats and stats.hunger >= 95.0:
		return # Full (>=95% fullness): ignores food and treats completely!
	_scan_for_food_or_treat()

func on_item_removed(item):
	if target_item == item:
		target_item = null
		if not _scan_for_food_or_treat():
			if current_state == State.CHASE_ITEM:
				_change_state(State.WANDER)

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
		
	# 1. Starving / Hiding & Sad override (< 10% hunger)
	if stats.hunger < 10.0 and current_state != State.EATING and current_state != State.SLEEPING:
		var close_food = _find_closest_food_or_treat()
		if is_instance_valid(close_food):
			target_item = close_food
			_change_state(State.CHASE_ITEM)
		elif current_state != State.SICK:
			_show_learning_emote("[SICK]")
			_change_state(State.SICK)

		return

	# 2. Begging override at panel/dispenser tab (at 30% hunger)
	if stats.hunger < 30.0 and current_state != State.EATING and current_state != State.CHASE_ITEM and current_state != State.BEGGING and current_state != State.SLEEPING:
		if _scan_for_food_or_treat():
			return
		_change_state(State.BEGGING)
		return

	# 3. Active Food searching override (< 50% hunger or bored_eater trait)
	if (stats.hunger < 50.0 or (bored_eater and stats.boredom < 50.0)) and (current_state == State.IDLE or current_state == State.WANDER):
		if _scan_for_food_or_treat():
			return
			
	# Self-Dispense override (steal food if neglected and starving, but ONLY if no food is left out!)
	if stats.hunger < 20.0 and current_state != State.EATING and current_state != State.CHASE_ITEM:
		var food = _find_closest_food_or_treat()
		if is_instance_valid(food):
			target_item = food
			_change_state(State.CHASE_ITEM)
			return
		else:
			_change_state(State.SELF_DISPENSE)
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

		if stats.wellness >= 70.0 and stats.hunger >= 10.0:
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

	# Toilet override: pet searches for corner starting at 80%
	if stats.toilet >= 80.0 and current_state != State.RELIEVING_SELF:
		_change_state(State.RELIEVING_SELF)
		return
		
	if current_state == State.RELIEVING_SELF:
		return

	var is_infant_stage = (life_stage == "infant" or life_stage == "hatchling")
	var is_adult_stage = (life_stage == "adult")

	# State specific transitions
	match current_state:
		State.IDLE:
			if _scan_for_food_or_treat():
				return
			var toy = _find_closest_item(false)
			if (stats.boredom < 60.0 or (randf() < 0.003 and stats.boredom < 90.0)) and is_instance_valid(toy):
				target_item = toy
				_change_state(State.CHASE_ITEM)
			elif stats.affection < 50.0 and not is_infant_stage:
				_change_state(State.CHASE_CURSOR)
			elif stats.curiosity < 30.0 or (randf() < 0.02 and stats.curiosity < 70.0):
				# Try to sit on a window border!
				var spots = _query_window_borders()
				if spots.size() > 0 and not is_infant_stage:
					target_wander_pos = spots[randi() % spots.size()]
					_change_state(State.WINDOW_SIT)
				elif not is_infant_stage:
					_find_curiosity_boundary_target()
					_change_state(State.WANDER)
			elif is_infant_stage and state_timer > rand_range(8.0, 16.0):
				if randf() < 0.3:
					_change_state(State.WANDER)
			elif is_adult_stage and state_timer > rand_range(6.0, 12.0):
				if randf() < 0.4:
					_change_state(State.WANDER)
			elif not is_infant_stage and not is_adult_stage and state_timer > rand_range(2.0, 4.0):
				_change_state(State.WANDER)
				
		State.WANDER:
			if _scan_for_food_or_treat():
				return
			var toy = _find_closest_item(false)
			var other_pet = _find_closest_other_pet()
			if (stats.boredom < 60.0 or (randf() < 0.003 and stats.boredom < 90.0)) and is_instance_valid(toy):
				target_item = toy
				_change_state(State.CHASE_ITEM)
			elif is_instance_valid(other_pet) and global_position.distance_to(other_pet.global_position) < base_radius * 3.5:
				partner_pet = other_pet
				_change_state(State.PLAY_WITH_PET)
			elif stats.curiosity < 45.0 and randf() < 0.0015 and not is_infant_stage:
				_change_state(State.DIGGING)
			elif stats.affection < 50.0 and not is_infant_stage:
				_change_state(State.CHASE_CURSOR)
			elif is_infant_stage and state_timer > rand_range(2.0, 4.0):
				_change_state(State.IDLE)
			elif state_timer > rand_range(4.0, 8.0):
				_change_state(State.IDLE)

		State.BEGGING:

			if _scan_for_food_or_treat():
				return
			if stats.hunger >= 50.0:
				_change_state(State.IDLE)

		State.PLAY_WITH_PET:
			if not is_instance_valid(partner_pet) or state_timer > 6.0:
				_change_state(State.IDLE)
			else:
				# Hearts & friendship boost
				stats.boredom = clamp(stats.boredom + delta * 20.0, 0.0, 100.0)
				stats.affection = clamp(stats.affection + delta * 15.0, 0.0, 100.0)

		State.DIGGING:
			if state_timer < 0.05 and AudioManager:
				AudioManager.play_digging()
			if state_timer > 2.5:
				# Complete digging & drop material into inventory
				_on_digging_complete()
				_change_state(State.IDLE)

		State.DANCING:
			stats.boredom = clamp(stats.boredom + delta * 25.0, 0.0, 100.0)
			stats.affection = clamp(stats.affection + delta * 15.0, 0.0, 100.0)
			if randf() < 0.006 and AudioManager:
				AudioManager.play_pet_emotion(self, "sing" if randf() < 0.5 else "giggle")

				
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
				if not _scan_for_food_or_treat():
					_change_state(State.IDLE)

func _change_state(new_state: int):
	current_state = new_state
	state_timer = 0.0
	if new_state != State.EMERGING_FROM_DISPENSER and new_state != State.RETURNING_TO_DISPENSER:
		transition_scale = 1.0
	
	# State initialization actions
	match new_state:
		State.IDLE:
			center_vel = Vector2.ZERO
			if AudioManager and randf() < 0.2:
				AudioManager.play_pet_emotion(self, "sigh")
		State.WANDER:
			_pick_random_wander_target()
		State.CHASE_CURSOR:
			if AudioManager and randf() < 0.3:
				AudioManager.play_pet_emotion(self, "giggle")
		State.CHASE_ITEM:
			if AudioManager:
				AudioManager.play_pet_emotion(self, "question_huh")
		State.SLEEPING:
			center_vel = Vector2.ZERO
			if AudioManager:
				AudioManager.play_pet_emotion(self, "yawn")
		State.EATING:
			center_vel = Vector2.ZERO
		State.SICK:
			center_vel = Vector2.ZERO
			if AudioManager:
				AudioManager.play_pet_emotion(self, "cry")
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
		State.AGITATED:
			if AudioManager:
				AudioManager.play_pet_emotion(self, "bark_roar")
		State.DANCING:
			if AudioManager:
				AudioManager.play_pet_emotion(self, "sing")

		State.RETURNING_TO_DISPENSER:
			pass
		State.EMERGING_FROM_DISPENSER:
			global_position = transition_nozzle_pos
			center_vel = Vector2(0, 150.0)
			transition_scale = 0.1
		State.RELIEVING_SELF:
			relieve_had_accident = false
			var bounds = _get_viewport_bounds()
			var floor_y = bounds.end.y - base_radius
			if randf() < 0.5:
				relieve_corner_pos = Vector2(bounds.position.x + base_radius + 20.0, floor_y)
			else:
				relieve_corner_pos = Vector2(bounds.end.x - base_radius - 20.0, floor_y)
		State.SELF_DISPENSE:
			center_vel = Vector2.ZERO
		State.WINDOW_SIT:
			center_vel = Vector2.ZERO
			window_sit_duration = rand_range(8.0, 20.0)
		State.BEGGING:
			center_vel = Vector2.ZERO
			_show_learning_emote("[HUNGRY]")



func _update_state_behavior(delta):
	match current_state:
		State.WANDER:
			# Walk towards wander target
			var dir = (target_wander_pos - global_position).normalized()
			var speed = 80.0
			var is_infant = (life_stage == "infant" or life_stage == "hatchling")
			if is_infant:
				speed = 22.0 # Crawling speed for infants!
				var perp = Vector2(-dir.y, dir.x)
				var crawl_wobble = perp * sin(state_timer * 8.0) * 10.0
				center_vel = dir * speed + crawl_wobble
			elif stats.wellness < 40.0:
				speed = 30.0 # move slow when sick
				center_vel = dir * speed
			else:
				center_vel = dir * speed

			
			# Check if reached target
			if global_position.distance_to(target_wander_pos) < 20.0 or state_timer > 6.0:
				if will_dig_on_arrival:
					will_dig_on_arrival = false
					_change_state(State.DIGGING)
					return
				var bounds = _get_viewport_bounds()
				if global_position.x >= bounds.end.x - 70.0 and stats and stats.knows_food_button < 1.0:
					# Pet curiosity tab interaction across all panel tabs!
					var main = get_parent()
					if main:
						var available_tabs = ["dispenser", "needs", "genetics", "inventory", "settings"]
						var chosen_tab = available_tabs[randi() % available_tabs.size()]
						if main.has_method("toggle_drawer_panel"):
							main.call("toggle_drawer_panel", chosen_tab)
						
						if chosen_tab == "dispenser" and (randf() < 0.5):
							var nozzle_pos = Vector2(OS.window_size.x / 2.0, 150.0)
							if "dispenser_device" in main and is_instance_valid(main.dispenser_device):
								nozzle_pos = main.dispenser_device.get_nozzle_global_position()
							if main.has_method("spawn_food"):
								main.call("spawn_food", nozzle_pos, false)
							stats.knows_food_button = clamp(stats.knows_food_button + 0.35, 0.0, 1.0)
							stats.knows_dispenser = clamp(stats.knows_dispenser + 0.35, 0.0, 1.0)
							_show_learning_emote("[IDEA]")
							_scan_for_food_or_treat()
							_change_state(State.IDLE)
							return
						else:
							_show_learning_emote("[%s]" % chosen_tab.to_upper())
							_change_state(State.IDLE)
							return
				if stats.curiosity < 30.0:
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
			
		State.BEGGING:
			var main = get_parent()
			var bounds = _get_viewport_bounds()
			var target_pos = Vector2(bounds.end.x - 40.0, bounds.position.y + bounds.size.y * 0.1)
			if main and "dispenser_device" in main and is_instance_valid(main.dispenser_device):
				target_pos = main.dispenser_device.get_nozzle_global_position()
			
			var dir = (target_pos - global_position).normalized()
			var dist = global_position.distance_to(target_pos)
			if dist > 35.0:
				center_vel = dir * 120.0
			else:
				center_vel = Vector2.ZERO
				head_shake_timer = 0.2
				head_shake_intensity = 3.0
				if fmod(state_timer, 2.5) < delta:
					_show_learning_emote("[FOOD]" if randf() < 0.5 else "[HUNGRY]")


			if _scan_for_food_or_treat():
				return

		State.CHASE_ITEM:
			if is_instance_valid(target_item):
				var target_pos = target_item.global_position
				var dir = (target_pos - global_position).normalized()
				var speed = 200.0

				var is_infant = (life_stage == "infant" or life_stage == "hatchling")
				var is_sick = (current_state == State.SICK or (stats and stats.wellness < 40.0))

				if is_infant:
					speed = 25.0 # Infants NEVER run, crawling speed ONLY!
				elif is_sick:
					speed = 30.0 # Sick pets NEVER run, slow movement ONLY!
				else:
					# Competition check: if another adult pet is targeting the exact same treat/food, HURRY!
					var main_node = get_parent()
					if main_node and ("active_pets" in main_node):
						for other_p in main_node.active_pets:
							if is_instance_valid(other_p) and other_p != self and other_p.target_item == target_item:
								speed = 330.0 # Race / hurry speed boost!
								break

				center_vel = lerp(center_vel, dir * speed, 0.1)
				
				# Check arrival at item
				var dist_to_item = global_position.distance_to(target_item.global_position)
					
				if target_item.has_method("apply_impulse"):
					# --- TOY PLAY ---
					if dist_to_item < base_radius + 20.0:
						# Kick the toy!
						var kick_dir = dir.rotated(rand_range(-0.6, 0.6))
						target_item.call("apply_impulse", kick_dir * rand_range(200.0, 380.0))
						# Boredom gain per kick
						stats.boredom = clamp(stats.boredom + 2.0, 0.0, 100.0)
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
						if not _scan_for_food_or_treat():
							_change_state(State.IDLE)
				elif dist_to_item < base_radius + 15.0:
					# --- FOOD ---
					_check_food_competition_and_eat()
			else:
				toy_play_time = 0.0
				if not _scan_for_food_or_treat():
					_change_state(State.IDLE)
				
		State.SLEEPING:
			# Wake up slowly
			stats.energy = clamp(stats.energy + delta * 12.0, 0.0, 100.0)
			
		State.EATING:
			# Eat animation vibration
			var shake = Vector2(rand_range(-2, 2), rand_range(-2, 2))
			global_position += shake
			
			# Continuous food guarding check while eating
			var other_pet = _find_closest_other_pet()
			if is_instance_valid(other_pet):
				var dist_to_other = global_position.distance_to(other_pet.global_position)
				if dist_to_other < base_radius * 4.5:
					var push_dir = (other_pet.global_position - global_position).normalized()
					look_dir = push_dir
					head_shake_timer = 0.6
					head_shake_intensity = 8.0
					if fmod(state_timer, 1.0) < delta:
						_show_learning_emote("[GROWL!]")
					other_pet.target_item = null
					other_pet._show_learning_emote("[SCARED]")
					other_pet.center_vel += push_dir * 320.0
					other_pet._change_state(State.WANDER)

			
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
			# Scale up smoothly
			transition_scale = lerp(transition_scale, 1.0, 0.12)
			
			# Floor bounce/landing
			var bounds = _get_viewport_bounds()
			var floor_y = bounds.end.y - base_radius
			if global_position.y >= floor_y or state_timer > 1.5:
				if global_position.y >= floor_y:
					global_position.y = floor_y
				center_vel = Vector2.ZERO
				transition_scale = 1.0
				_change_state(State.IDLE)
				
		State.RELIEVING_SELF:
			# Emergency / Accident: If toilet drive reaches 99%, pet goes right where it is (unhappy!)
			if stats.toilet >= 99.0:
				center_vel = Vector2.ZERO
				var vibe = Vector2(sin(OS.get_ticks_msec() * 0.1) * 2.0, cos(OS.get_ticks_msec() * 0.06) * 1.5)
				global_position += vibe
				
				if not relieve_had_accident:
					relieve_had_accident = true
					_show_learning_emote("[SICK]")
					stats.agitation = clamp(stats.agitation + 30.0, 0.0, 100.0)
					stats.affection = max(0.0, stats.affection - 15.0)
					stats.wellness = max(0.0, stats.wellness - 10.0)
				
				if state_timer > 2.0:
					_spawn_poop()
					stats.toilet = 0.0
					_change_state(State.WANDER)
				return
				
			# Normal corner search (between 80% and 99%)
			var dir = (relieve_corner_pos - global_position).normalized()
			var dist = global_position.distance_to(relieve_corner_pos)
			center_vel = dir * 100.0
			
			# Check if arrived at corner or close to edge
			var arrived = dist < 35.0 or (abs(global_position.x - relieve_corner_pos.x) < 30.0 and abs(global_position.y - relieve_corner_pos.y) < 35.0) or state_timer > 6.0
			if arrived:
				center_vel = Vector2.ZERO
				var vibe = Vector2(sin(OS.get_ticks_msec() * 0.08) * 1.5, cos(OS.get_ticks_msec() * 0.04) * 1.0)
				global_position += vibe
				
				if state_timer > 2.5:
					_spawn_poop()
					stats.toilet = 0.0
					_change_state(State.WANDER)
					
		State.SELF_DISPENSE:
			var main = get_parent()
			var bounds = _get_viewport_bounds()
			var tab_pos = Vector2(bounds.end.x - 30.0, bounds.position.y + bounds.size.y * 0.08)
			var nozzle_pos = Vector2(bounds.size.x / 2.0, 150.0)
			
			if main and "dispenser_device" in main and is_instance_valid(main.dispenser_device):
				nozzle_pos = main.dispenser_device.get_nozzle_global_position()
				
			if self_dispense_phase == 0:
				# Step 1: Walk to side tab ear on right edge
				var dir = (tab_pos - global_position).normalized()
				var dist = global_position.distance_to(tab_pos)
				center_vel = dir * 130.0
				
				if dist < 35.0:
					# Arrived at tab ear: Touch tab ear (50% dispenser, 50% other tabs)
					var available_tabs = ["dispenser", "needs", "genetics", "inventory", "settings"]
					var chosen_tab = available_tabs[randi() % available_tabs.size()]
					if main and main.has_method("toggle_drawer_panel"):
						main.call("toggle_drawer_panel", chosen_tab)
					
					_show_learning_emote("[%s]" % chosen_tab.to_upper())
					if chosen_tab == "dispenser" and (randf() < 0.5):
						self_dispense_phase = 1
						state_timer = 0.0
					else:
						self_dispense_phase = 0
						_change_state(State.IDLE)
			else:
				# Step 2: Walk to Food Button, take EXACTLY 1 food, and immediately finish!
				var button_pos = nozzle_pos + Vector2(-40.0, 20.0)
				if main and "dispenser_device" in main and is_instance_valid(main.dispenser_device):
					var disp_rect = main.dispenser_device.get_panel_rect()
					button_pos = disp_rect.position + Vector2(50.0, 50.0)
					
				var dir = (button_pos - global_position).normalized()
				var dist = global_position.distance_to(button_pos)
				center_vel = dir * 130.0
				
				if dist < 30.0 or state_timer > 3.0:
					# Dispense EXACTLY 1 food item!
					if main and main.has_method("spawn_food"):
						main.call("spawn_food", nozzle_pos, false)
						
					if stats:
						stats.knows_food_button = clamp(stats.knows_food_button + 0.35, 0.0, 1.0)
						stats.knows_dispenser = clamp(stats.knows_dispenser + 0.35, 0.0, 1.0)
					_show_learning_emote("[IDEA]")

					self_dispense_phase = 0
					
					if not _scan_for_food_or_treat():
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
	if stats and stats.knows_food_button < 1.0 and (stats.hunger < 75.0 or stats.curiosity < 75.0) and randf() < 0.5:
		var x = bounds.end.x - 30.0
		var y = rand_range(bounds.position.y + 60.0, bounds.end.y - 60.0)
		target_wander_pos = Vector2(x, y)
	else:
		var x = rand_range(bounds.position.x + 100.0, bounds.end.x - 100.0)
		var y = rand_range(bounds.position.y + 100.0, bounds.end.y - 100.0)
		target_wander_pos = Vector2(x, y)

func _find_curiosity_boundary_target():
	var bounds = _get_viewport_bounds()
	var edge = randi() % 4
	var x = 0.0
	var y = 0.0
	
	var horizon_y = bounds.position.y + 100.0
	var floor_max_y = bounds.end.y - 100.0

	match edge:
		0: # Left
			x = bounds.position.x + 50.0
			y = rand_range(horizon_y, floor_max_y)
		1: # Right
			x = bounds.end.x - 50.0
			y = rand_range(horizon_y, floor_max_y)
		2: # Top (horizon)
			x = rand_range(bounds.position.x + 100.0, bounds.end.x - 100.0)
			y = horizon_y
		3: # Bottom (foreground)
			x = rand_range(bounds.position.x + 100.0, bounds.end.x - 100.0)
			y = floor_max_y
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
		
	var stretch_factor = 1.0
	if OS.get_name() != "Android":
		var win_h = OS.window_size.y
		if win_h > 0.0:
			stretch_factor = 768.0 / win_h


	var stage_scale = 0.55 if (life_stage == "infant" or life_stage == "hatchling") else (0.85 if (life_stage == "child" or life_stage == "juvenile") else 1.0)
	var weight_scale = lerp(0.85, 1.25, clamp((weight - 0.7) / 0.6, 0.0, 1.0))
	var s = stage_scale * weight_scale * stretch_factor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(transition_scale * s, transition_scale * s))


		
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
	
	# Calculate shadow scaling
	var sh_scale = lerp(1.0, 0.4, clamp(y_height / 300.0, 0.0, 1.0))
	var sh_opacity = lerp(1.0, 0.15, clamp(y_height / 300.0, 0.0, 1.0))
	var shadow_y_offset = 0.0

	# 0.5. Draw limbs first (so they go in the back)
	for limb in limbs:
		var attach_local = limb.attachment - global_position
		var knee_local = limb.knee - global_position
		var foot_local = limb.foot - global_position

		# Shadow under foot (ground shadow)
		draw_circle(foot_local + Vector2(2, shadow_y_offset + 4), 4.0 * sh_scale, Color(0, 0, 0, 0.18 * sh_opacity))

		# --- Upper limb segment (attachment -> knee) ---
		var upper_dir = (knee_local - attach_local)
		var upper_len = upper_dir.length()
		if upper_len > 0.001:
			draw_line(attach_local, knee_local, outline_color, 11.0)
			draw_line(attach_local, knee_local, s_col, 8.0)
			draw_circle(knee_local, 4.5, outline_color)
			draw_circle(knee_local, 3.5, s_col)

		# --- Lower limb segment (knee -> foot) ---
		var lower_dir = (foot_local - knee_local)
		var lower_len = lower_dir.length()
		if lower_len > 0.001:
			draw_line(knee_local, foot_local, outline_color, 9.0)
			draw_line(knee_local, foot_local, p_col, 6.0)

		# Foot / hand ball
		draw_circle(foot_local, 5.0, outline_color)
		draw_circle(foot_local, 4.0, p_col)
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
			draw_circle(local_pos + Vector2(3, shadow_y_offset + 5), r * 0.7 * sh_scale, Color(0, 0, 0, 0.12 * sh_opacity))

		# Draw connecting body capsules between adjacent segments first
		for i in range(segment_positions.size() - 1, 0, -1):
			var pos_a = segment_positions[i] - global_position
			var pos_b = segment_positions[i - 1] - global_position
			var scale_a = active_breed.segment_scales[i] if i < active_breed.segment_scales.size() else 0.5
			var scale_b = active_breed.segment_scales[i - 1] if i - 1 < active_breed.segment_scales.size() else 0.5
			var r_avg = active_breed.head_radius * (scale_a + scale_b) * 0.5
			
			var t = float(i) / float(active_breed.num_segments)
			var seg_col = p_col.linear_interpolate(s_col, t)
			
			draw_line(pos_a, pos_b, outline_color, (r_avg + 2.5) * 2.0)
			draw_line(pos_a, pos_b, seg_col, r_avg * 2.0)

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

	# 1.5 Draw Wings & Tail if present
	if wing_type != "none":
		_draw_wings()
	if tail_type != "none":
		_draw_tail()

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
		shadow_poly.append(pt + Vector2(4, shadow_y_offset + 6))
	draw_colored_polygon(shadow_poly, Color(0, 0, 0, 0.12 * sh_opacity))

	# Draw head outline glow
	draw_polyline(local_poly, outline_color, 4.0, true)
	# Draw head color fill
	draw_colored_polygon(local_poly, p_col)
	
	# 2.1 Draw Head Feature / Horns if present
	if head_feature != "none":
		_draw_head_feature(shake_offset)

	# 2.2 Draw Procedural Fur / Spikes if enabled
	if has_fur:
		_draw_fur(local_poly)
		
	# 2.4 Draw Expressive Antennae if enabled
	if has_antennae:
		_draw_antennae(shake_offset)

	# Head highlight (top-left crescent for 3D depth)
	var hl_poly = PoolVector2Array()
	var hl_count = num_points / 3
	for i in range(hl_count):
		var angle = (i * 2.0 * PI / num_points) + PI * 1.2
		hl_poly.append(shake_offset + Vector2(cos(angle), sin(angle)) * base_radius * 0.6)
	hl_poly.append(shake_offset)
	if hl_poly.size() >= 3:
		draw_colored_polygon(hl_poly, Color(p_col.r + 0.2, p_col.g + 0.2, p_col.b + 0.2, 0.35))
	
	# Draw face elements on the head (offset by shake)
	draw_set_transform(shake_offset, 0.0, Vector2(transition_scale * s, transition_scale * s))
	_draw_eyes()
	_draw_mouth()
	if has_cheeks:
		_draw_cheeks()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(transition_scale * s, transition_scale * s))
	_draw_debug_stuffie_spot()

func _draw_debug_stuffie_spot():
	if not show_debug_stuffie_spot or not is_instance_valid(guarded_toy) or stuffed_animal_spot == Vector2.ZERO:
		return
		
	# Reset transform to 1:1 local pixel offset relative to pet global position
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	var local_spot = to_local(stuffed_animal_spot)
	var local_toy = to_local(guarded_toy.global_position)
	
	# Connecting lines
	draw_line(Vector2.ZERO, local_toy, Color(1.0, 0.0, 0.8, 0.45), 1.5)
	draw_line(local_toy, local_spot, Color(0.9, 0.9, 0.1, 0.75), 2.0)
	
	# Target Crosshairs
	var cross_col = Color("00e5ff") # Bright Cyan
	var ring_col = Color("ff007f") # Bright Magenta
	
	draw_arc(local_spot, 16.0, 0, 2 * PI, 24, ring_col, 2.0)
	draw_circle(local_spot, 4.0, cross_col)
	
	draw_line(local_spot + Vector2(-22, 0), local_spot + Vector2(-6, 0), cross_col, 2.0)
	draw_line(local_spot + Vector2(6, 0), local_spot + Vector2(22, 0), cross_col, 2.0)
	draw_line(local_spot + Vector2(0, -22), local_spot + Vector2(0, -6), cross_col, 2.0)
	draw_line(local_spot + Vector2(0, 6), local_spot + Vector2(0, 22), cross_col, 2.0)


func can_use_ability() -> bool:
	return life_stage != "hatchling"

func _draw_fur(head_poly: PoolVector2Array):
	var f_col = fur_color
	for i in range(head_poly.size()):
		var pt = head_poly[i]
		var next_pt = head_poly[(i + 1) % head_poly.size()]
		var mid = (pt + next_pt) / 2.0
		var out_dir = (mid).normalized()
		var tip = mid + out_dir * fur_length
		draw_line(mid, tip, f_col, 2.5)

func _draw_antennae(shake: Vector2):
	var time = OS.get_ticks_msec() * 0.005
	var wiggle_left = sin(time * 3.0) * 4.0
	var wiggle_right = cos(time * 3.0) * 4.0
	var base_l = shake + Vector2(-base_radius * 0.4, -base_radius * 0.8)
	var base_r = shake + Vector2(base_radius * 0.4, -base_radius * 0.8)
	var tip_l = base_l + Vector2(-6 + wiggle_left, -antenna_length)
	var tip_r = base_r + Vector2(6 + wiggle_right, -antenna_length)
	draw_line(base_l, tip_l, antenna_color, 2.5)
	draw_line(base_r, tip_r, antenna_color, 2.5)
	draw_circle(tip_l, 4.0, antenna_color.lightened(0.3))
	draw_circle(tip_r, 4.0, antenna_color.lightened(0.3))

func _draw_wings():
	if wing_type == "none":
		return
		
	var time = OS.get_ticks_msec() * 0.006
	var flap = sin(time * 4.0) * 12.0
	var w_col = wing_color
	
	match wing_type:
		"angel":
			var l_wing = PoolVector2Array([
				Vector2(-base_radius * 0.6, -4.0),
				Vector2(-base_radius * 1.3, -16.0 + flap),
				Vector2(-base_radius * 1.9, -10.0 + flap),
				Vector2(-base_radius * 1.5, 4.0 + flap * 0.5),
				Vector2(-base_radius * 1.0, 8.0)
			])
			var r_wing = PoolVector2Array([
				Vector2(base_radius * 0.6, -4.0),
				Vector2(base_radius * 1.3, -16.0 + flap),
				Vector2(base_radius * 1.9, -10.0 + flap),
				Vector2(base_radius * 1.5, 4.0 + flap * 0.5),
				Vector2(base_radius * 1.0, 8.0)
			])
			draw_colored_polygon(l_wing, w_col)
			draw_polyline(l_wing, outline_color, 2.0, true)
			draw_colored_polygon(r_wing, w_col)
			draw_polyline(r_wing, outline_color, 2.0, true)

		"bat":
			var l_wing = PoolVector2Array([
				Vector2(-base_radius * 0.6, -2.0),
				Vector2(-base_radius * 1.7, -18.0 + flap),
				Vector2(-base_radius * 1.5, -4.0 + flap),
				Vector2(-base_radius * 1.2, 8.0 + flap * 0.5),
				Vector2(-base_radius * 0.8, 4.0)
			])
			var r_wing = PoolVector2Array([
				Vector2(base_radius * 0.6, -2.0),
				Vector2(base_radius * 1.7, -18.0 + flap),
				Vector2(base_radius * 1.5, -4.0 + flap),
				Vector2(base_radius * 1.2, 8.0 + flap * 0.5),
				Vector2(base_radius * 0.8, 4.0)
			])
			draw_colored_polygon(l_wing, w_col)
			draw_polyline(l_wing, outline_color, 2.0, true)
			draw_colored_polygon(r_wing, w_col)
			draw_polyline(r_wing, outline_color, 2.0, true)

		"butterfly":
			var l_wing = PoolVector2Array([
				Vector2(-base_radius * 0.5, -6.0),
				Vector2(-base_radius * 1.6, -20.0 + flap),
				Vector2(-base_radius * 1.8, -4.0 + flap),
				Vector2(-base_radius * 1.4, 12.0 + flap * 0.7),
				Vector2(-base_radius * 0.7, 4.0)
			])
			var r_wing = PoolVector2Array([
				Vector2(base_radius * 0.5, -6.0),
				Vector2(base_radius * 1.6, -20.0 + flap),
				Vector2(base_radius * 1.8, -4.0 + flap),
				Vector2(base_radius * 1.4, 12.0 + flap * 0.7),
				Vector2(base_radius * 0.7, 4.0)
			])
			draw_colored_polygon(l_wing, w_col)
			draw_polyline(l_wing, outline_color, 2.0, true)
			draw_colored_polygon(r_wing, w_col)
			draw_polyline(r_wing, outline_color, 2.0, true)

		"fin", _:
			var l_wing = PoolVector2Array([
				Vector2(-base_radius * 0.7, 0),
				Vector2(-base_radius * 1.3, 10.0 + flap * 0.5),
				Vector2(-base_radius * 1.7, -10.0 + flap * 0.5)
			])
			var r_wing = PoolVector2Array([
				Vector2(base_radius * 0.7, 0),
				Vector2(base_radius * 1.3, 10.0 + flap * 0.5),
				Vector2(base_radius * 1.7, -10.0 + flap * 0.5)
			])
			draw_colored_polygon(l_wing, w_col)
			draw_polyline(l_wing, outline_color, 2.0, true)
			draw_colored_polygon(r_wing, w_col)
			draw_polyline(r_wing, outline_color, 2.0, true)


func _draw_tail():
	if segment_positions.size() < 1:
		return
	var tail_pos = segment_positions[segment_positions.size() - 1] - global_position
	var t_col = tail_color
	
	match tail_type:
		"fox_fluff":
			draw_circle(tail_pos + Vector2(-8, -4), 10.0, t_col)
			draw_circle(tail_pos + Vector2(-8, -4), 11.5, outline_color)
			draw_circle(tail_pos + Vector2(-8, -4), 10.0, t_col)
		"devil_fork":
			draw_line(tail_pos, tail_pos + Vector2(-15, -10), t_col, 3.0)
			draw_circle(tail_pos + Vector2(-15, -10), 4.0, t_col)
		"beaver_paddle":
			draw_rect(Rect2(tail_pos + Vector2(-16, -6), Vector2(14, 12)), t_col)
		"dragon_spikes":
			draw_line(tail_pos, tail_pos + Vector2(-12, -8), t_col, 4.0)

func _draw_head_feature(shake: Vector2):
	var h_col = horn_color
	match head_feature:
		"unicorn_horn":
			var pts = PoolVector2Array([
				shake + Vector2(-4, -base_radius * 0.8),
				shake + Vector2(4, -base_radius * 0.8),
				shake + Vector2(0, -base_radius * 1.7)
			])
			draw_colored_polygon(pts, h_col)
			draw_polyline(pts, outline_color, 2.0, true)
		"ram_horns":
			draw_arc(shake + Vector2(-base_radius * 0.6, -base_radius * 0.7), 8.0, PI*0.5, PI*1.8, 8, h_col, 3.5)
			draw_arc(shake + Vector2(base_radius * 0.6, -base_radius * 0.7), 8.0, -PI*0.8, PI*0.5, 8, h_col, 3.5)
		"dino_frill":
			draw_arc(shake + Vector2(0, -base_radius * 0.7), base_radius * 0.7, PI, 2*PI, 10, h_col, 4.0)

func _draw_cheeks():
	var c_col = cheek_color
	c_col.a = 0.75
	draw_circle(eye_left_pos + Vector2(-4, 8), 3.5, c_col)
	draw_circle(eye_right_pos + Vector2(4, 8), 3.5, c_col)

func _manifest_elemental_power():
	var main = get_parent()
	if not main:
		return
		
	var ElementalEffectScene = load("res://ElementalEffect.tscn")
	var elem_names = ["fire", "water", "lightning", "wind", "ice", "nature", "shadow", "light", "plasma", "earth"]
	var elem = elem_names[clamp(element_type_idx, 0, 9)]
	
	match elem:
		"fire":
			if ElementalEffectScene:
				var effect = ElementalEffectScene.instance()
				effect.effect_type = "scorch_mark"
				effect.global_position = global_position + Vector2(rand_range(-10, 10), base_radius)
				main.add_child(effect)
				if "active_items" in main:
					main.active_items.append(effect)
		"water":
			if ElementalEffectScene:
				var effect = ElementalEffectScene.instance()
				effect.effect_type = "water_puddle"
				effect.global_position = global_position + Vector2(rand_range(-15, 15), base_radius)
				main.add_child(effect)
				if "active_items" in main:
					main.active_items.append(effect)
		"ice":
			if ElementalEffectScene:
				var effect = ElementalEffectScene.instance()
				effect.effect_type = "ice_cube"
				effect.global_position = global_position + Vector2(rand_range(-20, 20), base_radius - 5.0)
				main.add_child(effect)
				if "active_items" in main:
					main.active_items.append(effect)
		"wind":
			if ElementalEffectScene:
				var effect = ElementalEffectScene.instance()
				effect.effect_type = "tornado_streak"
				effect.global_position = global_position
				effect.velocity = Vector2(rand_range(-250, 250), -50.0)
				main.add_child(effect)
				if "active_items" in main:
					main.active_items.append(effect)
		"lightning":
			# Lightning bolt strikes from ceiling to pet, supercharging toys and leaving scorch mark!
			if ElementalEffectScene:
				var effect = ElementalEffectScene.instance()
				effect.effect_type = "scorch_mark"
				effect.global_position = global_position + Vector2(rand_range(-10, 10), base_radius)
				main.add_child(effect)
				if "active_items" in main:
					main.active_items.append(effect)
			if "active_items" in main:
				for item in main.active_items:
					if is_instance_valid(item) and item.has_method("apply_element"):
						item.call("apply_element", "lightning")
		"nature":
			if ElementalEffectScene:
				var effect = ElementalEffectScene.instance()
				effect.effect_type = "weed_patch" if (randf() < 0.6) else "flower_patch"
				effect.global_position = global_position + Vector2(rand_range(-15, 15), base_radius)
				main.add_child(effect)
				if "active_items" in main:
					main.active_items.append(effect)
		"shadow":
			# Leaves void rift / time crack at origin, teleports, and leaves void rift at target!
			var origin_pos = global_position
			var bounds = _get_viewport_bounds()
			global_position.x = clamp(global_position.x + rand_range(-120, 120), bounds.position.x + base_radius, bounds.end.x - base_radius)
			if ElementalEffectScene:
				var rift1 = ElementalEffectScene.instance()
				rift1.effect_type = "void_rift"
				rift1.global_position = origin_pos
				main.add_child(rift1)
				var rift2 = ElementalEffectScene.instance()
				rift2.effect_type = "void_rift"
				rift2.global_position = global_position
				main.add_child(rift2)
				if "active_items" in main:
					main.active_items.append(rift1)
					main.active_items.append(rift2)
		"light":
			if stats:
				stats.agitation = 0.0
				stats.affection = clamp(stats.affection + 20.0, 0.0, 100.0)
		"plasma":
			# Psychic telekinetic pulse pulling nearby toys/food toward pet
			if "active_items" in main:
				for item in main.active_items:
					if is_instance_valid(item) and ("velocity" in item):
						var dir = (global_position - item.global_position).normalized()
						item.velocity += dir * 250.0
		"earth":
			if ElementalEffectScene:
				var effect = ElementalEffectScene.instance()
				effect.effect_type = "crystal_geode"
				effect.global_position = global_position + Vector2(rand_range(-15, 15), base_radius)
				main.add_child(effect)
				if "active_items" in main:
					main.active_items.append(effect)

func _draw_pupil_shape(center_pos: Vector2, rad: float, p_color: Color):
	match pupil_shape:
		"cat_eye":
			draw_line(center_pos - Vector2(0, rad * 1.1), center_pos + Vector2(0, rad * 1.1), p_color, 2.5)
		"lizard_eye":
			draw_line(center_pos - Vector2(rad * 1.1, 0), center_pos + Vector2(rad * 1.1, 0), p_color, 2.5)
		"spider_eye":
			draw_circle(center_pos, rad * 0.5, p_color)
			draw_circle(center_pos + Vector2(-3, -2), rad * 0.3, p_color)
			draw_circle(center_pos + Vector2(3, -2), rad * 0.3, p_color)
		_: # "round"
			draw_circle(center_pos, rad * 0.55, p_color)

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
			_draw_pupil_shape(eye_center + pupil_offset, big_rad, pupil_color)
		elif active_breed.eye_type == "slanted":
			draw_circle(eye_left_pos, radius * 0.9, eye_color)
			draw_circle(eye_right_pos, radius * 0.9, eye_color)
			var pupil_offset = look_dir * 2.0
			_draw_pupil_shape(eye_left_pos + pupil_offset, radius * 0.9, pupil_color)
			_draw_pupil_shape(eye_right_pos + pupil_offset, radius * 0.9, pupil_color)
		else:
			draw_circle(eye_left_pos, radius, eye_color)
			draw_circle(eye_right_pos, radius, eye_color)
			var pupil_offset = look_dir * 3.0
			_draw_pupil_shape(eye_left_pos + pupil_offset, radius, pupil_color)
			_draw_pupil_shape(eye_right_pos + pupil_offset, radius, pupil_color)
			
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

func emerge_from_dispenser(nozzle_pos: Vector2):
	transition_nozzle_pos = nozzle_pos
	global_position = nozzle_pos
	for i in range(point_positions.size()):
		point_positions[i] = nozzle_pos + (target_relative_offsets[i] if i < target_relative_offsets.size() else Vector2.ZERO) * 0.2
	for i in range(segment_positions.size()):
		segment_positions[i] = nozzle_pos
	for i in range(foot_positions.size()):
		foot_positions[i] = nozzle_pos
		if i < foot_step_start.size(): foot_step_start[i] = nozzle_pos
		if i < foot_step_target.size(): foot_step_target[i] = nozzle_pos
	center_vel = Vector2(rand_range(-60, 60), 280.0)
	transition_scale = 0.2
	_change_state(State.EMERGING_FROM_DISPENSER)

func change_breed(new_breed):
	breed_data = new_breed
	active_breed = new_breed
	base_radius = active_breed.head_radius

func setup_custom_data(pet_dict: Dictionary):
	pet_id = pet_dict.get("pet_id", pet_id)
	pet_name = pet_dict.get("pet_name", pet_name)
	genetic_seed = pet_dict.get("genetic_seed", 123456)
	element_type_idx = pet_dict.get("element_type_idx", 0)
	life_stage = pet_dict.get("life_stage", "adult")
	time_outside_dispenser_seconds = pet_dict.get("time_outside_dispenser_seconds", 0.0)
	
	voice_version = pet_dict.get("voice_version", randi() % 4)
	voice_pitch = pet_dict.get("voice_pitch", randi() % 3)
	if stats:
		stats.voice_version = voice_version
		stats.voice_pitch = voice_pitch

	has_fur = pet_dict.get("has_fur", false)
	fur_length = pet_dict.get("fur_length", 7.0)
	if pet_dict.has("fur_color"):
		fur_color = Color(pet_dict.get("fur_color"))
		
	has_antennae = pet_dict.get("has_antennae", false)
	antenna_length = pet_dict.get("antenna_length", 18.0)
	if pet_dict.has("antenna_color"):
		antenna_color = Color(pet_dict.get("antenna_color"))
		
	foot_shape = pet_dict.get("foot_shape", "circle")
	wing_type = pet_dict.get("wing_type", "none")
	if pet_dict.has("wing_color"):
		wing_color = Color(pet_dict.get("wing_color"))
		
	tail_type = pet_dict.get("tail_type", "none")
	if pet_dict.has("tail_color"):
		tail_color = Color(pet_dict.get("tail_color"))
		
	head_feature = pet_dict.get("head_feature", "none")
	if pet_dict.has("horn_color"):
		horn_color = Color(pet_dict.get("horn_color"))
		
	pattern_type = pet_dict.get("pattern_type", "solid")
	if pet_dict.has("pattern_color"):
		pattern_color = Color(pet_dict.get("pattern_color"))
		
	pupil_shape = pet_dict.get("pupil_shape", "round")
	has_cheeks = pet_dict.get("has_cheeks", true)
	if pet_dict.has("cheek_color"):
		cheek_color = Color(pet_dict.get("cheek_color"))
		
	if pet_dict.has("glow_color"):
		outline_color = Color(pet_dict.get("glow_color"))
		
	var bd = BreedData.new()
	bd.breed_name = pet_name
	bd.head_radius = pet_dict.get("head_radius", 22.0)
	bd.num_segments = pet_dict.get("num_segments", 4)
	bd.segment_spacing = pet_dict.get("segment_spacing", 18.0)
	bd.has_limbs = pet_dict.get("has_limbs", true)
	bd.num_limbs = pet_dict.get("num_limbs", 2)
	bd.eye_type = pet_dict.get("eye_type", "normal")
	
	if pet_dict.has("primary_color"):
		bd.primary_color = Color(pet_dict.get("primary_color"))
	else:
		bd.primary_color = Color("ab47bc")
	bd.secondary_color = bd.primary_color.darkened(0.2)
	
	var scales = []
	for i in range(bd.num_segments):
		scales.append(max(0.4, 1.0 - i * 0.15))
	bd.segment_scales = scales
	
	change_breed(bd)
	
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
		if stats:
			stats.hunger = pending_restore_stats.get("hunger", 100.0)
			stats.boredom = pending_restore_stats.get("boredom", 100.0)
			stats.energy = pending_restore_stats.get("energy", 100.0)
			stats.affection = pending_restore_stats.get("affection", 100.0)
			stats.curiosity = pending_restore_stats.get("curiosity", 100.0)
			stats.agitation = pending_restore_stats.get("agitation", 0.0)
			stats.wellness = pending_restore_stats.get("wellness", 100.0)
			stats.toilet = pending_restore_stats.get("toilet", 0.0)
		pending_restore_stats = null
		
	update()

func _get_viewport_bounds() -> Rect2:
	if get_viewport():
		return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return Rect2(Vector2.ZERO, OS.window_size)


func _draw_mouth():
	var m_color = Color("000000")
	var base_angle = look_dir.angle()
	var perp = look_dir.tangent()
	
	if current_state == State.SLEEPING:
		# Sleeping: Draw a small sleeping arc
		draw_arc(mouth_pos, 4.0, base_angle + PI * 0.1, base_angle + PI * 0.9, 8, m_color, 2.0)
	elif current_state == State.EATING:
		# Eating: Large open circle animation
		var eat_rad = lerp(4.0, 12.0, sin(OS.get_ticks_msec() * 0.03) * 0.5 + 0.5)
		draw_circle(mouth_pos, eat_rad, m_color)
	elif stats.agitation > 50.0:
		# Angry line aligned perpendicular to looking direction
		draw_line(mouth_pos - perp * 10.0, mouth_pos + perp * 10.0, m_color, 3.0)
	elif stats.hunger < 30.0:
		# Sad droopy mouth arc facing away from looking direction
		draw_arc(mouth_pos, 8.0, base_angle - PI * 0.8, base_angle - PI * 0.2, 12, m_color, 3.0)
	elif current_state == State.CHASE_CURSOR:
		# Happy smile arc facing looking direction
		draw_arc(mouth_pos, 8.0, base_angle + PI * 0.2, base_angle + PI * 0.8, 12, m_color, 3.0)
	else:
		# Normal mouth line aligned perpendicular to looking direction
		draw_line(mouth_pos - perp * 6.0, mouth_pos + perp * 6.0, m_color, 2.0)


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
		var is_colliding = (dist < min_dist and dist > 0.001)

		if is_colliding:
			var normal = (item.global_position - global_position).normalized()

			# --- Ball vs Pet collision ---
			if item.get("is_toy") == true:
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

func _find_closest_other_pet():
	var main = get_parent()
	if not main or not ("active_pets" in main):
		return null
	var closest = null
	var min_d = 99999.0
	for p in main.active_pets:
		if is_instance_valid(p) and p != self:
			var d = global_position.distance_to(p.global_position)
			if d < min_d:
				min_d = d
				closest = p
	return closest

func _on_digging_complete():
	var main = get_parent()
	if not main:
		return
		
	# 1. Spawn DigHole
	var DigHoleScene = load("res://DigHole.tscn")
	if DigHoleScene:
		var hole = DigHoleScene.instance()
		hole.global_position = global_position + Vector2(0, 10.0)
		main.add_child(hole)
		
	# 2. Spawn DigItem 25% of the time (75% of the time just leaves a dirt hole)
	if randf() < 0.25:
		var possible_materials = [
			"ancient_fossil", "starlight_crystal", "bio_slime", 
			"glowing_amber", "meteor_shard", "radiant_spore", "elastic_rubber", "gene_fragment"
		]
		var mat = possible_materials[randi() % possible_materials.size()]
		
		var DigItemScene = load("res://DigItem.tscn")
		if DigItemScene:
			var dig_item = DigItemScene.instance()
			dig_item.global_position = global_position + Vector2(rand_range(-25, 25), rand_range(-5, 5))
			dig_item.setup_item(mat)
			main.add_child(dig_item)
			if "active_items" in main:
				main.active_items.append(dig_item)
				
			# 3. Check pet learning for auto-collecting into inventory
			if stats and stats.knows_inventory >= 1.0:
				dig_item.collect_item()
				_show_learning_emote("[BAG]")
			elif stats and randf() < stats.knows_inventory:
				stats.knows_inventory = clamp(stats.knows_inventory + 0.25, 0.0, 1.0)
				dig_item.collect_item()
				_show_learning_emote("[BAG]")

func _scan_for_food_or_treat() -> bool:
	var item = _find_closest_food_or_treat()
	if is_instance_valid(item) and current_state != State.SLEEPING and current_state != State.SICK:
		target_item = item
		_change_state(State.CHASE_ITEM)
		return true
	return false

func _find_closest_food_or_treat() -> Node2D:
	var main = get_parent()
	if not main or not ("active_items" in main):
		return null
	if stats and stats.hunger >= 95.0:
		return null # >= 95% full -> ignores treats and food completely!

	var is_infant = (life_stage == "infant" or life_stage == "hatchling")
	var closest = null
	var min_d = 99999.0
	var allow_regular_food = (stats == null or stats.hunger < 50.0 or (bored_eater and stats.boredom < 50.0))

	for item in main.active_items:
		if is_instance_valid(item):
			var is_bottle = (item.get("is_bottle") == true)
			var is_treat = (item.get("is_treat") == true)
			var is_food = (item.get("is_food") == true or item.filename.find("Food") != -1)

			var matches = false
			if is_infant:
				# Infants ONLY want baby feeding bottles!
				if is_bottle and stats.hunger < 99.0:
					matches = true
			else:
				# Non-infants (adults, children) NEVER want baby bottles!
				if is_bottle:
					matches = false
				elif is_treat:
					matches = true # Below 95% hunger -> pursues treats!
				elif is_food and allow_regular_food:
					matches = true # Below 50% hunger or bored eater -> pursues regular food!

			if matches:
				var d = global_position.distance_to(item.global_position)
				if d < min_d:
					min_d = d
					closest = item
	return closest


func _show_learning_emote(icon_text: String):
	var main = get_parent()
	if not main:
		return
	var lbl = Label.new()
	lbl.text = icon_text
	lbl.rect_global_position = global_position + Vector2(-15, -35)
	main.add_child(lbl)
	
	var t = main.create_tween()
	if t:
		t.tween_property(lbl, "rect_global_position:y", lbl.rect_global_position.y - 30.0, 1.2)
		t.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
		t.tween_callback(lbl, "queue_free")


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

func on_glass_tapped(tap_pos: Vector2):
	if current_state == State.SLEEPING or current_state == State.SICK or current_state == State.RETURNING_TO_DISPENSER:
		return
	look_dir = (tap_pos - global_position).normalized()
	head_shake_timer = 0.35
	head_shake_intensity = 5.0
	if stats:
		stats.affection = clamp(stats.affection + 4.0, 0.0, 100.0)
	_show_learning_emote("[LOOK]")

func walk_to_tap_location(tap_pos: Vector2, try_dig: bool = true):
	if current_state == State.SLEEPING or current_state == State.SICK or current_state == State.RETURNING_TO_DISPENSER or current_state == State.EMERGING_FROM_DISPENSER:
		return
	target_wander_pos = tap_pos
	if try_dig:
		will_dig_on_arrival = (randf() < 0.50)
	if current_state != State.WANDER:
		_change_state(State.WANDER)

func eat_food(food_item) -> bool:
	if not is_instance_valid(food_item):
		return false
		
	var is_infant = (life_stage == "infant" or life_stage == "hatchling")
	var is_bottle = (food_item.get("is_bottle") == true)
	var is_treat = (food_item.get("is_treat") == true)
	
	if is_bottle:
		if is_infant:
			return feed_bottle(food_item)
		else:
			head_shake_timer = 0.4
			head_shake_intensity = 5.0
			_show_learning_emote("[FOR INFANTS]")
			return false
		
	if is_infant:
		# Infant refuses regular food or treats!
		head_shake_timer = 0.4
		head_shake_intensity = 5.0
		_show_learning_emote("[NO NO]")
		return false
		
	if is_treat:
		if stats and stats.hunger >= 95.0:
			_show_learning_emote("[FULL]")
			return false
		target_item = food_item
		weight = clamp(weight + 0.04, 0.7, 1.3)
		_check_food_competition_and_eat()
		return true
		
	# Regular food: Check hunger or bored_eater
	var is_hungry_or_bored = (stats == null or stats.hunger < 50.0 or (bored_eater and stats.boredom < 50.0))
	if not is_hungry_or_bored:
		head_shake_timer = 0.3
		head_shake_intensity = 4.0
		_show_learning_emote("[NOT HUNGRY]")
		return false
		
	target_item = food_item
	weight = clamp(weight + 0.04, 0.7, 1.3)
	_check_food_competition_and_eat()
	return true


func feed_bottle(bottle_item) -> bool:
	var is_infant_stage = (life_stage == "infant" or life_stage == "hatchling")
	if is_infant_stage or current_state == State.SICK or stats.hunger < 99.0:
		stats.hunger = clamp(stats.hunger + 40.0, 0.0, 100.0)
		stats.wellness = clamp(stats.wellness + 35.0, 0.0, 100.0)
		stats.affection = clamp(stats.affection + 15.0, 0.0, 100.0)
		weight = clamp(weight + 0.05, 0.7, 1.3)
		
		head_shake_timer = 0.5
		head_shake_intensity = 3.0
		
		# Animate bottle item leaning near mouth
		if is_instance_valid(bottle_item):
			bottle_item.global_position = mouth_pos + look_dir * 12.0
			bottle_item.rotation = -PI * 0.25
			
		if current_state == State.SICK:
			sick_auto_return_timer = 0.0
			if stats.wellness >= 70.0:
				_change_state(State.IDLE)
		else:
			_change_state(State.EATING)
			
		_show_learning_emote("[BOTTLE]")
		return true
	return false



func _check_food_competition_and_eat():

	var other_pet = _find_closest_other_pet()
	if is_instance_valid(other_pet):
		var dist_to_other = global_position.distance_to(other_pet.global_position)
		if dist_to_other < base_radius * 4.5:
			# GROWLING & FOOD GUARDING!
			var away_dir = (global_position - other_pet.global_position).normalized()
			look_dir = away_dir
			head_shake_timer = 0.5
			head_shake_intensity = 6.0
			
			if stats:
				stats.agitation = clamp(stats.agitation + 20.0, 0.0, 100.0)
			
			_show_learning_emote("[GROWL!]")
			
			# If rival pet is also targeting or chasing this food, rival pet backs off!
			if is_instance_valid(target_item) and other_pet.target_item == target_item:
				other_pet.target_item = null
				other_pet._show_learning_emote("[SCARED]")
				other_pet.center_vel = -away_dir * 120.0
				other_pet._change_state(State.WANDER)
	_change_state(State.EATING)


func _spawn_poop():
	var PoopScene = preload("res://Poop.tscn")
	var poop = PoopScene.instance()
	poop.global_position = global_position + Vector2.DOWN * 8.0
	get_parent().add_child(poop)
	
	var main = get_parent()
	if main and "active_items" in main:
		main.active_items.append(poop)



