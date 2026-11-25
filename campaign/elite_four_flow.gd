class_name EliteFourFlow
extends RefCounted
## The Elite Four gauntlet and Hall of Fame for Pokemon Ultimate
## World.
##
## Rules: the player needs all 8 badges to enter. The gauntlet runs
## the opponent sequence from the data file in order, with no Center
## break written into the flow (healing between battles is the
## player's own items, as in the games). Losing at any point ends the
## run and the player must start the gauntlet over. Beating the final
## opponent (the Champion) records the party in the Hall of Fame.


## Start a gauntlet run. sequence is the ordered opponent id list
## from the trainer data file. Returns false when the badge gate is
## not met or the sequence is empty.
static func start_gauntlet(state: Dictionary, sequence: Array) -> bool:
	if not GymProgression.can_challenge_elite_four(state):
		return false
	if sequence.is_empty():
		return false
	state["e4_run"] = {"order": sequence.duplicate(), "index": 0, "active": true}
	return true


## The opponent id the player faces next, or "" when no run is
## active or the run is finished.
static func current_opponent(state: Dictionary) -> String:
	var run: Dictionary = state.get("e4_run", {})
	if not bool(run.get("active", false)):
		return ""
	var order: Array = run.get("order", [])
	var index: int = int(run.get("index", 0))
	if index >= order.size():
		return ""
	return str(order[index])


## Record a win against the current opponent. Beating the last one
## (the Champion) ends the run, sets the champion flag, and writes
## the Hall of Fame entry. Returns true when the win was recorded.
static func record_win(state: Dictionary) -> bool:
	var run: Dictionary = state.get("e4_run", {})
	if not bool(run.get("active", false)):
		return false
	var order: Array = run.get("order", [])
	var index: int = int(run.get("index", 0)) + 1
	run["index"] = index
	if index >= order.size():
		run["active"] = false
		state["e4_run"] = run
		var flags: Dictionary = state.get("flags", {})
		flags["champion"] = true
		state["flags"] = flags
		register_hall_of_fame(state)
	else:
		state["e4_run"] = run
	return true


## A loss ends the run; the gauntlet must be restarted from the
## first opponent, as in the games.
static func record_loss(state: Dictionary) -> void:
	state["e4_run"] = {}


## Write a Hall of Fame entry: a snapshot of the winning party plus
## the badge count at the time of the win.
static func register_hall_of_fame(state: Dictionary) -> Dictionary:
	var party: Array = state.get("party", [])
	var entry: Dictionary = {
		"party": party.duplicate(true),
		"badge_count": GymProgression.badge_count(state),
	}
	var hof: Array = state.get("hall_of_fame", [])
	hof.append(entry)
	state["hall_of_fame"] = hof
	return entry
