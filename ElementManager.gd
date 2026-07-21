extends Node

enum Element {
	FIRE,
	WATER,
	LIGHTNING,
	WIND,
	ICE,
	NATURE,
	SHADOW,
	LIGHT,
	PLASMA,
	EARTH
}

const ELEMENT_NAMES = [
	"fire", "water", "lightning", "wind", "ice",
	"nature", "shadow", "light", "plasma", "earth"
]

const ELEMENT_COLORS = {
	"fire": Color("ff4500"),
	"water": Color("1e90ff"),
	"lightning": Color("ffd700"),
	"wind": Color("7fffd4"),
	"ice": Color("e0ffff"),
	"nature": Color("32cd32"),
	"shadow": Color("9932cc"),
	"light": Color("fffaca"),
	"plasma": Color("ff00ff"),
	"earth": Color("cd853f")
}

static func get_element_name(type_idx: int) -> String:
	if type_idx >= 0 and type_idx < ELEMENT_NAMES.size():
		return ELEMENT_NAMES[type_idx]
	return "fire"

static func get_element_color(element_name: String) -> Color:
	return ELEMENT_COLORS.get(element_name, Color("ffffff"))
