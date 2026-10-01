extends Control

## The title screen of Frozen Gate TD LIVE!, styled as the opening of a
## live broadcast.

## What the System says while the menu idles.
const SYSTEM_LINES: Array[String] = [
	"Welcome, builder. Please keep your limbs inside the arena at all times.",
	"Reminder: the gate is shared. So is the blame.",
	"Tonight's contestants have a 3% survival rate. We rounded up.",
	"Towers are non-refundable. Well. Seventy-five percent refundable.",
	"Our lawyers would like you to know the creeps are 'mostly' fictional.",
	"Viewer tip: build a maze. The audience hates a straight line.",
	"Sponsors are watching. Try to die somewhere photogenic.",
	"Position 9 is not a punishment. It is an opportunity. It is also a punishment.",
]

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var options_overlay: Control = %OptionsOverlay
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var effects_slider: HSlider = %EffectsSlider
@onready var edge_pan_check: CheckButton = %EdgePanCheck
@onready var close_options_button: Button = %CloseOptionsButton
@onready var system_line: SystemLowerThird = %SystemLine


func _ready() -> void:
	theme = BroadcastTheme.build()
	BroadcastTheme.headline(%Title, 96, BroadcastTheme.GOLD)
	BroadcastTheme.headline(%TitleLive, 72, BroadcastTheme.LIVE_RED, Color(BroadcastTheme.GOLD, 0.9))
	%TitleLive.rotation_degrees = -6.0
	%TitleLive.pivot_offset = Vector2(0, 60)
	BroadcastTheme.headline(%Kicker, 22, BroadcastTheme.CYAN, Color(0, 0, 0, 0.6))
	BroadcastTheme.headline(%Tagline, 24, BroadcastTheme.TEXT)
	BroadcastTheme.headline(%OptionsTitle, 30, BroadcastTheme.GOLD)
	%Episode.add_theme_color_override("font_color", BroadcastTheme.MUTED)
	%Version.text = "v%s" % BuildInfo.VERSION
	%Version.add_theme_color_override("font_color", BroadcastTheme.MUTED)
	system_line.set_lines(SYSTEM_LINES)
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_open_options)
	close_options_button.pressed.connect(_close_options)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	quit_button.mouse_entered.connect(func() -> void: system_line.say("Leaving so soon? The audience will remember this."))
	play_button.mouse_entered.connect(func() -> void: system_line.say("Excellent choice. Legally, we must say that."))
	master_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("master", value))
	music_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("music", value))
	effects_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("effects", value))
	edge_pan_check.toggled.connect(func(pressed: bool) -> void: GameSettings.set_edge_pan(pressed))
	options_overlay.visible = false
	_build_arena_card()
	play_button.grab_focus.call_deferred()


## "Tonight's arena": the battlefield drawn from the layout, in a studio frame.
func _build_arena_card() -> void:
	var card := PanelContainer.new()
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -470.0
	card.offset_right = -72.0
	card.offset_top = -270.0
	card.offset_bottom = 190.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	move_child(card, %OptionsOverlay.get_index())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var heading := Label.new()
	heading.text = "TONIGHT'S ARENA"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	BroadcastTheme.headline(heading, 26, BroadcastTheme.CYAN, Color(0, 0, 0, 0.6))
	column.add_child(heading)
	var arena := TextureRect.new()
	arena.texture = ImageTexture.create_from_image(ClassicWintermaulLayout.preview_image())
	arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(arena)
	var caption := Label.new()
	caption.text = "THE FROZEN GATE  ·  9 POSITIONS  ·  30 LEVELS  ·  1 SHARED GATE"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", BroadcastTheme.MUTED)
	column.add_child(caption)


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
