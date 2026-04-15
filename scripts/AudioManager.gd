extends Node

## Synthesises all game sounds from raw PCM at startup — no audio files required.
## Autoloaded as "AudioManager". Call AudioManager.play("name") from anywhere.
##
## Sounds with pool_size > 1 are polyphonic (e.g. enemy_hit during explosions).

const SAMPLE_RATE   : int    = 22050
const SETTINGS_PATH : String = "user://settings.cfg"


var _pools    : Dictionary = {}   # name → Array of AudioStreamPlayer
var _pool_idx : Dictionary = {}   # name → round-robin index


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create SFX bus routed through Master so each can be controlled separately
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx : int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

	_add("jump",        _gen_jump(),        1)
	_add("land",        _gen_land(),        1)
	_add("swing",       _gen_swing(),       1)
	_add("player_hit",  _gen_player_hit(),  1)
	_add("player_die",  _gen_player_die(),  1)
	_add("enemy_hit",   _gen_enemy_hit(),   4)   # polyphonic — explosion can hit many at once
	_add("enemy_die",   _gen_enemy_die(),   2)
	_add("throw",       _gen_throw(),       1)
	_add("explode",     _gen_explode(),     2)
	_add("orb_collect", _gen_orb_collect(), 1)
	_add("purchase",    _gen_purchase(),    1)
	_add("slam",        _gen_slam(),        1)
	_add("rest",        _gen_rest(),        1)

	GameData.rested.connect(func() -> void: play("rest"))
	_load_settings()


# ── Public API ─────────────────────────────────────────────────────────────────

func play(name: String, vol_db: float = 0.0) -> void:
	var pool : Array = _pools.get(name, [])
	if pool.is_empty():
		return
	var idx    : int               = _pool_idx.get(name, 0)
	var player : AudioStreamPlayer = pool[idx] as AudioStreamPlayer
	player.volume_db = vol_db
	player.play()
	_pool_idx[name] = (idx + 1) % pool.size()


# ── Registration ───────────────────────────────────────────────────────────────

func _add(name: String, stream: AudioStreamWAV, pool_size: int) -> void:
	var pool : Array = []
	for _i in pool_size:
		var p := AudioStreamPlayer.new()
		p.stream     = stream
		p.bus        = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		pool.append(p)
	_pools[name]    = pool
	_pool_idx[name] = 0


# ── Volume / settings ──────────────────────────────────────────────────────────

func set_master_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(linear, 0.001)))

func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(linear, 0.001)))

func get_master_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))

func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))

