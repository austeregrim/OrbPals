extends Control

var target_object = null

onready var remove_btn = $Panel/RemoveBtn

func _ready():
	remove_btn.connect("pressed", self, "_on_remove_pressed")
	# Position right at mouse position
	rect_global_position = get_global_mouse_position()

func setup(obj):
	target_object = obj

func _on_remove_pressed():
	if is_instance_valid(target_object):
		var main = target_object.get_parent()
		if main and main.has_method("remove_item"):
			main.call("remove_item", target_object)
		else:
			target_object.queue_free()
	queue_free()

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# Check if clicked outside this panel
		var local_rect = Rect2(rect_global_position, rect_size)
		if not local_rect.has_point(event.global_position):
			# Dismiss
			queue_free()
