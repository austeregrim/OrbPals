extends Resource

var track_name: String = "5: Star Chiptune"
var seed_value: int = 505
var bpm: float = 145.0
var scale_notes: Array = [293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25, 587.33] # D Dorian
var structure: Array = ["INTRO", "VERSE", "CHORUS", "CHORUS", "OUTRO"]
var chord_progression: Array = [0, 6, 3, 4] # i - VII - IV - V

var lead_instrument: Dictionary = {
	"wave": "square",
	"attack": 0.005,
	"decay": 0.12,
	"vibrato_freq": 10.0,
	"vibrato_depth": 16.0
}

var bass_instrument: Dictionary = {
	"wave": "square",
	"attack": 0.008,
	"decay": 0.15,
	"octave": 0.5
}
