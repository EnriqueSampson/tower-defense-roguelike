class_name EffectsLayer
extends Node2D

## Lightweight transient feedback (impacts, deaths, leaks, floating text)
## drawn from one node instead of spawning a scene per effect. Positions are
## sim pixels projected to the screen through `projector`.

enum Kind {
	IMPACT,
	DEATH,
	LEAK,
	RING,
	TEXT,
}

## (plane: Vector2, height: float) -> Vector2 screen position.
var projector := Callable()
## () -> float screen pixels per sim pixel.
var screen_scale := Callable()

var _effects: Array[Dictionary] = []


func impact(world_position: Vector2, color: Color, radius := 10.0) -> void:
	_add(Kind.IMPACT, world_position, color, 0.28, radius, "")


func death(world_position: Vector2, color: Color, radius := 8.0) -> void:
	_add(Kind.DEATH, world_position, color, 0.5, radius, "")


func leak(world_position: Vector2) -> void:
	_add(Kind.LEAK, world_position, Color("ff5c4d"), 0.9, 24.0, "LEAK  -1 LIFE")


func ring(world_position: Vector2, color: Color, radius := 16.0) -> void:
	_add(Kind.RING, world_position, color, 0.45, radius, "")


func floating_text(world_position: Vector2, text: String, color: Color) -> void:
	_add(Kind.TEXT, world_position, color, 0.9, 0.0, text)


func active_count() -> int:
	return _effects.size()


func _add(kind: int, world_position: Vector2, color: Color, duration: float, radius: float, text: String) -> void:
	_effects.append({
		"kind": kind,
		"position": world_position,
		"color": color,
		"age": 0.0,
		"duration": duration,
		"radius": radius,
		"text": text,
	})
	queue_redraw()


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	var survivors: Array[Dictionary] = []
	for effect in _effects:
		effect["age"] += delta
		if effect["age"] < effect["duration"]:
			survivors.append(effect)
	_effects = survivors
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var unit_scale: float = screen_scale.call() if screen_scale.is_valid() else 1.0
	for effect in _effects:
		var t: float = clampf(effect["age"] / effect["duration"], 0.0, 1.0)
		var fade := 1.0 - t
		var color: Color = effect["color"]
		var plane: Vector2 = effect["position"]
		var center: Vector2 = projector.call(plane, 0.3) if projector.is_valid() else plane
		var radius: float = effect["radius"] * unit_scale
		match int(effect["kind"]):
			Kind.IMPACT:
				# The ring shows the splash area; the spark stays small at any zoom.
				draw_arc(center, radius * (0.4 + t * 0.9), 0.0, TAU, 20, Color(color.r, color.g, color.b, fade * 0.9), 2.0)
				draw_circle(center, minf(radius * 0.2, 6.0) * fade, Color(color.lightened(0.6), fade * 0.9))
			Kind.DEATH:
				for index in range(6):
					var angle := TAU * index / 6.0
					var offset := Vector2.from_angle(angle) * radius * (0.4 + t * 1.6)
					draw_circle(center + offset, maxf(0.5, 3.0 * fade), Color(color.r, color.g, color.b, fade))
				draw_circle(center, radius * fade * 0.6, Color(0.1, 0.1, 0.1, fade * 0.5))
			Kind.LEAK:
				draw_arc(center, radius * (0.6 + t), 0.0, TAU, 32, Color(color.r, color.g, color.b, fade), 3.0)
				draw_string(font, center + Vector2(-42, -30 - t * 26), effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color.r, color.g, color.b, fade))
			Kind.RING:
				draw_arc(center, radius * (0.8 + t * 0.6), 0.0, TAU, 24, Color(color.r, color.g, color.b, fade), 2.0)
			Kind.TEXT:
				draw_string(font, center + Vector2(-12, -12 - t * 22), effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color.r, color.g, color.b, fade))
