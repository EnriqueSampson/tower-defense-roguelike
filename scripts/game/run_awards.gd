class_name RunAwards
extends RefCounted

## End-of-run awards from the per-player stats (RunState.peer_stats), in the
## voice of the show. Pure: the host computes them into the results.

## [stat key, title, line template (%s = amount), skip when the best is 0]
const AWARDS: Array[Array] = [
	["kills", "EMPLOYEE OF THE MONTH", "%s kills. Management is pleased.", false],
	["leaks", "MOST LEAKS ALLOWED", "%s creeps waved through. Very welcoming.", true],
	["gold_sent", "PHILANTHROPIST OF THE YEAR", "%s gold given away. Tax deductible.", true],
	["gold_spent", "BIG SPENDER", "%s gold spent. The sponsors adore you.", true],
	["towers_built", "ARCHITECT OF QUESTIONABLE TASTE", "%s towers built.", true],
	["trips", "PROFESSIONAL FALLER", "%s trips. Stunt double not included.", true],
	["gold_left", "DRAGON HOARD AWARD", "%s gold unspent at the end. You can't take it with you.", true],
]


## `stats`: peer id -> {kills, leaks, gold_sent, gold_spent, towers_built,
## trips}; `gold`: peer id -> gold left; `names`: peer id -> display name.
## Returns [{title, name, line, peer}] for every award someone earned. Ties go
## to the lower peer id, so every peer computes the same list.
static func compute(stats: Dictionary, gold: Dictionary, names: Dictionary) -> Array[Dictionary]:
	var peers: Array = names.keys()
	peers.sort()
	var awards: Array[Dictionary] = []
	for award in AWARDS:
		var key: String = award[0]
		var best_peer := 0
		var best := -1
		for peer_id in peers:
			var value := int(gold.get(peer_id, 0)) if key == "gold_left" else int((stats.get(peer_id, {}) as Dictionary).get(key, 0))
			if value > best:
				best = value
				best_peer = int(peer_id)
		if best_peer == 0 or (bool(award[3]) and best <= 0):
			continue
		awards.append({
			"title": award[1],
			"name": str(names[best_peer]),
			"line": str(award[2]) % LiveBadge.format_count(best),
			"peer": best_peer,
		})
	return awards
