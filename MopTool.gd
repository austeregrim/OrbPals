extends Node2D

export(float) var radius = 20.0

var is_mop = true
var is_dragging = false
var drag_positions = []
var prev_mouse_pos = Vector2.ZERO

var velocity = Vector2.ZERO
export(float) var gravity = 350.0
export(float) var bounce = 0.5

var ContextMenuScene = preload("res://ContextMenu.tscn")

func _ready():
	velocity = Vector2(rand_range(-50.0, 50.0), -100.0)

func _physics_process(delta):
	if is_dragging:
		var mouse_pos = prev_mouse_pos if prev_mouse_pos != Vector2.ZERO else get_global_mouse_position()
		global_position = mouse_pos
		velocity = Vector2.ZERO
		
		# Clean messes near mop while dragging
		_clean_messes_in_radius()
		
		drag_positions.append(mouse_pos)
		if drag_positions.size() > 5:
			drag_positions.remove(0)
	else:
		velocity.y += gravity * delta
		global_position += velocity * delta
		
		var vp_size = OS.window_size
		if get_viewport():
			vp_size = get_viewport().get_visible_rect().size
			
		var floor_y = vp_size.y - radius
		if global_position.y >= floor_y:
			global_position.y = floor_y
			velocity.y = -velocity.y * bounce
			velocity.x *= 0.9
			
		if global_position.x <= radius:
			global_position.x = radius
			velocity.x = -velocity.x * bounce
		elif global_position.x >= vp_size.x - radius:
			global_position.x = vp_size.x - radius
			velocity.x = -velocity.x * bounce
			
	update()

func _clean_messes_in_radius():
	var main = get_parent()
	if not main or not ("active_items" in main):
		return
		
	var clean_radius = radius * 1.8
	var items_to_remove = []
	for item in main.active_items:
		if is_instance_valid(item) and item != self:
			var d = item.global_position.distance_to(global_position)
			if d <= clean_radius:
				if item.has_method("clean_up"):
					item.call("clean_up")
					items_to_remove.append(item)
				elif "is_poop" in item or item.name.begins_with("Poop"):
					items_to_remove.append(item)
					
	for item in items_to_remove:
		if AudioManager:
			AudioManager.play_mop_sweep()
		main.active_items.erase(item)
		if is_instance_valid(item):
			item.queue_free()


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
			velocity = velocity.clamped(600.0)
		get_tree().set_input_as_handled()

func get_click_polygon() -> PoolVector2Array:
	var poly = PoolVector2Array()
	for i in range(8):
		var angle = i * 2.0 * PI / 8.0
		poly.append(global_position + Vector2(cos(angle), sin(angle)) * radius)
	return poly

func _draw():
	# Draw mop handle
	draw_line(Vector2(0, 10), Vector2(0, -26), Color("8d6e63"), 4.0)
	draw_circle(Vector2(0, -26), 3.0, Color("5d4037"))
	
	# Draw mop head bristles
	draw_rect(Rect2(-12, 6, 24, 8), Color("b0bec5"))
	for i in range(7):
		var x_off = -10 + i * 3.3
		draw_line(Vector2(x_off, 12), Vector2(x_off, 22), Color("eceff1"), 3.0)
