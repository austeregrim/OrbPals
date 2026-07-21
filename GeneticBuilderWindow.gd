extends Control

signal pet_hatched(pet_data)

onready var close_btn = $Panel/Margin/VBox/TitleBar/CloseBtn
onready var fragment_select_option = $Panel/Margin/VBox/Controls/FragOption
onready var add_frag_btn = $Panel/Margin/VBox/Controls/AddBtn
onready var remove_frag_btn = $Panel/Margin/VBox/Controls/RemoveBtn
onready var clear_strand_btn = $Panel/Margin/VBox/Controls/ClearBtn

onready var strand_list = $Panel/Margin/VBox/StrandList
onready var seed_label = $Panel/Margin/VBox/SeedInfo/SeedLabel
onready var status_label = $Panel/Margin/VBox/SeedInfo/StatusLabel
onready var name_input = $Panel/Margin/VBox/NameRow/NameInput
onready var hatch_btn = $Panel/Margin/VBox/HatchBtn

var is_dragging = false
var drag_offset = Vector2.ZERO

var fragment_types = [
	"adenine", "thymine", "cytosine", "guanine",
	"deoxyribose_sugar", "phosphate_group", "methyl_group", "nucleotide_polymer"
]

var body_strains = ["blob", "slinky", "aquatic", "alien"]
var dna_strand = [] # Array of fragment_type strings

func _ready():
	close_btn.connect("pressed", self, "_on_close_pressed")
	add_frag_btn.connect("pressed", self, "_on_add_frag_pressed")
	remove_frag_btn.connect("pressed", self, "_on_remove_frag_pressed")
	clear_strand_btn.connect("pressed", self, "_on_clear_strand_pressed")
	hatch_btn.connect("pressed", self, "_on_hatch_pressed")
	
	$Panel/Margin/VBox/TitleBar.connect("gui_input", self, "_on_titlebar_gui_input")
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	fragment_select_option.clear()
	for f in fragment_types:
		fragment_select_option.add_item(f.replace("_", " ").capitalize())
		
	refresh_strand_ui()

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
	$Panel.rect_global_position = (vp_size - $Panel.rect_size) / 2.0
	raise()
	refresh_strand_ui()

func _on_add_frag_pressed():
	var idx = fragment_select_option.selected
	if idx >= 0 and idx < fragment_types.size():
		var f_name = fragment_types[idx]
		
		# Check inventory availability
		var main = get_parent()
		var inv = main.inventory if (main and "inventory" in main) else {}
		var custom_count = 0
		if main and main.has_method("get_custom_pets_count"):
			custom_count = main.get_custom_pets_count()
			
		if custom_count > 0 and inv.get(f_name, 0) < 1:
			status_label.text = "⚠️ No %s fragments in inventory! Dig up items & deconstruct." % f_name.replace("_", " ").capitalize()
			return
			
		if custom_count > 0:
			inv[f_name] = inv.get(f_name, 0) - 1
			
		dna_strand.append(f_name)
		refresh_strand_ui()

func _on_remove_frag_pressed():
	if dna_strand.size() > 0:
		var removed = dna_strand.pop_back()
		var main = get_parent()
		if main and ("inventory" in main):
			main.inventory[removed] = main.inventory.get(removed, 0) + 1
		refresh_strand_ui()

func _on_clear_strand_pressed():
	var main = get_parent()
	for f in dna_strand:
		if main and ("inventory" in main):
			main.inventory[f] = main.inventory.get(f, 0) + 1
	dna_strand.clear()
	refresh_strand_ui()

func _generate_strand_seed() -> int:
	if dna_strand.size() == 0:
		return 12345678
	var seq_str = ":".join(dna_strand)
	return int(abs(seq_str.hash()))

func refresh_strand_ui():
	strand_list.clear()
	for i in range(dna_strand.size()):
		var f = dna_strand[i]
		strand_list.add_item("Base %d: 🧬 %s" % [i + 1, f.replace("_", " ").capitalize()])
		
	var seed_val = _generate_strand_seed()
	seed_label.text = "Strand Length: %d Bases | Genetic Seed: #%08X" % [dna_strand.size(), seed_val]
	status_label.text = "Build your DNA strand using fragments. Traits remain a mystery until hatching!"

