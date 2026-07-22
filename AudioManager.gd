extends Node

# Audio Settings
var master_volume: float = 0.8
var sfx_volume: float = 0.8
var music_volume: float = 0.8

# Sample Rate & Pool Configuration
const SAMPLE_RATE = 22050
const POOL_SIZE = 12

var sfx_pool: Array = []
var pool_index: int = 0

var music_player: AudioStreamPlayer = null

# Sample Cache
var sample_cache: Dictionary = {}

func _ready():
	# Initialize SFX player pool
	for i in range(POOL_SIZE):
		var asp = AudioStreamPlayer.new()
		asp.bus = "Master"
		add_child(asp)
		sfx_pool.append(asp)
		
	# Initialize Music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	
	_load_volumes_from_settings()

func _load_volumes_from_settings():
	if Settings:
		master_volume = Settings.get("master_volume") if ("master_volume" in Settings) else 0.8
		sfx_volume = Settings.get("sfx_volume") if ("sfx_volume" in Settings) else 0.8
		music_volume = Settings.get("music_volume") if ("music_volume" in Settings) else 0.8

func set_master_volume(val: float):
	master_volume = clamp(val, 0.0, 1.0)
	if Settings and ("master_volume" in Settings):
		Settings.master_volume = master_volume

func set_sfx_volume(val: float):
	sfx_volume = clamp(val, 0.0, 1.0)
	if Settings and ("sfx_volume" in Settings):
		Settings.sfx_volume = sfx_volume

func set_music_volume(val: float):
	music_volume = clamp(val, 0.0, 1.0)
	if Settings and ("music_volume" in Settings):
		Settings.music_volume = music_volume
	if is_instance_valid(music_player):
		music_player.volume_db = linear2db(max(0.001, music_volume * master_volume))

func play_stream(stream: AudioStreamSample, volume_scale: float = 1.0, pitch_scale: float = 1.0):
	if not stream:
		return
	var effective_vol = sfx_volume * master_volume * volume_scale
	if effective_vol <= 0.001:
		return
		
	var asp = sfx_pool[pool_index]
	pool_index = (pool_index + 1) % POOL_SIZE
	
	asp.stream = stream
	asp.volume_db = linear2db(max(0.001, effective_vol))
	asp.pitch_scale = clamp(pitch_scale, 0.1, 4.0)
	asp.play()

# ==============================================================================
# PCM WAVEFORM GENERATOR UTILITIES
# ==============================================================================

# Creates an AudioStreamSample from a PoolByteArray of 16-bit mono PCM data
func create_sample_from_pcm(data: PoolByteArray, loop: bool = false) -> AudioStreamSample:
	var sample = AudioStreamSample.new()
	sample.format = 1 # AudioStreamSample.FORMAT_16_BIT
	sample.mix_rate = SAMPLE_RATE
	sample.stereo = false
	sample.data = data
	if loop:
		sample.loop_mode = 1 # AudioStreamSample.LOOP_FORWARD
		sample.loop_end = data.size() / 2
	return sample


# Dynamic synthesizer generating 16-bit PCM buffer
func synthesize_sound(params: Dictionary) -> AudioStreamSample:
	# Params: duration, wave_type, freq_start, freq_end, attack, decay, noise_ratio, vibrato_freq, vibrato_depth, fm_mult
	var duration: float = params.get("duration", 0.15)
	var wave_type: String = params.get("wave_type", "sine") # "sine", "saw", "square", "triangle", "noise", "fm"
	var freq_start: float = params.get("freq_start", 440.0)
	var freq_end: float = params.get("freq_end", freq_start)
	var attack: float = params.get("attack", 0.01)
	var decay: float = params.get("decay", duration - attack)
	var noise_ratio: float = params.get("noise_ratio", 0.0)
	var vibrato_freq: float = params.get("vibrato_freq", 0.0)
	var vibrato_depth: float = params.get("vibrato_depth", 0.0)
	var fm_mult: float = params.get("fm_mult", 2.0)
	var volume: float = params.get("volume", 0.8)
	var loop: bool = params.get("loop", false)

	var total_samples = int(duration * SAMPLE_RATE)
	var bytes = PoolByteArray()
	bytes.resize(total_samples * 2)

	var phase: float = 0.0
	var fm_phase: float = 0.0

	for i in range(total_samples):
		var t = float(i) / float(SAMPLE_RATE)
		var progress = t / duration

		# Pitch Interpolation
		var current_freq = lerp(freq_start, freq_end, progress)
		if vibrato_freq > 0.0:
			current_freq += sin(t * vibrato_freq * 2.0 * PI) * vibrato_depth

		# Envelope (ADSR / Attack-Decay)
		var env = 0.0
		if t < attack:
			env = t / max(0.001, attack)
		else:
			var d_t = t - attack
			env = max(0.0, 1.0 - (d_t / max(0.001, decay)))
		env = pow(env, 1.5) * volume # exponential taper

		# Waveform calculation
		phase += (current_freq / float(SAMPLE_RATE)) * 2.0 * PI
		if phase > 2.0 * PI:
			phase -= 2.0 * PI

		var raw_val = 0.0
		if wave_type == "sine":
			raw_val = sin(phase)
		elif wave_type == "saw":
			raw_val = (phase / PI) - 1.0
		elif wave_type == "square":
			raw_val = 1.0 if sin(phase) >= 0.0 else -1.0
		elif wave_type == "triangle":
			raw_val = (2.0 / PI) * asin(sin(phase))
		elif wave_type == "fm":
			fm_phase += (current_freq * fm_mult / float(SAMPLE_RATE)) * 2.0 * PI
			raw_val = sin(phase + sin(fm_phase) * 3.0)
		elif wave_type == "noise":
			raw_val = rand_range(-1.0, 1.0)

		# Noise Blend
		if noise_ratio > 0.0:
			raw_val = lerp(raw_val, rand_range(-1.0, 1.0), noise_ratio)

		var final_val = raw_val * env
		var int_val = int(clamp(final_val * 30000.0, -32000.0, 32000.0))

		# Convert to 16-bit Signed Little Endian
		if int_val < 0:
			int_val += 65536
		bytes.set(i * 2, int_val & 0xFF)
		bytes.set(i * 2 + 1, (int_val >> 8) & 0xFF)

	return create_sample_from_pcm(bytes, loop)

