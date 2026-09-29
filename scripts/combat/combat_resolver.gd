class_name CombatResolver
extends RefCounted

## Host-only damage resolution. Separated from projectile/effect visuals so
## the same rules run identically in headless tests.


## Resolves one impact. Returns the list of creeps hit, each entry
## {"creep": RouteRunner, "damage": int, "slowed": bool, "killed": bool}.
static func resolve_impact(candidates: Array, payload: Dictionary, impact_position: Vector2, target: RouteRunner) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var splash_radius := float(payload.get("splash_radius", 0.0))
	var damage := int(payload.get("damage", 1))
	var armor_pierce := int(payload.get("armor_pierce", 0))
	var slow_factor := float(payload.get("slow_factor", 0.0))
	var slow_duration := float(payload.get("slow_duration", 0.0))

	var victims: Array = []
	if splash_radius > 0.0:
		var radius_squared := splash_radius * splash_radius
		for candidate in candidates:
			if candidate is RouteRunner and candidate.health > 0 and not candidate.is_queued_for_deletion():
				if impact_position.distance_squared_to(candidate.plane_position) <= radius_squared:
					victims.append(candidate)
	elif target != null and is_instance_valid(target) and target.health > 0:
		victims.append(target)

	for victim: RouteRunner in victims:
		var applied := victim.take_damage(damage, armor_pierce)
		var slowed := false
		if victim.health > 0 and slow_factor > 0.0:
			slowed = victim.apply_slow(slow_factor, slow_duration)
		hits.append({
			"creep": victim,
			"damage": applied,
			"slowed": slowed,
			"killed": victim.health <= 0,
		})
	return hits
