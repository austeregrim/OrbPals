extends Control

signal tab_clicked(tab_id)

export(String) var tab_id = ""
export(String) var icon_text = "📁"
export(Color) var accent_color = Color(0.8, 0.8, 1.0, 1.0)

onready var btn = $Button

func _ready():
	if btn:
		btn.text = icon_text
		btn.connect("pressed", self, "_on_button_pressed")
		_apply_custom_style(false)

func _on_button_pressed():
	emit_signal("tab_clicked", tab_id)

func set_active(is_active: bool):
	_apply_custom_style(is_active)

func _apply_custom_style(is_active: bool):
	if not btn:
		return
	if is_active:
		btn.modulate = Color(1.3, 1.3, 1.1, 1.0)
	else:
		btn.modulate = Color(0.9, 0.9, 0.9, 0.95)

func get_tab_rect() -> Rect2:
	if btn:
		return btn.get_global_rect()
	return get_global_rect()
