class_name ClassicWintermaulLayout
extends RefCounted

## The Wintermaul battlefield, retraced by hand from the classic map's
## structure. Authored as DESIGN_MAP, one character per two-by-two tower on an
## 82x84 design grid (the classic playable area), scaled by SCALE (2) to
## 164x168 cells. Design points map to the centre of their scaled block.
##
##   Top:    three lanes (Positions 1, 2, 3). Lanes 1 and 3 drain through a
##           no-build choke; lane 2 through a neck into Position 5's chamber.
##           Lane 2 spawns from a left and a right portal.
##   Middle: one band, 6 | 5 | 4, split by no-build dividers. Position 5
##           spawns from a nook either side of its chamber; 6 and 4 come in
##           from the map edges.
##   Bottom: necks drop into the side lanes (7 left, 8 right). 7 and 8 spawn
##           under the brow and walk a diagonal out to their lane. Position 9
##           spawns just below the chin and owns the centre down to the
##           relay checkpoint and the exit.
## Every spawner of a position shares that position's creep budget. Where the
## centre forks (Positions 2 and 5), each twin spawner's creeps take their own
## side's neck, so the load splits evenly between the left and right lanes.

enum Terrain {
	VOID,
	WALL,
	OPEN,
	SPAWN_PAD,
	EXIT_PAD,
}

const SCALE := 2
const _HALF := Vector2i(SCALE / 2, SCALE / 2)
const DESIGN_GRID_SIZE := Vector2i(82, 84)
const GRID_SIZE := DESIGN_GRID_SIZE * SCALE
const FINAL_GATE := Vector2i(40, 81) * SCALE + _HALF
## Shared relay every upstream position passes before the gate.
const FINAL_CHECKPOINT := Vector2i(40, 74) * SCALE + _HALF
## No-build necks from the middle band down into the side lanes.
const LEFT_NECK := Vector2i(10, 47) * SCALE + _HALF
const RIGHT_NECK := Vector2i(71, 47) * SCALE + _HALF
const PLAYER_COUNT := 9
const SPATIAL_PLAYER_ORDER: Array[int] = [
	1, 2, 3,
	6, 5, 4,
	7, 9, 8,
]
const PLAYER_COLORS: Array[Color] = [
	Color("ef5753"),
	Color("4f75e6"),
	Color("36c9bd"),
	Color("a65bd4"),
	Color("e0cf45"),
	Color("e79243"),
	Color("42bd69"),
	Color("ed82b5"),
	Color("aab4b2"),
]
const WAVE_MULTIPLIERS: Array[float] = [2.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.6]

