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
onready var recall_all_btn = $Panel/Margin/VBox/PetHeaderRow/RecallAllBtn
onready var exit_btn = $Panel/Margin/VBox/TitleBar/ExitBtn
onready var confirm_dialog = $ConfirmationDialog
onready var tab_ear = $PanelTabEar
onready var roster_vbox = $Panel/Margin/VBox/RosterScroll/RosterVBox

var bottle_btn = null
var chew_btn = null
var stuffie_btn = null
var boombox_btn = null

var is_undocked = false
var is_dragging = false
var drag_offset = Vector2.ZERO
var pending_euthanize_pet = null

var available_pets = []
onready var vbox = $Panel/Margin/VBox
var undock_btn = null

func _ready():
	_ensure_scroll_container()
	_setup_icon_btn(food_btn, "res://assets/food_bowl.png", "Dispense Food Bowl")
	_setup_icon_btn(cookie_btn, "res://assets/food_treat.png", "Dispense Cookie Treat")
	_setup_icon_btn(ball_btn, "res://assets/toy_ball.png", "Dispense Bouncy Ball")
	_setup_icon_btn(mop_btn, "res://assets/mop.png", "Use Mop Tool")

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
		_setup_icon_btn(bottle_btn, "res://assets/food_bottle.png", "Dispense Feeding Bottle")
		bottle_btn.connect("pressed", self, "_on_bottle_pressed")
		item_row.add_child(bottle_btn)
		item_row.move_child(bottle_btn, 1)

		var item_row2 = HBoxContainer.new()
		item_row2.name = "ItemRow2"
		item_row2.rect_min_size = Vector2(0, 44)
		item_row2.add_constant_override("separation", 6)

		chew_btn = Button.new()
		chew_btn.name = "ChewBtn"
		_setup_icon_btn(chew_btn, "res://assets/toy_chew.png", "Dispense Chew Toy")
		chew_btn.connect("pressed", self, "_on_chew_pressed")
		item_row2.add_child(chew_btn)

		stuffie_btn = Button.new()
		stuffie_btn.name = "StuffieBtn"
		_setup_icon_btn(stuffie_btn, "res://assets/toy_bear.png", "Dispense Stuffed Animal")
		stuffie_btn.connect("pressed", self, "_on_stuffie_pressed")
		item_row2.add_child(stuffie_btn)

		boombox_btn = Button.new()
		boombox_btn.name = "BoomboxBtn"
		_setup_icon_btn(boombox_btn, "res://assets/toy_radio.png", "Dispense Music Boombox")
		boombox_btn.connect("pressed", self, "_on_boombox_pressed")
		item_row2.add_child(boombox_btn)

		vbox.add_child(item_row2)
		vbox.move_child(item_row2, item_row.get_index() + 1)

	if recall_all_btn:
		recall_all_btn.connect("pressed", self, "_on_recall_all_pressed")

	if confirm_dialog:
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

func _setup_icon_btn(btn: Button, icon_path: String, tooltip: String):
	if btn:
		btn.rect_min_size = Vector2(44, 44)
		btn.expand_icon = true
		btn.text = ""
		btn.hint_tooltip = tooltip
		var tex = _load_texture_robust(icon_path)
		if tex:
			btn.icon = tex

