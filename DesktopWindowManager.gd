extends Node

# Signal emitted when window rectangles update
signal windows_updated(rects)

var window_rects: Array = []
var custom_window_rects: Array = []
var refresh_timer: Timer

func _ready():
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 1.5
	refresh_timer.autostart = true
	refresh_timer.one_shot = false
	refresh_timer.connect("timeout", self, "_update_desktop_windows")
	add_child(refresh_timer)
	
	# Initial update
	_update_desktop_windows()

func add_custom_window_rect(rect: Rect2):
	custom_window_rects.append(rect)
	_update_desktop_windows()

func clear_custom_window_rects():
	custom_window_rects.clear()
	_update_desktop_windows()

func get_window_rects() -> Array:
	if not Settings.window_detection:
		return []
	return window_rects + custom_window_rects

func _update_desktop_windows():
	if not Settings.window_detection:
		window_rects = []
		return

	var new_rects = []
	if OS.get_name() == "X11" or OS.get_name() == "Server":
		# Method 1: GNOME Shell Extension DBus (org.gnome.Shell.Extensions.Windows)
		new_rects = _query_gnome_extension_windows()
		
		# Method 2: Fall back to xwininfo if DBus Extension returned no windows
		if new_rects.empty():
			new_rects = _query_x11_windows()

	window_rects = new_rects
	if new_rects.size() > 0:
		print("[DesktopWindowManager] Tracked ", new_rects.size(), " application window bounds: ", new_rects)
	emit_signal("windows_updated", window_rects)

func _query_gnome_extension_windows() -> Array:
	var rects = []
	var output = []
	var exit_code = OS.execute("gdbus", ["call", "--session", "--dest", "org.gnome.Shell", "--object-path", "/org/gnome/Shell/Extensions/Windows", "--method", "org.gnome.Shell.Extensions.Windows.List"], true, output)
	if exit_code == 0 and output.size() > 0:
		var text = output[0].strip_edges()
		var json_start = text.find("[")
		var json_end = text.rfind("]")
		if json_start != -1 and json_end != -1:
			var json_str = text.substr(json_start, json_end - json_start + 1)
			var parse_result = JSON.parse(json_str)
			if parse_result.error == OK and parse_result.result is Array:
				for win in parse_result.result:
					if win is Dictionary:
						var wm_class = String(win.get("wm_class", ""))
						var title = String(win.get("title", ""))
						if "OrbPals" in title or "Godot" in wm_class or "mutter" in wm_class:
							continue
						var win_id = win.get("id")
						if win_id != null:
							var rect = _get_gnome_window_rect(win_id)
							if rect != Rect2() and rect.size.x > 80 and rect.size.y > 80:
								rects.append(rect)
	return rects

func _get_gnome_window_rect(win_id) -> Rect2:
	var output = []
	var exit_code = OS.execute("gdbus", ["call", "--session", "--dest", "org.gnome.Shell", "--object-path", "/org/gnome/Shell/Extensions/Windows", "--method", "org.gnome.Shell.Extensions.Windows.GetFrameRect", str(win_id)], true, output)
	if exit_code == 0 and output.size() > 0:
		var text = output[0].strip_edges()
		var json_start = text.find("{")
		var json_end = text.rfind("}")
		if json_start != -1 and json_end != -1:
			var json_str = text.substr(json_start, json_end - json_start + 1)
			var parse_result = JSON.parse(json_str)
			if parse_result.error == OK and parse_result.result is Dictionary:
				var dict = parse_result.result
				var x = float(dict.get("x", 0))
				var y = float(dict.get("y", 0))
				var w = float(dict.get("width", 0))
				var h = float(dict.get("height", 0))
				var rect = Rect2(x, y, w, h)
				
				# Filter out screen-spanning / maximized windows on multi-monitor setups
				if _is_screen_spanning_rect(rect):
					return Rect2()
				return rect
	return Rect2()

func _query_x11_windows() -> Array:
	var rects = []
	var output = []
	var exit_code = OS.execute("xwininfo", ["-root", "-tree"], true, output)
	if exit_code == 0 and output.size() > 0:
		var text = output[0]
		var lines = text.split("\n")
		for line in lines:
			if "x" in line and "+" in line and not "(has no name)" in line:
				if "OrbPals" in line or "mutter" in line or "ibus" in line:
					continue
				var rect = _parse_window_rect(line)
				if rect != Rect2() and rect.size.x > 80 and rect.size.y > 80:
					rects.append(rect)
	return rects

func _parse_window_rect(line: String) -> Rect2:
	# Example line snippet: 1920x1048+0+32
	var parts = line.strip_edges().split(" ")
	for part in parts:
		if "x" in part and "+" in part and part.count("+") >= 2:
			var dimensions = part.split("+")
			if dimensions.size() >= 3:
				var size_parts = dimensions[0].split("x")
				if size_parts.size() == 2:
					var w = size_parts[0].to_float()
					var h = size_parts[1].to_float()
					var x = dimensions[1].to_float()
					var y = dimensions[2].to_float()
					var rect = Rect2(x, y, w, h)
					
					if _is_screen_spanning_rect(rect):
						return Rect2()
						
					return rect
	return Rect2()

func _is_screen_spanning_rect(rect: Rect2) -> bool:
	var screen_count = OS.get_screen_count()
	for i in range(screen_count):
		var pos = OS.get_screen_position(i)
		var size = OS.get_screen_size(i)
		
		# Check if rect covers >= 90% of an individual monitor
		if rect.size.x >= size.x * 0.90 and rect.size.y >= size.y * 0.90:
			return true
			
		# Check if rect is a top-panel bar or top monitor edge spanning full width near the monitor top
		if abs(rect.position.y - pos.y) < 45 and rect.size.x >= size.x * 0.90:
			return true
	return false
