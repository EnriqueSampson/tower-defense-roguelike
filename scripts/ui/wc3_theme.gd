class_name WC3Theme
extends RefCounted

## Procedural Warcraft III-style HUD theme: dark stone panels with bronze
## borders, gold highlights and parchment text. A placeholder until authored
## UI art replaces the style boxes.

const STONE := Color("15181d")
const STONE_LIGHT := Color("222831")
const STONE_DARK := Color("0b0d10")
const BRONZE := Color("7a6337")
const BRONZE_DARK := Color("4a3c22")
const GOLD := Color("e2bf62")
const PARCHMENT := Color("e8dcc0")
const MUTED := Color("9d9582")


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 13
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_color("font_color", "Label", PARCHMENT)
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		theme.set_stylebox(state, "Button", _button_style(state))
		theme.set_stylebox(state, "OptionButton", _button_style(state))
	theme.set_color("font_color", "Button", PARCHMENT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_hover_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	theme.set_font_size("font_size", "Button", 12)
	return theme


## Stone panel with a double bronze rim, used for every console frame.
static func panel_style(padding := 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = STONE
	style.border_color = BRONZE
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 4
	style.set_content_margin_all(padding)
	return style


## Full-width bar behind the top resources and the bottom console.
static func bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = STONE_DARK
	style.border_color = BRONZE_DARK
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_content_margin_all(4)
	return style


static func _button_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(2)
	style.set_border_width_all(2)
	style.set_content_margin_all(4)
	match state:
		"hover":
			style.bg_color = STONE_LIGHT.lightened(0.06)
			style.border_color = GOLD
		"pressed", "hover_pressed":
			style.bg_color = STONE_DARK
			style.border_color = GOLD
		"disabled":
			style.bg_color = STONE_DARK
			style.border_color = BRONZE_DARK.darkened(0.3)
		"focus":
			style.draw_center = false
			style.border_color = Color(GOLD, 0.0)
		_:
			style.bg_color = STONE_LIGHT
			style.border_color = BRONZE
	return style
