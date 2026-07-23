extends Control

signal pet_hatched(pet_data)
signal tab_clicked(tab_id)

onready var frag_grid = $Panel/Margin/VBox/FragGrid
onready var remove_frag_btn = $Panel/Margin/VBox/ActionRow/RemoveBtn
onready var clear_strand_btn = $Panel/Margin/VBox/ActionRow/ClearBtn
onready var tab_ear = $PanelTabEar

onready var strand_list = $Panel/Margin/VBox/StrandList
onready var seed_label = $Panel/Margin/VBox/SeedInfo/SeedLabel
onready var status_label = $Panel/Margin/VBox/SeedInfo/StatusLabel
onready var name_input = $Panel/Margin/VBox/NameRow/NameInput
onready var hatch_btn = $Panel/Margin/VBox/HatchBtn

var is_undocked = false
var is_dragging = false
var drag_offset = Vector2.ZERO

var fragment_types = [
	"adenine", "thymine", "cytosine", "guanine",
	"deoxyribose_sugar", "phosphate_group", "methyl_group", "nucleotide_polymer"
]

var body_strains = ["blob", "slinky", "aquatic", "alien"]
var dna_strand = [] # Array of fragment_type strings
var frag_buttons = {}
onready var vbox = $Panel/Margin/VBox
var undock_btn = null

func _ready():
	_ensure_scroll_container()
	remove_frag_btn.connect("pressed", self, "_on_remove_frag_pressed")
	clear_strand_btn.connect("pressed", self, "_on_clear_strand_pressed")
	hatch_btn.connect("pressed", self, "_on_hatch_pressed")
	
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
	
	_build_fragment_grid_buttons()
		
	if tab_ear:
		tab_ear.tab_id = "genetics"
		tab_ear.icon_text = "GENE"
		tab_ear.connect("tab_clicked", self, "_on_tab_ear_clicked")

	refresh_strand_ui()

func toggle_undock():
	is_undocked = not is_undocked
	_update_undock_button_ui()
	var main = get_parent()
	if not is_undocked and main and main.has_method("_reposition_all_side_panels"):
		main.call("_reposition_all_side_panels", true)

func _update_undock_button_ui():
	if undock_btn:
		undock_btn.text = "[Unpin]" if is_undocked else "[Pin]"


func _build_fragment_grid_buttons():
	if not frag_grid:
		return
	for c in frag_grid.get_children():
		c.queue_free()
	frag_buttons.clear()

	for f_name in fragment_types:
		var btn = Button.new()
		btn.name = "FragBtn_" + f_name
		btn.rect_min_size = Vector2(130, 32)
		btn.text = "[DNA] " + f_name.replace("_", " ").capitalize()
		btn.connect("pressed", self, "_on_frag_btn_pressed", [f_name])
		frag_grid.add_child(btn)
		frag_buttons[f_name] = btn

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


func open():
	visible = true
	var vp_size = get_viewport_rect().size
	$Panel.rect_global_position = (vp_size - $Panel.rect_size) / 2.0
	raise()
	refresh_strand_ui()

func _on_frag_btn_pressed(f_name: String):
	var main = get_parent()
	var inv = main.inventory if (main and "inventory" in main) else {}

	var available_count = inv.get(f_name, 0)
	if available_count < 1:
		status_label.text = "[WARNING] No %s fragments in inventory! Dig up items & deconstruct." % f_name.replace("_", " ").capitalize()
		return

	# Deduct from inventory
	inv[f_name] = available_count - 1
	if main and main.has_method("save_inventory"):
		main.save_inventory()

	dna_strand.append(f_name)
	refresh_strand_ui()

func _on_remove_frag_pressed():
	if dna_strand.size() > 0:
		var removed = dna_strand.pop_back()
		var main = get_parent()
		if main and ("inventory" in main):
			main.inventory[removed] = main.inventory.get(removed, 0) + 1
			if main.has_method("save_inventory"):
				main.save_inventory()
		refresh_strand_ui()

func _on_clear_strand_pressed():
	var main = get_parent()
	for f in dna_strand:
		if main and ("inventory" in main):
			main.inventory[f] = main.inventory.get(f, 0) + 1
	dna_strand.clear()
	if main and main.has_method("save_inventory"):
		main.save_inventory()
	refresh_strand_ui()

func _generate_strand_seed() -> int:
	if dna_strand.size() == 0:
		return 12345678
	var seq_str = ":".join(dna_strand)
	return int(abs(seq_str.hash()))

func refresh_strand_ui():
	var main = get_parent()
	var inv = main.inventory if (main and "inventory" in main) else {}

	# Refresh interactive DNA fragment buttons with live inventory stock
	for f_name in fragment_types:
		if frag_buttons.has(f_name):
			var btn = frag_buttons[f_name]
			var count = inv.get(f_name, 0)
			var nice_name = f_name.replace("_", " ").capitalize()
			btn.text = "[DNA] %s (%d)" % [nice_name, count]
			btn.disabled = (count <= 0)

	strand_list.clear()
	for i in range(dna_strand.size()):
		var f = dna_strand[i]
		strand_list.add_item("Base %d: [DNA] %s" % [i + 1, f.replace("_", " ").capitalize()])

	var seed_val = _generate_strand_seed()
	seed_label.text = "Strand Length: %d Bases | Genetic Seed: #%08X" % [dna_strand.size(), seed_val]
	if dna_strand.size() == 0:
		status_label.text = "Tap available DNA fragment buttons to build your strand!"
	else:
		status_label.text = "Strand ready! Traits remain a mystery until hatching!"

