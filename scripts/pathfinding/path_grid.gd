class_name PathGrid
extends RefCounted

var revision := 0

var _astar := AStarGrid2D.new()
var _traversable_cells: Dictionary
var _route_starts: Array[Vector2i]
var _goal: Vector2i


func _init(
	grid_size: Vector2i,
	traversable_cells: Dictionary,
	route_starts: Array[Vector2i],
	goal: Vector2i
) -> void:
	_traversable_cells = traversable_cells.duplicate()
	_route_starts = route_starts.duplicate()
	_goal = goal
	_astar.region = Rect2i(Vector2i.ZERO, grid_size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	_astar.fill_solid_region(_astar.region, true)
	for cell in _traversable_cells:
		_astar.set_point_solid(cell, false)


func can_block(
	cell: Vector2i,
	additional_starts: Array[Vector2i] = [],
	required_segments: Array[Dictionary] = []
) -> bool:
	return can_block_cells([cell], additional_starts, required_segments)


## Probes blocking every cell of a footprint at once; all or nothing.
func can_block_cells(
	cells: Array[Vector2i],
	additional_starts: Array[Vector2i] = [],
	required_segments: Array[Dictionary] = []
) -> bool:
	if not _are_all_open(cells):
		return false
	for cell in cells:
		_astar.set_point_solid(cell, true)
	var routes_remain_open := _all_can_reach_goal(_route_starts)
	if routes_remain_open:
		routes_remain_open = _all_can_reach_goal(additional_starts)
	if routes_remain_open:
		routes_remain_open = _all_segments_remain_open(required_segments)
	for cell in cells:
		_astar.set_point_solid(cell, false)
	return routes_remain_open


func commit_block(cell: Vector2i) -> bool:
	return commit_block_cells([cell])


func commit_block_cells(cells: Array[Vector2i]) -> bool:
	if not _are_all_open(cells):
		return false
	for cell in cells:
		_astar.set_point_solid(cell, true)
	revision += 1
	return true


## Reopens a previously blocked traversable cell (tower sold). Opening a cell
## can never seal a route, so no probe is required.
func unblock(cell: Vector2i) -> bool:
	return unblock_cells([cell])


func unblock_cells(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	for cell in cells:
		if not _traversable_cells.has(cell) or not _astar.is_point_solid(cell):
			return false
	for cell in cells:
		_astar.set_point_solid(cell, false)
	revision += 1
	return true


func get_path(from_cell: Vector2i, target_cell := Vector2i(-1, -1)) -> Array[Vector2i]:
	if not _traversable_cells.has(from_cell) or _astar.is_point_solid(from_cell):
		return []
	var resolved_target: Vector2i = _goal if target_cell == Vector2i(-1, -1) else target_cell
	if not _traversable_cells.has(resolved_target) or _astar.is_point_solid(resolved_target):
		return []
	return _astar.get_id_path(from_cell, resolved_target)


func is_blocked(cell: Vector2i) -> bool:
	return not _traversable_cells.has(cell) or _astar.is_point_solid(cell)


func _are_all_open(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	for cell in cells:
		if not _traversable_cells.has(cell) or _astar.is_point_solid(cell):
			return false
	return true


func _all_can_reach_goal(starts: Array[Vector2i]) -> bool:
	for start in starts:
		if start == _goal:
			continue
		if get_path(start).is_empty():
			return false
	return true


func _all_segments_remain_open(segments: Array[Dictionary]) -> bool:
	for segment in segments:
		var start: Vector2i = segment.get("start", Vector2i(-1, -1))
		var target: Vector2i = segment.get("target", Vector2i(-1, -1))
		if start != target and get_path(start, target).is_empty():
			return false
	return true