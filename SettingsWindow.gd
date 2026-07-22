extends Control

signal settings_applied
signal tab_clicked(tab_id)

onready var play_pen_check = $Panel/Margin/VBox/PlayPenRow/PlayPenCheck
onready var screen_dropdown = $Panel/Margin/VBox/ScreenRow/ScreenDropdown
onready var fps_dropdown = $Panel/Margin/VBox/FpsRow/FpsDropdown
onready var window_detection_check = $Panel/Margin/VBox/WindowObstaclesRow/WindowObstaclesCheck

onready var save_btn = $Panel/Margin/VBox/BtnRow/SaveBtn
onready var cancel_btn = $Panel/Margin/VBox/BtnRow/CancelBtn
onready var tab_ear = $PanelTabEar

var fps_values = [30, 60, 90, 120, 0] # 0 represents unlimited

var is_dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	save_btn.connect("pressed", self, "_on_save_pressed")
	cancel_btn.connect("pressed", self, "_on_cancel_pressed")
	
	$Panel/Margin/VBox/TitleBar.connect("gui_input", self, "_on_titlebar_gui_input")
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if tab_ear:
		tab_ear.tab_id = "settings"
		tab_ear.icon_text = "⚙️"
		tab_ear.connect("tab_clicked", self, "_on_tab_ear_clicked")

	setup_ui()

func _on_tab_ear_clicked(tab_id: String):
	emit_signal("tab_clicked", tab_id)

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
		new_pos.x = clamp(new_pos.x, 0, max(0, vp_size.x - $Panel.rect_size.x))
		new_pos.y = clamp(new_pos.y, 0, max(0, vp_size.y - $Panel.rect_size.y))
		$Panel.rect_global_position = new_pos

func open():
	setup_ui()
	visible = true
	var vp_size = get_viewport_rect().size
	$Panel.rect_global_position = (vp_size - $Panel.rect_size) / 2.0
	raise()

func setup_ui():
	# 1. Play Pen Check
	play_pen_check.pressed = Settings.play_pen_mode
	
	# 2. Screen Dropdown
	screen_dropdown.clear()
	screen_dropdown.add_item("All Screens")
	var screen_count = OS.get_screen_count()
	for i in range(screen_count):
		screen_dropdown.add_item("Screen %d" % i)
	
	# Select correct index (Settings.screen_index + 1 because -1 is at index 0)
	screen_dropdown.selected = Settings.screen_index + 1
	
	# 3. FPS Dropdown
	fps_dropdown.clear()
	fps_dropdown.add_item("30 FPS")
	fps_dropdown.add_item("60 FPS")
	fps_dropdown.add_item("90 FPS")
	fps_dropdown.add_item("120 FPS")
	fps_dropdown.add_item("Unlimited")
	
	var fps_idx = fps_values.find(Settings.target_fps)
	if fps_idx != -1:
		fps_dropdown.selected = fps_idx
	else:
		fps_dropdown.selected = 1 # Default to 60 FPS
		
	# 4. Window Obstacles Check
	window_detection_check.pressed = Settings.window_detection

func _on_save_pressed():
	# Update Settings values
	Settings.play_pen_mode = play_pen_check.pressed
	Settings.screen_index = screen_dropdown.selected - 1
	
	var fps_idx = fps_dropdown.selected
	if fps_idx >= 0 and fps_idx < fps_values.size():
		Settings.target_fps = fps_values[fps_idx]
		
	Settings.window_detection = window_detection_check.pressed
	
	# Save to disk
	Settings.save_settings()
	
	# Apply immediately
	emit_signal("settings_applied")
	_close_panel()

func _on_cancel_pressed():
	_close_panel()

func _close_panel():
	var main = get_parent()
	if main and main.has_method("toggle_drawer_panel"):
		main.call("toggle_drawer_panel", "settings")

func get_panel_rect() -> Rect2:
	return $Panel.get_global_rect()

func get_tab_rect() -> Rect2:
	if is_instance_valid(tab_ear):
		return tab_ear.get_tab_rect()
	return Rect2()
