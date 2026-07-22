extends Resource
class_name PetStats

export(float) var hunger = 100.0
export(float) var boredom = 100.0
export(float) var energy = 100.0
export(float) var affection = 100.0
export(float) var curiosity = 100.0
export(float) var agitation = 0.0
export(float) var wellness = 100.0
export(float) var toilet = 0.0
export(float) var elemental_energy = 0.0 # 0 to 100 meter for elemental power

# Voice customization
export(int) var voice_version = 0 # 0, 1, 2, or 3
export(int) var voice_pitch = 1   # 0 (Low), 1 (Med), 2 (High)

# Learning stats (0.0 to 1.0 confidence)
export(float) var knows_dispenser = 0.0
export(float) var knows_food_button = 0.0
export(float) var knows_toy_button = 0.0
export(float) var knows_inventory = 0.0

export(float) var hunger_decay_rate = 0.028   # ~1 hour to decay completely (slow)
export(float) var boredom_decay_rate = 0.15   # ~11 mins to decay (active)
export(float) var energy_decay_rate = 0.12    # ~13 mins to decay (active)
export(float) var affection_decay_rate = 0.18 # ~9 mins to decay (active)
export(float) var curiosity_decay_rate = 0.20 # ~8 mins to decay (active)
export(float) var agitation_decay_rate = 5.0  # cooling down rate
export(float) var wellness_decay_rate = 0.005  # very slow passive
export(float) var elemental_energy_fill_rate = 0.35 # ~4.5 minutes to fill 0 -> 100

# Genetic Need Decay Rate Modifiers (±5% off normalized standard, e.g. 0.95 to 1.05)
export(Dictionary) var decay_modifiers = {
	"hunger": 1.0,
	"boredom": 1.0,
	"energy": 1.0,
	"affection": 1.0,
	"curiosity": 1.0,
	"wellness": 1.0
}

# Global speed multiplier — scale all decays. 1.0 = normal, 0.5 = half speed
export(float) var decay_multiplier = 1.0

func decay(delta: float, is_moving: bool = false):
	var d = delta * decay_multiplier * Settings.decay_rate_scale
	var current_energy_rate = energy_decay_rate * (2.5 if is_moving else 1.0) * float(decay_modifiers.get("energy", 1.0))
	hunger = clamp(hunger - hunger_decay_rate * float(decay_modifiers.get("hunger", 1.0)) * d, 0.0, 100.0)
	boredom = clamp(boredom - boredom_decay_rate * float(decay_modifiers.get("boredom", 1.0)) * d, 0.0, 100.0)
	energy = clamp(energy - current_energy_rate * d, 0.0, 100.0)
	affection = clamp(affection - affection_decay_rate * float(decay_modifiers.get("affection", 1.0)) * d, 0.0, 100.0)
	curiosity = clamp(curiosity - curiosity_decay_rate * float(decay_modifiers.get("curiosity", 1.0)) * d, 0.0, 100.0)
	agitation = clamp(agitation - agitation_decay_rate * d, 0.0, 100.0)
	toilet = clamp(toilet + 0.01 * d, 0.0, 100.0)
	elemental_energy = clamp(elemental_energy + elemental_energy_fill_rate * d, 0.0, 100.0)
	
	# Wellness degrades very slowly on its own.
	wellness = clamp(wellness - wellness_decay_rate * float(decay_modifiers.get("wellness", 1.0)) * d, 0.0, 100.0)