func save_settings(master: float, sfx: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sfx", sfx)
	cfg.save(SETTINGS_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	set_master_volume(cfg.get_value("audio", "master", 1.0))
	set_sfx_volume(cfg.get_value("audio", "sfx", 1.0))


# ── WAV helpers ────────────────────────────────────────────────────────────────

func _make_wav(buf: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.data     = buf
	s.format   = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SAMPLE_RATE
	s.stereo   = false
	return s


# ── Sound generators ───────────────────────────────────────────────────────────
# All use phase-accumulation for frequency sweeps (avoids discontinuities).
# Amplitudes are kept ≤ 0.65 so headroom stays comfortable after mixing.

func _gen_jump() -> AudioStreamWAV:
	# Rising sine chirp — 200 → 340 Hz, quick decay
	var n   : int   = int(SAMPLE_RATE * 0.09)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog : float = float(i) / float(n)
		var freq : float = 200.0 + prog * 140.0
		var env  : float = (1.0 - prog) * 0.38
		var s16  : int   = int(clampf(sin(ph) * env * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * freq / SAMPLE_RATE
	return _make_wav(buf)


func _gen_land() -> AudioStreamWAV:
	# Noise thud with fast exponential decay
	var n   : int   = int(SAMPLE_RATE * 0.12)
	var buf := PackedByteArray(); buf.resize(n * 2)
	for i in n:
		var prog : float = float(i) / float(n)
		var env  : float = exp(-prog * 20.0) * 0.52
		var s16  : int   = int(clampf(randf_range(-1.0, 1.0) * env * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _make_wav(buf)


func _gen_swing() -> AudioStreamWAV:
	# Descending whoosh: sine 310 → 160 Hz + noise layer
	var n   : int   = int(SAMPLE_RATE * 0.13)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog  : float = float(i) / float(n)
		var freq  : float = 310.0 - prog * 150.0
		var env   : float = exp(-prog * 11.0) * 0.36
		var samp  : float = sin(ph) * env + randf_range(-1.0, 1.0) * env * 0.45
		var s16   : int   = int(clampf(samp * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * freq / SAMPLE_RATE
	return _make_wav(buf)


func _gen_player_hit() -> AudioStreamWAV:
	# Descending impact tone 440 → 180 Hz with noise crunch
	var n   : int   = int(SAMPLE_RATE * 0.22)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog  : float = float(i) / float(n)
		var freq  : float = 440.0 - prog * 260.0
		var env   : float = exp(-prog * 7.0) * 0.52
		var samp  : float = sin(ph) * env + randf_range(-1.0, 1.0) * (1.0 - prog) * 0.18
		var s16   : int   = int(clampf(samp * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * freq / SAMPLE_RATE
	return _make_wav(buf)


func _gen_player_die() -> AudioStreamWAV:
	# Long descending tone 360 → 50 Hz, slow exponential decay
	var n   : int   = int(SAMPLE_RATE * 0.85)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog : float = float(i) / float(n)
		var freq : float = 360.0 * pow(50.0 / 360.0, prog)
		var env  : float = exp(-prog * 2.2) * 0.50
		var s16  : int   = int(clampf(sin(ph) * env * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * freq / SAMPLE_RATE
	return _make_wav(buf)


func _gen_enemy_hit() -> AudioStreamWAV:
	# Short percussive click — high freq decay + noise
	var n   : int   = int(SAMPLE_RATE * 0.07)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog  : float = float(i) / float(n)
		var env   : float = exp(-prog * 32.0) * 0.55
		var samp  : float = sin(ph) * env * 0.60 + randf_range(-1.0, 1.0) * env * 0.40
		var s16   : int   = int(clampf(samp * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * 680.0 / SAMPLE_RATE
	return _make_wav(buf)


func _gen_enemy_die() -> AudioStreamWAV:
	# Noise burst with descending tone — crumble feel
	var n   : int   = int(SAMPLE_RATE * 0.38)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog  : float = float(i) / float(n)
		var freq  : float = 260.0 - prog * 200.0
		var env   : float = exp(-prog * 5.5) * 0.45
		var samp  : float = sin(ph) * env * 0.50 + randf_range(-1.0, 1.0) * env * 0.50
		var s16   : int   = int(clampf(samp * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * freq / SAMPLE_RATE
	return _make_wav(buf)


func _gen_throw() -> AudioStreamWAV:
	# Soft whoosh — noise with bell envelope
	var n   : int   = int(SAMPLE_RATE * 0.14)
	var buf := PackedByteArray(); buf.resize(n * 2)
	for i in n:
		var prog : float = float(i) / float(n)
		var env  : float = prog * (1.0 - prog) * 4.0 * 0.28
		var s16  : int   = int(clampf(randf_range(-1.0, 1.0) * env * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
	return _make_wav(buf)


func _gen_explode() -> AudioStreamWAV:
	# Deep boom: 52 Hz sine body + white noise, slow decay
	var n   : int   = int(SAMPLE_RATE * 0.52)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog  : float = float(i) / float(n)
		var env   : float = exp(-prog * 4.8) * 0.60
		var samp  : float = sin(ph) * env * 0.55 + randf_range(-1.0, 1.0) * env * 0.45
		var s16   : int   = int(clampf(samp * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * 52.0 / SAMPLE_RATE
	return _make_wav(buf)


func _gen_orb_collect() -> AudioStreamWAV:
	# Ascending three-note arpeggio: 330 → 415 → 523 Hz (minor-ish sparkle)
	var note_frames : int   = int(SAMPLE_RATE * 0.09)
	var n           : int   = note_frames * 3
	var buf               := PackedByteArray(); buf.resize(n * 2)
	var freqs : Array       = [330.0, 415.0, 523.0]
	for note in 3:
		var ph   : float = 0.0
		var freq : float = freqs[note]
		for j in note_frames:
			var prog : float = float(j) / float(note_frames)
			var env  : float = (1.0 - prog) * 0.40
			var s16  : int   = int(clampf(sin(ph) * env * 32767.0, -32768.0, 32767.0))
			var idx  : int   = note * note_frames + j
			buf[idx * 2]     = s16 & 0xFF
			buf[idx * 2 + 1] = (s16 >> 8) & 0xFF
			ph += TAU * freq / SAMPLE_RATE
	return _make_wav(buf)


func _gen_purchase() -> AudioStreamWAV:
	# Two rising tones in sequence: 264 → 330 Hz
	var note_frames : int   = int(SAMPLE_RATE * 0.12)
	var n           : int   = note_frames * 2
	var buf               := PackedByteArray(); buf.resize(n * 2)
	var freqs : Array       = [264.0, 330.0]
	for note in 2:
		var ph   : float = 0.0
		var freq : float = freqs[note]
		for j in note_frames:
			var prog : float = float(j) / float(note_frames)
			var env  : float = (1.0 - prog) * 0.36
			var s16  : int   = int(clampf(sin(ph) * env * 32767.0, -32768.0, 32767.0))
			var idx  : int   = note * note_frames + j
			buf[idx * 2]     = s16 & 0xFF
			buf[idx * 2 + 1] = (s16 >> 8) & 0xFF
			ph += TAU * freq / SAMPLE_RATE
	return _make_wav(buf)


func _gen_slam() -> AudioStreamWAV:
	# Heavy floor impact: 38 Hz deep sine + noise burst
	var n   : int   = int(SAMPLE_RATE * 0.58)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph  : float = 0.0
	for i in n:
		var prog  : float = float(i) / float(n)
		var env   : float = exp(-prog * 3.2) * 0.65
		var samp  : float = sin(ph) * env * 0.68 + randf_range(-1.0, 1.0) * env * 0.32
		var s16   : int   = int(clampf(samp * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph += TAU * 38.0 / SAMPLE_RATE
	return _make_wav(buf)


func _gen_rest() -> AudioStreamWAV:
	# Soft A-minor chord: 220 + 261 + 330 Hz, gentle fade
	var n   : int   = int(SAMPLE_RATE * 0.65)
	var buf := PackedByteArray(); buf.resize(n * 2)
	var ph1 : float = 0.0
	var ph2 : float = 0.0
	var ph3 : float = 0.0
	for i in n:
		var prog : float = float(i) / float(n)
		var env  : float = exp(-prog * 2.8) * 0.40
		var samp : float = (sin(ph1) + sin(ph2) + sin(ph3)) / 3.0 * env
		var s16  : int   = int(clampf(samp * 32767.0, -32768.0, 32767.0))
		buf[i * 2]     = s16 & 0xFF
		buf[i * 2 + 1] = (s16 >> 8) & 0xFF
		ph1 += TAU * 220.0 / SAMPLE_RATE
		ph2 += TAU * 261.0 / SAMPLE_RATE
		ph3 += TAU * 330.0 / SAMPLE_RATE
	return _make_wav(buf)
