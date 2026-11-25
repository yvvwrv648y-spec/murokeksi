class_name PUWLiveBag
extends RefCounted
## Live bag wiring: the bridge between the real save state and
## the bound BW2 menu screens (binding build 6, code prep
## code_prep_live_bag).
##
## THE STATE CONTRACT. The one bag the game saves is
## state["bag"] in a PUWSaveManager state dict: a plain
## Dictionary mapping an item id to an int count, zero counts
## erased (the shape PUWQuestBoard, PUWGymRequirements and
## PUWCampaignStitch already read and write). Item ids reach
## that dict in either source spelling (PokeAPI "poke-ball" or
## project "poke_ball"); every function here resolves ids
## through PUWItemRegistry.canonical_id_for, so the two
## spellings of one item are one stack — the item-integrity
## rule the registry and MartShop already enforce.
##
## What this class owns:
## - holdings_for_screen(): state bag -> the exact row shape
##   PUWBagScreen renders ({"slug", "qty", "pocket"}), so the
##   screen shows the player's real items instead of the demo
##   holdings build 3 had to ship.
## - grant / count / consume against the state bag, in the
##   state's own key dialect (an existing stack keeps its key;
##   a new stack is created under the canonical id).
## - use_in_overworld(): the field-use path for the item
##   classes build 4 named as unwired call sites — the Repel
##   family (ItemEngine.repel_steps_for -> the habitat repel
##   counter, persisted into the state under the additive
##   "habitat_repel" key PUWHabitatEncounters already owns)
##   and the Escape Rope (ItemEngine.is_escape_rope ->
##   PUWMapLoader.escape_rope_target). Escape-class battle
##   items (Poké Doll / Fluffy Tail, ItemEngine.
##   guarantees_escape) refuse here: their use path is the
##   battle controller's, wired in build 4, and an overworld
##   use must never consume one. Every refusal returns
##   {"ok": false, "reason": ...} and leaves the state
##   untouched; nothing is consumed on a failed use.
##
## Pocket indices mirror PUWBagScreen.POCKETS exactly (the
## test suite pins the two lists equal):
##   0 Items, 1 Medicine, 2 Poké Balls, 3 TMs & HMs,
##   4 Berries, 5 Key Items.
## Pocket assignment comes from the item's category in
## items_full_compact.json (the same data the bag screen
## loads for names/descriptions), with three data-driven
## overrides: any slug ending in "berry" is a Berry; a
## canonical entry the registry files under "key_items" is
## a Key Item even when the compact data has no row for it
## (the Omni Ring is one); and KEY_ITEM_SLUGS names the
## classic key items the compact categories file elsewhere.
## An item no data source knows still gets a row (pocket 0,
## its slug as its name) — a held item is never hidden.

const ITEMS_PATH: String = "res://data/items_full_compact.json"

const POCKET_ITEMS: int = 0
const POCKET_MEDICINE: int = 1
const POCKET_BALLS: int = 2
const POCKET_TMS: int = 3
const POCKET_BERRIES: int = 4
const POCKET_KEY: int = 5

const POCKET_NAMES: Array = ["Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Key Items"]

const CATEGORY_POCKETS: Dictionary = {
	"standard-balls": POCKET_BALLS,
	"special-balls": POCKET_BALLS,
	"apricorn-balls": POCKET_BALLS,
	"healing": POCKET_MEDICINE,
	"revival": POCKET_MEDICINE,
	"status-cures": POCKET_MEDICINE,
	"medicine": POCKET_MEDICINE,
	"picky-healing": POCKET_MEDICINE,
	"pp-recovery": POCKET_MEDICINE,
	"vitamins": POCKET_MEDICINE,
	"all-machines": POCKET_TMS,
	"plot-advancement": POCKET_KEY,
}

const KEY_ITEM_SLUGS: Array = ["bicycle", "town-map"]

static var _item_data: Dictionary = {}
static var _item_data_loaded: bool = false


## The compact item data (slug -> entry), loaded once. Empty
## when the data file is missing: pocket assignment then
## falls back to the suffix / registry / default rules and
## every held item still lists.
static func _load_item_data() -> Dictionary:
	if _item_data_loaded:
		return _item_data
	_item_data_loaded = true
	_item_data = {}
	if not FileAccess.file_exists(ITEMS_PATH):
		return _item_data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return _item_data
	var data: Dictionary = parsed
	var items_value: Variant = data.get("items", [])
	if items_value is Array:
		var items: Array = items_value
		for entry_value in items:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				_item_data[str(entry.get("slug", ""))] = entry
	return _item_data


