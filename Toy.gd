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

var ContextMenuScene = preload("res://ContextMenu.tscn")

func _ready():
	velocity = Vector2(rand_range(-150.0, 150.0), -100.0)

func _physics_process(delta):
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
		var floor_y = OS.window_size.y - radius
		if global_position.y >= floor_y:
			global_position.y = floor_y
			velocity.y = -velocity.y * bounce
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
		elif global_position.x >= OS.window_size.x - radius:
			global_position.x = OS.window_size.x - radius
			velocity.x = -velocity.x * bounce
			
	update()

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			# Use expanded hit area for easier grab while ball is moving
			var grab_radius = radius * 1.6
			var dist = event.global_position.distance_to(global_position)
			if dist <= grab_radius:
				if event.button_index == BUTTON_RIGHT:
					var menu = ContextMenuScene.instance()
					get_parent().add_child(menu)
					menu.call("setup", self)
					get_tree().set_input_as_handled()
				elif event.button_index == BUTTON_LEFT:
					is_dragging = true
					drag_positions.clear()
					drag_positions.append(event.global_position)
					prev_mouse_pos = event.global_position
					get_tree().set_input_as_handled()
		else:
			if event.button_index == BUTTON_LEFT and is_dragging:
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
					velocity = velocity.clamped(800.0)
					
					# Notify pet
					var pet = get_parent().get_node_or_null("Pet")
					if is_instance_valid(pet) and pet.has_method("on_toy_thrown"):
						pet.call("on_toy_thrown", self)
				get_tree().set_input_as_handled()

func apply_impulse(impulse: Vector2):
	velocity += impulse
	velocity = velocity.clamped(600.0)

func get_click_polygon() -> PoolVector2Array:
	var poly = PoolVector2Array()
	for i in range(8):
		var angle = i * 2.0 * PI / 8.0
		poly.append(global_position + Vector2(cos(angle), sin(angle)) * radius)
	return poly

func _draw():
	var colors = [Color("e53935"), Color("3949ab"), Color("fdd835"), Color("43a047")]
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0))
	draw_circle(Vector2.ZERO, radius - 2.0, Color(1, 1, 1))
	
	var num_slices = 6
	for i in range(num_slices):
		var angle_start = i * 2.0 * PI / num_slices
		var angle_end = (i + 1) * 2.0 * PI / num_slices
		var color = colors[i % colors.size()]
		var points = PoolVector2Array([
			Vector2.ZERO,
			Vector2(cos(angle_start), sin(angle_start)) * (radius - 2.0),
			Vector2(cos(angle_end), sin(angle_end)) * (radius - 2.0)
		])
		draw_colored_polygon(points, color)
		
	draw_circle(Vector2.ZERO, radius * 0.25, Color(1, 1, 1))
