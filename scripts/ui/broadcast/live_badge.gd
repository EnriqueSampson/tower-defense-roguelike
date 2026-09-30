class_name LiveBadge
extends HBoxContainer

## A blinking "LIVE" tag with a viewer count that creeps upward, like a
## streaming broadcast. Purely cosmetic.

var viewers := 1_204_337

var _dot: Label
var _count: Label
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_dot = Label.new()
	_dot.text = "●"
	_dot.add_theme_color_override("font_color", BroadcastTheme.LIVE_RED)
	_dot.add_theme_font_size_override("font_size", 18)
	add_child(_dot)
	var live := Label.new()
	live.text = "LIVE"
	BroadcastTheme.headline(live, 20, BroadcastTheme.TEXT, Color(BroadcastTheme.LIVE_RED, 0.8))
	add_child(live)
	_count = Label.new()
	_count.add_theme_color_override("font_color", BroadcastTheme.MUTED)
	_count.add_theme_font_size_override("font_size", 14)
	add_child(_count)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	_dot.modulate.a = 1.0 if fmod(_time, 1.2) < 0.8 else 0.25
	if _rng.randf() < delta * 2.0:
		viewers += _rng.randi_range(-40, 260)
		_refresh()


func _refresh() -> void:
	_count.text = "%s VIEWERS" % format_count(viewers)


## 1204337 -> "1,204,337"
static func format_count(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for index in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return ("-" if value < 0 else "") + out