## The pocket index (0..5) one canonical slug renders in.
static func pocket_for_slug(slug: String) -> int:
	if slug.ends_with("berry"):
		return POCKET_BERRIES
	if KEY_ITEM_SLUGS.has(slug):
		return POCKET_KEY
	var data: Dictionary = _load_item_data()
	var entry_value: Variant = data.get(slug, {})
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		var category: String = str(entry.get("category", ""))
		if CATEGORY_POCKETS.has(category):
			return int(CATEGORY_POCKETS[category])
	var registry_entry: Dictionary = PUWItemRegistry.get_entry(slug)
	if str(registry_entry.get("category", "")) == "key_items":
		return POCKET_KEY
	return POCKET_ITEMS


## Display name for sorting: compact data first, then the
## registry, then the slug itself.
static func display_name_for(slug: String) -> String:
	var data: Dictionary = _load_item_data()
	var entry_value: Variant = data.get(slug, {})
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value
		var display: String = str(entry.get("display_name", ""))
		if display != "":
			return display
	var registry_entry: Dictionary = PUWItemRegistry.get_entry(slug)
	var reg_name: String = str(registry_entry.get("name", ""))
	if reg_name != "":
		return reg_name
	return slug


## The state's bag dict ({} when the key is absent or not a
## Dictionary). Returns the live nested dict; callers that
## mutate it write it back with _store_bag, the house pattern.
static func _bag_of(state: Dictionary) -> Dictionary:
	var bag_value: Variant = state.get("bag", {})
	if bag_value is Dictionary:
		var bag: Dictionary = bag_value
		return bag
	return {}


static func _store_bag(state: Dictionary, bag: Dictionary) -> void:
	state["bag"] = bag


## Total held of one item across every spelling of its id
## present in the state bag.
static func count_in_state(state: Dictionary, item_id: String) -> int:
	var canonical: String = PUWItemRegistry.canonical_id_for(item_id)
	if canonical == "":
		return 0
	var total: int = 0
	var bag: Dictionary = _bag_of(state)
	for key_value in bag.keys():
		var key: String = str(key_value)
		if PUWItemRegistry.canonical_id_for(key) == canonical:
			total += int(bag.get(key, 0))
	return total


## Add qty of an item to the state bag. An existing stack
## (under any spelling) keeps its key; a new stack is created
## under the canonical id. Returns the new total held.
static func grant_to_state(state: Dictionary, item_id: String, qty: int) -> int:
	if qty < 1:
		return count_in_state(state, item_id)
	var canonical: String = PUWItemRegistry.canonical_id_for(item_id)
	if canonical == "":
		return 0
	var bag: Dictionary = _bag_of(state)
	var target_key: String = canonical
	for key_value in bag.keys():
		var key: String = str(key_value)
		if PUWItemRegistry.canonical_id_for(key) == canonical:
			target_key = key
			break
	bag[target_key] = int(bag.get(target_key, 0)) + qty
	_store_bag(state, bag)
	return count_in_state(state, item_id)


## Take qty of an item out of the state bag. Returns false
## and changes nothing when the total held is short. Stacks
## are drained in the bag's own key order; a stack emptied
## to zero is erased, the save shape's rule.
static func consume_from_state(state: Dictionary, item_id: String, qty: int = 1) -> bool:
	if qty < 1:
		return false
	if count_in_state(state, item_id) < qty:
		return false
	var canonical: String = PUWItemRegistry.canonical_id_for(item_id)
	var bag: Dictionary = _bag_of(state)
	var remaining: int = qty
	var keys: Array = bag.keys()
	for key_value in keys:
		if remaining <= 0:
			break
		var key: String = str(key_value)
		if PUWItemRegistry.canonical_id_for(key) != canonical:
			continue
		var held: int = int(bag.get(key, 0))
		var taken: int = mini(held, remaining)
		remaining -= taken
		if held - taken <= 0:
			bag.erase(key)
		else:
			bag[key] = held - taken
	_store_bag(state, bag)
	return true


