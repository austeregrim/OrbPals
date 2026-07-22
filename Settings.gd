extends Node

const VERSION = "1.0.1"

var play_pen_mode: bool = false
var screen_index: int = -1 # -1 = All Screens
var target_fps: int = 60
var window_detection: bool = true
var theme_color: Color = Color.white

signal theme_color_changed(new_color)

# Pet Aging & Mortality Settings
var pet_aging_enabled: bool = true
var pet_mortality_enabled: bool = true
var decay_rate_scale: float = 1.0
var debug_unlocked: bool = false

const SAVE_PATH = "user://settings.cfg"

func _ready():
	load_settings()

func load_settings():
	debug_unlocked = false # Always start hidden on application launch
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		play_pen_mode = config.get_value("settings", "play_pen_mode", false)
		screen_index = config.get_value("settings", "screen_index", -1)
		target_fps = config.get_value("settings", "target_fps", 60)
		window_detection = config.get_value("settings", "window_detection", true)
		pet_aging_enabled = config.get_value("settings", "pet_aging_enabled", true)
		pet_mortality_enabled = config.get_value("settings", "pet_mortality_enabled", true)
		decay_rate_scale = config.get_value("settings", "decay_rate_scale", 1.0)
		theme_color = Color(config.get_value("settings", "theme_color", "ffffff"))
	else:
		save_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("settings", "play_pen_mode", play_pen_mode)
	config.set_value("settings", "screen_index", screen_index)
	config.set_value("settings", "target_fps", target_fps)
	config.set_value("settings", "window_detection", window_detection)
	config.set_value("settings", "pet_aging_enabled", pet_aging_enabled)
	config.set_value("settings", "pet_mortality_enabled", pet_mortality_enabled)
	config.set_value("settings", "decay_rate_scale", decay_rate_scale)
	config.set_value("settings", "theme_color", theme_color.to_html(false))
	config.set_value("settings", "debug_unlocked", false)
	var err = config.save(SAVE_PATH)
	if err != OK:
		print("Error saving settings: ", err)

func get_safe_theme_color(color: Color = theme_color) -> Color:
	var lum = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var safe_c = color
	# 1. Too Dark Check (Luminance < 0.18): Boost minimum RGB so UI elements & boundaries remain visible
	if lum < 0.18:
		var boost = (0.18 - lum) / 0.18
		safe_c.r = max(safe_c.r, 0.22 + boost * 0.15)
		safe_c.g = max(safe_c.g, 0.22 + boost * 0.15)
		safe_c.b = max(safe_c.b, 0.28 + boost * 0.15)
	# 2. Too Bright Check (Luminance > 0.92): Cap max RGB slightly so controls don't blow out
	elif lum > 0.92:
		safe_c.r = min(safe_c.r, 0.88)
		safe_c.g = min(safe_c.g, 0.88)
		safe_c.b = min(safe_c.b, 0.88)
	return safe_c

