extends Node2D

export(float) var radius = 18.0
export(float) var gravity = 350.0
export(float) var bounce = 0.75

# Type tag for reliable detection
var is_food = false
var is_toy = true

# Toy Sub-type: "ball", "chew", "stuffed_animal", "boombox"
export(String) var toy_type: String = "ball"

# Chew Toy degradation
var durability: float = 100.0
var max_durability: float = 100.0

# Stuffed Animal guarding
var owner_pet: Node = null
var is_being_guarded: bool = false

# Boombox properties
var current_track: int = 0 # 0 = OFF, 1..5 = Tracks
var hit_count: int = 0
var max_hits: int = 6
var is_broken: bool = false
var beat_anim_timer: float = 0.0

var track_names = [
	"OFF",
	"1: Orb Bop",
	"2: Chill Lounge",
	"3: Pal Dance",
	"4: Spooky Groove",
	"5: Star Chiptune"
]

var velocity = Vector2.ZERO
var is_dragging = false
var drag_positions = []
var prev_mouse_pos = Vector2.ZERO

# Elemental status ("normal", "fire", "ice", "lightning", "wind")
var elemental_state: String = "normal"
var elemental_timer: float = 0.0

# 3D Depth coordinates
var x_pos: float = 0.0
var z_depth: float = 0.0
var y_height: float = 0.0
var z_vel: float = 0.0

func get_depth_scale(z: float) -> float:
	return lerp(1.0, 0.85, z)

var ContextMenuScene = preload("res://ContextMenu.tscn")

func _ready():
	velocity = Vector2(rand_range(-150.0, 150.0), -100.0)
	if toy_type == "boombox":
		radius = 24.0
		bounce = 0.3
	elif toy_type == "chew":
		radius = 16.0
		bounce = 0.4
	elif toy_type == "stuffed_animal":
		radius = 18.0
		bounce = 0.35

func apply_element(elem_name: String):
	elemental_state = elem_name
	elemental_timer = 8.0 # 8 seconds of elemental effect
	if elem_name == "fire":
		bounce = 0.95
	elif elem_name == "ice":
		bounce = 0.4
	elif elem_name == "lightning":
		velocity *= 1.8
		velocity = velocity.clamped(1000.0)
	elif elem_name == "wind":
		velocity.y -= 250.0

func _physics_process(delta):
	if elemental_timer > 0.0:
		elemental_timer -= delta
		if elemental_timer <= 0.0:
			elemental_state = "normal"
			bounce = 0.75
			
	if toy_type == "boombox" and current_track > 0 and not is_broken:
		beat_anim_timer += delta * 6.0
		
	scale = Vector2.ONE
	if is_dragging:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos
		velocity = Vector2.ZERO
		
		drag_positions.append(mouse_pos)
		if drag_positions.size() > 5:
			drag_positions.remove(0)
			
		prev_mouse_pos = mouse_pos
	else:
		velocity.y += gravity * delta
		global_position += velocity * delta
		
		var play_bounce_sfx = false
		
		# Floor bounce
		var vp_size = OS.window_size
		if get_viewport():
			vp_size = get_viewport().get_visible_rect().size
		var floor_y = vp_size.y - radius
		if global_position.y >= floor_y:
			if abs(velocity.y) > 50.0: play_bounce_sfx = true
			global_position.y = floor_y
			velocity.y = -velocity.y * bounce
			if elemental_state == "ice":
				velocity.x *= 0.998
			else:
				velocity.x *= 0.95
			
		# Ceiling bounce
		var ceiling_y = radius
		if global_position.y <= ceiling_y:
			if abs(velocity.y) > 50.0: play_bounce_sfx = true
			global_position.y = ceiling_y
			velocity.y = -velocity.y * bounce

		# Wall bounce
		if global_position.x <= radius:
			if abs(velocity.x) > 50.0: play_bounce_sfx = true
			global_position.x = radius
			velocity.x = -velocity.x * bounce
		elif global_position.x >= vp_size.x - radius:
			if abs(velocity.x) > 50.0: play_bounce_sfx = true
			global_position.x = vp_size.x - radius
			velocity.x = -velocity.x * bounce
			
		# Desktop Window Bounces
		var main = get_parent()
		if main and "desktop_window_manager" in main and is_instance_valid(main.desktop_window_manager):
			var rects = main.desktop_window_manager.get_window_rects()
			for rect in rects:
				var expanded = rect.grow(radius)
				if expanded.has_point(global_position):
					var dist_left = abs(global_position.x - rect.position.x)
					var dist_right = abs(global_position.x - rect.end.x)
					var dist_top = abs(global_position.y - rect.position.y)
					var dist_bottom = abs(global_position.y - rect.end.y)
					
					var min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom))
					if min_dist == dist_top and velocity.y > 0:
						if abs(velocity.y) > 50.0: play_bounce_sfx = true
						global_position.y = rect.position.y - radius
						velocity.y = -velocity.y * bounce
						velocity.x *= 0.95
					elif min_dist == dist_bottom and velocity.y < 0:
						if abs(velocity.y) > 50.0: play_bounce_sfx = true
						global_position.y = rect.end.y + radius
						velocity.y = -velocity.y * bounce
					elif min_dist == dist_left and velocity.x > 0:
						if abs(velocity.x) > 50.0: play_bounce_sfx = true
						global_position.x = rect.position.x - radius
						velocity.x = -velocity.x * bounce
					elif min_dist == dist_right and velocity.x < 0:
						if abs(velocity.x) > 50.0: play_bounce_sfx = true
						global_position.x = rect.end.x + radius
						velocity.x = -velocity.x * bounce

		if play_bounce_sfx and AudioManager:
			if toy_type == "ball":
				AudioManager.play_ball_bounce()
			elif toy_type == "boombox":
				AudioManager.play_boombox_hit()
				
	update()

