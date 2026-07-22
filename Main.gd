extends Node2D

var PetScene = preload("res://Pet.tscn")
var DebugPanelScene = preload("res://DebugPanel.tscn")
var FoodScene = preload("res://Food.tscn")
var ToyScene = preload("res://Toy.tscn")
var DispenserDeviceScene = preload("res://DispenserDevice.tscn")
var TrashCanScene = preload("res://TrashCan.tscn")
var SettingsWindowScene = preload("res://SettingsWindow.tscn")
var GeneticBuilderWindowScene = preload("res://GeneticBuilderWindow.tscn")
var InventoryWindowScene = preload("res://InventoryWindow.tscn")
var NeedsPanelScene = preload("res://NeedsPanel.tscn")

var DesktopWindowManagerScene = preload("res://DesktopWindowManager.gd")
var RelationshipManagerScene = preload("res://RelationshipManager.gd")

var active_pets = [] # Array of active Pet instances on desktop
var debug_panel = null
var dispenser_device = null
var trash_can = null
var active_items = []
var settings_window = null
var genetic_builder_window = null
var inventory_window = null
var needs_panel = null

var playpen_bg = null
var last_passthrough_polygon = PoolVector2Array()
var desktop_window_manager = null
var relationship_manager = null

# Active drawer tab state ("dispenser", "needs", "genetics", "inventory", "settings", "debug", or "")
var active_drawer_tab = ""

# Ordered list of all tab-capable side panels
var side_panels_order = []

# Materials & DNA inventory
var inventory = {}

# Roster of all available pets (presets + custom saved pets)
var pet_roster = []
var saved_pet_states = {}

func _ready():
	# Check Android platform
	if OS.get_name() == "Android":
		Settings.play_pen_mode = true

	desktop_window_manager = DesktopWindowManagerScene.new()
	add_child(desktop_window_manager)
	
	relationship_manager = RelationshipManagerScene.new()
	add_child(relationship_manager)

	get_viewport().connect("size_changed", self, "_on_viewport_size_changed")
	apply_window_settings()

	# Instantiate panels upfront
	_init_drawer_panels()

	# Initialize Pet Roster (presets + user://pets/)
	load_pet_roster()

	# Spawn TrashCan
	trash_can = TrashCanScene.instance()
	add_child(trash_can)

func _init_drawer_panels():
	# 1. Dispenser Device (🚰)
	dispenser_device = DispenserDeviceScene.instance()
	add_child(dispenser_device)
	dispenser_device.connect("spawn_food", self, "spawn_food")
	dispenser_device.connect("spawn_toy", self, "spawn_toy")
	dispenser_device.connect("use_mop_tool", self, "use_mop_tool")
	dispenser_device.connect("summon_pet", self, "summon_pet")
	dispenser_device.connect("recall_pet", self, "recall_pet")
	dispenser_device.connect("recall_all_pets", self, "recall_all_pets")
	dispenser_device.connect("euthanize_pet", self, "euthanize_pet")

	# 2. Needs Panel (🐾)
	needs_panel = NeedsPanelScene.instance()
	add_child(needs_panel)

	# 3. Genetic Builder Window (🥚)
	genetic_builder_window = GeneticBuilderWindowScene.instance()
	add_child(genetic_builder_window)
	genetic_builder_window.connect("pet_hatched", self, "_on_pet_hatched")

	# 4. Inventory Window (📦)
	inventory_window = InventoryWindowScene.instance()
	add_child(inventory_window)

	# 5. Settings Window (⚙️)
	settings_window = SettingsWindowScene.instance()
	add_child(settings_window)
	settings_window.connect("settings_applied", self, "apply_window_settings")

	# 6. Debug Panel (🐛)
	debug_panel = DebugPanelScene.instance()
	add_child(debug_panel)
	debug_panel.connect("drive_changed", self, "_on_debug_drive_changed")
	debug_panel.connect("decay_toggled", self, "_on_debug_decay_toggled")
	if debug_panel.has_signal("decay_multiplier_changed"):
		debug_panel.connect("decay_multiplier_changed", self, "_on_debug_decay_multiplier_changed")

	# Ordered list for vertical tab ear alignment starting 1/20th down
	side_panels_order = [
		{"id": "dispenser", "panel": dispenser_device},
		{"id": "needs", "panel": needs_panel},
		{"id": "genetics", "panel": genetic_builder_window},
		{"id": "inventory", "panel": inventory_window},
		{"id": "settings", "panel": settings_window},
		{"id": "debug", "panel": debug_panel}
	]

	# Connect tab ear signals and make panels visible so tab ears remain visible at all times
	for entry in side_panels_order:
		var p = entry["panel"]
		if p.has_signal("tab_clicked"):
			p.connect("tab_clicked", self, "toggle_drawer_panel")
		p.visible = true

	# Align all panels offscreen initially
	_reposition_all_side_panels(false)