# ==============================================================================
# FOLEY SOUND EFFECTS
# ==============================================================================

func play_footstep_walk():
	if not sample_cache.has("footstep_walk"):
		sample_cache["footstep_walk"] = synthesize_sound({
			"duration": 0.12, "wave_type": "triangle",
			"freq_start": 160.0, "freq_end": 70.0,
			"attack": 0.01, "decay": 0.11,
			"noise_ratio": 0.65, "volume": 0.45
		})
	play_stream(sample_cache["footstep_walk"], 0.7, rand_range(0.95, 1.05))

func play_footstep_run():
	if not sample_cache.has("footstep_run"):
		sample_cache["footstep_run"] = synthesize_sound({
			"duration": 0.08, "wave_type": "square",
			"freq_start": 240.0, "freq_end": 90.0,
			"attack": 0.005, "decay": 0.075,
			"noise_ratio": 0.4, "volume": 0.6
		})
	play_stream(sample_cache["footstep_run"], 0.85, rand_range(0.98, 1.12))

func play_digging():
	if not sample_cache.has("digging"):
		sample_cache["digging"] = synthesize_sound({
			"duration": 0.18, "wave_type": "noise",
			"freq_start": 350.0, "freq_end": 180.0,
			"attack": 0.02, "decay": 0.16,
			"noise_ratio": 0.9, "volume": 0.75
		})
	play_stream(sample_cache["digging"], 0.9, rand_range(0.88, 1.15))

func play_ball_bounce(pitch_mod: float = 1.0):
	if not sample_cache.has("ball_bounce"):
		sample_cache["ball_bounce"] = synthesize_sound({
			"duration": 0.14, "wave_type": "sine",
			"freq_start": 180.0, "freq_end": 340.0,
			"attack": 0.008, "decay": 0.13,
			"volume": 0.8
		})
	play_stream(sample_cache["ball_bounce"], 0.85, pitch_mod * rand_range(0.95, 1.08))

func play_mop_sweep():
	if not sample_cache.has("mop_sweep"):
		sample_cache["mop_sweep"] = synthesize_sound({
			"duration": 0.32, "wave_type": "noise",
			"freq_start": 400.0, "freq_end": 200.0,
			"attack": 0.08, "decay": 0.24,
			"noise_ratio": 0.95, "volume": 0.5
		})
	play_stream(sample_cache["mop_sweep"], 0.75, rand_range(0.95, 1.05))

func play_thud():
	if not sample_cache.has("thud"):
		sample_cache["thud"] = synthesize_sound({
			"duration": 0.12, "wave_type": "sine",
			"freq_start": 140.0, "freq_end": 45.0,
			"attack": 0.005, "decay": 0.115,
			"volume": 0.95
		})
	play_stream(sample_cache["thud"], 0.9, rand_range(0.9, 1.1))

func play_button_beep():
	if not sample_cache.has("button_beep"):
		sample_cache["button_beep"] = synthesize_sound({
			"duration": 0.05, "wave_type": "sine",
			"freq_start": 1050.0, "freq_end": 1400.0,
			"attack": 0.004, "decay": 0.046,
			"volume": 0.65
		})
	play_stream(sample_cache["button_beep"], 0.6, 1.0)