func _input(event):
	var touch_pos = Vector2.ZERO
	var is_press = false
	var is_release = false
	var is_right_click = false

	if event is InputEventMouseButton:
		touch_pos = event.global_position
		is_press = event.pressed
		is_release = not event.pressed
		is_right_click = (event.button_index == BUTTON_RIGHT)
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
		var grab_radius = radius * 1.8
		var dist = touch_pos.distance_to(global_position)
		if dist <= grab_radius:
			if is_right_click:
				var menu = ContextMenuScene.instance()
				get_parent().add_child(menu)
				menu.call("setup", self)
				get_tree().set_input_as_handled()
			else:
				if toy_type == "boombox":
					smack_boombox()
				is_dragging = true
				drag_positions.clear()
				drag_positions.append(touch_pos)
				prev_mouse_pos = touch_pos
				get_tree().set_input_as_handled()
	elif is_release and is_dragging:
		is_dragging = false
		var main = get_parent()
		if main and main.has_method("is_over_trash_can") and main.call("is_over_trash_can", global_position):
			if toy_type == "boombox" and AudioManager:
				AudioManager.stop_music()
			if main.has_method("remove_item"):
				main.call("remove_item", self)
			get_tree().set_input_as_handled()
			return
		if drag_positions.size() > 1:
			var start_pos = drag_positions[0]
			var end_pos = drag_positions[drag_positions.size() - 1]
			velocity = (end_pos - start_pos) / (0.016 * drag_positions.size())
			velocity = velocity.clamped(800.0)
			
			for pet in get_parent().get_children():
				if is_instance_valid(pet) and pet.has_method("on_toy_thrown"):
					pet.call("on_toy_thrown", self)
		get_tree().set_input_as_handled()

# Chew Toy mechanics
func chew_toy(amount: float):
	if toy_type != "chew":
		return
	durability -= amount
	if AudioManager and randf() < 0.25:
		AudioManager.play_chew()
	if durability <= 0.0:
		break_toy()

func break_toy():
	if AudioManager:
		AudioManager.play_ball_pop()
	var main = get_parent()
	if main and main.has_method("remove_item"):
		main.call("remove_item", self)
	else:
		queue_free()

# Ball Popping mechanic
func check_ball_pop_chance():
	if toy_type != "ball":
		return
	# 0.6% chance to pop when played with by pet
	if randf() < 0.006:
		if AudioManager:
			AudioManager.play_ball_pop()
		var main = get_parent()
		if main and main.has_method("remove_item"):
			main.call("remove_item", self)
		else:
			queue_free()

# Boombox Smack mechanics
func smack_boombox():
	if toy_type != "boombox":
		return
	if is_broken:
		if AudioManager: AudioManager.play_boombox_hit()
		return
		
	hit_count += 1
	if AudioManager:
		AudioManager.play_boombox_hit()
		
	if hit_count >= max_hits:
		is_broken = true
		current_track = 0
		if AudioManager:
			AudioManager.stop_music()
			AudioManager.play_boombox_break()
	else:
		current_track = (current_track + 1) % 6
		if AudioManager:
			AudioManager.play_boombox_track(current_track)

func apply_impulse(impulse: Vector2):
	velocity += impulse
	velocity = velocity.clamped(600.0)

func get_click_polygon() -> PoolVector2Array:
	var poly = PoolVector2Array()
	var padded_r = radius * scale.x
	for i in range(8):
		var angle = i * 2.0 * PI / 8.0
		poly.append(global_position + Vector2(cos(angle), sin(angle)) * padded_r)
	return poly

func _draw():
	if toy_type == "ball":
		_draw_ball()
	elif toy_type == "chew":
		_draw_chew_toy()
	elif toy_type == "stuffed_animal":
		_draw_stuffed_animal()
	elif toy_type == "boombox":
		_draw_boombox()

