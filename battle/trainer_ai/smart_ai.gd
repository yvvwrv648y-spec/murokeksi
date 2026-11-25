# PUWSmartAI — Smart battle AI and overworld NPC AI for PUW (Godot 4)
#
# What this does, in plain words:
# This is PUW's own battle brain, written from scratch for this project.
# It does three battle jobs and one overworld job:
#   1. Pick the best move: it scores every move by how strong it is, how
#      good its type is against the other Pokemon, STAB (same-type bonus),
#      and accuracy, then picks the best one.
#   2. Decide when to switch: if the active Pokemon is in big type trouble
#      or nearly fainted, and a better Pokemon is waiting in the party.
#   3. Decide when to use an item: heal when HP is low, cure a bad status.
#   4. Overworld NPCs: a small brain for people walking around town. They
#      walk between points, stop, talk to the player, and follow a simple
#      day schedule (home in the morning, shop at noon, home at night).
#
# How to use it:
#   var ai = PUWSmartAI.new()
#   var move = ai.choose_move(my_moves, my_pokemon, enemy_pokemon)
#   var switch_plan = ai.should_switch(my_pokemon, my_party, enemy_pokemon)
#   var item = ai.choose_item(my_pokemon, my_items)
#   var npc = PUWSmartAI.NPCBrain.new()
#   npc.waypoints = [Vector2(0, 0), Vector2(100, 0)]
#   npc.update(delta, npc_node, hour_of_day)
#
# What a Pokemon looks like to this AI (a Dictionary):
#   {"species": "charizard", "types": ["fire", "flying"], "hp": 78,
#    "max_hp": 78, "attack": 84, "defense": 78, "speed": 100,
#    "status": "", "level": 50}
# What a move looks like (a Dictionary):
#   {"name": "flamethrower", "type": "fire", "power": 90, "accuracy": 100,
#    "category": "special", "priority": 0, "effect": ""}
#   "category" is "physical", "special", or "status". "effect" can be
#   "burn", "paralyze", "sleep", "poison", or "".
#
# Difficulty:
#   "easy"   — picks a random move, never switches, never uses items.
#   "normal" — picks the best scored move, switches only when in danger.
#   "hard"   — best move, smart switching, and uses items.
# Set ai.difficulty to change it.

class_name PUWSmartAI
extends RefCounted

