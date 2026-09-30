class_name SystemLowerThird
extends PanelContainer

## The System's voice as a TV lower third: a "SYSTEM" tag and a line that
## types itself out. Give it lines to cycle through, or say() one now.

const CHARS_PER_SECOND := 45.0
const HOLD_SECONDS := 6.0

var _tag: Label
var _line: Label
var _lines: Array[String] = []
var _next_index := 0
var _full_text := ""
var _typed := 0.0
var _hold := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BroadcastTheme.STUDIO, 0.92)
	style.border_color = BroadcastTheme.CYAN
	style.border_width_left = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_tag = Label.new()
	_tag.text = "SYSTEM"
	BroadcastTheme.headline(_tag, 20, BroadcastTheme.CYAN, Color(0, 0, 0, 0.6))
	row.add_child(_tag)
	_line = Label.new()
	_line.add_theme_font_size_override("font_size", 16)
	_line.add_theme_color_override("font_color", BroadcastTheme.TEXT)
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_line)


## Cycles through `lines` in a random order, one every few seconds.
func set_lines(lines: Array[String]) -> void:
	_lines = lines.duplicate()
	_lines.shuffle()
	_next_index = 0
	_advance()


## Says `text` now (it holds, then the cycle resumes).
func say(text: String) -> void:
	_full_text = text
	_typed = 0.0
	_hold = HOLD_SECONDS
	_line.text = ""


func current_text() -> String:
	return _full_text


func _process(delta: float) -> void:
	if _typed < _full_text.length():
		_typed = minf(_full_text.length(), _typed + CHARS_PER_SECOND * delta)
		_line.text = _full_text.left(int(_typed))
		return
	_hold -= delta
	if _hold <= 0.0 and not _lines.is_empty():
		_advance()


func _advance() -> void:
	if _lines.is_empty():
		return
	say(_lines[_next_index % _lines.size()])
	_next_index += 1
