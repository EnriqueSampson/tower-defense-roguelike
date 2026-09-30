class_name StudioBackdrop
extends Control

## Animated TV-studio background: a violet floor glow, sweeping spotlight
## cones, faint scanlines and a vignette. Drawn procedurally; mouse passes
## through.

const SPOTLIGHTS: Array[Dictionary] = [
	{"x": 0.12, "color": BroadcastTheme.MAGENTA, "speed": 0.37, "phase": 0.0},
	{"x": 0.38, "color": BroadcastTheme.CYAN, "speed": 0.29, "phase": 1.7},
	{"x": 0.64, "color": BroadcastTheme.GOLD, "speed": 0.33, "phase": 3.1},
	{"x": 0.9, "color": BroadcastTheme.MAGENTA, "speed": 0.41, "phase": 4.4},
]
const SWEEP := 0.38
const SCANLINE_SPACING := 3.0

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, BroadcastTheme.STUDIO)
	# Floor glow: stacked translucent bands, brightest at the bottom.
	for band in range(10):
		var t := band / 10.0
		var top := size.y * (0.55 + 0.45 * t)
		draw_rect(Rect2(0, top, size.x, size.y - top), Color(BroadcastTheme.STUDIO_LIGHT, 0.12))
	for light in SPOTLIGHTS:
		_draw_spotlight(light)
	var line_color := Color(0, 0, 0, 0.18)
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), line_color)
		y += SCANLINE_SPACING
	# Vignette: darken the edges with a few inset frames.
	for ring in range(6):
		var inset := ring * 18.0
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0), Color(0, 0, 0, 0.1), false, 36.0)


func _draw_spotlight(light: Dictionary) -> void:
	var origin := Vector2(size.x * float(light["x"]), -20.0)
	var angle := sin(_time * float(light["speed"]) + float(light["phase"])) * SWEEP
	var reach := size.y * 1.25
	var direction := Vector2.DOWN.rotated(angle)
	var spread := direction.orthogonal() * reach * 0.16
	var tip := origin + direction * reach
	var color: Color = light["color"]
	var cone := PackedVector2Array([origin, tip - spread, tip + spread])
	draw_colored_polygon(cone, Color(color, 0.06))
	var core := PackedVector2Array([origin, tip - spread * 0.45, tip + spread * 0.45])
	draw_colored_polygon(core, Color(color, 0.05))
	draw_circle(tip, reach * 0.09, Color(color, 0.05))