## How good each type is against each other type. Only the numbers that
## are not 1.0 are listed here; anything missing counts as 1.0.
## This is the standard Pokemon type chart (Generations 6 and later).
const TYPE_CHART: Dictionary = {
	"normal": {"rock": 0.5, "ghost": 0.0, "steel": 0.5},
	"fire": {"fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 2.0,
		"bug": 2.0, "rock": 0.5, "dragon": 0.5, "steel": 2.0},
	"water": {"fire": 2.0, "water": 0.5, "grass": 0.5, "ground": 2.0,
		"rock": 2.0, "dragon": 0.5},
	"electric": {"water": 2.0, "electric": 0.5, "grass": 0.5, "ground": 0.0,
		"flying": 2.0, "dragon": 0.5},
	"grass": {"fire": 0.5, "water": 2.0, "grass": 0.5, "poison": 0.5,
		"ground": 2.0, "flying": 0.5, "bug": 0.5, "rock": 2.0,
		"dragon": 0.5, "steel": 0.5},
	"ice": {"fire": 0.5, "water": 0.5, "grass": 2.0, "ice": 0.5,
		"ground": 2.0, "flying": 2.0, "dragon": 2.0, "steel": 0.5},
	"fighting": {"normal": 2.0, "ice": 2.0, "poison": 0.5, "flying": 0.5,
		"psychic": 0.5, "bug": 0.5, "rock": 2.0, "ghost": 0.0,
		"dark": 2.0, "steel": 2.0, "fairy": 0.5},
	"poison": {"grass": 2.0, "poison": 0.5, "ground": 0.5, "rock": 0.5,
		"ghost": 0.5, "steel": 0.0, "fairy": 2.0},
	"ground": {"fire": 2.0, "electric": 2.0, "grass": 0.5, "poison": 2.0,
		"flying": 0.0, "bug": 0.5, "rock": 2.0, "steel": 2.0},
	"flying": {"electric": 0.5, "grass": 2.0, "fighting": 2.0, "bug": 2.0,
		"rock": 0.5, "steel": 0.5},
	"psychic": {"fighting": 2.0, "poison": 2.0, "psychic": 0.5,
		"dark": 0.0, "steel": 0.5},
	"bug": {"fire": 0.5, "grass": 2.0, "fighting": 0.5, "poison": 0.5,
		"flying": 0.5, "psychic": 2.0, "ghost": 0.5, "dark": 2.0,
		"steel": 0.5, "fairy": 0.5},
	"rock": {"fire": 2.0, "ice": 2.0, "fighting": 0.5, "ground": 0.5,
		"flying": 2.0, "bug": 2.0, "steel": 0.5},
	"ghost": {"normal": 0.0, "psychic": 2.0, "ghost": 2.0, "dark": 0.5},
	"dragon": {"dragon": 2.0, "steel": 0.5, "fairy": 0.0},
	"dark": {"fighting": 0.5, "psychic": 2.0, "ghost": 2.0, "dark": 0.5,
		"fairy": 0.5},
	"steel": {"fire": 0.5, "water": 0.5, "electric": 0.5, "ice": 2.0,
		"rock": 2.0, "steel": 0.5, "fairy": 2.0},
	"fairy": {"fire": 0.5, "fighting": 2.0, "poison": 0.5, "dragon": 2.0,
		"dark": 2.0, "steel": 0.5},
}

## "easy", "normal", or "hard". See the header for what each one does.
var difficulty: String = "normal"

## Small random wobble added to move scores, so the AI does not always
## pick the exact same move in the exact same spot. Set to 0 for tests.
var score_jitter: float = 5.0


## How good one type is against a Pokemon with one or two types.
## Returns 0.0, 0.25, 0.5, 1.0, 2.0, or 4.0.
func effectiveness(move_type: String, defender_types: Array) -> float:
	var result: float = 1.0
	var row: Dictionary = TYPE_CHART.get(move_type.to_lower(), {})
	for defender_type in defender_types:
		result *= float(row.get(str(defender_type).to_lower(), 1.0))
	return result


## Score one move. Higher is better. The score is roughly:
## power x type goodness x STAB x accuracy, plus small bonuses for
## status moves and priority moves.
func score_move(move: Dictionary, attacker: Dictionary, defender: Dictionary) -> float:
	var power: float = float(move.get("power", 0))
	var move_type: String = str(move.get("type", "normal")).to_lower()
	var accuracy: float = float(move.get("accuracy", 100))
	var eff: float = effectiveness(move_type, defender.get("types", []))
	if move.get("category", "") == "status":
		# A status move is worth more when the target has no status yet.
		var bonus: float = 40.0 if str(defender.get("status", "")).is_empty() else 5.0
		if eff == 0.0:
			return 0.0
		return bonus + float(move.get("priority", 0)) * 10.0
	if power <= 0.0:
		return 0.0
	if eff == 0.0:
		return 0.0
	var score: float = power * eff * (accuracy / 100.0)
	# STAB: same type as the attacker is 1.5x.
	if move_type in attacker.get("types", []):
		score *= 1.5
	# Priority moves are worth more when the attacker is slower.
	if int(move.get("priority", 0)) > 0 and int(attacker.get("speed", 0)) < int(defender.get("speed", 0)):
		score *= 1.2
	# A finishing blow is worth more than a weak hit.
	var rough_damage: float = score / 10.0
	if rough_damage >= float(defender.get("hp", 1)):
		score *= 1.5
	return score + randf_range(0.0, score_jitter)


