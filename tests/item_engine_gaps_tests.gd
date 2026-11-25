extends SceneTree
## Headless tests for the item engine gap closures (code prep
## code_prep_item_engine_gaps, binding build 6):
##   G1 — vitamins / EV feathers / nature mints gained real
##        ItemEngine arms (held-data effects, canon EV caps),
##        proven at the engine and through PUWItemTarget.
##   G2 — Ability Capsule / Patch resolve wherever
##        PUWSpeciesAbilities carries the species' own row
##        (held Showdown pokedex conversion) and keep refusing
##        needs_species_data where it does not.
##   G3 — PUWItemServices and ItemEngine.use_tera_shard run
##        against state["bag"] through PUWStateBagInventory;
##        the demo inventory is never in the path.
## HARNESS COPY for code_prep_exp_candy: this is the gaps
## prep's suite with exactly one test updated — test 8
## pinned all six candies to the old refusal; the five EXP
## Candies are implemented now (the hunt desk sourced their
## amounts, triple-checked), so test 8 pins only what stays
## refused by Bossy ruling: the Dynamax Candy and the Let's
## Go candies. Every other assertion is the gaps prep's own,
## unchanged. The original suite lives in
## code_prep_item_engine_gaps/tests/.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/item_engine_gaps_tests.gd
## It prints one PASS or FAIL line per test, then a summary
## line, then quits. Exit code 0 means every test passed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW item engine gaps tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/item_engine_gaps_tests.gd")
		quit(1)
		return
	_main()