func play_ball_pop():
	if not sample_cache.has("ball_pop"):
		sample_cache["ball_pop"] = synthesize_sound({
			"duration": 0.15, "wave_type": "square",
			"freq_start": 600.0, "freq_end": 120.0,
			"attack": 0.002, "decay": 0.148,
			"noise_ratio": 0.6, "volume": 0.9
		})
	play_stream(sample_cache["ball_pop"], 1.0, rand_range(0.95, 1.1))

func play_chew():
	if not sample_cache.has("chew"):
		sample_cache["chew"] = synthesize_sound({
			"duration": 0.11, "wave_type": "fm",
			"freq_start": 520.0, "freq_end": 680.0,
			"attack": 0.01, "decay": 0.1,
			"fm_mult": 3.0, "volume": 0.7
		})
	play_stream(sample_cache["chew"], 0.75, rand_range(0.9, 1.15))

func play_boombox_hit():
	if not sample_cache.has("boombox_hit"):
		sample_cache["boombox_hit"] = synthesize_sound({
			"duration": 0.14, "wave_type": "square",
			"freq_start": 220.0, "freq_end": 80.0,
			"attack": 0.005, "decay": 0.135,
			"volume": 0.85
		})
	play_stream(sample_cache["boombox_hit"], 0.85, rand_range(0.95, 1.05))

func play_boombox_break():
	if not sample_cache.has("boombox_break"):
		sample_cache["boombox_break"] = synthesize_sound({
			"duration": 0.42, "wave_type": "saw",
			"freq_start": 480.0, "freq_end": 60.0,
			"attack": 0.01, "decay": 0.41,
			"noise_ratio": 0.7, "volume": 1.0
		})
	play_stream(sample_cache["boombox_break"], 1.0, 1.0)

# ==============================================================================
# PET EMOTION VOCALIZATIONS
# 4 Versions (0: Sine, 1: Saw/Triangle, 2: FM, 3: Raspy Noise)
# 3 Pitchings (0: Low ~0.82, 1: Med ~1.00, 2: High ~1.22)
# ==============================================================================

func play_pet_emotion(pet_node: Node, emotion: String):
	if not is_instance_valid(pet_node):
		return
		
	var v_version = int(pet_node.get("voice_version")) if ("voice_version" in pet_node) else 0
	var v_pitch_idx = int(pet_node.get("voice_pitch")) if ("voice_pitch" in pet_node) else 1

	var pitch_mult = 1.0
	if v_pitch_idx == 0:
		pitch_mult = 0.82
	elif v_pitch_idx == 2:
		pitch_mult = 1.22

	var wave_type = "sine"
	var noise_r = 0.0
	var fm_m = 2.0

	if v_version == 1:
		wave_type = "triangle"
	elif v_version == 2:
		wave_type = "fm"
		fm_m = 3.5
	elif v_version == 3:
		wave_type = "saw"
		noise_r = 0.35

	var cache_key = "emo_%s_%d_%d" % [emotion, v_version, v_pitch_idx]
	if not sample_cache.has(cache_key):
		sample_cache[cache_key] = _generate_emotion_sample(emotion, wave_type, noise_r, fm_m, pitch_mult)

	var sample = sample_cache[cache_key]
	play_stream(sample, 0.9, rand_range(0.96, 1.04))

