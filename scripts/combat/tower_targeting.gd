class_name TowerTargeting
extends RefCounted

enum Mode {
	FIRST,
	LAST,
	STRONGEST,
	NEAREST,
}

const MODE_NAMES: Array[String] = ["First", "Last", "Strongest", "Nearest"]


static func mode_name(mode: int) -> String:
	return MODE_NAMES[mode] if mode >= 0 and mode < MODE_NAMES.size() else "Unknown"


static func is_valid_mode(mode: int) -> bool:
	return mode >= 0 and mode < Mode.size()


## Picks a target among candidates inside attack_range of origin. Candidates
## must expose plane_position, health, and get_progress().
static func select(candidates: Array, origin: Vector2, attack_range: float, mode: int) -> RouteRunner:
	var best: RouteRunner
	var best_score := 0.0
	var range_squared := attack_range * attack_range
	for candidate in candidates:
		if not candidate is RouteRunner or candidate.health <= 0 or candidate.is_queued_for_deletion():
			continue
		var distance_squared := origin.distance_squared_to(candidate.plane_position)
		if distance_squared > range_squared:
			continue
		var score := _score(candidate, distance_squared, mode)
		if best == null or score > best_score:
			best = candidate
			best_score = score
	return best


static func _score(candidate: RouteRunner, distance_squared: float, mode: int) -> float:
	match mode:
		Mode.FIRST:
			return candidate.get_progress()
		Mode.LAST:
			return -candidate.get_progress()
		Mode.STRONGEST:
			return float(candidate.health) * 1000.0 + candidate.get_progress() * 0.001
		_:
			return -distance_squared
