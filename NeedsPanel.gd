extends Control

signal tab_clicked(tab_id)

onready var prev_pet_btn = $Panel/Margin/VBox/PetSelectorRow/PrevBtn
onready var next_pet_btn = $Panel/Margin/VBox/PetSelectorRow/NextBtn
onready var pet_name_label = $Panel/Margin/VBox/PetSelectorRow/PetNameLabel
onready var state_label = $Panel/Margin/VBox/StateLabel

onready var hunger_bar = $Panel/Margin/VBox/StatusGrid/HungerBar
onready var boredom_bar = $Panel/Margin/VBox/StatusGrid/BoredomBar
onready var energy_bar = $Panel/Margin/VBox/StatusGrid/EnergyBar
onready var affection_bar = $Panel/Margin/VBox/StatusGrid/AffectionBar
onready var toilet_bar = $Panel/Margin/VBox/StatusGrid/ToiletBar
onready var wellness_bar = $Panel/Margin/VBox/WellnessRow/WellnessBar
onready var agitation_label = $Panel/Margin/VBox/AgitationLabel
onready var tab_ear = $PanelTabEar

var selected_pet_idx: int = 0

var state_names = [
	"IDLE", "WANDER", "CHASE_CURSOR", "CHASE_ITEM", "EATING", 
	"SLEEPING", "AGITATED", "SICK", "RETURNING TO DISPENSER", 
	"EMERGING FROM DISPENSER", "RELIEVING SELF", "SELF DISPENSE",
	"WINDOW SIT", "PLAY WITH PET", "DIGGING", "BEGGING"
]

func _ready():
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS
	prev_pet_btn.connect("pressed", self, "_on_prev_pet_pressed")
	next_pet_btn.connect("pressed", self, "_on_next_pet_pressed")
	
	if tab_ear:
		tab_ear.tab_id = "needs"
		tab_ear.icon_text = "🐾"
		tab_ear.connect("tab_clicked", self, "_on_tab_ear_clicked")
		if tab_ear.has_method("_update_icon_and_text"):
			tab_ear.call("_update_icon_and_text")

func _on_tab_ear_clicked(tab_id: String):
	emit_signal("tab_clicked", tab_id)

func _on_prev_pet_pressed():
	selected_pet_idx -= 1
	_clamp_selected_idx()

func _on_next_pet_pressed():
	selected_pet_idx += 1
	_clamp_selected_idx()

func _clamp_selected_idx():
	var main = get_parent()
	if not main:
		return
	var active_pets = main.get("active_pets")
	if active_pets != null and active_pets.size() > 0:
		if selected_pet_idx < 0:
			selected_pet_idx = active_pets.size() - 1
		elif selected_pet_idx >= active_pets.size():
			selected_pet_idx = 0
	else:
		selected_pet_idx = 0

func _process(_delta):
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

		prev_pet_btn.disabled = (valid_pets.size() <= 1)
		next_pet_btn.disabled = (valid_pets.size() <= 1)

		var selected_pet = valid_pets[selected_pet_idx]
		if is_instance_valid(selected_pet) and selected_pet.stats:
			pet_name_label.text = "🐾 %s (%s)" % [selected_pet.pet_name, selected_pet.life_stage.capitalize()]
			
			if selected_pet.current_state >= 0 and selected_pet.current_state < state_names.size():
				state_label.text = "State: " + state_names[selected_pet.current_state]
			else:
				state_label.text = "State: IDLE"
				
			hunger_bar.value = selected_pet.stats.hunger
			boredom_bar.value = selected_pet.stats.boredom
			energy_bar.value = selected_pet.stats.energy
			affection_bar.value = selected_pet.stats.affection
			toilet_bar.value = selected_pet.stats.toilet
			wellness_bar.value = selected_pet.stats.wellness
			agitation_label.text = "Agitation: %.1f%% | Learning: %d%%" % [selected_pet.stats.agitation, int(selected_pet.stats.knows_food_button * 100)]
	else:
		prev_pet_btn.disabled = true
		next_pet_btn.disabled = true
		pet_name_label.text = "🐾 No Active Pets"
		state_label.text = "State: DISPENSER RESTING"
		hunger_bar.value = 100
		boredom_bar.value = 100
		energy_bar.value = 100
		affection_bar.value = 100
		toilet_bar.value = 100
		wellness_bar.value = 100
		agitation_label.text = "Agitation: 0.0% | Learning: 0%"

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()

func get_tab_rect() -> Rect2:
	if is_instance_valid(tab_ear):
		return tab_ear.get_tab_rect()
	return Rect2()
