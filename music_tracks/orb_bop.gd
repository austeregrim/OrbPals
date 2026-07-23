extends Resource

var track_name: String = "1: Orb Bop"
var seed_value: int = 101
var bpm: float = 124.0
var scale_notes: Array = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25] # C Major
var structure: Array = ["INTRO", "VERSE", "CHORUS", "VERSE", "CHORUS", "OUTRO"]
var chord_progression: Array = [0, 3, 4, 0] # I - IV - V - I

var lead_instrument: Dictionary = {
	"wave": "square",
	"attack": 0.01,
	"decay": 0.14,
	"vibrato_freq": 5.0,
	"vibrato_depth": 12.0
}

var bass_instrument: Dictionary = {
	"wave": "triangle",
	"attack": 0.02,
	"decay": 0.22,
	"octave": 0.5
}