func _reposition_all_side_panels(animated: bool = false):
	var vp = get_viewport_rect().size
	var top_start_y = vp.y * 0.05 # 1/20th down from top!
	var tab_height = 44.0
	var tab_spacing = 6.0

	for i in range(side_panels_order.size()):
		var entry = side_panels_order[i]
		var tab_id = entry["id"]
		var panel = entry["panel"]

		if not is_instance_valid(panel):
			continue

		var tab_y = top_start_y + i * (tab_height + tab_spacing)
		var is_open = (active_drawer_tab == tab_id)

		var target_x = vp.x - panel.rect_size.x if is_open else vp.x
		var target_pos = Vector2(target_x, tab_y)

		# Ensure panel itself stays visible so child PanelTabEar remains visible
		panel.visible = true

		# Update active styling on tab ear
		if "tab_ear" in panel and is_instance_valid(panel.tab_ear):
			panel.tab_ear.set_active(is_open)

		if animated:
			var t = create_tween()
			if t:
				t.tween_property(panel, "rect_global_position", target_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			else:
				panel.rect_global_position = target_pos
		else:
			panel.rect_global_position = target_pos

func toggle_drawer_panel(tab_name: String):
	if active_drawer_tab == tab_name:
		# Close currently open panel
		active_drawer_tab = ""
	else:
		active_drawer_tab = tab_name
		var panel = _get_panel_for_tab(tab_name)
		if panel:
			panel.raise()
			if tab_name == "inventory" and panel.has_method("refresh"):
				panel.call("refresh")
			elif tab_name == "settings" and panel.has_method("setup_ui"):
				panel.call("setup_ui")
			elif tab_name == "debug" and active_pets.size() > 0 and panel.has_method("setup"):
				panel.call("setup", active_pets[0])

	_reposition_all_side_panels(true)

func _get_panel_for_tab(tab_name: String) -> Control:
	for entry in side_panels_order:
		if entry["id"] == tab_name:
			return entry["panel"]
	return null

func _ensure_default_preset_files():
	var dir = Directory.new()
	if not dir.dir_exists("user://pets"):
		dir.make_dir_recursive("user://pets")
		
	var default_presets = {
		"grubby": {
			"pet_id": "grubby", "pet_name": "Grubby", "genetic_seed": 1001, "element_type_idx": 0,
			"body_type": "blob", "primary_color": "ab47bc", "glow_color": "d1c4e9",
			"has_fur": true, "fur_length": 6.0, "fur_color": "ce93d8", "has_antennae": false,
			"antenna_length": 18.0, "antenna_color": "ffff00", "foot_shape": "oval",
			"wing_type": "none", "wing_color": "ffffff", "tail_type": "fox_fluff", "tail_color": "8e24aa",
			"head_feature": "none", "horn_color": "ffffaa", "pattern_type": "belly_patch", "pattern_color": "7b1fa2",
			"pupil_shape": "round", "has_cheeks": true, "cheek_color": "f48fb1",
			"num_segments": 4, "base_radius": 22.0, "segment_spacing": 16.0, "has_limbs": true, "num_limbs": 2,
			"life_stage": "adult", "time_outside_dispenser_seconds": 0.0
		},
		"slinky": {
			"pet_id": "slinky", "pet_name": "Slinky", "genetic_seed": 1002, "element_type_idx": 2,
			"body_type": "slinky", "primary_color": "26c6da", "glow_color": "b2ebf2",
			"has_fur": false, "fur_length": 6.0, "fur_color": "ffffff", "has_antennae": true,
			"antenna_length": 22.0, "antenna_color": "80deea", "foot_shape": "circle",
			"wing_type": "none", "wing_color": "ffffff", "tail_type": "devil_fork", "tail_color": "0097a7",
			"head_feature": "ram_horns", "horn_color": "e0f7fa", "pattern_type": "tiger_stripes", "pattern_color": "006064",
			"pupil_shape": "cat_eye", "has_cheeks": true, "cheek_color": "80deea",
			"num_segments": 6, "base_radius": 20.0, "segment_spacing": 18.0, "has_limbs": true, "num_limbs": 4,
			"life_stage": "adult", "time_outside_dispenser_seconds": 0.0
		},
		"glub": {
			"pet_id": "glub", "pet_name": "Glub", "genetic_seed": 1003, "element_type_idx": 1,
			"body_type": "aquatic", "primary_color": "66bb6a", "glow_color": "c8e6c9",
			"has_fur": false, "fur_length": 6.0, "fur_color": "ffffff", "has_antennae": false,
			"antenna_length": 18.0, "antenna_color": "ffff00", "foot_shape": "oval",
			"wing_type": "fin", "wing_color": "a5d6a7", "tail_type": "beaver_paddle", "tail_color": "388e3c",
			"head_feature": "dino_frill", "horn_color": "e8f5e9", "pattern_type": "leopard_spots", "pattern_color": "1b5e20",
			"pupil_shape": "lizard_eye", "has_cheeks": true, "cheek_color": "a5d6a7",
			"num_segments": 3, "base_radius": 24.0, "segment_spacing": 14.0, "has_limbs": true, "num_limbs": 2,
			"life_stage": "adult", "time_outside_dispenser_seconds": 0.0
		},
		"gonzo": {
			"pet_id": "gonzo", "pet_name": "Gonzo", "genetic_seed": 1004, "element_type_idx": 6,
			"body_type": "alien", "primary_color": "ff4081", "glow_color": "ff80ab",
			"has_fur": true, "fur_length": 9.0, "fur_color": "ff80ab", "has_antennae": true,
			"antenna_length": 24.0, "antenna_color": "ffd54f", "foot_shape": "circle",
			"wing_type": "angel", "wing_color": "f8bbd0", "tail_type": "dragon_spikes", "tail_color": "c2185b",
			"head_feature": "unicorn_horn", "horn_color": "fff9c4", "pattern_type": "galaxy_swirl", "pattern_color": "880e4f",
			"pupil_shape": "spider_eye", "has_cheeks": true, "cheek_color": "ff80ab",
			"num_segments": 5, "base_radius": 22.0, "segment_spacing": 16.0, "has_limbs": true, "num_limbs": 2,
			"life_stage": "adult", "time_outside_dispenser_seconds": 0.0
		}
	}
	
	for pid in default_presets.keys():
		var file_path = "user://pets/" + pid + ".json"
		var f_check = File.new()
		if not f_check.file_exists(file_path):
			var f = File.new()
			if f.open(file_path, File.WRITE) == OK:
				f.store_string(JSON.print(default_presets[pid], "  "))
				f.close()

func load_pet_roster():
	pet_roster.clear()
	_ensure_default_preset_files()
	
	var dir = Directory.new()
	if dir.open("user://pets") == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var file_path = "user://pets/" + file_name
				var f = File.new()
				if f.open(file_path, File.READ) == OK:
					var text = f.get_as_text()
					var res = JSON.parse(text)
					if res.error == OK and res.result is Dictionary:
						var pet_dict = res.result
						pet_dict["type"] = "custom"
						pet_roster.append(pet_dict)
					f.close()
			file_name = dir.get_next()
			
	if is_instance_valid(dispenser_device):
		dispenser_device.call("populate_pet_roster", pet_roster)

func summon_pet(pet_info: Dictionary):
	var pid = pet_info.get("pet_id", "")
	for existing in active_pets:
		if is_instance_valid(existing) and existing.pet_id == pid:
			return # Already active!

	var new_pet = PetScene.instance()
	add_child(new_pet)
	active_pets.append(new_pet)
	
	new_pet.connect("returned_to_box", self, "_on_pet_returned_to_box", [new_pet])
	new_pet.setup_custom_data(pet_info)
		
	var nozzle_pos = Vector2(OS.window_size.x / 2.0, 150.0)
	if is_instance_valid(dispenser_device):
		nozzle_pos = dispenser_device.get_nozzle_global_position()
		
	new_pet.call("emerge_from_dispenser", nozzle_pos)
	
	if is_instance_valid(debug_panel) and debug_panel.visible:
		debug_panel.call("setup", new_pet)

func recall_pet(pet_info: Dictionary):
	var pid = pet_info.get("pet_id", "")
	for target_pet in active_pets:
		if is_instance_valid(target_pet) and target_pet.pet_id == pid:
			var nozzle_pos = dispenser_device.get_nozzle_global_position() if is_instance_valid(dispenser_device) else Vector2(OS.window_size.x / 2.0, 150.0)
			if target_pet.has_method("return_to_dispenser"):
				target_pet.call("return_to_dispenser", nozzle_pos, target_pet.active_breed)
			break

func recall_all_pets():
	var nozzle_pos = dispenser_device.get_nozzle_global_position() if is_instance_valid(dispenser_device) else Vector2(OS.window_size.x / 2.0, 150.0)
	for target_pet in active_pets:
		if is_instance_valid(target_pet):
			if target_pet.has_method("return_to_dispenser"):
				target_pet.call("return_to_dispenser", nozzle_pos, target_pet.active_breed)

func open_genetic_builder():
	toggle_drawer_panel("genetics")

func _on_pet_hatched(pet_data: Dictionary):
	summon_pet(pet_data)

func open_inventory():
	toggle_drawer_panel("inventory")

func open_settings():
	toggle_drawer_panel("settings")

func toggle_debug_panel():
	toggle_drawer_panel("debug")

func _process(_delta):
	if Settings.play_pen_mode or OS.get_name() == "Android":
		return

	var polygons = []
	
	# 1. Active Pets
	for p in active_pets:
		if is_instance_valid(p) and p.has_method("get_click_polygon"):
			var pet_poly = p.call("get_click_polygon")
			if pet_poly.size() > 0:
				polygons.append(pet_poly)

	# 2. Side Panels: Hanging tab ears and active open panel rect
	for entry in side_panels_order:
		var tab_id = entry["id"]
		var panel = entry["panel"]
		if is_instance_valid(panel):
			# Include hanging tab ear rect
			if panel.has_method("get_tab_rect"):
				var tr = panel.call("get_tab_rect")
				if tr.size.x > 0:
					polygons.append(_rect_to_poly(tr))
			
			# If this is the active open panel, include its main panel rect
			if active_drawer_tab == tab_id and panel.has_method("get_panel_rect"):
				polygons.append(_rect_to_poly(panel.call("get_panel_rect")))

	# 3. Popups & ContextMenus
	var popup_nodes = get_children()
	if get_viewport():
		popup_nodes += get_viewport().get_children()
	for child in popup_nodes:
		if is_instance_valid(child) and (child is PopupMenu or child.name.begins_with("ContextMenu")) and child.visible:
			var menu_rect = Rect2(child.rect_global_position, child.rect_size)
			polygons.append(_rect_to_poly(menu_rect))
		
	# 4. Active items
	for item in active_items:
		if is_instance_valid(item) and item.has_method("get_click_polygon"):
			var item_poly = item.call("get_click_polygon")
			if item_poly.size() > 0:
				polygons.append(item_poly)
				
	var combined = combine_polygons(polygons)
	if combined != last_passthrough_polygon:
		last_passthrough_polygon = combined
		OS.set_window_mouse_passthrough(combined)

func _rect_to_poly(r: Rect2) -> PoolVector2Array:
	var g = r.grow(8.0)
	return PoolVector2Array([
		g.position,
		Vector2(g.end.x, g.position.y),
		g.end,
		Vector2(g.position.x, g.end.y)
	])

func combine_polygons(polygons_list: Array) -> PoolVector2Array:
	var combined = PoolVector2Array()
	if polygons_list.empty():
		combined.append(Vector2(-10, -10))
		combined.append(Vector2(-9, -10))
		combined.append(Vector2(-9, -9))
		return combined
		
	var valid_polys = []
	for p in polygons_list:
		if p.size() >= 3:
			valid_polys.append(p)
			
	if valid_polys.empty():
		combined.append(Vector2(-10, -10))
		combined.append(Vector2(-9, -10))
		combined.append(Vector2(-9, -9))
		return combined

	var merged = [valid_polys[0]]
	for i in range(1, valid_polys.size()):
		var to_merge = valid_polys[i]
		var next_merged = []
		for existing in merged:
			var res = Geometry.merge_polygons_2d(existing, to_merge)
			if res.size() == 1:
				to_merge = res[0]
			else:
				next_merged.append(existing)
		next_merged.append(to_merge)
		merged = next_merged

	for i in range(merged.size()):
		var poly = merged[i]
		for pt in poly:
			combined.append(pt)
		combined.append(poly[0])
		if i < merged.size() - 1:
			combined.append(merged[i + 1][0])
			
	return combined

func apply_window_settings():
	Engine.target_fps = Settings.target_fps
	if Settings.target_fps > 0:
		Engine.iterations_per_second = Settings.target_fps
	else:
		Engine.iterations_per_second = 60

	if Settings.play_pen_mode or OS.get_name() == "Android":
		OS.window_borderless = false
		get_tree().get_root().set_transparent_background(false)
		OS.set_window_mouse_passthrough(PoolVector2Array())
		last_passthrough_polygon = PoolVector2Array()
		
		if OS.get_name() != "Android":
			var screen_idx = OS.current_screen
			var screen_pos = OS.get_screen_position(screen_idx)
			var screen_size = OS.get_screen_size(screen_idx)
			OS.window_size = Vector2(1024, 768)
			OS.window_position = screen_pos + (screen_size - Vector2(1024, 768)) / 2.0
	else:
		OS.window_borderless = true
		get_tree().get_root().set_transparent_background(true)
		
		if Settings.screen_index == -1:
			var min_x = 99999.0
			var min_y = 99999.0
			var max_x = -99999.0
			var max_y = -99999.0
			var screen_count = OS.get_screen_count()
			for i in range(screen_count):
				var pos = OS.get_screen_position(i)
				var size = OS.get_screen_size(i)
				min_x = min(min_x, pos.x)
				min_y = min(min_y, pos.y)
				max_x = max(max_x, pos.x + size.x)
				max_y = max(max_y, pos.y + size.y)
			OS.window_position = Vector2(min_x, min_y)
			OS.window_size = Vector2(max_x - min_x, max_y - min_y)
		else:
			var idx = clamp(Settings.screen_index, 0, OS.get_screen_count() - 1)
			OS.window_position = OS.get_screen_position(idx)
			OS.window_size = OS.get_screen_size(idx)
			
	update_playpen_bg()
	call_deferred("_reposition_all_side_panels", false)

func update_playpen_bg():
	if Settings.play_pen_mode or OS.get_name() == "Android":
		OS.set_window_mouse_passthrough(PoolVector2Array())
		last_passthrough_polygon = PoolVector2Array()
		var vp_size = get_viewport_rect().size
		if not playpen_bg:
			playpen_bg = Panel.new()
			playpen_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style = StyleBoxFlat.new()
			style.bg_color = Color("1e1e2e")
			style.border_width_left = 6
			style.border_width_top = 6
			style.border_width_right = 6
			style.border_width_bottom = 6
			style.border_color = Color("45475a")
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_right = 4
			style.corner_radius_bottom_left = 4
			playpen_bg.add_stylebox_override("panel", style)
			add_child(playpen_bg)
			move_child(playpen_bg, 0)
		playpen_bg.rect_position = Vector2.ZERO
		playpen_bg.rect_size = vp_size
		playpen_bg.visible = true
	else:
		if playpen_bg:
			playpen_bg.visible = false

var last_click_time: float = 0.0
var last_click_pos: Vector2 = Vector2.ZERO

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var now = OS.get_ticks_msec() * 0.001
		var pos = event.global_position
		var delta_t = now - last_click_time
		var dist = pos.distance_to(last_click_pos)
		
		if delta_t <= 0.38 and dist <= 30.0:
			# Double click / double tap: walk pet to tap location with dig chance
			last_click_time = 0.0
			for p in active_pets:
				if is_instance_valid(p) and p.has_method("walk_to_tap_location"):
					p.call("walk_to_tap_location", pos, true)
		else:
			# Single click / single tap: Cage glass tap attention!
			last_click_time = now
			last_click_pos = pos
			for p in active_pets:
				if is_instance_valid(p) and p.has_method("on_glass_tapped"):
					p.call("on_glass_tapped", pos)

	elif event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_F:
				spawn_food(get_global_mouse_position())
			KEY_T:
				spawn_toy(get_global_mouse_position())
			KEY_M:
				use_mop_tool(get_global_mouse_position())
			KEY_C:
				cure_pets()
			KEY_D:
				toggle_debug_panel()

func use_mop_tool(pos: Vector2 = Vector2.ZERO):
	if pos == Vector2.ZERO:
		pos = get_global_mouse_position()
	var MopScene = load("res://MopTool.tscn")
	if MopScene:
		var mop = MopScene.instance()
		mop.global_position = pos
		add_child(mop)
		active_items.append(mop)

func spawn_food(pos: Vector2, is_treat: bool = false):
	var food = FoodScene.instance()
	food.is_treat = is_treat
	food.global_position = pos
	add_child(food)
	active_items.append(food)
	for p in active_pets:
		if is_instance_valid(p) and p.has_method("on_food_spawned"):
			p.call("on_food_spawned", food)

func spawn_toy(pos: Vector2):
	var toy = ToyScene.instance()
	toy.global_position = pos
	add_child(toy)
	active_items.append(toy)
	for p in active_pets:
		if is_instance_valid(p) and p.has_method("on_toy_spawned"):
			p.call("on_toy_spawned", toy)

func cure_pets():
	for p in active_pets:
		if is_instance_valid(p) and p.has_method("cure"):
			p.call("cure")

func remove_item(item):
	if item in active_items:
		active_items.erase(item)
		if is_instance_valid(item):
			item.queue_free()

func _on_debug_drive_changed(drive_name: String, value: float):
	for p in active_pets:
		if is_instance_valid(p) and p.has_method("set_drive_value"):
			p.call("set_drive_value", drive_name, value)

func _on_debug_decay_toggled(decay_enabled: bool):
	for p in active_pets:
		if is_instance_valid(p) and p.has_method("set_decay_enabled"):
			p.call("set_decay_enabled", decay_enabled)

func _on_debug_decay_multiplier_changed(value: float):
	for p in active_pets:
		if is_instance_valid(p) and p.stats:
			p.stats.decay_multiplier = value

func is_over_trash_can(pos: Vector2) -> bool:
	if is_instance_valid(trash_can) and trash_can.has_method("is_point_inside"):
		return trash_can.call("is_point_inside", pos)
	return false

func _on_pet_returned_to_box(arg1, arg2 = null):
	var target_pet = arg2 if is_instance_valid(arg2) else (arg1 if (arg1 is Node and is_instance_valid(arg1)) else null)
	if target_pet and active_pets.has(target_pet):
		active_pets.erase(target_pet)
	if is_instance_valid(target_pet):
		target_pet.queue_free()

func _on_viewport_size_changed():
	if Settings.play_pen_mode or OS.get_name() == "Android":
		OS.set_window_mouse_passthrough(PoolVector2Array())
		last_passthrough_polygon = PoolVector2Array()
	update_playpen_bg()
	call_deferred("_reposition_all_side_panels", false)

func euthanize_pet(pet_info: Dictionary):
	var pid = pet_info.get("pet_id", "")
	for target_pet in active_pets:
		if is_instance_valid(target_pet) and target_pet.pet_id == pid:
			target_pet.center_vel = Vector2(0, -2500.0)
			active_pets.erase(target_pet)
			get_tree().create_timer(1.2).connect("timeout", target_pet, "queue_free")
			break
			
	var file_path = "user://pets/" + pid + ".json"
	var dir = Directory.new()
	if dir.file_exists(file_path):
		dir.remove(file_path)
		
	load_pet_roster()