## ' ' void, '#' cliff, '.' walkable but never buildable, '1'-'9' ground
## Position N builds on, 'a'-'i' Position 1-9's spawn pads, '=' exit pad.
const DESIGN_MAP: Array[String] = [
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##aaaaaaaaaa##                ##bbbbbbbbbb##                ##cccccccccc##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##                ##2222222222##                ##3333333333##    ",
	"    ##1111111111##            ######2222222222######            ##3333333333##    ",
	"    ##1111111111##            #########....#########            ##3333333333##    ",
	"    ##1111111111##            ##ee#####....#####ee##            ##3333333333##    ",
	"    ####111111####            ##ee##5555555555##ee##            ####333333####    ",
	"    ####......####            ##ee..5555555555..ee##            ####......####    ",
	"     ##........##             ##ee..5555555555..ee##             ##........##     ",
	"     ##........##             ##ee##5555555555##ee##             ##........##     ",
	"    ####......######################5555555555######################......####    ",
	"    ####666666######################5555555555######################444444####    ",
	"    ##66666666666####5555555555555##5555555555##5555555555555####44444444444##    ",
	"######66666666666....5555555555555##5555555555##5555555555555....44444444444######",
	"######66666666666....5555555555555##5555555555##5555555555555....44444444444######",
	"ffff##66666666666....5555555555555##5555555555##5555555555555....44444444444##dddd",
	"ffff##66666666666....5555555555555##5555555555##5555555555555....44444444444##dddd",
	"ffff..66666666666....5555555555555555555555555555555555555555....44444444444..dddd",
	"ffff..66666666666....5555555555555555555555555555555555555555....44444444444..dddd",
	"ffff..66666666666....5555555555555555555555555555555555555555....44444444444..dddd",
	"ffff..66666666666....5555555555555555555555555555555555555555....44444444444..dddd",
	"ffff##66666666666####5555555555555555555555555555555555555555####44444444444##dddd",
	"ffff#####...##########################################################...#####dddd",
	"#########...##########################################################...#########",
	"######7777777777##  ####....gggggggggg..##..hhhhhhhhhh....####  ##8888888888######",
	"    ##7777777777## ####.....gggggggggg..##..hhhhhhhhhh.....#### ##8888888888##    ",
	"    ##7777777777######......gggggggggg..##..hhhhhhhhhh......######8888888888##    ",
	"    ##7777777777#####.......gggggggggg..##..hhhhhhhhhh.......#####8888888888##    ",
	"    ##7777777777####.....################################.....####8888888888##    ",
	"    ##7777777777###.....##99999999999iiiiiiii99999999999##.....###8888888888##    ",
	"    ##7777777777##.....##999999999999iiiiiiii999999999999##.....##8888888888##    ",
	"    ##7777777777......##9999999999999iiiiiiii9999999999999##......8888888888##    ",
	"    ##7777777777.....##999999999999999999999999999999999999##.....8888888888##    ",
	"    ##7777777777....##99999999999999999999999999999999999999##....8888888888##    ",
	"    ##7777777777#######999999999999999999999999999999999999#######8888888888##    ",
	"    ##7777777777#######999999999999999999999999999999999999#######8888888888##    ",
	"    ##7777777777777777777777##9999999999999999999999##8888888888888888888888##    ",
	"    ##7777777777777777777777##9999999999999999999999##8888888888888888888888##    ",
	"    ##7777777777777777777777##9999999999999999999999##8888888888888888888888##    ",
	"    ##7777777777777777777777##9999999999999999999999##8888888888888888888888##    ",
	"    ##7777777777777777777777##9999999999999999999999##8888888888888888888888##    ",
	"    ##7777777777777777777777##9999999999999999999999##8888888888888888888888##    ",
	"    ##7777777777777777777777########9999999999########8888888888888888888888##    ",
	"    ##777777777777777777777#########9999999999#########888888888888888888888##    ",
	"    ##77777777777777777777####    ##9999999999##    ####88888888888888888888##    ",
	"    ##7777777777777777777####     ##9999999999##     ####8888888888888888888##    ",
	"    ########################      ##9999999999##      ########################    ",
	"    #######################       ##9999999999##       #######################    ",
	"                                  ##9999999999##                                  ",
	"                                  ##9999999999##                                  ",
	"                                  ##9999999999##                                  ",
	"                                  ##9999999999##                                  ",
	"                                  ##9999999999##                                  ",
	"                                  ##9999999999##                                  ",
	"                                  ####======####                                  ",
	"                                  ####======####                                  ",
	"                                    ##======##                                    ",
	"                                    ##======##                                    ",
	"                                    ##======##                                    ",
]
const _PAD_CHARS := "abcdefghi"

static var _bounds: Array[Rect2i] = []


static func setup_map_coordinates() -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	for design in _design_positions():
		var spawns: Array[Vector2i] = []
		for spawn: Vector2i in design["spawns"]:
			spawns.append(scale_point(spawn))
		var position_data := _position(
			int(design["player_id"]), spawns, scale_point(design["checkpoint"]), scale_point(design["label_anchor"]))
		if design.has("via"):
			position_data["via"] = design["via"]
		positions.append(position_data)
	return positions


## Design rect -> grid rect.
static func scale_rect(rect: Rect2i) -> Rect2i:
	return Rect2i(rect.position * SCALE, rect.size * SCALE)


## Design cell -> centre cell of its scaled block.
static func scale_point(point: Vector2i) -> Vector2i:
	return point * SCALE + _HALF


static func _design_positions() -> Array[Dictionary]:
	return [
		{"player_id": 1, "spawns": [Vector2i(10, 3)], "checkpoint": Vector2i(10, 33), "label_anchor": Vector2i(6, 9)},
		# Twin spawns, like Wintermaul's "Middle Left/Right Spawn": each side's
		# creeps take that side's neck ("via" is per spawner, in grid cells).
		{"player_id": 2, "spawns": [Vector2i(38, 3), Vector2i(43, 3)], "checkpoint": Vector2i(40, 30), "label_anchor": Vector2i(36, 9),
			"via": [[LEFT_NECK], [RIGHT_NECK]]},
		{"player_id": 3, "spawns": [Vector2i(71, 3)], "checkpoint": Vector2i(71, 33), "label_anchor": Vector2i(66, 9)},
		{"player_id": 4, "spawns": [Vector2i(80, 43)], "checkpoint": Vector2i(71, 38), "label_anchor": Vector2i(65, 45)},
		{"player_id": 5, "spawns": [Vector2i(32, 32), Vector2i(49, 32)], "checkpoint": Vector2i(40, 44), "label_anchor": Vector2i(21, 45),
			"via": [[LEFT_NECK], [RIGHT_NECK]]},
		{"player_id": 6, "spawns": [Vector2i(1, 43)], "checkpoint": Vector2i(10, 38), "label_anchor": Vector2i(6, 45)},
		{"player_id": 7, "spawns": [Vector2i(32, 50)], "checkpoint": Vector2i(10, 68), "label_anchor": Vector2i(6, 50)},
		{"player_id": 8, "spawns": [Vector2i(49, 50)], "checkpoint": Vector2i(71, 68), "label_anchor": Vector2i(66, 50)},
		# Position 9 spawns once, centred just below the chin and close to the
		# relay and gate, like the single "Grey spawn" in Wintermaul v.72.2.
		{"player_id": 9, "spawns": [Vector2i(40, 55)], "checkpoint": Vector2i(40, 74), "label_anchor": Vector2i(30, 62)},
	]


