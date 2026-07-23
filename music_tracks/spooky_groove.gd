extends Resource

var track_name: String = "4: Spooky Groove"
var seed_value: int = 404
var bpm: float = 110.0
var scale_notes: Array = [220.00, 246.94, 261.63, 293.66, 329.63, 349.23, 392.00, 440.00] # A Minor
var structure: Array = ["INTRO", "VERSE", "CHORUS", "VERSE", "CHORUS", "OUTRO"]
var chord_progression: Array = [0, 5, 3, 4] # i - VI - iv - v

var lead_instrument: Dictionary = {
	"wave": "fm",
	"attack": 0.02,
	"decay": 0.22,
	"vibrato_freq": 8.0,
	"vibrato_depth": 20.0
}

var bass_instrument: Dictionary = {
	"wave": "saw",
	"attack": 0.02,
	"decay": 0.28,
	"octave": 0.5
}
