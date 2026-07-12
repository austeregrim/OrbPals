extends Node2D

# Size of trash can hit area
const TRASH_RADIUS = 36.0
const TRASH_MARGIN = 55.0

var is_hot = false  # true when an item is being dragged nearby
var hot_timer = 0.0

func _ready():
    # Position at bottom-right corner
    var bounds = Rect2(Vector2.ZERO, OS.window_size)
    global_position = Vector2(bounds.end.x - TRASH_MARGIN, bounds.end.y - TRASH_MARGIN)

func _process(delta):
    # Update position in case window resizes
    var bounds = Rect2(Vector2.ZERO, OS.window_size)
    global_position = Vector2(bounds.end.x - TRASH_MARGIN, bounds.end.y - TRASH_MARGIN)

    # Detect if any item is being dragged
    var main = get_parent()
    var any_dragging = false
    if main and "active_items" in main:
        for item in main.active_items:
            if is_instance_valid(item) and item.get("is_dragging") == true:
                any_dragging = true
                break

    if any_dragging:
        hot_timer = 0.3
    elif hot_timer > 0.0:
        hot_timer -= delta

    is_hot = hot_timer > 0.0
    update()

func is_point_inside(pos: Vector2) -> bool:
    return global_position.distance_to(pos) <= TRASH_RADIUS

func _draw():
    # Only draw when something is being dragged
    if not is_hot:
        return

    var lid_color = Color("ef5350")  # Red lid when active
    var body_color = Color("b71c1c")
    var outline_col = Color(1, 1, 1, 0.9)

    # Shadow
    draw_circle(Vector2(0, 4), TRASH_RADIUS * 0.8, Color(0, 0, 0, 0.3))

    # Bin body (trapezoid via polygon)
    var body_pts = PoolVector2Array([
        Vector2(-TRASH_RADIUS * 0.55, -TRASH_RADIUS * 0.1),
        Vector2( TRASH_RADIUS * 0.55, -TRASH_RADIUS * 0.1),
        Vector2( TRASH_RADIUS * 0.45,  TRASH_RADIUS * 0.7),
        Vector2(-TRASH_RADIUS * 0.45,  TRASH_RADIUS * 0.7),
    ])
    draw_colored_polygon(body_pts, body_color)
    draw_polyline(PoolVector2Array([body_pts[0], body_pts[1], body_pts[2], body_pts[3], body_pts[0]]), outline_col, 2.5, true)

    # Stripes on body
    for i in range(3):
        var ty = lerp(-TRASH_RADIUS * 0.05, TRASH_RADIUS * 0.6, float(i + 1) / 4.0)
        draw_line(Vector2(-TRASH_RADIUS * 0.5, ty), Vector2(TRASH_RADIUS * 0.5, ty), Color(1, 1, 1, 0.15), 1.5)

    # Lid
    draw_rect(Rect2(-TRASH_RADIUS * 0.65, -TRASH_RADIUS * 0.22, TRASH_RADIUS * 1.3, TRASH_RADIUS * 0.18), lid_color)
    draw_rect(Rect2(-TRASH_RADIUS * 0.65, -TRASH_RADIUS * 0.22, TRASH_RADIUS * 1.3, TRASH_RADIUS * 0.18), outline_col, false, 2.0)
    # Handle
    draw_rect(Rect2(-TRASH_RADIUS * 0.2, -TRASH_RADIUS * 0.38, TRASH_RADIUS * 0.4, TRASH_RADIUS * 0.18), lid_color)
    draw_rect(Rect2(-TRASH_RADIUS * 0.2, -TRASH_RADIUS * 0.38, TRASH_RADIUS * 0.4, TRASH_RADIUS * 0.18), outline_col, false, 2.0)

    # Glow ring when item is directly over it
    var main = get_parent()
    if main and "active_items" in main:
        for item in main.active_items:
            if is_instance_valid(item) and item.get("is_dragging") == true:
                if is_point_inside(item.global_position):
                    draw_arc(Vector2.ZERO, TRASH_RADIUS * 1.1, 0, 2 * PI, 32, Color("ff1744"), 3.0)
                    break
