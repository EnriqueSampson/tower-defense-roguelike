class_name SystemAnnouncer
extends RefCounted

## The System, the show's snarky host. The host feeds it run events and
## broadcasts whatever line it returns; "" means stay quiet (cooldown, or a
## once-per-run line already used). Lines pick from pools with a seeded RNG,
## so a run's commentary is repeatable from its seed.

## Seconds between ordinary lines; `urgent` events ignore it.
const COOLDOWN := 8.0
const LOW_LIVES := 5
## A selling spree: this many sells by one player within SPREE_SECONDS.
const SPREE_SELLS := 5
const SPREE_SECONDS := 12.0
const BIG_GIFT := 100

const LINES := {
	"run_start": [
		"Welcome to Frozen Gate TD LIVE!, builders! Nine positions, one gate, zero refunds.",
		"And we're live! Please remain calm and build towers.",
		"Good evening and welcome to the Frozen Gate, where hope goes to freeze.",
	],
	"first_leak": [
		"First leak of the night! The audience gasps. Mostly with delight.",
		"And there goes a life. Somebody check Position 9's pulse.",
		"A creep made it through! Our sponsors thank you for the drama.",
	],
	"low_lives": [
		"%d lives left. Our insurance department has been notified.",
		"%d lives remaining. This is what the professionals call 'content'.",
	],
	"boss_wave": [
		"Boss incoming: %s. Sponsors are paying extra for this one.",
		"Please welcome our special guest, %s! Try not to die on camera.",
		"%s has entered the arena. Viewers are placing bets. Not on you.",
	],
	"boss_killed": [
		"%s is down! Ratings are through the roof.",
		"Somebody deleted %s. The producers are thrilled and a little scared.",
	],
	"trip": [
		"%s tripped over their own building. Replaying that in slow motion.",
		"Breaking news: %s has discovered gravity.",
		"%s fell over. The audience would like to see that again.",
	],
	"ability": [
		"%s called a %s. %d creeps are reconsidering their career choices.",
		"%s just held a %s. %d creeps froze in sheer corporate terror.",
	],
	"selling_spree": [
		"%s is having a clearance sale. Everything must go!",
		"%s is selling towers like the gate isn't right there.",
	],
	"big_gift": [
		"%s just sent %d gold to %s. Friendship is magic. And taxable.",
		"%s wired %d gold to %s. The audience suspects bribery.",
	],
	"close_call": [
		"Level cleared with %d lives left. Nobody panic. (Panic.)",
		"Survived with %d lives. The ratings love a nail-biter.",
	],
	"sponsor": [
		"%s viewers! A sponsor would like a word. Several words, mostly legal.",
		"We just crossed %s viewers. Sponsor crate incoming!",
		"%s people are watching you. A sponsor has noticed. Pick something shiny.",
	],
	"halfway": [
		"Halfway there! Choose wisely: a Relic, or a whole second race. No pressure. Lots of pressure.",
	],
	"victory": [
		"They did it! Against all odds and several legal disclaimers, the gate holds!",
		"Victory! Please collect your participation trophy on the way out.",
	],
	"defeat": [
		"And the gate falls! Thank you for watching, and remember: it was mostly their fault.",
		"That's the show, folks. Better luck in your next life. You have zero.",
	],
}

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _last_spoke := -INF
var _said_once: Dictionary = {}
## peer id -> times of recent sells
var _sells: Dictionary = {}


func _init(run_seed := 0) -> void:
	_rng.seed = run_seed


func tick(delta: float) -> void:
	_time += delta


func run_started() -> String:
	return _once("run_start", _pick("run_start"), true)


func leaked(lives_left: int) -> String:
	if lives_left > 0 and lives_left <= LOW_LIVES and not _said_once.has("low_lives"):
		return _once("low_lives", _pick("low_lives") % lives_left, true)
	return _once("first_leak", _pick("first_leak"), true)


func boss_wave(boss_name: String) -> String:
	return _say(_pick("boss_wave") % boss_name, true)


func boss_killed(boss_name: String) -> String:
	return _say(_pick("boss_killed") % boss_name, true)


func tripped(player: String) -> String:
	return _say(_pick("trip") % player)


func ability_used(player: String, ability: String, creeps: int) -> String:
	if creeps <= 0:
		return ""
	return _say(_pick("ability") % [player, ability, creeps])


func sold(peer_id: int, player: String) -> String:
	var recent: Array = (_sells.get(peer_id, []) as Array).filter(func(at: float) -> bool: return _time - at < SPREE_SECONDS)
	recent.append(_time)
	_sells[peer_id] = recent
	if recent.size() < SPREE_SELLS:
		return ""
	_sells[peer_id] = []
	return _say(_pick("selling_spree") % player)


func gold_sent(from_player: String, amount: int, to_player: String) -> String:
	if amount < BIG_GIFT:
		return ""
	return _say(_pick("big_gift") % [from_player, amount, to_player])


func level_cleared(lives_left: int) -> String:
	if lives_left > 3:
		return ""
	return _say(_pick("close_call") % lives_left)


## A ratings milestone bought a sponsor offer.
func sponsor_milestone(viewers: int) -> String:
	return _say(_pick("sponsor") % LiveBadge.format_count(viewers), true)


func halfway() -> String:
	return _once("halfway", _pick("halfway"), true)


func run_ended(victory: bool) -> String:
	var kind := "victory" if victory else "defeat"
	return _once(kind, _pick(kind), true)


func _pick(kind: String) -> String:
	var pool: Array = LINES[kind]
	return str(pool[_rng.randi_range(0, pool.size() - 1)])


func _once(key: String, line: String, urgent := false) -> String:
	if _said_once.has(key):
		return ""
	var said := _say(line, urgent)
	if not said.is_empty():
		_said_once[key] = true
	return said


func _say(line: String, urgent := false) -> String:
	if not urgent and _time - _last_spoke < COOLDOWN:
		return ""
	_last_spoke = _time
	return line
