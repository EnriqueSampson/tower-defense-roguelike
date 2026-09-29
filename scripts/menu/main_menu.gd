extends Control

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options_overlay: Control = %OptionsOverlay
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var effects_slider: HSlider = %EffectsSlider
@onready var edge_pan_check: CheckButton = %EdgePanCheck
@onready var close_options_button: Button = %CloseOptionsButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_open_options)
	close_options_button.pressed.connect(_close_options)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	master_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("master", value))
	music_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("music", value))
	effects_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("effects", value))
	edge_pan_check.toggled.connect(func(pressed: bool) -> void: GameSettings.set_edge_pan(pressed))
	options_overlay.visible = false


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _open_options() -> void:
	master_slider.set_value_no_signal(GameSettings.master_volume)
	music_slider.set_value_no_signal(GameSettings.music_volume)
	effects_slider.set_value_no_signal(GameSettings.effects_volume)
	edge_pan_check.set_pressed_no_signal(GameSettings.edge_pan_enabled)
	options_overlay.visible = true


func _close_options() -> void:
	options_overlay.visible = false
