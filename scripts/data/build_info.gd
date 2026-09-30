class_name BuildInfo
extends RefCounted

## Semantic version of the shipped game build. Bump MINOR for content drops and
## PATCH for fixes that keep network compatibility.
const VERSION := "0.2.0"
## Bump whenever RPC signatures, snapshot fields, or content IDs change in a way
## that older clients cannot interpret. Lobbies only match equal protocols.
const PROTOCOL_VERSION := "6"
const GAME_TAG := "wintermaul_td_roguelike_mvp"
const MAP_ID := "wintermaul_mvp"


## Steam supplies a real build ID for uploaded depots. Development runs report 0,
## so fall back to the semantic version to keep local clients comparable.
static func build_id(steam_build_id := 0) -> String:
	return str(steam_build_id) if steam_build_id > 0 else VERSION
