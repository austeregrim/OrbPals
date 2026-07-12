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

export(float) var hunger_decay_rate = 0.5
export(float) var boredom_decay_rate = 0.25  # Lowered: boredom fills slower
export(float) var energy_decay_rate = 0.3
export(float) var affection_decay_rate = 0.6
export(float) var curiosity_decay_rate = 0.4
export(float) var agitation_decay_rate = 5.0 # cooling down rate
export(float) var wellness_decay_rate = 0.02  # very slow passive; real drops from spoiled food/poop


# Global speed multiplier — scale all decays. 1.0 = normal, 0.5 = half speed
export(float) var decay_multiplier = 1.0

func decay(delta: float):
	var d = delta * decay_multiplier
	hunger = clamp(hunger - hunger_decay_rate * d, 0.0, 100.0)
	boredom = clamp(boredom - boredom_decay_rate * d, 0.0, 100.0)
	energy = clamp(energy - energy_decay_rate * d, 0.0, 100.0)
	affection = clamp(affection - affection_decay_rate * d, 0.0, 100.0)
	curiosity = clamp(curiosity - curiosity_decay_rate * d, 0.0, 100.0)
	agitation = clamp(agitation - agitation_decay_rate * d, 0.0, 100.0)
	toilet = clamp(toilet + 0.1 * d, 0.0, 100.0)
	
	# Wellness only degrades very slowly on its own.
	# Real wellness drops come from: spoiled food (Pet.gd) or poop proximity (Pet.gd).
	wellness = clamp(wellness - wellness_decay_rate * d, 0.0, 100.0)


