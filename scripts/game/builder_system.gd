class_name BuilderSystem
extends RefCounted

## Host-authoritative builders: one per controlling player. Builders walk in
## a straight line and clip through towers, creeps and each other (they never
## touch the creep path grid). Orders queue WC3-style: a plain order replaces
## the queue, a shift order appends. A build order starts construction when
## the builder reaches the site; the tower then builds itself and the builder
## moves on to its next order.

enum State { IDLE, MOVING, STUNNED }

const ORDER_MOVE := "move"
const ORDER_BUILD := "build"

## peer id -> {owner, position: Vector2, orders: Array[Dictionary], stun: float}
var builders: Dictionary = {}
var speed_pixels := 224.0
var reach_pixels := 45.0
## Easter egg: a builder that stops next to a building after a move order
## sometimes bumps it and falls over. Rolled on the host from the run seed.
var trip_chance := 0.0
var trip_seconds := 1.6
var _rng := RandomNumberGenerator.new()


func _init(speed := 224.0, reach := 45.0, seed := 0) -> void:
	speed_pixels = speed
	reach_pixels = reach
	_rng.seed = seed


func ensure_builder(peer_id: int, spawn: Vector2) -> void:
	if not builders.has(peer_id):
		builders[peer_id] = {"owner": peer_id, "position": spawn, "orders": [], "stun": 0.0}


func remove_builder(peer_id: int) -> void:
	builders.erase(peer_id)


func has_builder(peer_id: int) -> bool:
	return builders.has(peer_id)


func get_position(peer_id: int) -> Vector2:
	return builders[peer_id]["position"] if builders.has(peer_id) else Vector2.ZERO


func get_orders(peer_id: int) -> Array:
	return builders[peer_id]["orders"] if builders.has(peer_id) else []


func issue_move(peer_id: int, point: Vector2, queue := false) -> bool:
	return _issue(peer_id, {"type": ORDER_MOVE, "point": point}, queue)


## `site` is the footprint centre in sim pixels; `cell` its anchor.
func issue_build(peer_id: int, definition_id: String, cell: Vector2i, site: Vector2, queue := false) -> bool:
	return _issue(peer_id, {"type": ORDER_BUILD, "definition_id": definition_id, "cell": cell, "point": site}, queue)


func _issue(peer_id: int, order: Dictionary, queue: bool) -> bool:
	if not builders.has(peer_id):
		return false
	var orders: Array = builders[peer_id]["orders"]
	if not queue:
		orders.clear()
	orders.append(order)
	# A trip is cosmetic: any new order gets the builder straight back up.
	builders[peer_id]["stun"] = 0.0
	return true


func stop(peer_id: int) -> void:
	if builders.has(peer_id):
		(builders[peer_id]["orders"] as Array).clear()


## Cosmetic trip: the builder pauses where it stands for `seconds`.
func stun(peer_id: int, seconds: float) -> void:
	if builders.has(peer_id):
		builders[peer_id]["stun"] = maxf(float(builders[peer_id]["stun"]), seconds)


## Advances every builder. `start_build(peer, definition_id, cell) -> int`
## returns a WintermaulMap.Placement code; `near_building(point) -> bool`
## (optional) lets a builder that stops beside a building trip over it.
## Returns events for feedback: {peer, kind: "build_started" | "build_failed"
## | "tripped", result, cell, definition_id}.
func tick(delta: float, start_build: Callable, near_building := Callable()) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for peer_id in builders:
		var builder: Dictionary = builders[peer_id]
		if float(builder["stun"]) > 0.0:
			builder["stun"] = maxf(0.0, float(builder["stun"]) - delta)
			continue
		var budget := speed_pixels * delta
		var orders: Array = builder["orders"]
		while not orders.is_empty() and budget > 0.0:
			var order: Dictionary = orders[0]
			var point: Vector2 = order["point"]
			var position: Vector2 = builder["position"]
			var arrive_distance := reach_pixels if order["type"] == ORDER_BUILD else 0.5
			var remaining := position.distance_to(point) - arrive_distance
			if remaining > 0.0:
				var step := minf(budget, remaining)
				builder["position"] = position.move_toward(point, step)
				budget -= step
				if remaining - step > 0.001:
					break
			orders.pop_front()
			if order["type"] == ORDER_MOVE and orders.is_empty() and _rolls_trip(builder["position"], near_building):
				builder["stun"] = trip_seconds
				events.append({"peer": peer_id, "kind": "tripped"})
			if order["type"] == ORDER_BUILD:
				var result: int = start_build.call(peer_id, str(order["definition_id"]), order["cell"])
				events.append({
					"peer": peer_id,
					"kind": "build_started" if result == WintermaulMap.Placement.OK else "build_failed",
					"result": result,
					"cell": order["cell"],
					"definition_id": order["definition_id"],
				})
	return events


func _rolls_trip(point: Vector2, near_building: Callable) -> bool:
	if trip_chance <= 0.0 or not near_building.is_valid():
		return false
	return bool(near_building.call(point)) and _rng.randf() < trip_chance


func state_of(peer_id: int) -> int:
	if not builders.has(peer_id):
		return State.IDLE
	var builder: Dictionary = builders[peer_id]
	if float(builder["stun"]) > 0.0:
		return State.STUNNED
	return State.MOVING if not (builder["orders"] as Array).is_empty() else State.IDLE


## Replicated presentation records (state snapshot and builder snapshots).
func records() -> Array:
	var out: Array = []
	var peers := builders.keys()
	peers.sort()
	for peer_id in peers:
		var builder: Dictionary = builders[peer_id]
		var position: Vector2 = builder["position"]
		var orders: Array = builder["orders"]
		var target: Vector2 = orders[0]["point"] if not orders.is_empty() else position
		var sites: Array = []
		for order in orders:
			if order["type"] == ORDER_BUILD:
				sites.append({"definition_id": order["definition_id"], "cell": order["cell"]})
		out.append({
			"owner": peer_id,
			"x": position.x,
			"y": position.y,
			"tx": target.x,
			"ty": target.y,
			"state": state_of(peer_id),
			"sites": sites,
		})
	return out
