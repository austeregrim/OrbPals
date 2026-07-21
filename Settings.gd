extends Node

var play_pen_mode: bool = false
var screen_index: int = -1 # -1 = All Screens
var target_fps: int = 60
var window_detection: bool = true

# Pet Aging & Mortality Settings
var pet_aging_enabled: bool = true
var pet_mortality_enabled: bool = true
var decay_rate_scale: float = 1.0

const SAVE_PATH = "user://settings.cfg"

func _ready():
	load_settings()

func load_settings():
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
	var err = config.save(SAVE_PATH)
	if err != OK:
		print("Error saving settings: ", err)

