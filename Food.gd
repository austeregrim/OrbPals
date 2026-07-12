extends Node2D

export(float) var radius = 15.0
export(float) var gravity = 400.0
export(float) var bounce = 0.25

var velocity = Vector2.ZERO
var is_dragging = false
var drag_positions = []
var prev_mouse_pos = Vector2.ZERO

# Type tag for reliable detection
var is_food = true
var is_toy = false

# Spoiling mechanics
export(bool) var is_treat = false
var is_spoiled = false
var age = 0.0
export(float) var spoil_time = 300.0 # regular food spoils in 5 minutes

var ContextMenuScene = preload("res://ContextMenu.tscn")

func _physics_process(delta):
    # Process spoiling (treats never spoil)
    if not is_treat and not is_spoiled:
        age += delta
        if age >= spoil_time:
            is_spoiled = true
            update()
            
    if is_dragging:
        var mouse_pos = get_global_mouse_position()
        global_position = mouse_pos
        velocity = Vector2.ZERO
        
        drag_positions.append(mouse_pos)
        if drag_positions.size() > 5:
            drag_positions.remove(0)
            
        prev_mouse_pos = mouse_pos
    else:
        # NO gravity: float in space and drift with air friction
        velocity *= 0.95 # air friction/drag
        global_position += velocity * delta
        
        # Boundary bounce check
        var floor_y = OS.window_size.y - radius
        var ceiling_y = radius
        var wall_l = radius
        var wall_r = OS.window_size.x - radius
        
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

    # Keep within screen
    global_position.x = clamp(global_position.x, radius, OS.window_size.x - radius)
    global_position.y = clamp(global_position.y, radius, OS.window_size.y - radius)
    update()

func _input(event):
    if event is InputEventMouseButton:
        var hit = event.global_position.distance_to(global_position) <= radius * 1.6
        if event.pressed:
            if hit:
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
                get_tree().set_input_as_handled()

func get_click_polygon() -> PoolVector2Array:
    # Padded circle polygon for the passthrough region — covers item + margin
    var poly = PoolVector2Array()
    var padded_r = radius + 10.0
    for i in range(10):
        var angle = i * 2.0 * PI / 10.0
        poly.append(global_position + Vector2(cos(angle), sin(angle)) * padded_r)
    return poly

func _draw():
    if is_treat:
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
