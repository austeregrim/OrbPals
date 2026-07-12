extends Control

signal drive_changed(drive_name, value)
signal decay_toggled(decay_enabled)
signal decay_multiplier_changed(value)

var pet_ref = null

onready var state_label = $Panel/Margin/VBox/StateLabel
onready var decay_check = $Panel/Margin/VBox/DecayCheck

onready var hunger_slider = $Panel/Margin/VBox/HungerSection/Slider
onready var hunger_label = $Panel/Margin/VBox/HungerSection/Label

onready var boredom_slider = $Panel/Margin/VBox/BoredomSection/Slider
onready var boredom_label = $Panel/Margin/VBox/BoredomSection/Label

onready var energy_slider = $Panel/Margin/VBox/EnergySection/Slider
onready var energy_label = $Panel/Margin/VBox/EnergySection/Label

onready var affection_slider = $Panel/Margin/VBox/AffectionSection/Slider
onready var affection_label = $Panel/Margin/VBox/AffectionSection/Label

onready var curiosity_slider = $Panel/Margin/VBox/CuriositySection/Slider
onready var curiosity_label = $Panel/Margin/VBox/CuriositySection/Label

onready var agitation_slider = $Panel/Margin/VBox/AgitationSection/Slider
onready var agitation_label = $Panel/Margin/VBox/AgitationSection/Label

onready var wellness_slider = $Panel/Margin/VBox/WellnessSection/Slider
onready var wellness_label = $Panel/Margin/VBox/WellnessSection/Label

onready var speed_slider = $Panel/Margin/VBox/SpeedSection/Slider
onready var speed_label = $Panel/Margin/VBox/SpeedSection/Label

func _ready():
    hunger_slider.connect("value_changed", self, "_on_slider_value_changed", ["hunger"])
    boredom_slider.connect("value_changed", self, "_on_slider_value_changed", ["boredom"])
    energy_slider.connect("value_changed", self, "_on_slider_value_changed", ["energy"])
    affection_slider.connect("value_changed", self, "_on_slider_value_changed", ["affection"])
    curiosity_slider.connect("value_changed", self, "_on_slider_value_changed", ["curiosity"])
    agitation_slider.connect("value_changed", self, "_on_slider_value_changed", ["agitation"])
    wellness_slider.connect("value_changed", self, "_on_slider_value_changed", ["wellness"])
    
    speed_slider.min_value = 0.05
    speed_slider.max_value = 3.0
    speed_slider.step = 0.05
    speed_slider.value = 1.0
    speed_slider.connect("value_changed", self, "_on_speed_slider_changed")
    
    decay_check.connect("toggled", self, "_on_decay_toggled")

func setup(pet):
    pet_ref = pet
    if is_instance_valid(pet_ref) and pet_ref.stats:
        decay_check.pressed = pet_ref.decay_enabled
        speed_slider.value = pet_ref.stats.decay_multiplier
        speed_label.text = "Decay Speed (%.2fx)" % pet_ref.stats.decay_multiplier
        _update_ui_from_pet()

func get_panel_rect() -> Rect2:
    return $Panel.get_global_rect()

func _process(_delta):
    if not is_instance_valid(pet_ref):
        return
        
    # Translate state enum to string
    var state_name = "IDLE"
    match pet_ref.current_state:
        0: state_name = "IDLE"
        1: state_name = "WANDER"
        2: state_name = "CHASE_CURSOR"
        3: state_name = "CHASE_ITEM"
        4: state_name = "EATING"
        5: state_name = "SLEEPING"
        6: state_name = "AGITATED"
        7: state_name = "SICK"
    state_label.text = "State: " + state_name
    
    # Sync UI only if the user is not actively adjusting a slider
    if not Input.is_mouse_button_pressed(BUTTON_LEFT):
        _update_ui_from_pet()

func _update_ui_from_pet():
    if not is_instance_valid(pet_ref) or not pet_ref.stats:
        return
    var stats = pet_ref.stats
    
    hunger_slider.value = stats.hunger
    boredom_slider.value = stats.boredom
    energy_slider.value = stats.energy
    affection_slider.value = stats.affection
    curiosity_slider.value = stats.curiosity
    agitation_slider.value = stats.agitation
    wellness_slider.value = stats.wellness
    
    hunger_label.text = "Hunger (%.1f%%)" % stats.hunger
    boredom_label.text = "Boredom (%.1f%%)" % stats.boredom
    energy_label.text = "Energy (%.1f%%)" % stats.energy
    affection_label.text = "Affection (%.1f%%)" % stats.affection
    curiosity_label.text = "Curiosity (%.1f%%)" % stats.curiosity
    agitation_label.text = "Agitation (%.1f%%)" % stats.agitation
    wellness_label.text = "Wellness (%.1f%%)" % stats.wellness
    if not Input.is_mouse_button_pressed(BUTTON_LEFT):
        speed_slider.value = stats.decay_multiplier
    speed_label.text = "Decay Speed (%.2fx)" % stats.decay_multiplier

func _on_slider_value_changed(value: float, drive_name: String):
    match drive_name:
        "hunger": hunger_label.text = "Hunger (%.1f%%)" % value
        "boredom": boredom_label.text = "Boredom (%.1f%%)" % value
        "energy": energy_label.text = "Energy (%.1f%%)" % value
        "affection": affection_label.text = "Affection (%.1f%%)" % value
        "curiosity": curiosity_label.text = "Curiosity (%.1f%%)" % value
        "agitation": agitation_label.text = "Agitation (%.1f%%)" % value
        "wellness": wellness_label.text = "Wellness (%.1f%%)" % value
        
    if Input.is_mouse_button_pressed(BUTTON_LEFT):
        emit_signal("drive_changed", drive_name, value)

func _on_decay_toggled(button_pressed: bool):
    emit_signal("decay_toggled", button_pressed)

func _on_speed_slider_changed(value: float):
    speed_label.text = "Decay Speed (%.2fx)" % value
    emit_signal("decay_multiplier_changed", value)