func _load_texture_robust(path: String) -> Texture:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture:
			return res
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		var tex = ImageTexture.new()
		tex.create_from_image(img, 7)
		return tex
	return null

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
	if not roster_vbox:
		roster_vbox = get_node_or_null("Panel/Margin/VBox/RosterScroll/RosterVBox")
	if not roster_vbox:
		return

	for c in roster_vbox.get_children():
		c.queue_free()

	var main = get_parent()
	var active_ids = []
	var active_names = []
	if main and "active_pets" in main:
		for ap in main.active_pets:
			if is_instance_valid(ap):
				if ap.pet_id != "":
					active_ids.append(ap.pet_id)
				if ap.pet_name != "":
					active_names.append(ap.pet_name.to_lower())

	for pet_info in available_pets:
		var pid = pet_info.get("pet_id", "")
		var pname = pet_info.get("pet_name", pet_info.get("breed_name", "Unknown"))
		var raw_stage = str(pet_info.get("life_stage", "adult"))
		var stage = raw_stage.capitalize()
		
		var is_active = false
		if pid != "" and active_ids.has(pid):
			is_active = true
		elif pname != "" and active_names.has(pname.to_lower()):
			is_active = true

		var card = PanelContainer.new()
		card.rect_min_size = Vector2(0, 48)

		var hbox = HBoxContainer.new()
		hbox.add_constant_override("separation", 8)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL

		var name_lbl = Label.new()
		name_lbl.text = pname
		name_lbl.add_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		info_vbox.add_child(name_lbl)

		var stage_lbl = Label.new()
		stage_lbl.text = "Stage: " + stage
		stage_lbl.add_color_override("font_color", Color(0.7, 0.85, 1.0, 0.8))
		info_vbox.add_child(stage_lbl)

		hbox.add_child(info_vbox)

		# 3-Year-Old Friendly Visual Status Badge (Sun / Playing vs House / Home)
		var status_badge = PanelContainer.new()
		status_badge.rect_min_size = Vector2(80, 32)
		var badge_style = StyleBoxFlat.new()
		badge_style.set_corner_radius_all(6)
		badge_style.content_margin_left = 6
		badge_style.content_margin_right = 6
		badge_style.content_margin_top = 4
		badge_style.content_margin_bottom = 4

		var status_lbl = Label.new()
		status_lbl.align = Label.ALIGN_CENTER
		status_lbl.valign = Label.VALIGN_CENTER

		if is_active:
			badge_style.bg_color = Color(0.15, 0.45, 0.2, 0.85)
			status_lbl.text = "☀️ Playing"
			status_lbl.add_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			badge_style.bg_color = Color(0.2, 0.25, 0.4, 0.85)
			status_lbl.text = "🏠 Home"
			status_lbl.add_color_override("font_color", Color(0.75, 0.85, 1.0))

		status_badge.add_stylebox_override("panel", badge_style)
		status_badge.add_child(status_lbl)
		hbox.add_child(status_badge)

		# Action Button
		var action_btn = Button.new()
		action_btn.rect_min_size = Vector2(85, 32)
		if is_active:
			action_btn.text = "🏠 Recall"
			action_btn.hint_tooltip = "Send %s back to dispenser" % pname
			action_btn.add_color_override("font_color", Color(1.0, 0.8, 0.5))
			action_btn.connect("pressed", self, "_on_recall_card_pressed", [pet_info])
		else:
			action_btn.text = "🟢 Call Out"
			action_btn.hint_tooltip = "Call %s out into room" % pname
			action_btn.add_color_override("font_color", Color(0.5, 1.0, 0.6))
			action_btn.connect("pressed", self, "_on_summon_card_pressed", [pet_info])
		hbox.add_child(action_btn)

		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.rect_min_size = Vector2(28, 32)
		del_btn.add_color_override("font_color", Color(1.0, 0.35, 0.35))
		del_btn.hint_tooltip = "Permanently delete/euthanize %s" % pname
		del_btn.connect("pressed", self, "_on_euthanize_card_pressed", [pet_info])
		hbox.add_child(del_btn)

		card.add_child(hbox)
		roster_vbox.add_child(card)

func _on_summon_card_pressed(pet_info: Dictionary):
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("summon_pet", pet_info)

func _on_recall_card_pressed(pet_info: Dictionary):
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("recall_pet", pet_info)

func _on_euthanize_card_pressed(pet_info: Dictionary):
	if AudioManager: AudioManager.play_button_beep()
	pending_euthanize_pet = pet_info
	var pname = pending_euthanize_pet.get("pet_name", "this pet")
	if confirm_dialog:
		confirm_dialog.dialog_text = "WARNING\n\nAre you sure you want to send '%s' into the void?\nThis will PERMANENTLY DELETE its save file!" % pname
		confirm_dialog.popup_centered()

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

func _on_recall_all_pressed():
	if AudioManager: AudioManager.play_button_beep()
	emit_signal("recall_all_pets")

func _on_euthanize_confirmed():
	if pending_euthanize_pet != null:
		emit_signal("euthanize_pet", pending_euthanize_pet)
		pending_euthanize_pet = null

func _on_exit_pressed():
	get_tree().quit()

func get_nozzle_global_position() -> Vector2:
	var r = $Panel.get_global_rect()
	if $Panel.visible and r.size.x > 10 and r.position.x >= -50 and r.position.x <= OS.window_size.x:
		return r.position + Vector2(r.size.x / 2.0, r.size.y + 10.0)
		
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
	var vbox_node = margin.get_node_or_null("VBox")
	if vbox_node and not vbox_node.get_parent() is ScrollContainer:
		margin.remove_child(vbox_node)
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		scroll.anchor_right = 1.0
		scroll.anchor_bottom = 1.0
		scroll.size_flags_horizontal = SIZE_EXPAND_FILL
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		scroll.scroll_horizontal_enabled = false
		margin.add_child(scroll)
		scroll.add_child(vbox_node)
		vbox_node.size_flags_horizontal = SIZE_EXPAND_FILL
		vbox_node.size_flags_vertical = SIZE_EXPAND_FILL
