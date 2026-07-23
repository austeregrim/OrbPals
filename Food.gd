extends Node2D

export(float) var radius = 15.0
export(float) var gravity = 400.0
export(float) var bounce = 0.25

var velocity = Vector2.ZERO
var is_dragging = false
var drag_positions = []
var prev_mouse_pos = Vector2.ZERO

# 3D Coordinates
var x_pos: float = 0.0
var z_depth: float = 0.0
var y_height: float = 0.0
var z_vel: float = 0.0

func get_depth_scale(z: float) -> float:
	return lerp(1.0, 0.85, z)

func _ready():
	x_pos = global_position.x
	y_height = 0.0
	
	var horizon_y = OS.window_size.y * 0.35
	var floor_max_y = OS.window_size.y - radius
	var depth_span = max(floor_max_y - horizon_y, 1.0)
	
	var main = get_parent()
	if main and "dispenser_device" in main and is_instance_valid(main.dispenser_device):
		var nozzle_pos = main.dispenser_device.get_nozzle_global_position()
		if global_position.distance_to(nozzle_pos) < 50.0:
			z_depth = 0.8
			var ground_y = lerp(floor_max_y, horizon_y, z_depth)
			y_height = max(ground_y - global_position.y, 0.0)
			return
			
	z_depth = clamp((floor_max_y - global_position.y) / depth_span, 0.0, 1.0)

# Type tag for reliable detection
var is_food = true
var is_toy = false

# Spoiling mechanics
export(bool) var is_treat = false
export(bool) var is_bottle = false
var is_spoiled = false
var age = 0.0
export(float) var spoil_time = 300.0 # regular food spoils in 5 minutes

var ContextMenuScene = preload("res://ContextMenu.tscn")

var drag_history: Array = []

func _physics_process(delta):
	# Process spoiling (treats and bottles never spoil)
	if not is_treat and not is_bottle and not is_spoiled:
		age += delta
		if age >= spoil_time:
			is_spoiled = true
			update()

	scale = Vector2.ONE
	if is_dragging:
		var mouse_pos = get_global_mouse_position()
		global_position = mouse_pos
		velocity = Vector2.ZERO
		
		var now = OS.get_ticks_msec() * 0.001
		drag_history.append({"pos": mouse_pos, "time": now})
		while drag_history.size() > 0 and (now - drag_history[0].time) > 0.14:
			drag_history.remove(0)
	else:
		# Float in space and drift with air friction
		velocity *= 0.95
		global_position += velocity * delta

		
		# Boundary bounce check
		var vp_size = get_viewport().get_visible_rect().size if get_viewport() else OS.window_size
		var floor_y = vp_size.y - radius
		var ceiling_y = radius
		var wall_l = radius
		var wall_r = vp_size.x - radius
		
		if global_position.y >= floor_y:
			global_position.y = floor_y
			velocity.y = -velocity.y * bounce
		elif global_position.y <= ceiling_y:
			global_position.y = ceiling_y
			velocity.y = -velocity.y * bounce
			
		if global_position.x <= wall_l:
			global_position.x = wall_l
			velocity.x = -velocity.x * bounce
		elif global_position.x >= wall_r:
			global_position.x = wall_r
			velocity.x = -velocity.x * bounce
			
		# Spoiled food wiggles slightly in place
		if is_spoiled:
			global_position.x += sin(OS.get_ticks_msec() * 0.015) * 0.4
			
		# Keep within screen boundaries
		global_position.x = clamp(global_position.x, radius, vp_size.x - radius)
		global_position.y = clamp(global_position.y, radius, vp_size.y - radius)

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
		var hit = touch_pos.distance_to(global_position) <= radius * 1.6 * scale.x
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

		# Direct Drag Auto-eating check when dropped on a pet
		if main and ("active_pets" in main):
			for pet in main.active_pets:
				if is_instance_valid(pet) and global_position.distance_to(pet.global_position) < pet.base_radius * 2.2:
					if is_bottle:
						if pet.has_method("feed_bottle") and pet.feed_bottle(self):
							if main.has_method("remove_item"):
								main.call("remove_item", self)
							get_tree().set_input_as_handled()
							return
					else:
						if pet.has_method("eat_food"):
							var consumed = pet.eat_food(self)
							if consumed:
								if main.has_method("remove_item"):
									main.call("remove_item", self)
								get_tree().set_input_as_handled()
								return


		if drag_history.size() >= 2:
			var oldest = drag_history[0]
			var newest = drag_history[drag_history.size() - 1]
			var dt = newest.time - oldest.time
			if dt > 0.005:
				var toss_vel = (newest.pos - oldest.pos) / dt
				velocity = toss_vel * 1.15
				velocity = velocity.clamped(1200.0)
		drag_history.clear()
		get_tree().set_input_as_handled()


func get_click_polygon() -> PoolVector2Array:
	# Padded circle polygon for the passthrough region — covers item + margin
	var poly = PoolVector2Array()
	var padded_r = (radius + 10.0) * scale.x
	for i in range(10):
		var angle = i * 2.0 * PI / 10.0
		poly.append(global_position + Vector2(cos(angle), sin(angle)) * padded_r)
	return poly

func _draw():
	if is_bottle:
		# Draw Feeding Bottle 🍼
		draw_rect(Rect2(Vector2(-7, -10), Vector2(14, 18)), Color("e0f7fa"))
		draw_rect(Rect2(Vector2(-7, -10), Vector2(14, 18)), Color("006064"), false, 1.5)
		draw_rect(Rect2(Vector2(-6, -4), Vector2(12, 11)), Color("ffffff"))
		draw_circle(Vector2(0, -12), 4.5, Color("ffb74d"))
		draw_line(Vector2(-4, -10), Vector2(4, -10), Color("ef6c00"), 2.0)
	elif is_treat:

		# Draw Treat (Cookie)
		# Cookie base (tan brown)
		draw_circle(Vector2.ZERO, radius, Color("d7ccc8"))
		draw_circle(Vector2.ZERO, radius - 2.0, Color("bcaaa4"))
		
		# Chocolate chips (dark brown spots)
		draw_circle(Vector2(-5, -4), 2.0, Color("4e342e"))
		draw_circle(Vector2(5, -2), 2.2, Color("4e342e"))
		draw_circle(Vector2(-1, 5), 1.8, Color("4e342e"))
		draw_circle(Vector2(3, 4), 2.0, Color("4e342e"))
		draw_circle(Vector2(-6, 3), 1.7, Color("4e342e"))
	else:
		# Draw Regular Food (Kibble)
		var base_color = Color("8d6e63") # Kibble brown
		var accent_color = Color("5d4037")
		if is_spoiled:
			base_color = Color("689f38") # Moldy green
			accent_color = Color("33691e")
			
		# Draw triangular kibble pellet
		var points = PoolVector2Array([
			Vector2(0, -radius),
			Vector2(radius, radius * 0.8),
			Vector2(-radius, radius * 0.8)
		])
		draw_colored_polygon(points, base_color)
		
		# Draw outline
		var outline = PoolVector2Array([
			Vector2(0, -radius),
			Vector2(radius, radius * 0.8),
			Vector2(-radius, radius * 0.8),
			Vector2(0, -radius)
		])
		draw_polyline(outline, Color("000000"), 2.0, true)
		
		# Center details
		draw_circle(Vector2.ZERO, radius * 0.3, accent_color)
		
		# Mold indicator label if spoiled
		if is_spoiled:
			draw_line(Vector2(-4, -6), Vector2(4, -6), Color("ff1744"), 2.0)
			draw_line(Vector2(0, -6), Vector2(0, -2), Color("ff1744"), 2.0)
