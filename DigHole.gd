extends Node2D

var lifetime: float = 30.0

func _ready():
	z_index = -1 # Draw behind pets and items
	update()
	var t = create_tween()
	if t:
		t.tween_property(self, "modulate:a", 0.0, lifetime).set_delay(lifetime - 5.0)
		t.tween_callback(self, "queue_free")

func _draw():
	var points = PoolVector2Array()
	var center = Vector2.ZERO
	var radius_x = 18.0
	var radius_y = 9.0
	for i in range(16):
		var angle = i * 2.0 * PI / 16.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	
	# Dirt hole fill and rim
	draw_polygon(points, PoolColorArray([Color("2d1b0e")]))
	draw_polyline(points, Color("5c3a21"), 2.0, true)