func _generate_emotion_sample(emotion: String, wave_type: String, noise_r: float, fm_m: float, pitch_mult: float) -> AudioStreamSample:
	var base_freq = 400.0 * pitch_mult
	var dur = 0.25
	var f_start = base_freq
	var f_end = base_freq
	var att = 0.02
	var dec = 0.23
	var vib_f = 0.0
	var vib_d = 0.0

	if emotion == "yawn":
		dur = 0.6
		f_start = base_freq * 1.3
		f_end = base_freq * 0.7
		att = 0.15
		dec = 0.45
	elif emotion == "giggle":
		dur = 0.28
		f_start = base_freq * 1.5
		f_end = base_freq * 1.8
		vib_f = 16.0
		vib_d = 80.0 * pitch_mult
		att = 0.01
		dec = 0.27
	elif emotion == "question_huh":
		dur = 0.22
		f_start = base_freq * 0.9
		f_end = base_freq * 1.6
		att = 0.02
		dec = 0.20
	elif emotion == "sigh":
		dur = 0.5
		f_start = base_freq * 1.1
		f_end = base_freq * 0.6
		att = 0.05
		dec = 0.45
		noise_r = max(noise_r, 0.4)
	elif emotion == "cry":
		dur = 0.65
		f_start = base_freq * 1.4
		f_end = base_freq * 0.8
		vib_f = 9.0
		vib_d = 110.0 * pitch_mult
		att = 0.05
		dec = 0.6
	elif emotion == "growl":
		dur = 0.45
		f_start = base_freq * 0.45
		f_end = base_freq * 0.4
		vib_f = 24.0
		vib_d = 40.0
		wave_type = "saw"
		att = 0.03
		dec = 0.42
	elif emotion == "bark_roar":
		dur = 0.2
		f_start = base_freq * 1.6
		f_end = base_freq * 0.5
		wave_type = "square"
		att = 0.005
		dec = 0.195
	elif emotion == "whistle":
		dur = 0.35
		f_start = base_freq * 1.8
		f_end = base_freq * 2.2
		wave_type = "sine"
		vib_f = 8.0
		vib_d = 30.0
		att = 0.03
		dec = 0.32
	elif emotion == "sing":
		dur = 0.42
		f_start = base_freq * 1.2
		f_end = base_freq * 2.0
		vib_f = 12.0
		vib_d = 60.0
		att = 0.02
		dec = 0.4

	return synthesize_sound({
		"duration": dur, "wave_type": wave_type,
		"freq_start": f_start, "freq_end": f_end,
		"attack": att, "decay": dec,
		"noise_ratio": noise_r, "vibrato_freq": vib_f,
		"vibrato_depth": vib_d, "fm_mult": fm_m,
		"volume": 0.85
	})

# ==============================================================================
# BOOMBOX MUSIC TRACK GENERATOR
# ==============================================================================

func play_boombox_track(track_index: int):
	if not is_instance_valid(music_player):
		return
	if track_index <= 0 or track_index > 5:
		music_player.stop()
		return

	var cache_key = "music_track_%d" % track_index
	if not sample_cache.has(cache_key):
		sample_cache[cache_key] = _generate_music_track(track_index)

	music_player.stream = sample_cache[cache_key]
	var eff_vol = music_volume * master_volume
	music_player.volume_db = linear2db(max(0.001, eff_vol))
	music_player.play()

func stop_music():
	if is_instance_valid(music_player):
		music_player.stop()

func _generate_music_track(track_id: int) -> AudioStreamSample:
	# Synthesize a ~3.2 second seamless looping synth track
	var duration = 3.2
	var total_samples = int(duration * SAMPLE_RATE)
	var bytes = PoolByteArray()
	bytes.resize(total_samples * 2)

	# Track notes & scale frequencies
	var notes = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25] # C Major
	if track_id == 4: # Minor key for Spooky Groove
		notes = [220.00, 246.94, 261.63, 293.66, 329.63, 349.23, 392.00, 440.00] # A Minor

	var beats_per_sec = 4.0
	if track_id == 5:
		beats_per_sec = 6.0 # Faster for Chiptune

	for i in range(total_samples):
		var t = float(i) / float(SAMPLE_RATE)
		var beat = int(t * beats_per_sec) % 8

		# Select melody note based on track rhythm pattern
		var note_idx = 0
		if track_id == 1: # Orb Bop
			note_idx = (beat * 3 + 2) % notes.size()
		elif track_id == 2: # Chill Lounge
			note_idx = (beat / 2) % notes.size()
		elif track_id == 3: # Pal Dance
			note_idx = (beat * 2) % notes.size()
		elif track_id == 4: # Spooky Groove
			note_idx = (beat * 5) % notes.size()
		elif track_id == 5: # Chiptune
			note_idx = (beat * 7 + 1) % notes.size()

		var freq = notes[note_idx]
		var beat_t = fmod(t * beats_per_sec, 1.0)
		var env = max(0.0, 1.0 - beat_t * 1.4)

		# Lead wave
		var lead_wave = sin(t * freq * 2.0 * PI)
		if track_id == 1 or track_id == 5: # Chiptune square
			lead_wave = 1.0 if sin(t * freq * 2.0 * PI) >= 0.0 else -1.0
		elif track_id == 3: # Saw lead
			lead_wave = (fmod(t * freq, 1.0)) * 2.0 - 1.0

		# Sub-bass rhythm
		var bass_freq = notes[beat % 4] * 0.5
		var bass_wave = sin(t * bass_freq * 2.0 * PI) * 0.6

		var mix_val = (lead_wave * env * 0.5 + bass_wave * 0.5) * 0.6
		var int_val = int(clamp(mix_val * 24000.0, -30000.0, 30000.0))

		if int_val < 0:
			int_val += 65536
		bytes.set(i * 2, int_val & 0xFF)
		bytes.set(i * 2 + 1, (int_val >> 8) & 0xFF)

	return create_sample_from_pcm(bytes, true)
