extends Control

signal tab_clicked(tab_id)
signal spawn_food(pos, is_treat)
signal spawn_bottle(pos)
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
var bottle_btn = null
var chew_btn = null
var stuffie_btn = null
var boombox_btn = null

onready var breed_dropdown = $Panel/Margin/VBox/BreedRow/BreedDropdown
onready var summon_btn = $Panel/Margin/VBox/PetActionRow/SummonBtn
onready var recall_btn = $Panel/Margin/VBox/PetActionRow/RecallBtn
onready var recall_all_btn = $Panel/Margin/VBox/PetActionRow/RecallAllBtn
onready var euthanize_btn = $Panel/Margin/VBox/EuthanizeRow/EuthanizeBtn
onready var confirm_dialog = $ConfirmationDialog
onready var tab_ear = $PanelTabEar

var is_undocked = false
var is_dragging = false
var drag_offset = Vector2.ZERO
var pending_euthanize_pet = null

var available_pets = []
onready var vbox = $Panel/Margin/VBox
var undock_btn = null

func _ready():
	_ensure_scroll_container()
	food_btn.connect("pressed", self, "_on_food_pressed")
	cookie_btn.connect("pressed", self, "_on_cookie_pressed")
	ball_btn.connect("pressed", self, "_on_ball_pressed")
	mop_btn.connect("pressed", self, "_on_mop_pressed")
	if exit_btn:
		exit_btn.connect("pressed", self, "_on_exit_pressed")
	
	if vbox and vbox.has_node("ItemRow"):
		var item_row = vbox.get_node("ItemRow")
		bottle_btn = Button.new()
		bottle_btn.name = "BottleBtn"
		bottle_btn.text = "Bottle"
		bottle_btn.hint_tooltip = "Dispense Feeding Bottle"
		bottle_btn.size_flags_horizontal = SIZE_EXPAND_FILL
		bottle_btn.connect("pressed", self, "_on_bottle_pressed")
		item_row.add_child(bottle_btn)
		item_row.move_child(bottle_btn, 1)

		# Add second row of items for Chew Toy, Stuffie, and Boombox
		var item_row2 = HBoxContainer.new()
		item_row2.name = "ItemRow2"

		chew_btn = Button.new()
		chew_btn.name = "ChewBtn"
		chew_btn.text = "Chew"
		chew_btn.hint_tooltip = "Dispense Chew Toy"
		chew_btn.size_flags_horizontal = SIZE_EXPAND_FILL
		chew_btn.connect("pressed", self, "_on_chew_pressed")
		item_row2.add_child(chew_btn)

		stuffie_btn = Button.new()
		stuffie_btn.name = "StuffieBtn"
		stuffie_btn.text = "Stuffie"
		stuffie_btn.hint_tooltip = "Dispense Stuffed Animal"
		stuffie_btn.size_flags_horizontal = SIZE_EXPAND_FILL
		stuffie_btn.connect("pressed", self, "_on_stuffie_pressed")
		item_row2.add_child(stuffie_btn)

		boombox_btn = Button.new()
		boombox_btn.name = "BoomboxBtn"
		boombox_btn.text = "Boombox"
		boombox_btn.hint_tooltip = "Dispense Music Boombox"
		boombox_btn.size_flags_horizontal = SIZE_EXPAND_FILL
		boombox_btn.connect("pressed", self, "_on_boombox_pressed")
		item_row2.add_child(boombox_btn)

		vbox.add_child(item_row2)
		vbox.move_child(item_row2, item_row.get_index() + 1)


	summon_btn.connect("pressed", self, "_on_summon_pressed")
	recall_btn.connect("pressed", self, "_on_recall_pressed")
	recall_all_btn.connect("pressed", self, "_on_recall_all_pressed")
	euthanize_btn.connect("pressed", self, "_on_euthanize_pressed")

	confirm_dialog.connect("confirmed", self, "_on_euthanize_confirmed")
	
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
		if exit_btn:
			tb.move_child(undock_btn, exit_btn.get_index())
	
	if tab_ear:
		tab_ear.tab_id = "dispenser"
		tab_ear.icon_text = "DISP"
		tab_ear.connect("tab_clicked", self, "_on_tab_ear_clicked")

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

func _on_mop_pressed():
	emit_signal("use_mop_tool")

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

func populate_pet_roster(pet_list: Array):
	available_pets = pet_list
	breed_dropdown.clear()
	for pet_info in available_pets:
		var pname = pet_info.get("pet_name", pet_info.get("breed_name", "Unknown"))
		breed_dropdown.add_item(pname)

func _on_food_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("spawn_food", get_nozzle_global_position(), false)

func _on_cookie_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("spawn_food", get_nozzle_global_position(), true)

func _on_bottle_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("spawn_bottle", get_nozzle_global_position())

func _on_ball_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("spawn_toy", get_nozzle_global_position(), "ball")

func _on_chew_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("spawn_toy", get_nozzle_global_position(), "chew")

func _on_stuffie_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("spawn_toy", get_nozzle_global_position(), "stuffed_animal")

func _on_boombox_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("spawn_toy", get_nozzle_global_position(), "boombox")



func _on_summon_pressed():
	if AudioManager: AudioManager.play_button_beep()
	var idx = breed_dropdown.selected
	if idx >= 0 and idx < available_pets.size():
		emit_signal("summon_pet", available_pets[idx])

func _on_recall_pressed():
	if AudioManager: AudioManager.play_button_beep()
	var idx = breed_dropdown.selected
	if idx >= 0 and idx < available_pets.size():
		emit_signal("recall_pet", available_pets[idx])

func _on_recall_all_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("recall_all_pets")

func _on_euthanize_pressed():
	if AudioManager: AudioManager.play_button_beep()
	var idx = breed_dropdown.selected
	if idx >= 0 and idx < available_pets.size():
		pending_euthanize_pet = available_pets[idx]
		var pname = pending_euthanize_pet.get("pet_name", "this pet")
		confirm_dialog.dialog_text = "WARNING\n\nAre you sure you want to send '%s' into the void?\nThis will PERMANENTLY DELETE its save file!" % pname

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
