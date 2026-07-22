extends Area2D

signal collected(item_type)

export(String) var item_type = "ancient_fossil"

var is_dragging = false
var drag_offset = Vector2.ZERO
var is_collected = false
var hover_time = 0.0

func _ready():
	connect("input_event", self, "_on_input_event")
	if has_node("Label"):
		$Label.visible = false
	if has_node("IconLabel"):
		$IconLabel.visible = false
	update()

func setup_item(type: String):
	item_type = type
	update()

func _process(delta):
	hover_time += delta * 3.0
	update()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		collect_item()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var click_pos = get_global_mouse_position()
		if global_position.distance_to(click_pos) <= 28.0:
			collect_item()
			get_tree().set_input_as_handled()

func collect_item():
	if is_collected:
		return
	is_collected = true
	
	var main = get_parent()
	if main and ("inventory" in main):
		main.inventory[item_type] = main.inventory.get(item_type, 0) + 1
		_spawn_floating_text("+1 " + item_type.replace("_", " ").capitalize())
		
	emit_signal("collected", item_type)
	queue_free()

func _spawn_floating_text(txt: String):
	var main = get_parent()
	if not main:
		return
	var lbl = Label.new()
	lbl.text = txt
	lbl.rect_global_position = global_position + Vector2(-40, -25)
	lbl.modulate = Color(1.0, 0.9, 0.4, 1.0)
	main.add_child(lbl)
	
	var t = main.create_tween()
	if t:
		t.tween_property(lbl, "rect_global_position:y", lbl.rect_global_position.y - 45.0, 0.8)
		t.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
		t.tween_callback(lbl, "queue_free")

func _draw():
	var bounce_y = sin(hover_time) * 3.0
	var draw_pos = Vector2(0, bounce_y)
	
	# Ground shadow
	draw_ellipse(Vector2(0, 14), 14.0, 6.0, Color(0, 0, 0, 0.25))

	match item_type:
		"starlight_crystal":
			# Star shape
			_draw_star(draw_pos, 5, 14.0, 7.0, Color("f1fa8c"), Color("ffb86c"))
		"meteor_shard":
			# 3D Isometric Cube shape
			_draw_cube(draw_pos, 12.0, Color("bd93f9"), Color("6272a4"))
		"glowing_amber":
			# Gem / Diamond shape
			_draw_gem(draw_pos, 13.0, Color("ffb86c"), Color("ff5555"))
		"bio_slime":
			# Slime drop shape
			_draw_slime_drop(draw_pos, 12.0, Color("50fa7b"), Color("8be9fd"))
		"radiant_spore":
			# Glowing Orb shape
			_draw_orb(draw_pos, 11.0, Color("ff79c6"), Color("8be9fd"))
		"elastic_rubber":
			# Ball shape
			_draw_sphere(draw_pos, 12.0, Color("ff5555"), Color("ff79c6"))
		"gene_fragment":
			# DNA Capsule shape
			_draw_dna_capsule(draw_pos, 12.0, Color("8be9fd"), Color("bd93f9"))
		_: # "ancient_fossil" or default
			_draw_fossil_bone(draw_pos, 13.0, Color("f8f8f2"), Color("e2e2dc"))

func _draw_star(pos: Vector2, points_count: int, r_outer: float, r_inner: float, color: Color, outline: Color):
	var pts = PoolVector2Array()
	for i in range(points_count * 2):
		var r = r_outer if (i % 2 == 0) else r_inner
		var angle = i * PI / points_count - PI / 2.0
		pts.append(pos + Vector2(cos(angle), sin(angle)) * r)
	draw_polygon(pts, PoolColorArray([color]))
	draw_polyline(pts, outline, 2.0, true)

