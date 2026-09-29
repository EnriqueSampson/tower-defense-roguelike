extends Node

## Persisted user preferences (user://settings.cfg).

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_UX := "ux"

var master_volume := 0.8
var music_volume := 0.5
var effects_volume := 0.8
var edge_pan_enabled := true
var controls_seen := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_volume = clampf(float(config.get_value(SECTION_AUDIO, "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value(SECTION_AUDIO, "music", music_volume)), 0.0, 1.0)
	effects_volume = clampf(float(config.get_value(SECTION_AUDIO, "effects", effects_volume)), 0.0, 1.0)
	edge_pan_enabled = bool(config.get_value(SECTION_UX, "edge_pan", edge_pan_enabled))
	controls_seen = bool(config.get_value(SECTION_UX, "controls_seen", controls_seen))
	changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master", master_volume)
	config.set_value(SECTION_AUDIO, "music", music_volume)
	config.set_value(SECTION_AUDIO, "effects", effects_volume)
	config.set_value(SECTION_UX, "edge_pan", edge_pan_enabled)
	config.set_value(SECTION_UX, "controls_seen", controls_seen)
	config.save(SETTINGS_PATH)


func set_volume(bus: String, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	match bus:
		"master":
			master_volume = clamped
		"music":
			music_volume = clamped
		"effects":
			effects_volume = clamped
	changed.emit()
	save_settings()


func set_edge_pan(enabled: bool) -> void:
	edge_pan_enabled = enabled
	changed.emit()
	save_settings()


func mark_controls_seen() -> void:
	controls_seen = true
	save_settings()
