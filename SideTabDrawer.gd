extends Control

signal tab_selected(tab_name)

onready var dispenser_tab = $VBox/DispenserTab
onready var settings_tab = $VBox/SettingsTab
onready var genetics_tab = $VBox/GeneticsTab
onready var inventory_tab = $VBox/InventoryTab
onready var debug_tab = $VBox/DebugTab

var active_tab_name = ""

func _ready():
	dispenser_tab.connect("pressed", self, "_on_tab_pressed", ["dispenser"])
	settings_tab.connect("pressed", self, "_on_tab_pressed", ["settings"])
	genetics_tab.connect("pressed", self, "_on_tab_pressed", ["genetics"])
	inventory_tab.connect("pressed", self, "_on_tab_pressed", ["inventory"])
	debug_tab.connect("pressed", self, "_on_tab_pressed", ["debug"])
	
	update_tab_highlights()

func _on_tab_pressed(tab_name: String):
	emit_signal("tab_selected", tab_name)

func set_active_tab(tab_name: String):
	active_tab_name = tab_name
	update_tab_highlights()

func update_tab_highlights():
	_highlight_button(dispenser_tab, active_tab_name == "dispenser")
	_highlight_button(settings_tab, active_tab_name == "settings")
	_highlight_button(genetics_tab, active_tab_name == "genetics")
	_highlight_button(inventory_tab, active_tab_name == "inventory")
	_highlight_button(debug_tab, active_tab_name == "debug")

func _highlight_button(btn: Button, is_active: bool):
	if is_active:
		btn.modulate = Color(1.2, 1.2, 1.0, 1.0)
	else:
		btn.modulate = Color(0.9, 0.9, 0.9, 0.9)

func get_panel_rect() -> Rect2:
	return $VBox.get_global_rect()
