extends Resource

var track_name: String = "3: Pal Dance"
var seed_value: int = 303
var bpm: float = 132.0
var scale_notes: Array = [196.00, 220.00, 246.94, 293.66, 329.63, 392.00, 440.00, 493.88] # G Pentatonic
var structure: Array = ["INTRO", "VERSE", "CHORUS", "BRIDGE", "CHORUS", "OUTRO"]
var chord_progression: Array = [0, 3, 1, 4] # I - IV - II - V

var lead_instrument: Dictionary = {
	"wave": "saw",
	"attack": 0.01,
	"decay": 0.16,
	"vibrato_freq": 6.0,
	"vibrato_depth": 14.0
}

var bass_instrument: Dictionary = {
	"wave": "square",
	"attack": 0.01,
	"decay": 0.20,
	"octave": 0.5
}
