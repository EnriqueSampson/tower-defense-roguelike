class_name ChatCommands
extends RefCounted

## Parses chat slash commands on the host. Pure functions, so the rules are
## testable without a network: the controller resolves the result.

const MAX_MESSAGE_LENGTH := 200
const HELP := "/give 50 Name (or p3 for Position 3's player) sends gold  ·  /gold lists everyone's gold  ·  /help"


## Trims a chat line and caps its length. Returns "" for nothing to send.
static func clean(text: String) -> String:
	return text.strip_edges().left(MAX_MESSAGE_LENGTH)


static func is_command(text: String) -> bool:
	return text.begins_with("/")


## "/give 50 bob" -> "give"
static func command_name(text: String) -> String:
	return text.trim_prefix("/").get_slice(" ", 0).to_lower()


## "/give 50 bob" -> "50 bob"
static func arguments(text: String) -> String:
	var space := text.find(" ")
	return text.substr(space + 1).strip_edges() if space >= 0 else ""


## Parses "/give" arguments: an amount and a player, in either order. The
## player is a name (exact, else a unique prefix, ignoring case) or "pN" for
## the player controlling Position N. `names` maps peer id -> display name,
## for every player with a gold account. Returns {peer, amount} or {error}.
static func parse_give(args: String, names: Dictionary, owners: PackedInt32Array, host_peer_id := BuildPermissionPolicy.HOST_PEER_ID) -> Dictionary:
	var words := args.split(" ", false)
	var amount := -1
	var name_words := PackedStringArray()
	for word in words:
		if amount < 0 and word.is_valid_int():
			amount = int(word)
		else:
			name_words.append(word)
	if amount <= 0 or name_words.is_empty():
		return {"error": "Usage: /give 50 Name (or p3 for Position 3's player)."}
	var query := " ".join(name_words)
	var peer_id := find_player(query, names, owners, host_peer_id)
	if peer_id == 0:
		return {"error": "No single player matches \"%s\"." % query}
	return {"peer": peer_id, "amount": amount}


## The peer a query names, or 0 when none or several match.
static func find_player(query: String, names: Dictionary, owners: PackedInt32Array, host_peer_id := BuildPermissionPolicy.HOST_PEER_ID) -> int:
	var lowered := query.to_lower()
	if lowered.length() >= 2 and lowered.begins_with("p") and lowered.substr(1).is_valid_int():
		var position_index := int(lowered.substr(1)) - 1
		if position_index < 0 or position_index >= owners.size():
			return 0
		var owner := owners[position_index]
		var controller := owner if owner > 0 else host_peer_id
		return controller if names.has(controller) else 0
	for peer_id in names:
		if str(names[peer_id]).to_lower() == lowered:
			return int(peer_id)
	var found := 0
	for peer_id in names:
		if str(names[peer_id]).to_lower().begins_with(lowered):
			if found != 0:
				return 0
			found = int(peer_id)
	return found