func _main() -> void:
	await process_frame
	await _run("test_vitamin_engine_arm", Callable(self, "test_vitamin_engine_arm"))
	await _run("test_feather_engine_arm", Callable(self, "test_feather_engine_arm"))
	await _run("test_mint_engine_arm", Callable(self, "test_mint_engine_arm"))
	await _run("test_vitamin_through_item_target", Callable(self, "test_vitamin_through_item_target"))
	await _run("test_mint_through_item_target", Callable(self, "test_mint_through_item_target"))
	await _run("test_ability_capsule_and_patch", Callable(self, "test_ability_capsule_and_patch"))
	await _run("test_ability_species_without_data", Callable(self, "test_ability_species_without_data"))
	await _run("test_ruled_out_candies_stay_refused", Callable(self, "test_ruled_out_candies_stay_refused"))
	await _run("test_state_bag_adapter", Callable(self, "test_state_bag_adapter"))
	await _run("test_hyper_train_in_state", Callable(self, "test_hyper_train_in_state"))
	await _run("test_relearn_in_state", Callable(self, "test_relearn_in_state"))
	await _run("test_tera_shard_via_adapter", Callable(self, "test_tera_shard_via_adapter"))
	print("SUMMARY: " + str(_passed) + " passed, " + str(_failed) + " failed.")
	if _failed > 0:
		print("FAILED TESTS: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var result: Variant = await fn.call()
	var ok: bool = bool(result)
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _expect(cond: bool, what: String) -> bool:
	if not cond:
		print("  check failed: " + what)
	return cond


## The item-target suite's fixture dialect (Oak-grant shape).
func _mon(name: String, level: int, hp: int, max_hp: int, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {
		"name": name, "species": name, "species_slug": name.to_lower(), "species_id": 0,
		"family": "PKDX", "level": level, "hp": hp, "max_hp": max_hp,
		"status": "", "confused": false, "item": "", "held_item": "",
		"moves": [], "exp": 0, "exp_frac": 0.0,
		"evs": {"hp": 0, "atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0},
	}
	for k in extra.keys():
		m[k] = extra[k]
	return m


## NOTE (the item-target prep's own warning): build_state
## deep-copies the party, so tests rebind fixtures from
## state["party"] before inspecting them.
func _state(party: Array, bag: Dictionary, badges: Array = []) -> Dictionary:
	return PUWSaveManager.build_state(party, [], bag, 0, badges, [], [], {}, {"name": "Riley"})


func _ev_total(mon: Dictionary) -> int:
	var evs: Dictionary = mon.get("evs", {})
	var total: int = 0
	for k in evs.keys():
		total += int(evs[k])
	return total


# Test 1 (G1): the vitamin arm — +10 EV in the named stat,
# partial gains at the canon's ceilings, refusal when nothing
# fits, the fainted refusal, friendship on the engine's flat
# convention.
func test_vitamin_engine_arm() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 24, 30, 64)
	ok = _expect(ItemEngine.use_battle_item("HP Up", mon, logs), "HP Up must work on a fresh mon") and ok
	ok = _expect(int(mon["evs"]["hp"]) == 10, "HP EV must rise by 10, got " + str(mon["evs"])) and ok
	ok = _expect(int(mon.get("friendship", 0)) == 71, "friendship must rise by the flat 1 (70 default + 1), got " + str(mon.get("friendship", -1))) and ok
	ok = _expect(str(logs[logs.size() - 1]).begins_with("Used HP Up on"), "the final log line must be the engine's Used line") and ok
	# Partial gain at the per-stat ceiling: 250 + 10 -> 252.
	var capped: Dictionary = _mon("Pikachu", 24, 30, 64)
	capped["evs"]["atk"] = 250
	ok = _expect(ItemEngine.use_battle_item("Protein", capped, logs), "Protein at 250 Atk EV must partially apply") and ok
	ok = _expect(int(capped["evs"]["atk"]) == 252, "Atk EV must stop at 252, got " + str(capped["evs"]["atk"])) and ok
	# Partial gain at the total ceiling: 505 total, +10 -> +5.
	var totalled: Dictionary = _mon("Pikachu", 24, 30, 64)
	totalled["evs"] = {"hp": 252, "atk": 252, "def": 1, "spa": 0, "spd": 0, "spe": 0}
	ok = _expect(ItemEngine.use_battle_item("Calcium", totalled, logs), "Calcium at 505 total must partially apply") and ok
	ok = _expect(_ev_total(totalled) == 510, "the total must stop at 510, got " + str(_ev_total(totalled))) and ok
	# Nothing fits: stat already at the ceiling.
	var full: Dictionary = _mon("Pikachu", 24, 30, 64)
	full["evs"]["spe"] = 252
	ok = _expect(not ItemEngine.use_battle_item("Carbos", full, logs), "Carbos at 252 Spe EV must refuse") and ok
	ok = _expect(int(full["evs"]["spe"]) == 252, "a refusal must change nothing") and ok
	# Nothing fits: total already at the ceiling.
	var full_total: Dictionary = _mon("Pikachu", 24, 30, 64)
	full_total["evs"] = {"hp": 252, "atk": 252, "def": 6, "spa": 0, "spd": 0, "spe": 0}
	ok = _expect(not ItemEngine.use_battle_item("Zinc", full_total, logs), "Zinc at 510 total must refuse") and ok
	# Fainted refuses (the engine's EV Berry precedent).
	var fainted: Dictionary = _mon("Pikachu", 24, 0, 64)
	ok = _expect(not ItemEngine.use_battle_item("Iron", fainted, logs), "Iron on a fainted mon must refuse") and ok
	ok = _expect(int(fainted["evs"]["def"]) == 0, "the fainted refusal must change nothing") and ok
	return ok


# Test 2 (G1): the feather arm — +1 EV, both spellings of the
# item (compact slug and display name), refusal at the cap.
func test_feather_engine_arm() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 24, 30, 64)
	ok = _expect(ItemEngine.use_battle_item("Health Feather", mon, logs), "Health Feather (display name) must work") and ok
	ok = _expect(int(mon["evs"]["hp"]) == 1, "HP EV must rise by 1, got " + str(mon["evs"])) and ok
	ok = _expect(ItemEngine.use_battle_item("health-wing", mon, logs), "health-wing (compact slug) must work") and ok
	ok = _expect(int(mon["evs"]["hp"]) == 2, "HP EV must rise by 1 again, got " + str(mon["evs"])) and ok
	var capped: Dictionary = _mon("Pikachu", 24, 30, 64)
	capped["evs"]["spe"] = 252
	ok = _expect(not ItemEngine.use_battle_item("Swift Feather", capped, logs), "Swift Feather at 252 Spe EV must refuse") and ok
	# Pretty Wing has no use effect in the games: no arm.
	ok = _expect(not ItemEngine.use_battle_item("Pretty Wing", mon, logs), "Pretty Wing must stay unhandled") and ok
	return ok


# Test 3 (G1): the mint arm — the nature becomes the mint's
# own nature, the same-nature case refuses, a mon with no
# recorded nature gains one, and a fainted mon can take a
# mint (the engine's ability-arm precedent: not medicine).
func test_mint_engine_arm() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 24, 30, 64, {"nature": "Adamant"})
	ok = _expect(ItemEngine.use_battle_item("Lonely Mint", mon, logs), "Lonely Mint must work") and ok
	ok = _expect(str(mon.get("nature", "")) == "Lonely", "the nature must become Lonely, got " + str(mon.get("nature", ""))) and ok
	ok = _expect(ItemEngine.use_battle_item("Serious Mint", mon, logs), "Serious Mint must work") and ok
	ok = _expect(str(mon.get("nature", "")) == "Serious", "the nature must become Serious (neutral)") and ok
	ok = _expect(not ItemEngine.use_battle_item("Serious Mint", mon, logs), "a mint matching the current nature must refuse") and ok
	var plain: Dictionary = _mon("Pikachu", 24, 30, 64)
	plain.erase("nature")
	ok = _expect(ItemEngine.use_battle_item("Jolly Mint", plain, logs), "a mint must work on a mon with no recorded nature") and ok
	ok = _expect(str(plain.get("nature", "")) == "Jolly", "the nature must be recorded as Jolly") and ok
	var fainted: Dictionary = _mon("Pikachu", 24, 0, 64, {"nature": "Adamant"})
	ok = _expect(ItemEngine.use_battle_item("Timid Mint", fainted, logs), "a mint must work on a fainted mon (not medicine)") and ok
	ok = _expect(str(fainted.get("nature", "")) == "Timid", "the fainted mon's nature must change") and ok
	return ok