func _draw_ball():
	var colors = [Color("e53935"), Color("3949ab"), Color("fdd835"), Color("43a047")]
	if elemental_state == "fire":
		colors = [Color("ff4500"), Color("ff8c00"), Color("ffd700"), Color("ff1493")]
	elif elemental_state == "ice":
		colors = [Color("e0ffff"), Color("00ffff"), Color("1e90ff"), Color("b0c4de")]
	elif elemental_state == "lightning":
		colors = [Color("ffff00"), Color("ffffff"), Color("ffd700"), Color("ff8c00")]

	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0))
	draw_circle(Vector2.ZERO, radius - 2.0, Color(1, 1, 1))
	
	var num_slices = 6
	for i in range(num_slices):
		var angle_start = i * 2.0 * PI / num_slices
		var angle_end = (i + 1) * 2.0 * PI / num_slices
		var color = colors[i % colors.size()]
		var points = PoolVector2Array([
			Vector2.ZERO,
			Vector2(cos(angle_end), sin(angle_end)) * (radius - 2.0),
			Vector2(cos(angle_start), sin(angle_start)) * (radius - 2.0)
		])
		draw_colored_polygon(points, color)
		
	draw_circle(Vector2.ZERO, radius * 0.25, Color(1, 1, 1))

func _draw_chew_toy():
	# Bone / Chew toy shape with degradation display
	var chew_ratio = durability / max_durability
	var c_col = Color("ff7043").linear_interpolate(Color("8d6e63"), 1.0 - chew_ratio)
	
	# Draw bone knobs
	var r = radius * (0.8 + 0.2 * chew_ratio)
	draw_circle(Vector2(-r * 0.6, -r * 0.4), r * 0.45, c_col)
	draw_circle(Vector2(-r * 0.6, r * 0.4), r * 0.45, c_col)
	draw_circle(Vector2(r * 0.6, -r * 0.4), r * 0.45, c_col)
	draw_circle(Vector2(r * 0.6, r * 0.4), r * 0.45, c_col)
	
	# Central bone bar
	draw_rect(Rect2(-r * 0.6, -r * 0.35, r * 1.2, r * 0.7), c_col)
	draw_rect(Rect2(-r * 0.6, -r * 0.35, r * 1.2, r * 0.7), Color.black, false, 1.5)

func _draw_stuffed_animal():
	# Teddy bear stuffed animal shape
	var body_col = Color("ab47bc") # Purple plushie
	if is_being_guarded:
		body_col = Color("ec407a") # Warm guarded tone
		
	# Ears
	draw_circle(Vector2(-12, -14), 7, body_col)
	draw_circle(Vector2(12, -14), 7, body_col)
	draw_circle(Vector2(-12, -14), 4, Color("f48fb1"))
	draw_circle(Vector2(12, -14), 4, Color("f48fb1"))
	
	# Head & Body
	draw_circle(Vector2(0, 4), 14, body_col) # Body
	draw_circle(Vector2(0, -6), 12, body_col) # Head
	draw_circle(Vector2(0, -4), 5, Color("f48fb1")) # Snout
	
	# Eyes
	draw_circle(Vector2(-4, -8), 2, Color.black)
	draw_circle(Vector2(4, -8), 2, Color.black)
	draw_circle(Vector2(0, -5), 1.5, Color.black) # Nose

func _draw_boombox():
	# Retro Boombox
	var width = 42.0
	var height = 26.0
	var rect = Rect2(-width * 0.5, -height * 0.5, width, height)
	
	var main_col = Color("37474f") if not is_broken else Color("212121")
	draw_rect(rect, main_col)
	draw_rect(rect, Color("90a4ae") if not is_broken else Color("424242"), false, 2.0)
	
	# Handle
	draw_rect(Rect2(-width * 0.3, -height * 0.5 - 6.0, width * 0.6, 6.0), main_col, false, 2.0)
	
	# Twin Speakers
	var pulse = 0.0
	if current_track > 0 and not is_broken:
		pulse = sin(beat_anim_timer) * 2.0
		
	var spk_r = 7.0 + pulse
	draw_circle(Vector2(-width * 0.28, 0), spk_r, Color("263238"))
	draw_circle(Vector2(-width * 0.28, 0), spk_r * 0.5, Color("ffb74d") if current_track > 0 else Color("546e7a"))
	
	draw_circle(Vector2(width * 0.28, 0), spk_r, Color("263238"))
	draw_circle(Vector2(width * 0.28, 0), spk_r * 0.5, Color("ffb74d") if current_track > 0 else Color("546e7a"))
	
	# Cassette Door
	draw_rect(Rect2(-6, -6, 12, 12), Color("102027"))
	draw_rect(Rect2(-6, -6, 12, 12), Color("78909c"), false, 1.0)
	
	if is_broken:
		# Broken cracks
		draw_line(Vector2(-10, -8), Vector2(4, 6), Color("e53935"), 2.0)
		draw_line(Vector2(2, -10), Vector2(-6, 8), Color("e53935"), 1.5)

