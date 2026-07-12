extends Control

signal spawn_food(pos, is_treat)
signal spawn_toy(pos)
signal breed_selected(breed_res)

onready var header = $Panel/Margin/VBox/Header
onready var food_btn = $Panel/Margin/VBox/ItemRow/FoodBtn
onready var cookie_btn = $Panel/Margin/VBox/ItemRow/CookieBtn
onready var ball_btn = $Panel/Margin/VBox/ItemRow/BallBtn
onready var exit_btn = $Panel/Margin/VBox/ControlRow/ExitBtn
onready var breed_dropdown = $Panel/Margin/VBox/BreedRow/BreedDropdown

# Progress Bars
onready var hunger_bar = $Panel/Margin/VBox/StatusGrid/HungerBar
onready var boredom_bar = $Panel/Margin/VBox/StatusGrid/BoredomBar
onready var energy_bar = $Panel/Margin/VBox/StatusGrid/EnergyBar
onready var affection_bar = $Panel/Margin/VBox/StatusGrid/AffectionBar
onready var toilet_bar = $Panel/Margin/VBox/StatusGrid/ToiletBar
onready var wellness_bar = $Panel/Margin/VBox/WellnessRow/WellnessBar

# Debug Values
onready var state_val = $Panel/Margin/VBox/DebugGrid/StateVal
onready var agitation_val = $Panel/Margin/VBox/DebugGrid/AgitationVal
onready var breed_val = $Panel/Margin/VBox/DebugGrid/BreedVal

var is_dragging = false
var drag_offset = Vector2.ZERO

var breed_names = ["grubby", "slinky", "glub"]

# Enum State mapping to text
var state_names = [
    "IDLE", "WANDER", "CHASE_CURSOR", "CHASE_ITEM", "EATING", 
    "SLEEPING", "AGITATED", "SICK", "RETURNING TO DISPENSER", 
    "EMERGING FROM DISPENSER", "RELIEVING SELF", "SELF DISPENSE"
]

func _ready():
    food_btn.connect("pressed", self, "_on_food_pressed")
    cookie_btn.connect("pressed", self, "_on_cookie_pressed")
    ball_btn.connect("pressed", self, "_on_ball_pressed")
    exit_btn.connect("pressed", self, "_on_exit_pressed")
    
    # Configure breed dropdown
    breed_dropdown.clear()
    breed_dropdown.add_item("Grubby")
    breed_dropdown.add_item("Slinky")
    breed_dropdown.add_item("Glub")
    breed_dropdown.connect("item_selected", self, "_on_dropdown_breed_selected")
    
    # Set drag cursor hint on the header panel
    header.mouse_default_cursor_shape = Control.CURSOR_DRAG
    header.connect("gui_input", self, "_on_header_gui_input")

func _process(_delta):
    # Query pet and update progress bars
    var main = get_parent()
    if main and "pet" in main and is_instance_valid(main.pet):
        var pet = main.pet
        if pet.stats:
            hunger_bar.value = pet.stats.hunger
            boredom_bar.value = pet.stats.boredom
            energy_bar.value = pet.stats.energy
            affection_bar.value = pet.stats.affection
            toilet_bar.value = pet.stats.toilet
            wellness_bar.value = pet.stats.wellness
            
            agitation_val.text = "%.1f%%" % pet.stats.agitation
            
        if pet.current_state >= 0 and pet.current_state < state_names.size():
            state_val.text = state_names[pet.current_state]
            
        if pet.active_breed:
            breed_val.text = pet.active_breed.breed_name

func _on_food_pressed():
    emit_signal("spawn_food", get_nozzle_global_position(), false)

func _on_cookie_pressed():
    emit_signal("spawn_food", get_nozzle_global_position(), true)

func _on_ball_pressed():
    emit_signal("spawn_toy", get_nozzle_global_position())

func _on_exit_pressed():
    get_tree().quit()

func _on_dropdown_breed_selected(index: int):
    if index >= 0 and index < breed_names.size():
        var breed_name = breed_names[index]
        var breed_path = "res://breeds/" + breed_name + ".tres"
        var breed_res = load(breed_path)
        if breed_res:
            emit_signal("breed_selected", breed_res)

func _on_header_gui_input(event):
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if event.pressed:
                is_dragging = true
                drag_offset = get_global_mouse_position() - rect_global_position
            else:
                is_dragging = false
    elif event is InputEventMouseMotion and is_dragging:
        rect_global_position = get_global_mouse_position() - drag_offset
        
        # Clamp within OS window dimensions
        rect_global_position.x = clamp(rect_global_position.x, 0.0, OS.window_size.x - rect_size.x)
        rect_global_position.y = clamp(rect_global_position.y, 0.0, OS.window_size.y - rect_size.y)

func get_nozzle_global_position() -> Vector2:
    return rect_global_position + Vector2(rect_size.x / 2.0, rect_size.y + 10.0)

func get_panel_rect() -> Rect2:
    return Rect2(rect_global_position, rect_size)