# Test 4 (G1): vitamins resolve through the whole bag flow —
# picker validity, consumption of exactly one, the engine's
# message — and refuse ev_full with the state byte-untouched
# when the ceilings leave no room.
func test_vitamin_through_item_target() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_mon("Pikachu", 24, 30, 64)], {"hp-up": 2})
	var mon: Dictionary = state["party"][0]
	ok = _expect(PUWItemTarget.use_mode(state, "hp-up") == "target", "hp-up must be a targeted item now") and ok
	var v: Dictionary = PUWItemTarget.target_validity(state, "use", "hp-up", 0)
	ok = _expect(bool(v.get("valid", false)), "hp-up on a fresh mon must be a valid target") and ok
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "hp-up", 0)
	ok = _expect(bool(res.get("ok", false)), "hp-up must resolve, got " + str(res)) and ok
	ok = _expect(int(mon["evs"]["hp"]) == 10, "HP EV must be 10 after the flow, got " + str(mon["evs"])) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "hp-up") == 1, "exactly one hp-up must be consumed") and ok
	ok = _expect(str(res.get("message", "")).contains("Used HP Up on Pikachu."), "the message must carry the engine's Used line, got: " + str(res.get("message", ""))) and ok
	# ev_full: a mon at the total ceiling greys out and the
	# resolver refuses without touching anything.
	var full_state: Dictionary = _state([_mon("Pikachu", 24, 30, 64)], {"hp-up": 1})
	var full_mon: Dictionary = full_state["party"][0]
	full_mon["evs"] = {"hp": 252, "atk": 252, "def": 6, "spa": 0, "spd": 0, "spe": 0}
	var before: String = JSON.stringify(full_mon)
	var fv: Dictionary = PUWItemTarget.target_validity(full_state, "use", "hp-up", 0)
	ok = _expect(not bool(fv.get("valid", true)) and str(fv.get("reason", "")) == "ev_full", "a capped mon must grey ev_full, got " + str(fv)) and ok
	var fres: Dictionary = PUWItemTarget.use_on_mon(full_state, "hp-up", 0)
	ok = _expect(not bool(fres.get("ok", true)) and str(fres.get("reason", "")) == "ev_full", "the resolver must refuse ev_full") and ok
	ok = _expect(JSON.stringify(full_mon) == before, "the ev_full refusal must leave the mon byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(full_state, "hp-up") == 1, "the ev_full refusal must not consume") and ok
	return ok


# Test 5 (G1): a mint resolves through the bag flow, and the
# same-nature target greys no_effect before anything is spent.
func test_mint_through_item_target() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_mon("Pikachu", 24, 30, 64, {"nature": "Adamant"})], {"jolly-mint": 2})
	var mon: Dictionary = state["party"][0]
	ok = _expect(PUWItemTarget.use_mode(state, "jolly-mint") == "target", "a mint must be a targeted item") and ok
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "jolly-mint", 0)
	ok = _expect(bool(res.get("ok", false)), "the mint must resolve, got " + str(res)) and ok
	ok = _expect(str(mon.get("nature", "")) == "Jolly", "the nature must be Jolly after the flow") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "jolly-mint") == 1, "exactly one mint must be consumed") and ok
	var v: Dictionary = PUWItemTarget.target_validity(state, "use", "jolly-mint", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "no_effect", "a same-nature target must grey no_effect, got " + str(v)) and ok
	var res2: Dictionary = PUWItemTarget.use_on_mon(state, "jolly-mint", 0)
	ok = _expect(not bool(res2.get("ok", true)), "the same-nature use must refuse") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "jolly-mint") == 1, "the refusal must not consume") and ok
	return ok


