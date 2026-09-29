extends Node

## Procedurally synthesized audio so the MVP ships without third-party sound
## assets. Buses: Master -> Music, Master -> Effects.

const MUSIC_BUS := "Music"
const EFFECTS_BUS := "Effects"
const SAMPLE_RATE := 22050
const EFFECT_PLAYER_COUNT := 12
## Minimum seconds between repeats of the same rapid-fire event.
const RATE_LIMITS := {
	"attack": 0.05,
	"impact": 0.05,
	"death": 0.04,
}

var _streams: Dictionary = {}
var _effect_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _last_played: Dictionary = {}
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_build_library()
	for index in range(EFFECT_PLAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = EFFECTS_BUS
		add_child(player)
		_effect_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.stream = _streams["music_loop"]
	add_child(_music_player)
	GameSettings.changed.connect(apply_volumes)
	apply_volumes()


func _process(delta: float) -> void:
	_clock += delta


func has_event(event_name: String) -> bool:
	return _streams.has(event_name)


func play(event_name: String) -> bool:
	if not _streams.has(event_name):
		return false
	var limit := float(RATE_LIMITS.get(event_name, 0.0))
	if limit > 0.0 and _clock - float(_last_played.get(event_name, -1.0)) < limit:
		return false
	_last_played[event_name] = _clock
	var player := _effect_players[_next_player]
	_next_player = (_next_player + 1) % _effect_players.size()
	player.stream = _streams[event_name]
	player.pitch_scale = randf_range(0.96, 1.04)
	player.play()
	return true


func start_music() -> void:
	if not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(GameSettings.master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), linear_to_db(maxf(GameSettings.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(EFFECTS_BUS), linear_to_db(maxf(GameSettings.effects_volume, 0.0001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), GameSettings.master_volume <= 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), GameSettings.music_volume <= 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(EFFECTS_BUS), GameSettings.effects_volume <= 0.0)


func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


func _build_library() -> void:
	_streams["ui_confirm"] = _tone([660.0, 880.0], 0.09, 0.25, "sine")
	_streams["ui_error"] = _tone([220.0, 180.0], 0.16, 0.3, "square")
	_streams["build"] = _tone([330.0, 440.0, 550.0], 0.14, 0.35, "triangle")
	_streams["upgrade"] = _tone([440.0, 660.0, 880.0, 1100.0], 0.2, 0.35, "triangle")
	_streams["sell"] = _tone([880.0, 660.0, 440.0], 0.16, 0.3, "sine")
	_streams["attack"] = _noise_burst(0.05, 0.18, 2400.0)
	_streams["impact"] = _tone([160.0, 90.0], 0.08, 0.3, "square")
	_streams["death"] = _noise_burst(0.14, 0.32, 900.0)
	_streams["wave_start"] = _tone([392.0, 523.0, 659.0], 0.32, 0.4, "triangle")
	_streams["boss_warning"] = _tone([110.0, 98.0, 110.0, 87.0], 0.6, 0.5, "square")
	_streams["leak"] = _tone([300.0, 150.0], 0.28, 0.45, "square")
	_streams["victory"] = _tone([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.9, 0.5, "triangle")
	_streams["defeat"] = _tone([440.0, 330.0, 262.0, 196.0], 1.1, 0.5, "sine")
	_streams["upgrade_chosen"] = _tone([523.0, 784.0, 1047.0], 0.3, 0.4, "sine")
	# The pad is the most expensive stream to synthesize; headless runs never hear it.
	_streams["music_loop"] = _ambient_loop(8.0) if DisplayServer.get_name() != "headless" else _tone([110.0], 0.1, 0.0, "sine")


## Short arpeggio: each frequency plays for an equal slice of the duration.
func _tone(frequencies: Array, duration: float, amplitude: float, wave_shape: String) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var slice := maxi(1, sample_count / frequencies.size())
	var phase := 0.0
	for index in range(sample_count):
		var frequency: float = frequencies[mini(index / slice, frequencies.size() - 1)]
		phase += frequency / SAMPLE_RATE
		var envelope := minf(1.0, float(index) / (SAMPLE_RATE * 0.005)) * (1.0 - float(index) / sample_count)
		var sample := _oscillate(phase, wave_shape) * amplitude * envelope
		_write_sample(data, index, sample)
	return _make_stream(data, false)


func _noise_burst(duration: float, amplitude: float, cutoff_hz: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff_hz)
	var filtered := 0.0
	var alpha := clampf(cutoff_hz / SAMPLE_RATE * TAU, 0.01, 1.0)
	for index in range(sample_count):
		var noise := rng.randf_range(-1.0, 1.0)
		filtered += alpha * (noise - filtered)
		var envelope := 1.0 - float(index) / sample_count
		_write_sample(data, index, filtered * amplitude * envelope * envelope)
	return _make_stream(data, false)


## Slow chord pad that loops seamlessly.
func _ambient_loop(duration: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var chord := [110.0, 164.81, 196.0, 246.94]
	for index in range(sample_count):
		var t := float(index) / SAMPLE_RATE
		var loop_phase := t / duration
		var sample := 0.0
		for voice_index in range(chord.size()):
			var frequency: float = chord[voice_index]
			var swell := 0.5 + 0.5 * sin(TAU * (loop_phase + voice_index * 0.25))
			sample += sin(TAU * frequency * t) * swell * 0.12
		_write_sample(data, index, sample)
	return _make_stream(data, true)


func _oscillate(phase: float, wave_shape: String) -> float:
	var fraction := fmod(phase, 1.0)
	match wave_shape:
		"square":
			return 1.0 if fraction < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(fraction - 0.5) - 1.0
	return sin(TAU * fraction)


func _write_sample(data: PackedByteArray, index: int, sample: float) -> void:
	var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data.encode_s16(index * 2, value)


func _make_stream(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	return stream
