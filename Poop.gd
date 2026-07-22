extends Node2D

export(float) var radius = 12.0
export(float) var gravity = 400.0
export(float) var bounce = 0.2

# Type tag for reliable detection
var is_food = false
var is_toy = false

var velocity = Vector2.ZERO
var is_dragging = false
var drag_positions = []
var prev_mouse_pos = Vector2.ZERO

# 3D coordinates
var x_pos: float = 0.0
var z_depth: float = 0.0
var y_height: float = 0.0
var z_vel: float = 0.0

func get_depth_scale(z: float) -> float:
	return lerp(1.0, 0.85, z)

var ContextMenuScene = preload("res://ContextMenu.tscn")

func _ready():
	# Small initial bounce when dropped
	velocity = Vector2(rand_range(-50.0, 50.0), -120.0)

func _physics_process(delta):
	scale = Vector2.ONE
	if is_dragging:
		var mouse_pos = prev_mouse_pos if prev_mouse_pos != Vector2.ZERO else get_global_mouse_position()
		global_position = mouse_pos
		velocity = Vector2.ZERO
		
		drag_positions.append(mouse_pos)
		if drag_positions.size() > 5:
			drag_positions.remove(0)
	else:
		velocity.y += gravity * delta
		global_position += velocity * delta
		
		# Floor bounce
		var vp_size = get_viewport_rect().size if get_viewport() else OS.window_size
		var floor_y = vp_size.y - radius
		if global_position.y >= floor_y:
			global_position.y = floor_y
			velocity.y = -velocity.y * bounce
			velocity.x *= 0.8 # heavy friction
			
			if abs(velocity.y) < 15.0:
				velocity.y = 0
				
		# Wall bounds
		global_position.x = clamp(global_position.x, radius, vp_size.x - radius)
		
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
		var hit = touch_pos.distance_to(global_position) <= radius * 1.8 * scale.x
		if hit:
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
		# Check if dropped on trash can
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
			velocity = velocity.clamped(600.0)
		get_tree().set_input_as_handled()

func get_click_polygon() -> PoolVector2Array:
	# Padded polygon for passthrough — poop has a tall visual shape
	var poly = PoolVector2Array()
	var pad_w = (radius + 8.0) * scale.x
	var pad_h = (radius * 1.8 + 8.0) * scale.x
	for i in range(10):
		var angle = i * 2.0 * PI / 10.0
		poly.append(global_position + Vector2(cos(angle) * pad_w, sin(angle) * pad_h - radius * 0.4 * scale.x))
	return poly

func _draw():

	# Draw cartoon poop pile (layered brown circles/pill shapes)
	var c_dark = Color("5d4037") # dark brown border/outline
	var c_light = Color("8d6e63") # light brown body
	
	# Bottom layer
	draw_circle(Vector2(0, 4), radius * 1.0, c_dark)
	draw_circle(Vector2(0, 4), radius * 0.9, c_light)
	
	# Middle layer
	draw_circle(Vector2(0, -2), radius * 0.8, c_dark)
	draw_circle(Vector2(0, -2), radius * 0.7, c_light)
	
	# Top tip
	draw_circle(Vector2(0, -8), radius * 0.5, c_dark)
	draw_circle(Vector2(0, -8), radius * 0.4, c_light)
	
	# Cute little eyes to make it cartoonish!
	draw_circle(Vector2(-3, -2), 1.5, Color(0, 0, 0))
	draw_circle(Vector2(3, -2), 1.5, Color(0, 0, 0))