# Test 6 (G2): the ability items resolve from the species'
# own held row — Capsule cycles Pidgey's two regular
# abilities, Patch grants the Hidden one, and each arm
# refuses exactly where the engine would.
func test_ability_capsule_and_patch() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([_mon("Pidgey", 12, 30, 40, {"ability": "Keen Eye"})], {"ability-capsule": 3, "ability-patch": 2})
	var mon: Dictionary = state["party"][0]
	var res: Dictionary = PUWItemTarget.use_on_mon(state, "ability-capsule", 0)
	ok = _expect(bool(res.get("ok", false)), "the capsule must resolve for Pidgey, got " + str(res)) and ok
	ok = _expect(str(mon.get("ability", "")) == "Tangled Feet", "the capsule must switch to the other regular ability, got " + str(mon.get("ability", ""))) and ok
	res = PUWItemTarget.use_on_mon(state, "ability-capsule", 0)
	ok = _expect(bool(res.get("ok", false)) and str(mon.get("ability", "")) == "Keen Eye", "the capsule must cycle back to Keen Eye") and ok
	res = PUWItemTarget.use_on_mon(state, "ability-patch", 0)
	ok = _expect(bool(res.get("ok", false)) and str(mon.get("ability", "")) == "Big Pecks", "the patch must grant the Hidden ability Big Pecks, got " + str(mon.get("ability", ""))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "ability-patch") == 1, "exactly one patch must be consumed") and ok
	# Already on the Hidden ability: Patch has no effect and
	# Capsule cannot reach it (it is not in the regular list).
	var v: Dictionary = PUWItemTarget.target_validity(state, "use", "ability-patch", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "no_effect", "patch on the Hidden ability must grey no_effect, got " + str(v)) and ok
	v = PUWItemTarget.target_validity(state, "use", "ability-capsule", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "no_effect", "capsule on the Hidden ability must grey no_effect, got " + str(v)) and ok
	# A single-regular-ability species: the Capsule can never
	# work, the Patch can (Bulbasaur: Overgrow / Chlorophyll).
	var bulb_state: Dictionary = _state([_mon("Bulbasaur", 12, 30, 45, {"ability": "Overgrow"})], {"ability-capsule": 1, "ability-patch": 1})
	var bulb: Dictionary = bulb_state["party"][0]
	v = PUWItemTarget.target_validity(bulb_state, "use", "ability-capsule", 0)
	ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "no_effect", "capsule on a one-ability species must grey no_effect, got " + str(v)) and ok
	res = PUWItemTarget.use_on_mon(bulb_state, "ability-patch", 0)
	ok = _expect(bool(res.get("ok", false)) and str(bulb.get("ability", "")) == "Chlorophyll", "the patch must grant Bulbasaur's Chlorophyll") and ok
	return ok


