extends Control

signal tab_clicked(tab_id)
signal spawn_food(pos, is_treat)
signal spawn_toy(pos)
signal use_mop_tool
signal summon_pet(pet_info)
signal recall_pet(pet_info)
signal recall_all_pets
signal euthanize_pet(pet_info)

onready var food_btn = $Panel/Margin/VBox/ItemRow/FoodBtn
onready var cookie_btn = $Panel/Margin/VBox/ItemRow/CookieBtn
onready var ball_btn = $Panel/Margin/VBox/ItemRow/BallBtn
onready var mop_btn = $Panel/Margin/VBox/ItemRow/MopBtn
onready var exit_btn = $Panel/Margin/VBox/TitleBar/ExitBtn

onready var breed_dropdown = $Panel/Margin/VBox/BreedRow/BreedDropdown
onready var summon_btn = $Panel/Margin/VBox/PetActionRow/SummonBtn
onready var recall_btn = $Panel/Margin/VBox/PetActionRow/RecallBtn
onready var recall_all_btn = $Panel/Margin/VBox/PetActionRow/RecallAllBtn
onready var euthanize_btn = $Panel/Margin/VBox/EuthanizeRow/EuthanizeBtn
onready var confirm_dialog = $ConfirmationDialog
onready var tab_ear = $PanelTabEar

var is_dragging = false
var drag_offset = Vector2.ZERO
var pending_euthanize_pet = null

var available_pets = []

func _ready():
	food_btn.connect("pressed", self, "_on_food_pressed")
	cookie_btn.connect("pressed", self, "_on_cookie_pressed")
	ball_btn.connect("pressed", self, "_on_ball_pressed")
	mop_btn.connect("pressed", self, "_on_mop_pressed")
	if exit_btn:
		exit_btn.connect("pressed", self, "_on_exit_pressed")
	
	summon_btn.connect("pressed", self, "_on_summon_pressed")
	recall_btn.connect("pressed", self, "_on_recall_pressed")
	recall_all_btn.connect("pressed", self, "_on_recall_all_pressed")
	euthanize_btn.connect("pressed", self, "_on_euthanize_pressed")
	confirm_dialog.connect("confirmed", self, "_on_euthanize_confirmed")
	
	$Panel/Margin/VBox/TitleBar.connect("gui_input", self, "_on_titlebar_gui_input")
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if tab_ear:
		tab_ear.tab_id = "dispenser"
		tab_ear.icon_text = "🚰"
		tab_ear.connect("tab_clicked", self, "_on_tab_ear_clicked")

func _on_tab_ear_clicked(tab_id: String):
	emit_signal("tab_clicked", tab_id)

func _on_mop_pressed():
	emit_signal("use_mop_tool")

func _on_titlebar_gui_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = event.global_position - rect_global_position
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = event.global_position - drag_offset
		var vp_size = get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0, max(0, vp_size.x - rect_size.x))
		new_pos.y = clamp(new_pos.y, 0, max(0, vp_size.y - rect_size.y))
		rect_global_position = new_pos

func populate_pet_roster(pet_list: Array):
	available_pets = pet_list
	breed_dropdown.clear()
	for pet_info in available_pets:
		var pname = pet_info.get("pet_name", pet_info.get("breed_name", "Unknown"))
		breed_dropdown.add_item(pname)

func _on_food_pressed():
	emit_signal("spawn_food", get_nozzle_global_position(), false)

func _on_cookie_pressed():
	emit_signal("spawn_food", get_nozzle_global_position(), true)

func _on_ball_pressed():
	emit_signal("spawn_toy", get_nozzle_global_position())

func _on_summon_pressed():
	var idx = breed_dropdown.selected
	if idx >= 0 and idx < available_pets.size():
		emit_signal("summon_pet", available_pets[idx])

func _on_recall_pressed():
	var idx = breed_dropdown.selected
	if idx >= 0 and idx < available_pets.size():
		emit_signal("recall_pet", available_pets[idx])

func _on_recall_all_pressed():
	emit_signal("recall_all_pets")

func _on_euthanize_pressed():
	var idx = breed_dropdown.selected
	if idx >= 0 and idx < available_pets.size():
		pending_euthanize_pet = available_pets[idx]
		var pname = pending_euthanize_pet.get("pet_name", "this pet")
		confirm_dialog.dialog_text = "⚠️ WARNING ⚠️\n\nAre you sure you want to comically send '%s' into the void?\nThis will PERMANENTLY DELETE its save file!" % pname
		confirm_dialog.popup_centered()

func _on_euthanize_confirmed():
	if pending_euthanize_pet != null:
		emit_signal("euthanize_pet", pending_euthanize_pet)
		pending_euthanize_pet = null

func _on_exit_pressed():
	get_tree().quit()

func get_nozzle_global_position() -> Vector2:
	# If drawer panel is open and visible on screen, use bottom of panel
	var r = $Panel.get_global_rect()
	if $Panel.visible and r.size.x > 10 and r.position.x >= -50 and r.position.x <= OS.window_size.x:
		return r.position + Vector2(r.size.x / 2.0, r.size.y + 10.0)
		
	# Fallback: emerge directly from the side tab ear
	if is_instance_valid(tab_ear):
		var tab_r = tab_ear.get_tab_rect()
		if tab_r.size.x > 0:
			return tab_r.position + Vector2(tab_r.size.x / 2.0, tab_r.size.y / 2.0)
			
	return Vector2(clamp(r.position.x + 165.0, 40.0, OS.window_size.x - 40.0), 100.0)

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()

func get_tab_rect() -> Rect2:
	if is_instance_valid(tab_ear):
		return tab_ear.get_tab_rect()
	return Rect2()
