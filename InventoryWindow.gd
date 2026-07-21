extends Control

onready var close_btn = $Panel/Margin/VBox/TitleBar/CloseBtn
onready var item_list = $Panel/Margin/VBox/ItemList
onready var deconstruct_btn = $Panel/Margin/VBox/DeconstructBtn
onready var dna_label = $Panel/Margin/VBox/DnaLabel

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

func _ready():
	close_btn.connect("pressed", self, "_on_close_pressed")
	deconstruct_btn.connect("pressed", self, "_on_deconstruct_pressed")
	$Panel/Margin/VBox/TitleBar.connect("gui_input", self, "_on_titlebar_gui_input")
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS

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
	var summary_text = "🧬 GENETIC FRAGMENTS:\n"
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
			item_list.add_item("📦 %s (x%d)" % [item_name.replace("_", " ").capitalize(), count])

func _on_deconstruct_pressed():
	var selected = item_list.get_selected_items()
	if selected.size() == 0:
		return
	var idx = selected[0]
	var text = item_list.get_item_text(idx)
	var raw_name = text.replace("📦 ", "").split(" (x")[0].to_lower().replace(" ", "_")
	
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
				
			refresh()

func _on_close_pressed():
	visible = false

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()