# Test 7 (G2): a species the held data does not cover keeps
# the honest refusal, and the resolver's key folding matches
# the generated table's keys.
func test_ability_species_without_data() -> bool:
	var ok: bool = true
	ok = _expect(PUWSpeciesAbilities.species_count() == 1481, "the table must carry 1481 species rows, got " + str(PUWSpeciesAbilities.species_count())) and ok
	ok = _expect(PUWSpeciesAbilities.key_for("Mr. Mime") == "mrmime", "key folding: Mr. Mime -> mrmime") and ok
	ok = _expect(PUWSpeciesAbilities.key_for("Farfetch'd") == "farfetchd", "key folding: Farfetch'd -> farfetchd") and ok
	ok = _expect(PUWSpeciesAbilities.key_for("Nidoran♀") == "nidoranf", "key folding: Nidoran♀ -> nidoranf") and ok
	ok = _expect(PUWSpeciesAbilities.key_for("Type: Null") == "typenull", "key folding: Type: Null -> typenull") and ok
	ok = _expect(PUWSpeciesAbilities.has_species("Mr. Mime"), "Mr. Mime must have a row") and ok
	var mime_ctx: Dictionary = PUWSpeciesAbilities.context_for("Mr. Mime")
	ok = _expect(str(mime_ctx.get("hidden_ability", "")) == "Technician", "Mr. Mime's hidden ability must be Technician, got " + str(mime_ctx)) and ok
	# Pupjaw is an H-version fakemon: no row exists in the
	# held conversion, so both items refuse needs_species_data
	# and nothing is consumed or changed.
	ok = _expect(not PUWSpeciesAbilities.has_species("Pupjaw"), "Pupjaw must have no row in the held data") and ok
	var state: Dictionary = _state([_mon("Pupjaw", 12, 30, 40, {"ability": "Run Away"})], {"ability-capsule": 1, "ability-patch": 1})
	var mon: Dictionary = state["party"][0]
	var before: String = JSON.stringify(mon)
	for slug in ["ability-capsule", "ability-patch"]:
		var v: Dictionary = PUWItemTarget.target_validity(state, "use", slug, 0)
		ok = _expect(not bool(v.get("valid", true)) and str(v.get("reason", "")) == "needs_species_data", slug + " on an unsourced species must grey needs_species_data, got " + str(v)) and ok
		var res: Dictionary = PUWItemTarget.use_on_mon(state, slug, 0)
		ok = _expect(not bool(res.get("ok", true)) and str(res.get("reason", "")) == "needs_species_data", slug + " must refuse needs_species_data") and ok
	ok = _expect(JSON.stringify(mon) == before, "the refusals must leave the mon byte-identical") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "ability-capsule") == 1 and PUWLiveBag.count_in_state(state, "ability-patch") == 1, "the refusals must not consume") and ok
	return ok


# Test 8 (boundary, UPDATED for code_prep_exp_candy): the
# five EXP Candies left this test — the hunt desk sourced
# their EXP amounts (Bulbapedia / PokémonDB / Serebii, in
# exact agreement) and code_prep_exp_candy implemented
# them; its own suite proves them. What stays refused is
# what Bossy ruled out: the Dynamax Candy (it raises a
# Dynamax Level no mon record carries — a Galar-turn build
# item) and the Let's Go candies, stat and species alike
# (they feed the Awakening Value system PUW does not
# adopt). The engine has no arm for them, the bag flow
# reports engine_gap, nothing is consumed. Rare Candy is
# not one of them either (its arm predates this prep).
func test_ruled_out_candies_stay_refused() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 24, 30, 64)
	for item_name in ["Dynamax Candy", "Health Candy", "Health Candy L", "Quick Candy XL", "Pikachu Candy"]:
		ok = _expect(not ItemEngine.use_battle_item(item_name, mon, logs), item_name + " must have no engine arm (Bossy-ruled refusal)") and ok
	var state: Dictionary = _state([_mon("Pikachu", 24, 30, 64)], {"dynamax-candy": 1, "health-candy": 1, "pikachu-candy": 1})
	for slug in ["dynamax-candy", "health-candy", "pikachu-candy"]:
		ok = _expect(PUWItemTarget.use_mode(state, slug) == "none", slug + " must not be a targeted item") and ok
		var nu: Dictionary = PUWItemTarget.not_usable_result(state, slug)
		ok = _expect(str(nu.get("reason", "")) == "engine_gap", slug + " must refuse engine_gap, got " + str(nu)) and ok
	return ok


