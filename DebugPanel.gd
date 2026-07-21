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

onready var close_btn = $Panel/Margin/VBox/TitleBar/CloseBtn

var is_dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	$Panel/Margin/VBox/TitleBar.connect("gui_input", self, "_on_titlebar_gui_input")
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS
	close_btn.connect("pressed", self, "_on_close_pressed")
	
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
	speed_slider.connect("value_changed", self, "_on_speed_changed")
	decay_check.connect("toggled", self, "_on_decay_toggled")

func _on_titlebar_gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = event.global_position - $Panel.rect_global_position
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = event.global_position - drag_offset
		var vp_size = get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 10, max(10, vp_size.x - $Panel.rect_size.x - 10))
		new_pos.y = clamp(new_pos.y, 10, max(10, vp_size.y - $Panel.rect_size.y - 10))
		$Panel.rect_global_position = new_pos

func open():
	visible = true
	var vp_size = get_viewport_rect().size
	$Panel.rect_global_position = Vector2(20, (vp_size.y - $Panel.rect_size.y) / 2.0)
	raise()

func _process(_delta):
	if visible:
		var main = get_parent()
		if main and ("active_pets" in main) and main.active_pets.size() > 0:
			if not is_instance_valid(pet_ref) or not (pet_ref in main.active_pets):
				pet_ref = main.active_pets[0]
			if is_instance_valid(pet_ref) and pet_ref.stats:
				update_ui_from_stats()

func _on_close_pressed():
	visible = false

func setup(pet):
	pet_ref = pet
	if is_instance_valid(pet_ref) and pet_ref.stats:
		update_ui_from_stats()

func update_ui_from_stats():
	if not is_instance_valid(pet_ref) or not pet_ref.stats:
		return
	var stats = pet_ref.stats
	state_label.text = "Pet: %s | State: %d" % [pet_ref.pet_name, pet_ref.current_state]
	hunger_slider.value = stats.hunger
	hunger_label.text = "Hunger (%.1f%%)" % stats.hunger
	boredom_slider.value = stats.boredom
	boredom_label.text = "Boredom (%.1f%%)" % stats.boredom
	energy_slider.value = stats.energy
	energy_label.text = "Energy (%.1f%%)" % stats.energy
	affection_slider.value = stats.affection
	affection_label.text = "Affection (%.1f%%)" % stats.affection
	curiosity_slider.value = stats.curiosity
	curiosity_label.text = "Curiosity (%.1f%%)" % stats.curiosity
	agitation_slider.value = stats.agitation
	agitation_label.text = "Agitation (%.1f%%)" % stats.agitation
	wellness_slider.value = stats.wellness
	wellness_label.text = "Wellness (%.1f%%)" % stats.wellness

func _on_slider_value_changed(val, drive_name):
	emit_signal("drive_changed", drive_name, val)
	if is_instance_valid(pet_ref) and pet_ref.stats:
		pet_ref.stats.set(drive_name, val)
		update_ui_from_stats()

func _on_decay_toggled(button_pressed):
	emit_signal("decay_toggled", button_pressed)

func _on_speed_changed(val):
	speed_label.text = "Decay Speed (%.2fx)" % val
	emit_signal("decay_multiplier_changed", val)

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()