func _draw_cube(pos: Vector2, size: float, col_main: Color, col_dark: Color):
	var top_face = PoolVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size, -size * 0.5),
		pos + Vector2(0, 0),
		pos + Vector2(-size, -size * 0.5)
	])
	var left_face = PoolVector2Array([
		pos + Vector2(-size, -size * 0.5),
		pos + Vector2(0, 0),
		pos + Vector2(0, size),
		pos + Vector2(-size, size * 0.5)
	])
	var right_face = PoolVector2Array([
		pos + Vector2(0, 0),
		pos + Vector2(size, -size * 0.5),
		pos + Vector2(size, size * 0.5),
		pos + Vector2(0, size)
	])
	draw_polygon(top_face, PoolColorArray([col_main.lightened(0.2)]))
	draw_polygon(left_face, PoolColorArray([col_main]))
	draw_polygon(right_face, PoolColorArray([col_dark]))
	draw_polyline(top_face, Color("ffffff"), 1.5, true)

func _draw_gem(pos: Vector2, size: float, main_col: Color, dark_col: Color):
	var pts = PoolVector2Array([
		pos + Vector2(0, -size),
		pos + Vector2(size * 0.8, -size * 0.4),
		pos + Vector2(0, size),
		pos + Vector2(-size * 0.8, -size * 0.4)
	])
	draw_polygon(pts, PoolColorArray([main_col]))
	draw_polyline(pts, dark_col, 2.0, true)
	draw_line(pos + Vector2(-size * 0.8, -size * 0.4), pos + Vector2(size * 0.8, -size * 0.4), Color("ffffff"), 1.5)

func _draw_slime_drop(pos: Vector2, rad: float, col1: Color, col2: Color):
	draw_circle(pos + Vector2(0, 2), rad, col1)
	var tip = PoolVector2Array([
		pos + Vector2(-rad * 0.7, 0),
		pos + Vector2(0, -rad * 1.5),
		pos + Vector2(rad * 0.7, 0)
	])
	draw_polygon(tip, PoolColorArray([col1]))
	draw_circle(pos + Vector2(-3, -3), rad * 0.3, col2)

func _draw_orb(pos: Vector2, rad: float, col1: Color, col2: Color):
	draw_circle(pos, rad, col1)
	draw_arc(pos, rad * 1.4, 0, 2 * PI, 16, col2, 2.0)
	draw_circle(pos + Vector2(-3, -3), rad * 0.35, Color("ffffff"))

func _draw_sphere(pos: Vector2, rad: float, col1: Color, col2: Color):
	draw_circle(pos, rad, col1)
	draw_circle(pos + Vector2(-3, -3), rad * 0.35, col2)

func _draw_dna_capsule(pos: Vector2, rad: float, col1: Color, col2: Color):
	draw_circle(pos + Vector2(-6, 0), rad * 0.7, col1)
	draw_circle(pos + Vector2(6, 0), rad * 0.7, col2)
	draw_line(pos + Vector2(-6, 0), pos + Vector2(6, 0), Color("ffffff"), 3.0)

func _draw_fossil_bone(pos: Vector2, _size: float, col1: Color, col2: Color):
	draw_line(pos + Vector2(-10, 0), pos + Vector2(10, 0), col1, 6.0)
	draw_circle(pos + Vector2(-10, -4), 4.0, col1)
	draw_circle(pos + Vector2(-10, 4), 4.0, col1)
	draw_circle(pos + Vector2(10, -4), 4.0, col1)
	draw_circle(pos + Vector2(10, 4), 4.0, col1)
	draw_line(pos + Vector2(-10, 0), pos + Vector2(10, 0), col2, 2.0)

func draw_ellipse(center: Vector2, rx: float, ry: float, color: Color):
	var pts = PoolVector2Array()
	for i in range(16):
		var angle = i * 2.0 * PI / 16.0
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polygon(pts, PoolColorArray([color]))

func get_click_polygon() -> PoolVector2Array:
	var r = Rect2(global_position - Vector2(18, 18), Vector2(36, 36))
	return PoolVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y)
	])
