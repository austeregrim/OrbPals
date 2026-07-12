extends Node2D

var PetScene = preload("res://Pet.tscn")
var DebugPanelScene = preload("res://DebugPanel.tscn")
var FoodScene = preload("res://Food.tscn")
var ToyScene = preload("res://Toy.tscn")
var DispenserDeviceScene = preload("res://DispenserDevice.tscn")
var TrashCanScene = preload("res://TrashCan.tscn")

var pet = null
var debug_panel = null
var dispenser_device = null
var trash_can = null
var active_items = []

# Saved states for each breed (breed_name: String -> stats: Dictionary)
var saved_pet_states = {}

func _ready():
	# Cap framerate to 60fps to avoid excessive CPU usage
	Engine.target_fps = 60
	Engine.iterations_per_second = 60
	get_tree().get_root().set_transparent_background(true)
	
	# Position window to cover all connected screens
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
		
	var combined_pos = Vector2(min_x, min_y)
	var combined_size = Vector2(max_x - min_x, max_y - min_y)
	
	OS.window_position = combined_pos
	OS.window_size = combined_size
	OS.window_borderless = true
	OS.set_window_always_on_top(true)
	
	# Spawn Pet
	pet = PetScene.instance()
	# Start in the middle
	pet.global_position = combined_size / 2.0
	add_child(pet)
	pet.connect("returned_to_box", self, "_on_pet_returned_to_box")
	
	# Spawn DebugPanel
	debug_panel = DebugPanelScene.instance()
	add_child(debug_panel)
	debug_panel.visible = false
	
	# Connect DebugPanel signals
	debug_panel.connect("drive_changed", self, "_on_debug_drive_changed")
	debug_panel.connect("decay_toggled", self, "_on_debug_decay_toggled")
	
	# Spawn DispenserDevice
	dispenser_device = DispenserDeviceScene.instance()
	add_child(dispenser_device)
	# Position at top center
	dispenser_device.rect_global_position = Vector2((OS.window_size.x - dispenser_device.rect_size.x) / 2.0, 15.0)
	
	# Spawn TrashCan
	trash_can = TrashCanScene.instance()
	add_child(trash_can)
	
	# Connect Dispenser signals
	dispenser_device.connect("spawn_food", self, "spawn_food")
	dispenser_device.connect("spawn_toy", self, "spawn_toy")
	dispenser_device.connect("breed_selected", self, "_on_breed_selected")
	# Connect DebugPanel decay multiplier signal
	if debug_panel.has_signal("decay_multiplier_changed"):
		debug_panel.connect("decay_multiplier_changed", self, "_on_debug_decay_multiplier_changed")


func _process(_delta):
	# Dynamic click-through calculation
	var polygons = []
	
	# 1. Add Pet's polygon
	if is_instance_valid(pet) and pet.has_method("get_click_polygon"):
		var pet_poly = pet.call("get_click_polygon")
		if pet_poly.size() > 0:
			polygons.append(pet_poly)
			
	# 2. Add DebugPanel's polygon
	if is_instance_valid(debug_panel) and debug_panel.visible:
		# DebugPanel is a CanvasLayer or Control node. Let's assume it's a Control node or returns its rect.
		if debug_panel.has_method("get_panel_rect"):
			var panel_rect = debug_panel.call("get_panel_rect")
			var panel_poly = PoolVector2Array([
				panel_rect.position,
				Vector2(panel_rect.end.x, panel_rect.position.y),
				panel_rect.end,
				Vector2(panel_rect.position.x, panel_rect.end.y)
			])
			polygons.append(panel_poly)
		
	# 2.5 Add DispenserDevice's polygon
	if is_instance_valid(dispenser_device) and dispenser_device.visible:
		if dispenser_device.has_method("get_panel_rect"):
			var disp_rect = dispenser_device.call("get_panel_rect")
			var disp_poly = PoolVector2Array([
				disp_rect.position,
				Vector2(disp_rect.end.x, disp_rect.position.y),
				disp_rect.end,
				Vector2(disp_rect.position.x, disp_rect.end.y)
			])
			polygons.append(disp_poly)
		
	# 3. Add active items' polygons
	for item in active_items:
		if is_instance_valid(item) and item.has_method("get_click_polygon"):
			var item_poly = item.call("get_click_polygon")
			if item_poly.size() > 0:
				polygons.append(item_poly)
				
	# Combine and apply to the OS window
	var combined = combine_polygons(polygons)
	OS.set_window_mouse_passthrough(combined)

