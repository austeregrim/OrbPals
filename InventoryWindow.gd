extends Control

signal tab_clicked(tab_id)

onready var item_list = $Panel/Margin/VBox/ItemList
onready var deconstruct_btn = $Panel/Margin/VBox/DeconstructBtn
onready var dna_label = $Panel/Margin/VBox/DnaLabel
onready var tab_ear = $PanelTabEar

var is_undocked = false
var is_dragging = false
var drag_offset = Vector2.ZERO

var fragment_names = [
	"adenine", "thymine", "cytosine", "guanine",
	"deoxyribose_sugar", "phosphate_group", "methyl_group", "nucleotide_polymer"
]

var material_breakdown = {
	"ancient_fossil": {"deoxyribose_sugar": 3, "phosphate_group": 2},
	"starlight_crystal": {"adenine": 3, "phosphate_group": 3},
	"bio_slime": {"cytosine": 3, "guanine": 3},
	"glowing_amber": {"thymine": 3, "methyl_group": 2},
	"meteor_shard": {"nucleotide_polymer": 2, "guanine": 2},
	"radiant_spore": {"adenine": 2, "thymine": 2, "deoxyribose_sugar": 2},
	"elastic_rubber": {"methyl_group": 3, "cytosine": 2},
	"gene_fragment": {"nucleotide_polymer": 2, "adenine": 1}
}

onready var vbox = $Panel/Margin/VBox
var undock_btn = null

func _ready():
	_ensure_scroll_container()
	deconstruct_btn.connect("pressed", self, "_on_deconstruct_pressed")
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

	if tab_ear:
		tab_ear.tab_id = "inventory"
		tab_ear.icon_text = "INVT"
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
	refresh()
	var vp_size = get_viewport_rect().size
	$Panel.rect_global_position = (vp_size - $Panel.rect_size) / 2.0
	raise()

func refresh():
	var main = get_parent()
	if not main or not ("inventory" in main):
		return
	
	item_list.clear()
	var inv = main.inventory
	
	# Display genetic fragment counts summary
	var summary_text = "GENETIC FRAGMENTS:\n"
	summary_text += "A: %d | T: %d | C: %d | G: %d\n" % [
		inv.get("adenine", 0), inv.get("thymine", 0),
		inv.get("cytosine", 0), inv.get("guanine", 0)
	]
	summary_text += "Sugar: %d | Phos: %d | Methyl: %d | Poly: %d" % [
		inv.get("deoxyribose_sugar", 0), inv.get("phosphate_group", 0),
		inv.get("methyl_group", 0), inv.get("nucleotide_polymer", 0)
	]
	dna_label.text = summary_text
	
	# Populate raw materials list
	for item_name in inv.keys():
		if item_name in fragment_names:
			continue
		var count = inv[item_name]
		if count > 0:
			item_list.add_item("%s (x%d)" % [item_name.replace("_", " ").capitalize(), count])

func _on_deconstruct_pressed():
	if AudioManager: AudioManager.play_button_beep()
	var selected = item_list.get_selected_items()

	if selected.size() == 0:
		return
	var idx = selected[0]
	var text = item_list.get_item_text(idx)
	var raw_name = text.split(" (x")[0].to_lower().replace(" ", "_")

	
	var main = get_parent()
	if main and ("inventory" in main) and main.inventory.has(raw_name):
		if main.inventory[raw_name] > 0:
			main.inventory[raw_name] -= 1
			if main.inventory[raw_name] <= 0:
				main.inventory.erase(raw_name)
				
			# Award corresponding genetic fragments
			var yield_dict = material_breakdown.get(raw_name, {"adenine": 1, "deoxyribose_sugar": 1})
			for frag in yield_dict.keys():
				main.inventory[frag] = main.inventory.get(frag, 0) + yield_dict[frag]
				
			if main.has_method("save_inventory"):
				main.save_inventory()
			refresh()

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
