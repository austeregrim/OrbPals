extends Control

signal drive_changed(drive_name, value)
signal decay_toggled(decay_enabled)
signal decay_multiplier_changed(value)
signal tab_clicked(tab_id)

var pet_ref = null
var selected_pet_idx: int = 0

onready var prev_pet_btn = $Panel/Margin/VBox/PetSelectorRow/PrevBtn
onready var next_pet_btn = $Panel/Margin/VBox/PetSelectorRow/NextBtn
onready var pet_title_label = $Panel/Margin/VBox/PetSelectorRow/PetTitleLabel
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

onready var tab_ear = $PanelTabEar

var is_undocked = false
var is_dragging = false
var drag_offset = Vector2.ZERO
onready var vbox = $Panel/Margin/VBox
var undock_btn = null

func _ready():
	_ensure_scroll_container()
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS

	if vbox and vbox.has_node("TitleBar"):
		var tb = vbox.get_node("TitleBar")
		tb.connect("gui_input", self, "_on_titlebar_gui_input")
		if not undock_btn:
			undock_btn = Button.new()
			undock_btn.name = "UndockBtn"
			undock_btn.text = "[Pin]"
			undock_btn.flat = true
			undock_btn.hint_tooltip = "Undock / Dock Panel"
			undock_btn.connect("pressed", self, "toggle_undock")
			tb.add_child(undock_btn)

	prev_pet_btn.connect("pressed", self, "_on_prev_pet_pressed")
	next_pet_btn.connect("pressed", self, "_on_next_pet_pressed")

	if tab_ear:
		tab_ear.tab_id = "debug"
		tab_ear.icon_text = "DBUG"
		tab_ear.connect("tab_clicked", self, "_on_tab_ear_clicked")

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

func toggle_undock():
	is_undocked = not is_undocked
	_update_undock_button_ui()
	var main = get_parent()
	if not is_undocked and main and main.has_method("_reposition_all_side_panels"):
		main.call("_reposition_all_side_panels", true)

func _update_undock_button_ui():
	if undock_btn:
		undock_btn.text = "[Unpin]" if is_undocked else "[Pin]"


func _on_tab_ear_clicked(tab_id: String):
	emit_signal("tab_clicked", tab_id)

func _on_titlebar_gui_input(event):
	if not is_undocked:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = event.global_position - rect_global_position
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging and is_undocked:
		var new_pos = event.global_position - drag_offset
		var vp_size = get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0, max(0, vp_size.x - rect_size.x))
		new_pos.y = clamp(new_pos.y, 0, max(0, vp_size.y - rect_size.y))
		rect_global_position = new_pos


func _on_prev_pet_pressed():
	selected_pet_idx -= 1
	_update_selected_pet()

func _on_next_pet_pressed():
	selected_pet_idx += 1
	_update_selected_pet()

func _update_selected_pet():
	var main = get_parent()
	if not main:
		return
	var active_pets = main.get("active_pets")
	var valid_pets = []
	if active_pets != null:
		for p in active_pets:
			if is_instance_valid(p):
				valid_pets.append(p)

	if valid_pets.size() > 0:
		if selected_pet_idx < 0:
			selected_pet_idx = valid_pets.size() - 1
		elif selected_pet_idx >= valid_pets.size():
			selected_pet_idx = 0
		pet_ref = valid_pets[selected_pet_idx]
	else:
		pet_ref = null
		selected_pet_idx = 0
	update_ui_from_stats()

func open():

	visible = true
	var vp_size = get_viewport_rect().size
	$Panel.rect_global_position = Vector2(20, (vp_size.y - $Panel.rect_size.y) / 2.0)
	raise()
	_update_selected_pet()

func _process(_delta):
	if visible:
		var main = get_parent()
		if main and ("active_pets" in main):
			var valid_pets = []
			for p in main.active_pets:
				if is_instance_valid(p):
					valid_pets.append(p)
					
			if valid_pets.size() > 0:
				if not is_instance_valid(pet_ref) or not (pet_ref in valid_pets):
					_update_selected_pet()
				else:
					update_ui_from_stats()
			else:
				pet_ref = null
				update_ui_from_stats()

func setup(pet):
	pet_ref = pet
	update_ui_from_stats()

func update_ui_from_stats():
	var main = get_parent()
	var valid_count = 0
	if main and ("active_pets" in main):
		for p in main.active_pets:
			if is_instance_valid(p):
				valid_count += 1

	prev_pet_btn.disabled = (valid_count <= 1)
	next_pet_btn.disabled = (valid_count <= 1)

	if not is_instance_valid(pet_ref) or not pet_ref.stats:
		pet_title_label.text = "Pet: None"
		state_label.text = "State: DISPENSER RESTING"
		return

	var stats = pet_ref.stats
	pet_title_label.text = "Pet: %s" % pet_ref.pet_name
	state_label.text = "State: %d" % pet_ref.current_state
	hunger_slider.value = stats.hunger
	hunger_label.text = "Hunger: %.0f%%" % stats.hunger
	boredom_slider.value = stats.boredom
	boredom_label.text = "Boredom: %.0f%%" % stats.boredom
	energy_slider.value = stats.energy
	energy_label.text = "Energy: %.0f%%" % stats.energy
	affection_slider.value = stats.affection
	affection_label.text = "Affection: %.0f%%" % stats.affection
	curiosity_slider.value = stats.curiosity
	curiosity_label.text = "Curiosity: %.0f%%" % stats.curiosity
	agitation_slider.value = stats.agitation
	agitation_label.text = "Agitation: %.0f%%" % stats.agitation
	wellness_slider.value = stats.wellness
	wellness_label.text = "Wellness: %.0f%%" % stats.wellness

func _on_slider_value_changed(val, drive_name):
	emit_signal("drive_changed", drive_name, val)
	if is_instance_valid(pet_ref) and pet_ref.stats:
		pet_ref.stats.set(drive_name, val)

func _on_decay_toggled(button_pressed):
	emit_signal("decay_toggled", button_pressed)

func _on_speed_changed(val):
	speed_label.text = "Speed: %.2fx" % val
	emit_signal("decay_multiplier_changed", val)

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()

func get_tab_rect() -> Rect2:
	if is_instance_valid(tab_ear):
		return tab_ear.get_tab_rect()
	return Rect2()

func _ensure_scroll_container():
	var margin = get_node_or_null("Panel/Margin")
	if not margin:
		return
	var vbox = margin.get_node_or_null("VBox")
	if vbox and not vbox.get_parent() is ScrollContainer:
		margin.remove_child(vbox)
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.anchor_right = 1.0
		scroll.anchor_bottom = 1.0
		scroll.size_flags_horizontal = SIZE_EXPAND_FILL
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		scroll.scroll_horizontal_enabled = false
		margin.add_child(scroll)
		scroll.add_child(vbox)
		vbox.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox.size_flags_vertical = SIZE_EXPAND_FILL

