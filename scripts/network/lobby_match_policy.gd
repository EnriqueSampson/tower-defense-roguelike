class_name LobbyMatchPolicy
extends RefCounted


static func is_compatible(
	metadata: Dictionary,
	member_count: int,
	member_limit: int,
	game_tag: String,
	protocol_version: String,
	build_id: String,
	map_id: String
) -> bool:
	return (
		metadata.get("game", "") == game_tag
		and metadata.get("protocol", "") == protocol_version
		and metadata.get("build", "") == build_id
		and metadata.get("map", "") == map_id
		and metadata.get("state", "") == "waiting"
		and member_limit > 0
		and member_count < member_limit
	)


static func select_quick_match(lobbies: Array[Dictionary]) -> int:
	if lobbies.is_empty():
		return 0
	return int(lobbies[0].get("id", 0))