func _on_hatch_pressed():
	if dna_strand.size() == 0:
		status_label.text = "⚠️ Add at least 1 genetic fragment to assemble the DNA strand!"
		return
		
	var main = get_parent()
	var seed_val = _generate_strand_seed()
	seed(seed_val)
	
	var pet_name = name_input.text.strip_edges()
	if pet_name == "":
		pet_name = "OrbPal_" + str(seed_val % 1000)
		
	var strain = body_strains[randi() % body_strains.size()]
	var num_segs = 1 + (randi() % 5)
	var hue = randf()
	var primary_col = Color.from_hsv(hue, 0.75, 0.95)
	var glow_col = Color.from_hsv(fmod(hue + 0.5, 1.0), 0.6, 1.0)
	var fur_col = Color.from_hsv(fmod(hue + 0.25, 1.0), 0.8, 0.9)
	var antenna_col = Color.from_hsv(fmod(hue + 0.75, 1.0), 0.9, 1.0)
	
	# Procedural features derived from seed
	var has_fur = (randf() < 0.4)
	var has_antennae = (randf() < 0.5)
	var elem_idx = randi() % 10 # 10 elemental powers
	
	var wing_options = ["none", "angel", "bat", "butterfly", "fin"]
	var tail_options = ["none", "fox_fluff", "devil_fork", "beaver_paddle", "dragon_spikes"]
	var horn_options = ["none", "unicorn_horn", "ram_horns", "dino_frill", "crown_spikes"]
	var pattern_options = ["solid", "tiger_stripes", "leopard_spots", "galaxy_swirl", "belly_patch"]
	var pupil_options = ["round", "cat_eye", "lizard_eye", "spider_eye"]
	
	var pet_data = {
		"pet_id": pet_name.to_lower().replace(" ", "_"),
		"pet_name": pet_name,
		"genetic_seed": seed_val,
		"element_type_idx": elem_idx,
		"body_type": strain,
		"primary_color": primary_col.to_html(),
		"glow_color": glow_col.to_html(),
		"has_fur": has_fur,
		"fur_length": rand_range(4.0, 10.0),
		"fur_color": fur_col.to_html(),
		"has_antennae": has_antennae,
		"antenna_length": rand_range(14.0, 24.0),
		"antenna_color": antenna_col.to_html(),
		"foot_shape": "oval" if randf() < 0.5 else "circle",
		"wing_type": wing_options[randi() % wing_options.size()],
		"wing_color": Color.from_hsv(fmod(hue + 0.1, 1.0), 0.8, 0.9).to_html(),
		"tail_type": tail_options[randi() % tail_options.size()],
		"tail_color": Color.from_hsv(fmod(hue + 0.3, 1.0), 0.85, 0.95).to_html(),
		"head_feature": horn_options[randi() % horn_options.size()],
		"horn_color": Color.from_hsv(fmod(hue + 0.6, 1.0), 0.9, 1.0).to_html(),
		"pattern_type": pattern_options[randi() % pattern_options.size()],
		"pattern_color": primary_col.darkened(0.35).to_html(),
		"pupil_shape": pupil_options[randi() % pupil_options.size()],
		"has_cheeks": (randf() < 0.7),
		"cheek_color": Color.from_hsv(fmod(hue + 0.8, 1.0), 0.7, 0.95).to_html(),
		"num_segments": num_segs,
		"base_radius": 22.0,
		"spring_k": 280.0,
		"damping": 14.0,
		"head_radius": 22.0,
		"segment_radius_decay": 0.85,
		"segment_spacing": 18.0,
		"has_limbs": (strain == "blob" or strain == "slinky"),
		"num_limbs": 4 if strain == "slinky" else 2,
		"limb_length": 15.0,
		"limb_width": 4.0,
		"limb_color": primary_col.darkened(0.2).to_html(),
		"eye_type": "standard",
		"eye_color": primary_col.inverted().to_html(),
		"eye_size": 4.0,
		"eye_spacing": 10.0,
		"life_stage": "hatchling",
		"time_outside_dispenser_seconds": 0.0
	}
	
	if main and main.has_method("save_custom_pet"):
		main.save_custom_pet(pet_data)
		
	emit_signal("pet_hatched", pet_data)
	dna_strand.clear()
	visible = false

func _on_close_pressed():
	visible = false

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()
