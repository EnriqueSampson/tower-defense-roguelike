class_name BroadcastTheme
extends RefCounted

## The game-show broadcast look for the menus and the System's voice: a dark
## studio, neon magenta and cyan, gold for money and the title, and Anton for
## headlines. The battlefield keeps the WC3 look (WC3Theme).

const STUDIO := Color("07060c")
const STUDIO_LIGHT := Color("16112a")
const PANEL := Color("110d1e")
const PANEL_EDGE := Color("3a2d63")
const MAGENTA := Color("ff3d8b")
const CYAN := Color("33e1ff")
const GOLD := Color("ffcf3a")
const LIVE_RED := Color("ff2a3d")
const TEXT := Color("f4ecff")
const MUTED := Color("9a8fb3")
const HEADLINE_FONT: FontFile = preload("res://assets/fonts/Anton-Regular.ttf")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())
	for type in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			theme.set_stylebox(state, type, button_style(state))
		theme.set_font(&"font", type, HEADLINE_FONT)
		theme.set_font_size(&"font_size", type, 18)
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, STUDIO)
		theme.set_color("font_pressed_color", type, STUDIO)
		theme.set_color("font_hover_pressed_color", type, STUDIO)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_disabled_color", type, MUTED.darkened(0.35))
	theme.set_stylebox("panel", "ItemList", _list_style())
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("selected", "ItemList", _fill(MAGENTA.darkened(0.35), MAGENTA))
	theme.set_stylebox("selected_focus", "ItemList", _fill(MAGENTA.darkened(0.35), MAGENTA))
	theme.set_stylebox("hovered", "ItemList", _fill(STUDIO_LIGHT, PANEL_EDGE))
	theme.set_color("font_color", "ItemList", TEXT)
	theme.set_color("font_selected_color", "ItemList", TEXT)
	theme.set_color("font_hovered_color", "ItemList", GOLD)
	theme.set_constant("v_separation", "ItemList", 6)
	theme.set_font_size("font_size", "ItemList", 15)
	theme.set_stylebox("normal", "LineEdit", _list_style())
	theme.set_stylebox("focus", "LineEdit", _fill(PANEL, CYAN))
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", GOLD)
	theme.set_color("font_pressed_color", "CheckButton", TEXT)
	theme.set_stylebox("slider", "HSlider", _fill(STUDIO_LIGHT, PANEL_EDGE, 3))
	theme.set_stylebox("grabber_area", "HSlider", _fill(MAGENTA, MAGENTA, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _fill(GOLD, GOLD, 3))
	theme.set_stylebox("separator", "HSeparator", _fill(PANEL_EDGE, PANEL_EDGE, 0))
	return theme


## Studio panel: near-black glass with a violet rim and a magenta top edge.
static func panel_style(padding := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL, 0.88)
	style.border_color = PANEL_EDGE
	style.set_border_width_all(2)
	style.border_width_top = 4
	style.border_color = PANEL_EDGE
	style.set_corner_radius_all(6)
	style.shadow_color = Color(MAGENTA, 0.18)
	style.shadow_size = 10
	style.set_content_margin_all(padding)
	return style


## Game-show button: dark with a gold rim; lights up gold (dark text) on hover.
static func button_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	match state:
		"hover":
			style.bg_color = GOLD
			style.border_color = Color.WHITE
			style.shadow_color = Color(GOLD, 0.45)
			style.shadow_size = 12
		"pressed", "hover_pressed":
			style.bg_color = MAGENTA
			style.border_color = GOLD
		"disabled":
			style.bg_color = Color(STUDIO, 0.7)
			style.border_color = PANEL_EDGE.darkened(0.3)
		"focus":
			style.draw_center = false
			style.border_color = CYAN
		_:
			style.bg_color = Color(STUDIO_LIGHT, 0.92)
			style.border_color = GOLD.darkened(0.25)
	return style


## Applies the headline font to a label, with a drop shadow in `shadow`.
static func headline(label: Label, size: int, color := TEXT, shadow := Color(MAGENTA, 0.8)) -> void:
	label.add_theme_font_override("font", HEADLINE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", shadow)
	label.add_theme_constant_override("shadow_offset_x", maxi(2, roundi(size / 24.0)))
	label.add_theme_constant_override("shadow_offset_y", maxi(2, roundi(size / 24.0)))


static func _list_style() -> StyleBoxFlat:
	var style := _fill(Color(STUDIO, 0.85), PANEL_EDGE)
	style.set_content_margin_all(10)
	return style


static func _fill(color: Color, border: Color, radius := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border != color else 0)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(4)
	return style
