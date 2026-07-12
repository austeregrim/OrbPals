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

var ContextMenuScene = preload("res://ContextMenu.tscn")

func _ready():
    # Small initial bounce when dropped
    velocity = Vector2(rand_range(-50.0, 50.0), -120.0)

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
            velocity.x *= 0.8 # heavy friction
            
            if abs(velocity.y) < 15.0:
                velocity.y = 0
                
        # Wall bounds
        global_position.x = clamp(global_position.x, radius, OS.window_size.x - radius)
        
    update()

func _input(event):
    if event is InputEventMouseButton:
        var hit = event.global_position.distance_to(global_position) <= radius * 1.8
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
                    velocity = velocity.clamped(600.0)
                get_tree().set_input_as_handled()

func get_click_polygon() -> PoolVector2Array:
    # Padded polygon for passthrough — poop has a tall visual shape
    var poly = PoolVector2Array()
    var pad_w = radius + 8.0
    var pad_h = radius * 1.8 + 8.0
    for i in range(10):
        var angle = i * 2.0 * PI / 10.0
        poly.append(global_position + Vector2(cos(angle) * pad_w, sin(angle) * pad_h - radius * 0.4))
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