## Pick the best move from a list. Returns the move Dictionary.
func choose_move(moves: Array, attacker: Dictionary, defender: Dictionary) -> Dictionary:
	if moves.is_empty():
		return {}
	if difficulty == "easy":
		return moves[randi() % moves.size()]
	var best: Dictionary = moves[0]
	var best_score: float = -1.0
	for move in moves:
		var score: float = score_move(move, attacker, defender)
		if score > best_score:
			best_score = score
			best = move
	return best


## Should the AI switch out, and to whom?
## Returns {"switch": false} or {"switch": true, "to_index": 2}.
## "party" is an Array of Pokemon Dictionaries; "active_index" says
## which one is fighting right now.
func should_switch(active: Dictionary, party: Array, active_index: int,
		defender: Dictionary) -> Dictionary:
	var no_switch: Dictionary = {"switch": false, "to_index": -1}
	if difficulty == "easy":
		return no_switch
	var active_hp_frac: float = float(active.get("hp", 1)) / max(1.0, float(active.get("max_hp", 1)))
	var active_eff: float = _best_offense_against(active, defender)
	var in_danger: bool = active_eff <= 0.5 and active_hp_frac < 0.5
	var nearly_dead: bool = active_hp_frac < 0.25
	if not (in_danger or nearly_dead):
		return no_switch
	var best_index: int = -1
	var best_value: float = 0.0
	for i in range(party.size()):
		if i == active_index:
			continue
		var member: Dictionary = party[i]
		if int(member.get("hp", 0)) <= 0:
			continue
		var member_hp_frac: float = float(member["hp"]) / max(1.0, float(member["max_hp"]))
		var value: float = _best_offense_against(member, defender) * (0.5 + member_hp_frac)
		if value > best_value:
			best_value = value
			best_index = i
	if best_index == -1:
		return no_switch
	# Only switch if the new Pokemon is clearly better than staying.
	if best_value <= active_eff * 1.5 and not nearly_dead:
		return no_switch
	return {"switch": true, "to_index": best_index}


## Best type goodness any of a Pokemon's moves could have, guessed from
## its own types (used when we do not know its move list).
func _best_offense_against(attacker: Dictionary, defender: Dictionary) -> float:
	var best: float = 0.0
	for attack_type in attacker.get("types", []):
		var eff: float = effectiveness(str(attack_type), defender.get("types", []))
		if eff > best:
			best = eff
	return best


## Pick an item to use, or "" for none.
## "items" is a Dictionary of item name -> count.
## Known items: "potion", "super_potion", "hyper_potion", "full_restore",
## "antidote", "paralyze_heal", "awakening", "burn_heal", "ice_heal".
func choose_item(battler: Dictionary, items: Dictionary) -> String:
	if difficulty != "hard":
		return ""
	var hp_frac: float = float(battler.get("hp", 1)) / max(1.0, float(battler.get("max_hp", 1)))
	var status: String = str(battler.get("status", ""))
	if status == "poison" and int(items.get("antidote", 0)) > 0:
		return "antidote"
	if status == "paralyze" and int(items.get("paralyze_heal", 0)) > 0:
		return "paralyze_heal"
	if status == "sleep" and int(items.get("awakening", 0)) > 0:
		return "awakening"
	if status == "burn" and int(items.get("burn_heal", 0)) > 0:
		return "burn_heal"
	if status == "freeze" and int(items.get("ice_heal", 0)) > 0:
		return "ice_heal"
	if hp_frac < 0.25 and int(items.get("full_restore", 0)) > 0:
		return "full_restore"
	if hp_frac < 0.3 and int(items.get("hyper_potion", 0)) > 0:
		return "hyper_potion"
	if hp_frac < 0.5 and int(items.get("super_potion", 0)) > 0:
		return "super_potion"
	if hp_frac < 0.6 and int(items.get("potion", 0)) > 0:
		return "potion"
	return ""


