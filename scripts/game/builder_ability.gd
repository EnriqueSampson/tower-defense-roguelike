class_name BuilderAbility
extends RefCounted

## Builder abilities (prototype): one active power per race, centred on the
## builder, so waves are something to play and not only watch. Only Humans
## have one until playtests say it lands; then it moves into the race content
## (tools/race_content.py).

const ABILITIES := {
	"humans": {
		"name": "Performance Review",
		"short": "Review",
		"description": "Your builder calls every creep nearby into a meeting: they stand still for 2.5 s (bosses half as long). Usable during waves.",
		"radius_tiles": 4.0,
		"stun_seconds": 2.5,
		"cooldown": 40.0,
	},
}


## The race's ability ({} when it has none).
static func for_race(race_id: String) -> Dictionary:
	return ABILITIES.get(race_id, {})
