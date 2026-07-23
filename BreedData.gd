extends Resource
class_name BreedData

export(String) var breed_name = "Generic"
export(float) var head_radius = 18.0
export(int) var num_segments = 5
export(Array, float) var segment_scales = [1.0, 0.9, 0.8, 0.7, 0.6]
export(Color) var primary_color = Color("ab47bc")
export(Color) var secondary_color = Color("ec407a")
export(String, "normal", "cyclops", "slanted") var eye_type = "normal"
export(float) var wobble_speed = 15.0
export(float) var wobble_amplitude = 8.0
export(float) var segment_spacing = 14.0

# Advanced Body structures
export(int) var num_body_segments = 2
export(int) var num_tail_segments = 0
export(bool) var has_limbs = false
export(int) var num_limbs = 0
export(Array, float) var limb_lengths = [12.0, 12.0]

# Voice Genetics
export(int) var voice_version = 0 # 0 (Sine), 1 (Saw/Triangle), 2 (FM), 3 (Raspy)
export(int) var voice_pitch = 1   # 0 (Low), 1 (Medium), 2 (High)