## ------------------------------------------------------------------
## Overworld NPC brain. One NPCBrain per person walking around town.
##
## States: "idle" (standing still), "walk" (walking to the next point),
## "talk" (talking to the player), "home" (going to the home point).
## The brain keeps a simple day schedule: a list of
## {"hour": 8, "point": Vector2(100, 50), "name": "shop"} entries.
## When the hour changes, the NPC walks to that hour's point and waits.
##
## How to use it:
##   var brain = PUWSmartAI.NPCBrain.new()
##   brain.waypoints = [Vector2(0, 0), Vector2(120, 0), Vector2(120, 80)]
##   brain.talk_lines = ["Hello, trainer!", "Nice day, isn't it?"]
##   brain.speed = 40.0
##   # every frame, in your NPC's _process():
##   brain.update(delta, self, current_hour)
##   # when the player talks to the NPC:
##   var line = brain.talk()
## ------------------------------------------------------------------
class NPCBrain:
	extends RefCounted

	var state: String = "idle"
	var waypoints: Array[Vector2] = []
	var waypoint_index: int = 0
	var speed: float = 40.0
	var talk_lines: Array[String] = ["Hello!"]
	var schedule: Array = []
	var home_point: Vector2 = Vector2.ZERO
	var idle_timer: float = 0.0
	var _target: Vector2 = Vector2.ZERO
	var _has_target: bool = false
	var _on_schedule: bool = false

	func update(delta: float, npc_node: Node2D, hour: int = 12) -> void:
		if state == "talk":
			return
		_check_schedule(hour, npc_node.position)
		match state:
			"idle":
				idle_timer -= delta
				# Waypoints only run when no schedule point is holding the NPC.
				if idle_timer <= 0.0 and not _on_schedule and not waypoints.is_empty():
					waypoint_index = (waypoint_index + 1) % waypoints.size()
					_target = waypoints[waypoint_index]
					_has_target = true
					state = "walk"
			"walk":
				if not _has_target:
					state = "idle"
					idle_timer = randf_range(1.0, 3.0)
					return
				var to_target: Vector2 = _target - npc_node.position
				if to_target.length() < 4.0:
					npc_node.position = _target
					_has_target = false
					state = "idle"
					idle_timer = randf_range(1.0, 4.0)
				else:
					npc_node.position += to_target.normalized() * speed * delta
			"home":
				var to_home: Vector2 = home_point - npc_node.position
				if to_home.length() < 4.0:
					npc_node.position = home_point
					state = "idle"
					idle_timer = 5.0
				else:
					npc_node.position += to_home.normalized() * speed * delta

	## Start talking. Returns one of the NPC's lines.
	func talk() -> String:
		state = "talk"
		if talk_lines.is_empty():
			return "..."
		return talk_lines[randi() % talk_lines.size()]

	## Stop talking and go back to idling.
	func stop_talking() -> void:
		if state == "talk":
			state = "idle"
			idle_timer = 2.0

	## Send the NPC home (used at night, or when the shop closes).
	func go_home() -> void:
		state = "home"
		_has_target = false

	func _check_schedule(hour: int, npc_position: Vector2) -> void:
		if schedule.is_empty():
			_on_schedule = false
			return
		var best: Dictionary = {}
		for entry in schedule:
			if int(entry.get("hour", 0)) <= hour:
				if best.is_empty() or int(entry["hour"]) > int(best["hour"]):
					best = entry
		if best.is_empty():
			_on_schedule = false
			return
		var point: Vector2 = best.get("point", Vector2.ZERO)
		if npc_position.distance_to(point) <= 8.0:
			# Already at today's point: stay here, do not wander off.
			_on_schedule = true
			return
		_on_schedule = true
		if not _has_target or _target != point:
			_target = point
			_has_target = true
			state = "walk"