func combine_polygons(polygons_list: Array) -> PoolVector2Array:
	var combined = PoolVector2Array()
	if polygons_list.empty():
		# A tiny polygon offscreen
		combined.append(Vector2(-10, -10))
		combined.append(Vector2(-9, -10))
		combined.append(Vector2(-9, -9))
		return combined
		
	for i in range(polygons_list.size()):
		var poly = polygons_list[i]
		if poly.empty():
			continue
		for pt in poly:
			combined.append(pt)
		# Return to start point of this sub-polygon
		combined.append(poly[0])
	return combined

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.scancode:
			KEY_F:
				spawn_food(get_global_mouse_position())
			KEY_T:
				spawn_toy(get_global_mouse_position())
			KEY_C:
				cure_pet(get_global_mouse_position())
			KEY_D:
				toggle_debug_panel()

func spawn_food(pos: Vector2, is_treat: bool = false):
	var food = FoodScene.instance()
	food.is_treat = is_treat
	food.global_position = pos
	add_child(food)
	active_items.append(food)
	# Notify pet to investigate
	if is_instance_valid(pet) and pet.has_method("on_food_spawned"):
		pet.call("on_food_spawned", food)

func spawn_toy(pos: Vector2):
	var toy = ToyScene.instance()
	toy.global_position = pos
	add_child(toy)
	active_items.append(toy)
	# Notify pet to investigate
	if is_instance_valid(pet) and pet.has_method("on_toy_spawned"):
		pet.call("on_toy_spawned", toy)

func cure_pet(_pos: Vector2):
	if is_instance_valid(pet) and pet.has_method("cure"):
		pet.call("cure")

func toggle_debug_panel():
	if is_instance_valid(debug_panel):
		debug_panel.visible = !debug_panel.visible
		if debug_panel.visible:
			debug_panel.call("setup", pet)

func remove_item(item):
	if item in active_items:
		active_items.erase(item)
		if is_instance_valid(item):
			item.queue_free()

func _on_debug_drive_changed(drive_name: String, value: float):
	if is_instance_valid(pet) and pet.has_method("set_drive_value"):
		pet.call("set_drive_value", drive_name, value)

func _on_debug_decay_toggled(decay_enabled: bool):
	if is_instance_valid(pet) and pet.has_method("set_decay_enabled"):
		pet.call("set_decay_enabled", decay_enabled)

func _on_debug_decay_multiplier_changed(value: float):
	if is_instance_valid(pet) and pet.stats:
		pet.stats.decay_multiplier = value

func is_over_trash_can(pos: Vector2) -> bool:
	if is_instance_valid(trash_can) and trash_can.has_method("is_point_inside"):
		return trash_can.call("is_point_inside", pos)
	return false

func _on_pet_returned_to_box(old_breed_name: String):
	if old_breed_name != "" and is_instance_valid(pet) and pet.stats:
		# Save stats of the pet returning to box
		var stats_dict = {
			"hunger": pet.stats.hunger,
			"boredom": pet.stats.boredom,
			"energy": pet.stats.energy,
			"affection": pet.stats.affection,
			"curiosity": pet.stats.curiosity,
			"agitation": pet.stats.agitation,
			"wellness": pet.stats.wellness,
			"toilet": pet.stats.toilet
		}
		
		# If the pet returned to box because it was sick, we heal it fully
		if pet.stats.wellness < 40.0:
			stats_dict["wellness"] = 100.0
			stats_dict["hunger"] = 100.0
			stats_dict["energy"] = 100.0
			stats_dict["affection"] = 100.0
			stats_dict["boredom"] = 100.0
			stats_dict["agitation"] = 0.0

		saved_pet_states[old_breed_name] = stats_dict

func _on_breed_selected(breed_res):
	if is_instance_valid(pet):
		var nozzle_pos = Vector2(OS.window_size.x / 2.0, 150.0)
		if is_instance_valid(dispenser_device):
			nozzle_pos = dispenser_device.get_nozzle_global_position()
		
		# Before switching, save current breed stats
		if pet.active_breed:
			var curr_breed = pet.active_breed.breed_name
			saved_pet_states[curr_breed] = {
				"hunger": pet.stats.hunger,
				"boredom": pet.stats.boredom,
				"energy": pet.stats.energy,
				"affection": pet.stats.affection,
				"curiosity": pet.stats.curiosity,
				"agitation": pet.stats.agitation,
				"wellness": pet.stats.wellness,
				"toilet": pet.stats.toilet
			}
			
		# Check if the breed we are switching TO has a saved state
		var target_breed_name = breed_res.breed_name
		if saved_pet_states.has(target_breed_name):
			pet.pending_restore_stats = saved_pet_states[target_breed_name]
		else:
			# Brand new breed comes out fresh
			pet.pending_restore_stats = {
				"hunger": 100.0,
				"boredom": 100.0,
				"energy": 100.0,
				"affection": 100.0,
				"curiosity": 100.0,
				"agitation": 0.0,
				"wellness": 100.0,
				"toilet": 0.0
			}

		if pet.has_method("return_to_dispenser"):
			pet.call("return_to_dispenser", nozzle_pos, breed_res)
		else:
			pet.call("change_breed", breed_res)
			if is_instance_valid(debug_panel) and debug_panel.visible:
				debug_panel.call("setup", pet)