# Test 9 (G3): the adapter counts, grants and consumes
# against state["bag"] with the state's own id dialect, and
# carries no demo inventory; a plain PUWInventoryManager
# keeps its demo seed, untouched by the adapter's state.
func test_state_bag_adapter() -> bool:
	var ok: bool = true
	var state: Dictionary = _state([], {"poke-ball": 3, "bottle-cap": 1})
	var adapter: PUWStateBagInventory = PUWStateBagInventory.new(state)
	ok = _expect(adapter.count_item("poke_ball") == 3, "the other spelling must count the same stack, got " + str(adapter.count_item("poke_ball"))) and ok
	ok = _expect(adapter.count_item("poke-ball") == 3, "the stored spelling must count 3") and ok
	ok = _expect(adapter.items.is_empty(), "the adapter must carry no demo inventory") and ok
	ok = _expect(adapter.consume_item("poke-ball", 2), "consuming 2 of 3 must succeed") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "poke-ball") == 1, "the state bag must drop to 1") and ok
	ok = _expect(not adapter.consume_item("poke-ball", 2), "consuming more than held must refuse") and ok
	ok = _expect(adapter.add_item("potion", 2) == 2, "granting a new item must report the new total") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "potion") == 2, "the grant must land in the state bag") and ok
	var demo: PUWInventoryManager = PUWInventoryManager.new()
	ok = _expect(demo.count_item("potion") == 15, "a plain manager keeps its own demo seed (15 potions), got " + str(demo.count_item("potion"))) and ok
	ok = _expect(demo.count_item("bottle-cap") == 0, "the demo store holds no Bottle Cap while the state bag holds 1 — the two stores are independent") and ok
	# The demo store is worse than unbound (verified here
	# against the bound code): its seed keys are the project
	# spelling ("poke_ball") while the registry's canonical id
	# is hyphenated, so its own count_item cannot reach its
	# seeded Poké Balls at all. The adapter path never reads
	# this store; the observation is recorded for the report.
	ok = _expect(int((demo.items.get("poke_ball", {}) as Dictionary).get("qty", 0)) == 20, "the demo seed's raw dict does list 20 poke_ball") and ok
	ok = _expect(demo.count_item("poke-ball") == 0, "yet the demo manager's own API cannot count them (canonical spelling mismatch)") and ok
	demo.free()
	adapter.free()
	return ok


# Test 10 (G3): Hyper Training spends the Bottle Cap from
# the player's real bag and refuses — untouched — when the
# bag cannot pay. The bound entry point keeps working
# against a plain manager exactly as before.
func test_hyper_train_in_state() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 50, 100, 120, {"ivs": {"hp": 31, "atk": 12, "def": 31, "spa": 31, "spd": 31, "spe": 31}})
	var state: Dictionary = _state([], {"bottle-cap": 1})
	ok = _expect(PUWItemServices.hyper_train_in_state(mon, "Bottle Cap", "atk", state, logs), "hyper training must succeed against the state bag") and ok
	ok = _expect(PUWItemServices.effective_iv(mon, "atk") == 31, "the trained stat must read IV 31") and ok
	ok = _expect(int(mon.get("ivs", {}).get("atk", 0)) == 12, "the base IV must stay 12 (training is a flag, not an edit)") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "bottle-cap") == 0, "the Bottle Cap must be spent from the state bag") and ok
	var poor_state: Dictionary = _state([], {})
	var mon2: Dictionary = _mon("Pikachu", 50, 100, 120, {"ivs": {"hp": 31, "atk": 12, "def": 31, "spa": 31, "spd": 31, "spe": 31}})
	ok = _expect(not PUWItemServices.hyper_train_in_state(mon2, "Bottle Cap", "atk", poor_state, logs), "hyper training with no Bottle Cap in the bag must refuse") and ok
	ok = _expect(not mon2.has("hyper_trained"), "the refusal must leave the mon untouched") and ok
	# The bound signature against a plain (demo) manager is
	# unchanged: it spends from that manager.
	var demo: PUWInventoryManager = PUWInventoryManager.new()
	demo.add_item("bottle-cap", 1)
	var mon3: Dictionary = _mon("Pikachu", 50, 100, 120, {"ivs": {"hp": 31, "atk": 12, "def": 31, "spa": 31, "spd": 31, "spe": 31}})
	ok = _expect(PUWItemServices.hyper_train(mon3, "Bottle Cap", "atk", demo, logs), "the bound hyper_train must still work with a plain manager") and ok
	ok = _expect(demo.count_item("bottle-cap") == 0, "the plain manager must be charged, as before") and ok
	demo.free()
	return ok