func _on_hatch_pressed():
	if dna_strand.size() == 0:
		status_label.text = "[WARNING] Add at least 1 genetic fragment to assemble the DNA strand!"
		return
		
	var main = get_parent()
	var seed_val = _generate_strand_seed()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var pet_name = name_input.text.strip_edges()
	if pet_name == "":
		pet_name = "OrbPal_" + str(seed_val % 1000)
		
	var strain = body_strains[rng.randi() % body_strains.size()]
	var num_segs = 1 + (rng.randi() % 5)
	var hue = rng.randf()
	var primary_col = Color.from_hsv(hue, 0.75, 0.95)
	var glow_col = Color.from_hsv(fmod(hue + 0.5, 1.0), 0.6, 1.0)
	var fur_col = Color.from_hsv(fmod(hue + 0.25, 1.0), 0.8, 0.9)
	var antenna_col = Color.from_hsv(fmod(hue + 0.75, 1.0), 0.9, 1.0)
	
	# Procedural features derived from seed
	var has_fur = (rng.randf() < 0.4)
	var has_antennae = (rng.randf() < 0.5)
	var elem_idx = rng.randi() % 10 # 10 elemental powers
	
	# Balanced Wing Selection: 50% chance of wings, 50% none
	var wing_type = "none"
	if rng.randf() < 0.5:
		var wing_styles = ["angel", "bat", "butterfly", "fin"]
		wing_type = wing_styles[rng.randi() % wing_styles.size()]

	var tail_options = ["none", "fox_fluff", "devil_fork", "beaver_paddle", "dragon_spikes"]
	var horn_options = ["none", "unicorn_horn", "ram_horns", "dino_frill", "crown_spikes"]
	var pattern_options = ["solid", "tiger_stripes", "leopard_spots", "galaxy_swirl", "belly_patch"]
	var pupil_options = ["round", "cat_eye", "lizard_eye", "spider_eye"]
	
	# Genetic need decay modifiers (±5% off normalized standard: 0.95 to 1.05)
	var decay_mods = {
		"hunger": rng.randf_range(0.95, 1.05),
		"boredom": rng.randf_range(0.95, 1.05),
		"energy": rng.randf_range(0.95, 1.05),
		"affection": rng.randf_range(0.95, 1.05),
		"curiosity": rng.randf_range(0.95, 1.05),
		"wellness": rng.randf_range(0.95, 1.05)
	}
	var bored_eater = (rng.randf() < 0.4)
	
	var pet_id_safe = sanitize_filename(pet_name)
	var pet_data = {
		"pet_id": pet_id_safe,
		"pet_name": pet_name,
		"genetic_seed": seed_val,
		"element_type_idx": elem_idx,
		"body_type": strain,
		"primary_color": primary_col.to_html(),
		"glow_color": glow_col.to_html(),
		"has_fur": has_fur,
		"fur_length": rng.randf_range(4.0, 10.0),
		"fur_color": fur_col.to_html(),
		"has_antennae": has_antennae,
		"antenna_length": rng.randf_range(14.0, 24.0),
		"antenna_color": antenna_col.to_html(),
		"foot_shape": "oval" if rng.randf() < 0.5 else "circle",
		"wing_type": wing_type,
		"wing_color": Color.from_hsv(fmod(hue + 0.1, 1.0), 0.8, 0.9).to_html(),
		"tail_type": tail_options[rng.randi() % tail_options.size()],
		"tail_color": Color.from_hsv(fmod(hue + 0.3, 1.0), 0.85, 0.95).to_html(),
		"head_feature": horn_options[rng.randi() % horn_options.size()],
		"horn_color": Color.from_hsv(fmod(hue + 0.6, 1.0), 0.9, 1.0).to_html(),
		"pattern_type": pattern_options[rng.randi() % pattern_options.size()],
		"pattern_color": primary_col.darkened(0.35).to_html(),
		"pupil_shape": pupil_options[rng.randi() % pupil_options.size()],
		"has_cheeks": (rng.randf() < 0.7),
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
		"life_stage": "infant",
		"time_outside_dispenser_seconds": 0.0,
		"decay_modifiers": decay_mods,
		"bored_eater": bored_eater,
		"voice_version": (rng.randi() % 4),
		"voice_pitch": (rng.randi() % 3),
		"weight": 1.0
	}

	
	if main and main.has_method("save_custom_pet"):
		main.save_custom_pet(pet_data)
		
	emit_signal("pet_hatched", pet_data)
	dna_strand.clear()
	_close_panel()


func _close_panel():
	var main = get_parent()
	if main and main.has_method("toggle_drawer_panel"):
		main.call("toggle_drawer_panel", "genetics")

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()

func get_tab_rect() -> Rect2:
	if is_instance_valid(tab_ear):
		return tab_ear.get_tab_rect()
	return Rect2()

func sanitize_filename(input_name: String) -> String:
	var clean = input_name.strip_edges()
	var valid_str = ""
	for i in range(clean.length()):
		var c = clean[i]
		if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_' or c == '-':
			valid_str += c
		else:
			valid_str += '_'
	while valid_str.find("__") != -1:
		valid_str = valid_str.replace("__", "_")
	valid_str = valid_str.strip_edges("_")
	if valid_str == "":
		valid_str = "orbpal_" + str(OS.get_ticks_msec() % 10000)
	return valid_str.to_lower()

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
