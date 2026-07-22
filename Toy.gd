extends Node2D

export(float) var radius = 18.0
export(float) var gravity = 350.0
export(float) var bounce = 0.75

# Type tag for reliable detection
var is_food = false
var is_toy = true

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
		
		# Floor bounce
		var vp_size = OS.window_size
		if get_viewport():
			vp_size = get_viewport().get_visible_rect().size
		var floor_y = vp_size.y - radius
		if global_position.y >= floor_y:
			global_position.y = floor_y
			velocity.y = -velocity.y * bounce
			if elemental_state == "ice":
				velocity.x *= 0.998 # Almost zero friction on ice!
			else:
				velocity.x *= 0.95
			
		# Ceiling bounce
		var ceiling_y = radius
		if global_position.y <= ceiling_y:
			global_position.y = ceiling_y
			velocity.y = -velocity.y * bounce

		# Wall bounce
		if global_position.x <= radius:
			global_position.x = radius
			velocity.x = -velocity.x * bounce
		elif global_position.x >= vp_size.x - radius:
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
						global_position.y = rect.position.y - radius
						velocity.y = -velocity.y * bounce
						velocity.x *= 0.95
					elif min_dist == dist_bottom and velocity.y < 0:
						global_position.y = rect.end.y + radius
						velocity.y = -velocity.y * bounce
					elif min_dist == dist_left and velocity.x > 0:
						global_position.x = rect.position.x - radius
						velocity.x = -velocity.x * bounce
					elif min_dist == dist_right and velocity.x < 0:
						global_position.x = rect.end.x + radius
						velocity.x = -velocity.x * bounce
			
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
				is_dragging = true
				drag_positions.clear()
				drag_positions.append(touch_pos)
				prev_mouse_pos = touch_pos
				get_tree().set_input_as_handled()
	elif is_release and is_dragging:
		is_dragging = false
		var main = get_parent()
		if main and main.has_method("is_over_trash_can") and main.call("is_over_trash_can", global_position):
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
