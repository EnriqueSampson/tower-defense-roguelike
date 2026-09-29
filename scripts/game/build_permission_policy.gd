class_name BuildPermissionPolicy
extends RefCounted

## Position ownership rules:
## - A player controls the position assigned in the lobby roster.
## - The host controls every unfilled position (owner 0).
## - Position 9 follows the same rule: its assigned player, or the host when empty.
## - When a peer disconnects its positions transfer to the host.
const HOST_PEER_ID := 1
const UNOWNED := 0


static func can_control(peer_id: int, position_index: int, owners: PackedInt32Array, host_peer_id := HOST_PEER_ID) -> bool:
	if position_index < 0 or position_index >= owners.size() or peer_id <= 0:
		return false
	var owner := owners[position_index]
	if owner == peer_id:
		return true
	return owner == UNOWNED and peer_id == host_peer_id


static func controlled_positions(peer_id: int, owners: PackedInt32Array, host_peer_id := HOST_PEER_ID) -> Array[int]:
	var positions: Array[int] = []
	for position_index in range(owners.size()):
		if can_control(peer_id, position_index, owners, host_peer_id):
			positions.append(position_index)
	return positions


## Builds the owner table from the lobby roster. `peer_lookup` maps a Steam ID
## to a multiplayer peer ID and returns 0 when the peer is unknown.
static func resolve_owners(
	roster: Array,
	position_count: int,
	peer_lookup: Callable,
	host_steam_id: int,
	host_peer_id := HOST_PEER_ID
) -> PackedInt32Array:
	var owners := PackedInt32Array()
	owners.resize(position_count)
	owners.fill(UNOWNED)
	for member in roster:
		var position_number := int(member.get("lane", -1))
		if position_number < 1 or position_number > position_count:
			continue
		var steam_id := int(member.get("steam_id", 0))
		var peer_id := host_peer_id if steam_id == host_steam_id or bool(member.get("is_host", false)) else int(peer_lookup.call(steam_id))
		if peer_id > 0:
			owners[position_number - 1] = peer_id
	return owners


static func transfer_to_host(owners: PackedInt32Array, departed_peer_id: int, host_peer_id := HOST_PEER_ID) -> PackedInt32Array:
	var updated := owners.duplicate()
	for position_index in range(updated.size()):
		if updated[position_index] == departed_peer_id:
			updated[position_index] = host_peer_id
	return updated


static func owner_label(owner_peer_id: int, local_peer_id: int, host_peer_id := HOST_PEER_ID) -> String:
	if owner_peer_id == local_peer_id and owner_peer_id != UNOWNED:
		return "YOU"
	if owner_peer_id == UNOWNED or owner_peer_id == host_peer_id:
		return "HOST"
	return "P%d" % owner_peer_id
