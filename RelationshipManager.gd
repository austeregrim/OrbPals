extends Node

# Dictionary keyed by pair_key string ("petA_id:petB_id") -> Dictionary {"friendship": float, "romance": float}
var relationships = {}

func _get_pair_key(id_a: String, id_b: String) -> String:
	if id_a < id_b:
		return id_a + ":" + id_b
	else:
		return id_b + ":" + id_a

func get_relationship(id_a: String, id_b: String) -> Dictionary:
	var key = _get_pair_key(id_a, id_b)
	if not relationships.has(key):
		relationships[key] = {
			"friendship": 50.0,
			"romance": 0.0
		}
	return relationships[key]

func modify_relationship(id_a: String, id_b: String, friendship_delta: float, romance_delta: float):
	var rel = get_relationship(id_a, id_b)
	rel["friendship"] = clamp(rel["friendship"] + friendship_delta, 0.0, 100.0)
	rel["romance"] = clamp(rel["romance"] + romance_delta, 0.0, 100.0)

func get_status_text(id_a: String, id_b: String) -> String:
	var rel = get_relationship(id_a, id_b)
	var f = rel["friendship"]
	var r = rel["romance"]
	
	if r >= 75.0:
		return "Soulmates 💕"
	elif r >= 40.0:
		return "Sweethearts ❤️"
	elif f >= 80.0:
		return "Best Friends 🌟"
	elif f >= 60.0:
		return "Friends 😊"
	elif f <= 20.0:
		return "Rivals 😠"
	else:
		return "Acquaintances 👋"
