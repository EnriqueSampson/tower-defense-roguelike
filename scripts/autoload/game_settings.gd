extends Node

## Persisted user preferences (user://settings.cfg).

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_UX := "ux"
const SECTION_GRAPHICS := "graphics"

var master_volume := 0.8
var music_volume := 0.5
var effects_volume := 0.8
var edge_pan_enabled := true
var controls_seen := false
## Real-time sun shadows cost ~5-13 ms on the Iris 550 target; off by default
## (WC3 itself used blob shadows, which creeps keep either way).
var shadows_enabled := false
## Last race picked in the lobby (RaceDefinition.id; empty = default race).
var preferred_race := ""


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
	shadows_enabled = bool(config.get_value(SECTION_GRAPHICS, "shadows", shadows_enabled))
	preferred_race = str(config.get_value(SECTION_UX, "race", preferred_race))
	changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, "master", master_volume)
	config.set_value(SECTION_AUDIO, "music", music_volume)
	config.set_value(SECTION_AUDIO, "effects", effects_volume)
	config.set_value(SECTION_UX, "edge_pan", edge_pan_enabled)
	config.set_value(SECTION_UX, "controls_seen", controls_seen)
	config.set_value(SECTION_GRAPHICS, "shadows", shadows_enabled)
	config.set_value(SECTION_UX, "race", preferred_race)
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


func set_shadows(enabled: bool) -> void:
	shadows_enabled = enabled
	changed.emit()
	save_settings()


func set_preferred_race(race_id: String) -> void:
	preferred_race = race_id
	save_settings()


func mark_controls_seen() -> void:
	controls_seen = true
	save_settings()