# Test 11 (G3): the move relearner spends the Heart Scale
# from the real bag; without one it refuses and teaches
# nothing.
func test_relearn_in_state() -> bool:
	var ok: bool = true
	var logs: Array = []
	var rows: Array = [{"move": "Quick Attack", "level": 13}, {"move": "Electro Ball", "level": 18}]
	var mon: Dictionary = _mon("Pikachu", 20, 50, 60, {"moves": ["Tackle"]})
	var state: Dictionary = _state([], {"heart-scale": 1})
	ok = _expect(PUWItemServices.relearn_move_in_state(mon, "Quick Attack", -1, rows, state, logs), "relearning must succeed against the state bag") and ok
	ok = _expect((mon.get("moves", []) as Array).has("Quick Attack"), "the move must be learned") and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "heart-scale") == 0, "the Heart Scale must be spent from the state bag") and ok
	var mon2: Dictionary = _mon("Pikachu", 20, 50, 60, {"moves": ["Tackle"]})
	ok = _expect(not PUWItemServices.relearn_move_in_state(mon2, "Quick Attack", -1, rows, state, logs), "relearning with no Heart Scale left must refuse") and ok
	ok = _expect(not (mon2.get("moves", []) as Array).has("Quick Attack"), "the refusal must teach nothing") and ok
	return ok


# Test 12 (G3): Tera Shards charge the real bag through the
# adapter — 50 shards buy the type change, 49 refuse and
# change nothing. ItemEngine.use_tera_shard itself is
# unmodified; the adapter is what binds it to the save.
func test_tera_shard_via_adapter() -> bool:
	var ok: bool = true
	var logs: Array = []
	var mon: Dictionary = _mon("Pikachu", 24, 30, 64)
	var state: Dictionary = _state([], {"fire-tera-shard": 50})
	var adapter: PUWStateBagInventory = PUWStateBagInventory.new(state)
	ok = _expect(ItemEngine.use_tera_shard("Fire Tera Shard", mon, adapter, logs), "50 shards in the state bag must buy the type change") and ok
	ok = _expect(str(mon.get("tera_type", "")) == "Fire", "the Tera Type must be Fire, got " + str(mon.get("tera_type", ""))) and ok
	ok = _expect(PUWLiveBag.count_in_state(state, "fire-tera-shard") == 0, "all 50 shards must be spent from the state bag") and ok
	var mon2: Dictionary = _mon("Pikachu", 24, 30, 64)
	var poor_state: Dictionary = _state([], {"fire-tera-shard": 49})
	var poor_adapter: PUWStateBagInventory = PUWStateBagInventory.new(poor_state)
	ok = _expect(not ItemEngine.use_tera_shard("Fire Tera Shard", mon2, poor_adapter, logs), "49 shards must refuse") and ok
	ok = _expect(str(mon2.get("tera_type", "")) == "", "the refusal must not set a Tera Type") and ok
	ok = _expect(PUWLiveBag.count_in_state(poor_state, "fire-tera-shard") == 49, "the refusal must not spend shards") and ok
	adapter.free()
	poor_adapter.free()
	return ok