static func get_position(position_index: int) -> Dictionary:
	var positions := setup_map_coordinates()
	return positions[position_index] if position_index >= 0 and position_index < positions.size() else {}


static func get_wave_multiplier(position_index: int) -> float:
	return WAVE_MULTIPLIERS[position_index] if position_index >= 0 and position_index < PLAYER_COUNT else 0.0


static func is_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


## DESIGN_MAP character covering a grid cell (' ' outside the grid).
static func design_char(cell: Vector2i) -> String:
	if not is_in_grid(cell):
		return " "
	var design := cell / SCALE
	return DESIGN_MAP[design.y][design.x]


static func terrain_at(cell: Vector2i) -> int:
	var tile := design_char(cell)
	match tile:
		" ":
			return Terrain.VOID
		"#":
			return Terrain.WALL
		"=":
			return Terrain.EXIT_PAD
	return Terrain.SPAWN_PAD if _PAD_CHARS.contains(tile) else Terrain.OPEN


static func is_traversable(terrain: int) -> bool:
	return terrain in [Terrain.OPEN, Terrain.SPAWN_PAD, Terrain.EXIT_PAD]


## Index of the position that may build on the cell, or -1 (walls, pads and
## no-build ground belong to nobody).
static func position_index_at(cell: Vector2i) -> int:
	var tile := design_char(cell)
	return int(tile) - 1 if tile.is_valid_int() and tile != "0" else -1


## Grid rect enclosing a position's build ground and spawn pads.
static func territory_bounds(position_index: int) -> Rect2i:
	if _bounds.is_empty():
		var found: Array[Rect2i] = []
		found.resize(PLAYER_COUNT)
		for y in range(DESIGN_GRID_SIZE.y):
			for x in range(DESIGN_GRID_SIZE.x):
				var tile := DESIGN_MAP[y][x]
				var owner := int(tile) - 1 if tile.is_valid_int() else _PAD_CHARS.find(tile)
				if owner < 0 or owner >= PLAYER_COUNT:
					continue
				var block := Rect2i(x, y, 1, 1)
				found[owner] = block if found[owner].size == Vector2i.ZERO else found[owner].merge(block)
		for rect in found:
			_bounds.append(scale_rect(rect))
	return _bounds[position_index] if position_index >= 0 and position_index < _bounds.size() else Rect2i()


## One pixel per design cell: cliffs, walk-only ground, each position's
## ground in its colour (spawn pads darker), the exit in red, void clear.
## Menus show it as the arena preview.
static func preview_image() -> Image:
	var image := Image.create(DESIGN_GRID_SIZE.x, DESIGN_GRID_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(DESIGN_GRID_SIZE.y):
		for x in range(DESIGN_GRID_SIZE.x):
			var tile := DESIGN_MAP[y][x]
			var color := Color(0, 0, 0, 0)
			if tile == "#":
				color = Color("5a5470")
			elif tile == ".":
				color = Color("c9d3dc")
			elif tile == "=":
				color = Color("d0404a")
			elif tile.is_valid_int():
				color = PLAYER_COLORS[int(tile) - 1]
			elif _PAD_CHARS.contains(tile):
				color = PLAYER_COLORS[_PAD_CHARS.find(tile)].darkened(0.45)
			image.set_pixel(x, y, color)
	return image


static func _position(
	player_id: int,
	spawns: Array[Vector2i],
	checkpoint: Vector2i,
	label_anchor: Vector2i
) -> Dictionary:
	return {
		"player_id": player_id,
		"macro_bounds": territory_bounds(player_id - 1),
		"spawns": spawns,
		"spawn": spawns[0],
		"checkpoint": checkpoint,
		"label_anchor": label_anchor,
		"color": PLAYER_COLORS[player_id - 1],
		"wave_multiplier": WAVE_MULTIPLIERS[player_id - 1],
	}
