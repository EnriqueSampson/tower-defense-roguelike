class_name SponsorTicker
extends Control

## A news-style strip scrolling tonight's (entirely made up) sponsors.
## Invented names only: no real brands, and nothing from the Dungeon
## Crawler Carl books.

const SPONSORS: Array[String] = [
	"GRIMSBY'S DISCOUNT COFFINS  ·  Buy one, get buried free",
	"OGRE-SHIELD HOME INSURANCE  ·  Does not cover ogres",
	"FROSTBITE & SONS PREMIUM ICE  ·  Colder than your ex",
	"UNPAID INTERN STAFFING SOLUTIONS  ·  Exposure is a currency",
	"LOOT CRATE LEGAL DEFENSE FUND  ·  It's not gambling if you win",
	"MOLDY CRUST PIZZA  ·  Now with 40% more crust",
	"DEAD END TRAVEL  ·  One-way tickets to exciting places",
	"MIDDLE MANAGEMENT MONTHLY  ·  Synergize your screams",
]
const SPEED := 70.0
const STRIP_HEIGHT := 30.0

var _offset := 0.0
var _text := ""
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size.y = STRIP_HEIGHT
	_font = BroadcastTheme.HEADLINE_FONT
	_text = "TONIGHT'S DEFENSE IS BROUGHT TO YOU BY    ★    " + "    ★    ".join(SPONSORS) + "    ★    "


func _process(delta: float) -> void:
	_offset += SPEED * delta
	var width := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	if width > 0.0 and _offset > width:
		_offset -= width
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(BroadcastTheme.MAGENTA, 0.9))
	draw_rect(Rect2(0, 0, size.x, 2), BroadcastTheme.GOLD)
	var width := _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var baseline := size.y * 0.5 + 7.0
	var x := -_offset
	while x < size.x:
		draw_string(_font, Vector2(x, baseline), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, BroadcastTheme.STUDIO)
		x += maxf(width, 1.0)
