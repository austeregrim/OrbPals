extends Node2D

export(String) var effect_type = "scorch_mark" # "scorch_mark", "water_puddle", "ice_cube", "flower_patch", "weed_patch", "void_rift", "crystal_geode"
export(float) var lifetime = 60.0 # automatically fades after 60s if not cleaned
export(float) var radius = 22.0

var velocity = Vector2.ZERO
var fade_timer = 0.0
var opacity = 1.0

# Click polygon support
func get_click_polygon() -> PoolVector2Array:
	var poly = PoolVector2Array()
	for i in range(8):
		var angle = i * 2.0 * PI / 8.0
		poly.append(global_position + Vector2(cos(angle), sin(angle)) * radius)
	return poly

func _ready():
	fade_timer = lifetime

func _physics_process(delta):
	if effect_type == "tornado_streak":
		global_position += velocity * delta
		opacity -= delta * 0.5
		if opacity <= 0.0:
			queue_free()
			return
			
	fade_timer -= delta
	if fade_timer <= 5.0:
		opacity = clamp(fade_timer / 5.0, 0.0, 1.0)
	if fade_timer <= 0.0:
		var main = get_parent()
		if main and main.has_method("remove_item"):
			main.call("remove_item", self)
		else:
			queue_free()
		return
		
	update()

func clean_up():
	queue_free()

func _draw():
	var col = Color(1, 1, 1, opacity)
	match effect_type:
		"scorch_mark":
			# Dark charred burn mark
			draw_circle(Vector2.ZERO, radius, Color(0.15, 0.1, 0.08, 0.7 * opacity))
			draw_circle(Vector2.ZERO, radius * 0.6, Color(0.05, 0.05, 0.05, 0.85 * opacity))
			draw_arc(Vector2.ZERO, radius * 0.8, 0, PI*2, 10, Color(0.8, 0.3, 0.0, 0.5 * opacity), 2.0)
		"water_puddle":
			# Blue splash puddle
			draw_circle(Vector2.ZERO, radius * 1.2, Color(0.1, 0.5, 0.9, 0.5 * opacity))
			draw_circle(Vector2(4, -3), radius * 0.5, Color(0.4, 0.8, 1.0, 0.6 * opacity))
		"ice_cube":
			# Cyan shiny ice block
			draw_rect(Rect2(-Vector2(radius, radius), Vector2(radius*2, radius*2)), Color(0.7, 0.95, 1.0, 0.75 * opacity))
			draw_rect(Rect2(-Vector2(radius, radius), Vector2(radius*2, radius*2)), Color(1, 1, 1, opacity), false, 2.0)
		"flower_patch":
			# Green leaves with pink petals
			draw_circle(Vector2.ZERO, radius * 0.8, Color(0.2, 0.8, 0.3, 0.8 * opacity))
			for i in range(5):
				var a = i * 2.0 * PI / 5.0
				var p_pos = Vector2(cos(a), sin(a)) * (radius * 0.6)
				draw_circle(p_pos, radius * 0.35, Color(1.0, 0.4, 0.7, opacity))
			draw_circle(Vector2.ZERO, radius * 0.3, Color(1.0, 0.9, 0.2, opacity))
		"weed_patch":
			# Wild green grass/weed patch
			draw_circle(Vector2.ZERO, radius * 0.9, Color(0.15, 0.65, 0.2, 0.8 * opacity))
			for i in range(6):
				var h = 10.0 + (i % 3) * 4.0
				draw_line(Vector2(-12 + i*5, 0), Vector2(-12 + i*5, -h), Color(0.1, 0.5, 0.15, opacity), 2.5)
		"void_rift":
			# Crack in the fabric of time
			var rift_pts = PoolVector2Array([
				Vector2(0, -radius),
				Vector2(-6, -radius*0.4),
				Vector2(10, 0),
				Vector2(-4, radius*0.5),
				Vector2(2, radius)
			])
			draw_polyline(rift_pts, Color(0.1, 0.0, 0.2, 0.9 * opacity), 6.0, true)
			draw_polyline(rift_pts, Color(0.8, 0.2, 1.0, opacity), 2.5, true)
		"crystal_geode":
			# Purple shiny crystal shard
			var pts = PoolVector2Array([
				Vector2(0, -radius),
				Vector2(radius * 0.7, -radius * 0.2),
				Vector2(radius * 0.5, radius * 0.8),
				Vector2(-radius * 0.5, radius * 0.8),
				Vector2(-radius * 0.7, -radius * 0.2)
			])
			draw_colored_polygon(pts, Color(0.7, 0.3, 0.9, 0.85 * opacity))
			draw_polyline(pts, Color(1, 1, 1, opacity), 2.0, true)
		"tornado_streak":
			# Swirling gust trail
			draw_arc(Vector2.ZERO, radius, 0, PI * 1.5, 12, Color(0.6, 0.9, 0.8, 0.6 * opacity), 3.0)
