extends Control

signal spawn_food(pos, is_treat)
signal spawn_toy(pos)
signal use_mop_tool
signal summon_pet(pet_info)
signal recall_pet(pet_info)
signal recall_all_pets
signal euthanize_pet(pet_info)
signal open_genetic_builder
signal open_inventory

onready var food_btn = $Panel/Margin/VBox/ItemRow/FoodBtn
onready var cookie_btn = $Panel/Margin/VBox/ItemRow/CookieBtn
onready var ball_btn = $Panel/Margin/VBox/ItemRow/BallBtn
onready var mop_btn = $Panel/Margin/VBox/ItemRow/MopBtn
onready var exit_btn = $Panel/Margin/VBox/ControlRow/ExitBtn
onready var settings_btn = $Panel/Margin/VBox/ControlRow/SettingsBtn
onready var close_btn = $Panel/Margin/VBox/TitleBar/CloseBtn

onready var breed_dropdown = $Panel/Margin/VBox/BreedRow/BreedDropdown
onready var summon_btn = $Panel/Margin/VBox/PetActionRow/SummonBtn
onready var recall_btn = $Panel/Margin/VBox/PetActionRow/RecallBtn
onready var recall_all_btn = $Panel/Margin/VBox/PetActionRow/RecallAllBtn
onready var euthanize_btn = $Panel/Margin/VBox/EuthanizeRow/EuthanizeBtn
onready var confirm_dialog = $ConfirmationDialog

onready var genetic_btn = $Panel/Margin/VBox/HubRow/GeneticBtn
onready var inventory_btn = $Panel/Margin/VBox/HubRow/InventoryBtn

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
var pending_euthanize_pet = null

var available_pets = [] # Array of Dictionary or BreedData resources

var state_names = [
	"IDLE", "WANDER", "CHASE_CURSOR", "CHASE_ITEM", "EATING", 
	"SLEEPING", "AGITATED", "SICK", "RETURNING TO DISPENSER", 
	"EMERGING FROM DISPENSER", "RELIEVING SELF", "SELF DISPENSE",
	"WINDOW SIT", "PLAY WITH PET", "DIGGING", "BEGGING"
]

func _ready():
	food_btn.connect("pressed", self, "_on_food_pressed")
	cookie_btn.connect("pressed", self, "_on_cookie_pressed")
	ball_btn.connect("pressed", self, "_on_ball_pressed")
	mop_btn.connect("pressed", self, "_on_mop_pressed")
	exit_btn.connect("pressed", self, "_on_exit_pressed")
	settings_btn.connect("pressed", self, "_on_settings_pressed")
	close_btn.connect("pressed", self, "_on_exit_pressed")
	
	summon_btn.connect("pressed", self, "_on_summon_pressed")
	recall_btn.connect("pressed", self, "_on_recall_pressed")
	recall_all_btn.connect("pressed", self, "_on_recall_all_pressed")
	euthanize_btn.connect("pressed", self, "_on_euthanize_pressed")
	confirm_dialog.connect("confirmed", self, "_on_euthanize_confirmed")
	
	genetic_btn.connect("pressed", self, "_on_genetic_pressed")
	inventory_btn.connect("pressed", self, "_on_inventory_pressed")
	
	$Panel/Margin/VBox/TitleBar.connect("gui_input", self, "_on_titlebar_gui_input")
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS

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

func _process(_delta):
	var main = get_parent()
	if not main:
		return
		
	# Find pet matching dropdown selection for individual inspection
	var selected_pet = null
	var idx = breed_dropdown.selected
	if idx >= 0 and idx < available_pets.size():
		var sel_info = available_pets[idx]
		var sel_id = sel_info.get("pet_id", "")
		var active_pets = main.get("active_pets")
		if active_pets != null:
			for p in active_pets:
				if is_instance_valid(p) and p.pet_id == sel_id:
					selected_pet = p
					break
					
	if not selected_pet:
		var active_pets = main.get("active_pets")
		if active_pets != null and active_pets.size() > 0:
			selected_pet = active_pets[0]

	if is_instance_valid(selected_pet) and selected_pet.stats:
		hunger_bar.value = selected_pet.stats.hunger
		boredom_bar.value = selected_pet.stats.boredom
		energy_bar.value = selected_pet.stats.energy
		affection_bar.value = selected_pet.stats.affection
		toilet_bar.value = selected_pet.stats.toilet
		wellness_bar.value = selected_pet.stats.wellness
		agitation_val.text = "%.1f%%" % selected_pet.stats.agitation
		
		if selected_pet.current_state >= 0 and selected_pet.current_state < state_names.size():
			state_val.text = state_names[selected_pet.current_state]
			
		breed_val.text = selected_pet.pet_name + " (%s)" % selected_pet.life_stage.capitalize()
	else:
		state_val.text = "DISPENSER RESTING"
		breed_val.text = "None Active"
		hunger_bar.value = 100
		boredom_bar.value = 100
		energy_bar.value = 100
		affection_bar.value = 100
		wellness_bar.value = 100

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

func _on_genetic_pressed():
	emit_signal("open_genetic_builder")

func _on_inventory_pressed():
	emit_signal("open_inventory")

func _on_exit_pressed():
	get_tree().quit()

func _on_settings_pressed():
	var main = get_parent()
	if main and main.has_method("open_settings"):
		main.call("open_settings")

func get_nozzle_global_position() -> Vector2:
	var r = $Panel.get_global_rect()
	return r.position + Vector2(r.size.x / 2.0, r.size.y + 10.0)

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()
