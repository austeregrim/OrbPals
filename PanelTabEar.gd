extends Control

signal tab_clicked(tab_id)

export(String) var tab_id = ""
export(String) var icon_text = ""
export(Color) var accent_color = Color(0.8, 0.8, 1.0, 1.0)

onready var btn = $Button
onready var icon_node = $Button/Icon if has_node("Button/Icon") else null

func _ready():
	_update_icon_and_text()
	if btn:
		btn.hint_tooltip = _get_tooltip_text(tab_id)
		if not btn.is_connected("pressed", self, "_on_button_pressed"):
			btn.connect("pressed", self, "_on_button_pressed")
		_apply_custom_style(false)

	if Settings.has_signal("theme_color_changed"):
		if not Settings.is_connected("theme_color_changed", self, "_on_theme_color_changed"):
			Settings.connect("theme_color_changed", self, "_on_theme_color_changed")
	
	_on_theme_color_changed(Settings.theme_color)

func _update_icon_and_text():
	if not btn:
		return
	var tex_path = "res://assets/%s_icon.png" % tab_id
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		if icon_node:
			icon_node.texture = tex
			icon_node.visible = true
		else:
			btn.icon = tex
			btn.expand_icon = true
		btn.text = ""
	else:
		if icon_node:
			icon_node.visible = false
		if icon_text != "" and not icon_text.match("*[\u0080-\uFFFF]*"):
			btn.text = icon_text
		else:
			match tab_id:
				"dispenser": btn.text = "DISP"
				"needs": btn.text = "NEED"
				"genetics": btn.text = "GENE"
				"inventory": btn.text = "INVT"
				"settings": btn.text = "SETT"
				"debug": btn.text = "DBUG"
				_: btn.text = tab_id.left(4).to_upper()


func _on_theme_color_changed(color: Color):
	var safe_color = color
	if Settings.has_method("get_safe_theme_color"):
		safe_color = Settings.call("get_safe_theme_color", color)

	# 1. Update window Panel background
	var parent = get_parent()
	if parent:
		var panel_node = parent.get_node_or_null("Panel")
		if panel_node and panel_node is Panel:
			var bg_col = safe_color.darkened(0.82)
			bg_col.r = max(bg_col.r, 0.08)
			bg_col.g = max(bg_col.g, 0.08)
			bg_col.b = max(bg_col.b, 0.12)
			
			var border_col = safe_color
			var b_lum = border_col.r * 0.299 + border_col.g * 0.587 + border_col.b * 0.114
			if b_lum < 0.30:
				border_col = border_col.lightened(0.35)

			var panel_style = StyleBoxFlat.new()
			panel_style.bg_color = bg_col
			panel_style.border_width_left = 2
			panel_style.border_width_top = 2
			panel_style.border_width_right = 2
			panel_style.border_width_bottom = 2
			panel_style.border_color = border_col
			panel_style.corner_radius_top_left = 8
			panel_style.corner_radius_top_right = 8
			panel_style.corner_radius_bottom_left = 8
			panel_style.corner_radius_bottom_right = 8
			panel_node.add_stylebox_override("panel", panel_style)

	# 2. Style tab ear button
	if btn:
		var ear_style = StyleBoxFlat.new()
		ear_style.bg_color = safe_color
		ear_style.border_width_top = 2
		ear_style.border_width_bottom = 2
		ear_style.border_color = safe_color.lightened(0.2)
		if tab_id == "debug":
			ear_style.border_width_right = 2
			ear_style.corner_radius_top_right = 8
			ear_style.corner_radius_bottom_right = 8
		else:
			ear_style.border_width_left = 2
			ear_style.corner_radius_top_left = 8
			ear_style.corner_radius_bottom_left = 8
		btn.add_stylebox_override("normal", ear_style)
		btn.add_stylebox_override("hover", ear_style)
		btn.add_stylebox_override("pressed", ear_style)
		btn.add_stylebox_override("focus", ear_style)

	# 3. High contrast check for icon / text
	var lum = safe_color.r * 0.299 + safe_color.g * 0.587 + safe_color.b * 0.114
	var icon_col = Color.white if lum < 0.45 else safe_color.darkened(0.65)
	if icon_node and icon_node.visible:
		icon_node.modulate = icon_col

func _get_tooltip_text(id: String) -> String:
	match id:
		"dispenser": return "Care & Pet Dispenser"
		"needs": return "Pet Needs & Stats"
		"genetics": return "Hatchery & Genetics"
		"inventory": return "Inventory & Items"
		"settings": return "Settings"
		"debug": return "Debug Controls"
		_: return id.capitalize()

func _on_button_pressed():
	emit_signal("tab_clicked", tab_id)

func set_active(is_active: bool):
	_apply_custom_style(is_active)

func _apply_custom_style(is_active: bool):
	if not btn:
		return
	if is_active:
		btn.modulate = Color(1.2, 1.2, 1.2, 1.0)
	else:
		btn.modulate = Color(0.75, 0.75, 0.75, 0.9)

func get_tab_rect() -> Rect2:
	if btn:
		return btn.get_global_rect()
	return get_global_rect()