## The bag screen's rows for a state: one {"slug", "qty",
## "pocket"} dict per canonical item held, spellings merged,
## zero counts skipped, sorted by pocket then display name.
static func holdings_for_screen(state: Dictionary) -> Array:
	var totals: Dictionary = {}
	var bag: Dictionary = _bag_of(state)
	for key_value in bag.keys():
		var key: String = str(key_value)
		var canonical: String = PUWItemRegistry.canonical_id_for(key)
		if canonical == "":
			canonical = key
		totals[canonical] = int(totals.get(canonical, 0)) + int(bag.get(key, 0))
	var rows: Array = []
	for slug_value in totals.keys():
		var slug: String = str(slug_value)
		var qty: int = int(totals[slug])
		if qty <= 0:
			continue
		rows.append({"slug": slug, "qty": qty, "pocket": pocket_for_slug(slug)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pocket_a: int = int(a.get("pocket", 0))
		var pocket_b: int = int(b.get("pocket", 0))
		if pocket_a != pocket_b:
			return pocket_a < pocket_b
		return display_name_for(str(a.get("slug", ""))) < display_name_for(str(b.get("slug", "")))
	)
	return rows


## Toss one of an item from the state bag. Key Items refuse
## (the games' own rule, and a tossed key item could strand
## a save). Returns the result dict shape use_in_overworld
## uses: {"ok": bool, "reason": String, ...}.
static func toss_from_state(state: Dictionary, item_id: String) -> Dictionary:
	var canonical: String = PUWItemRegistry.canonical_id_for(item_id)
	if canonical == "":
		return {"ok": false, "reason": "unknown_item"}
	if pocket_for_slug(canonical) == POCKET_KEY:
		return {"ok": false, "reason": "key_item"}
	if not consume_from_state(state, canonical, 1):
		return {"ok": false, "reason": "not_held"}
	return {"ok": true, "effect": "toss", "item": canonical, "remaining": count_in_state(state, canonical)}


## Use one item from the bag in the overworld. context may
## carry "habitat" (the live PUWHabitatEncounters, whose
## repel counter is fed and then persisted into the state)
## and "map_loader" (the live PUWMapLoader, whose recorded
## entrance is the Escape Rope's target). Both are optional:
## without a habitat the repel steps are written straight
## into the state's "habitat_repel" key in the exact shape
## PUWHabitatEncounters.attach_repel_to_save writes, and
## the overworld restores them on load; without a map
## loader (or without a recorded entrance) the rope refuses
## "no_target" and is NOT consumed.
static func use_in_overworld(state: Dictionary, item_id: String, context: Dictionary = {}) -> Dictionary:
	var canonical: String = PUWItemRegistry.canonical_id_for(item_id)
	if canonical == "":
		return {"ok": false, "reason": "unknown_item"}
	# Repel family: the item's own step count, through the
	# habitat counter so the encounter rule reads one place.
	var steps: int = ItemEngine.repel_steps_for(canonical)
	if steps > 0:
		if count_in_state(state, canonical) < 1:
			return {"ok": false, "reason": "not_held"}
		consume_from_state(state, canonical, 1)
		var habitat_value: Variant = context.get("habitat", null)
		var habitat: PUWHabitatEncounters = habitat_value as PUWHabitatEncounters
		if habitat != null:
			habitat.apply_repel(steps)
			habitat.attach_repel_to_save(state)
		else:
			var saved_value: Variant = state.get("habitat_repel", {})
			var saved_steps: int = 0
			if saved_value is Dictionary:
				var saved: Dictionary = saved_value
				saved_steps = int(saved.get("steps", 0))
			state["habitat_repel"] = {"steps": maxi(saved_steps, steps)}
		return {"ok": true, "effect": "repel", "item": canonical, "steps": steps, "remaining": count_in_state(state, canonical)}
	# Escape Rope: only inside, only with a recorded
	# entrance; the caller (scene) performs the warp to the
	# returned target and the entrance is spent either way
	# the warp lands, so it is cleared here.
	if ItemEngine.is_escape_rope(canonical):
		var loader_value: Variant = context.get("map_loader", null)
		var loader: PUWMapLoader = loader_value as PUWMapLoader
		if loader == null:
			return {"ok": false, "reason": "no_target"}
		var target: Dictionary = loader.escape_rope_target()
		if target.is_empty():
			return {"ok": false, "reason": "no_target"}
		if count_in_state(state, canonical) < 1:
			return {"ok": false, "reason": "not_held"}
		consume_from_state(state, canonical, 1)
		loader.clear_entrance()
		return {"ok": true, "effect": "escape_rope", "item": canonical, "target": target, "remaining": count_in_state(state, canonical)}
	# Escape-class battle items end a WILD BATTLE; the
	# overworld has no battle to end. Refuse, never consume
	# (their wired path is the battle controller's, build 4).
	if ItemEngine.guarantees_escape(canonical):
		return {"ok": false, "reason": "battle_only"}
	return {"ok": false, "reason": "not_field_usable"}
