extends Resource

var track_name: String = "2: Chill Lounge"
var seed_value: int = 202
var bpm: float = 95.0
var scale_notes: Array = [349.23, 392.00, 440.00, 493.88, 523.25, 587.33, 659.25, 698.46] # F Major 7
var structure: Array = ["INTRO", "VERSE", "CHORUS", "OUTRO"]
var chord_progression: Array = [0, 2, 4, 3] # I - III - V - IV

var lead_instrument: Dictionary = {
	"wave": "sine",
	"attack": 0.04,
	"decay": 0.35,
	"vibrato_freq": 3.0,
	"vibrato_depth": 8.0
}

var bass_instrument: Dictionary = {
	"wave": "sine",
	"attack": 0.05,
	"decay": 0.45,
	"octave": 0.5
}
