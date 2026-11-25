class_name PUWFollowerController
extends Node
## Follower selection and trailing positions for Pokemon Ultimate World.
##
## Vision: the player chooses 1-6 legal party followers.
##
## NOTE ON LOCATION: this class lives in
## res://systems/followers/puw_follower_controller.gd, NOT in
## res://systems/followers/follower_controller.gd, because that
## path already holds a different, existing class
## (FollowerController, a Node3D movement node). That file was
## left untouched.
##
## What it does, in plain words:
## - select_followers(party, chosen) validates the choice and
##   builds one follower record per chosen party member.
##   "chosen" is an Array whose entries are indices into
##   "party" (the documented, primary form). As a convenience,
##   String entries are also accepted: a String is treated as a
##   species slug/name and resolves to the first party member
##   whose normalized slug matches it.
##   The choice is refused ({"ok": false, "reason": ...}) when
##   it is empty, has duplicates (after resolving entries to
##   party indices), has an out-of-range / not-in-party entry,
##   or has more than MAX_FOLLOWERS (6) entries. A refused
##   choice leaves the current selection unchanged.
## - Each follower record is a Dictionary:
##     {
##       "species": <normalized species slug>,
##       "slug": <same normalized species slug>,
##       "family": <mon's "family" if present, else "PKDX">,
##       "locomotion": <locomotion class, see below>,
##       "trail_offset": <1 for the first follower, 2, 3, ...>,
##       "party_index": <index into the party Array>,
##       "sprite_url": <verbatim sprite index URL, "" if missing>,
##       "sprite_classification": <"animated" | "static-only" |
##         "missing", from PUWFollowerSpriteResolver>,
##       "sprite_source": <plain source name, "" if missing>,
##       "sprite_animated": <bool>,
##     }
## - Locomotion comes from the real seed data at
##   res://systems/followers/follower_locomotion.json, which
##   transcribes ONLY the 4 "pallet_and_route1_seed" entries of
##   docs/PUW_POKEMON_OVERWORLD_REGISTER.json. Lookup is by
##   slug + family. A species with no register entry gets the
##   file's top-level "default" locomotion, "ground_follow",
##   which is labeled inside that data file itself as a
##   placeholder that is NOT sourced data.
## - Position tracking: record_player_position(pos) appends
##   the player's position to a trail (the last TRAIL_CAP
##   positions are kept). follower_positions() returns one
##   Vector2 per follower: follower i (0-based) stands at the
##   trail position (i + 1) steps back from the newest player
##   position. If the trail is shorter than that, the follower
##   stands at the oldest known position. If no position has
##   been recorded yet, follower_positions() returns [].
##
## Species slugs are normalized the way the evolution manager
## (pokemon/evolution/evolution_manager.gd) does it: lowercase,
## spaces become hyphens, apostrophes and periods are dropped,
## the female sign becomes -f and the male sign becomes -m.
## A mon dict names its species with "slug" if present, else
## "species", else "name".

const DATA_PATH: String = "res://systems/followers/follower_locomotion.json"
const MAX_FOLLOWERS: int = 6
const TRAIL_CAP: int = 64
const DEFAULT_FAMILY: String = "PKDX"
const FALLBACK_LOCOMOTION: String = "ground_follow"

var _followers: Array = []
var _trail: Array = []
var _entries: Array = []
var _default_locomotion: String = FALLBACK_LOCOMOTION
var _loaded: bool = false


# ----------------------------------------------------------------
# Selection
# ----------------------------------------------------------------

## Validate a follower choice and, on success, replace the
## current selection. Returns {"ok": bool, ...}: on success
## also "followers" (the new records) and "count"; on failure
## also "reason" (a plain String saying why).
func select_followers(party: Array, chosen: Array) -> Dictionary:
	_ensure_loaded()
	if chosen.is_empty():
		_party = party.duplicate(true)
		_chosen = []
		_followers = []
		_behavior.clear()
		return {"ok": true, "followers": [], "count": 0}
	if chosen.size() > MAX_FOLLOWERS:
		return {"ok": false, "reason": "chosen has %d entries: at most %d followers are allowed" % [chosen.size(), MAX_FOLLOWERS]}
	var resolved: Array = []
	for entry_value in chosen:
		var entry: Variant = entry_value
		var party_index: int = -1
		if entry is int:
			party_index = int(entry)
		elif entry is float:
			var as_float: float = float(entry)
			if as_float != floorf(as_float):
				return {"ok": false, "reason": "chosen entry is not a whole party index: " + str(entry)}
			party_index = int(as_float)
		elif entry is String:
			var wanted_slug: String = _slugify(str(entry))
			party_index = _find_party_index_by_slug(party, wanted_slug)
			if party_index < 0:
				return {"ok": false, "reason": "chosen species is not in the party: " + str(entry)}
		else:
			return {"ok": false, "reason": "chosen entry must be a party index or a species slug, got: " + str(entry)}
		if party_index < 0 or party_index >= party.size():
			return {"ok": false, "reason": "chosen party index is out of range: " + str(party_index)}
		if resolved.has(party_index):
			return {"ok": false, "reason": "chosen has a duplicate party member at index: " + str(party_index)}
		resolved.append(party_index)
	var records: Array = []
	for order in range(resolved.size()):
		var party_index: int = int(resolved[order])
		var mon_value: Variant = party[party_index]
		if not (mon_value is Dictionary):
			return {"ok": false, "reason": "party entry is not a mon dict at index: " + str(party_index)}
		var mon: Dictionary = mon_value
		var slug: String = _mon_species_slug(mon)
		var family: String = str(mon.get("family", "")).strip_edges()
		if family.is_empty():
			family = DEFAULT_FAMILY
		var form_name: String = str(mon.get("form", mon.get("forme", ""))).strip_edges()
		var sprite_info: Dictionary = _sprite_info_for(slug, family, form_name)
		records.append({
			"species": slug,
			"slug": slug,
			"family": family,
			"locomotion": _lookup_locomotion(slug, family),
			"trail_offset": order + 1,
			"party_index": party_index,
			"sprite_url": str(sprite_info.get("url", "")),
			"sprite_classification": str(sprite_info.get("classification", "missing")),
			"sprite_source": str(sprite_info.get("source", "")),
			"sprite_animated": bool(sprite_info.get("animated", false)),
			"sprite_provenance": str(sprite_info.get("provenance", "")),
			"sprite_animation_status": str(sprite_info.get("animation_status", "")),
			"sprite_rig": sprite_info.get("rig", {}),
		})
	_followers = records
	_party = party.duplicate(true)
	_chosen = resolved.duplicate()
	_rebuild_behavior()
	return {"ok": true, "followers": get_followers(), "count": records.size()}


## The current follower records (a deep copy; changing the
## returned value does not change the selection).
func get_followers() -> Array:
	return _followers.duplicate(true)


# ----------------------------------------------------------------
# Follower sprite binding (visual coverage, 2026-11-23)
# ----------------------------------------------------------------
## Every follower record carries its sprite binding, resolved
## at selection time by PUWFollowerSpriteResolver from the
## project's sprite index data ONLY (no URL is ever built):
##   "sprite_url"            verbatim index URL, "" when missing
##   "sprite_classification" "animated" | "static-only" | "missing"
##   "sprite_source"         plain source name, "" when missing
##   "sprite_animated"       true only for real animated
##                           overworld/follower art (none exists
##                           in the project today -- see
##                           FOLLOWER_SPRITES.md in the pack)
## MDX followers resolve through the MDX data layer
## (PUWMDXData, data/mdx_sprites_index.json): builds 3-4 bound
## real Moemon follower sheets for 1,403 of the 1,519 MDX
## slots. A bound slot classifies "animated" (or "static-only"
## for a bound still) with the sheet's res:// path as the URL;
## a slot whose follower record is "missing" (116 slots)
## classifies "missing" with an empty URL. The counterpart's
## PKDX sprite is never borrowed for an MDX follower, and
## nothing fake is substituted.
## (Mechanics-completeness prep F4, 2026-11-24: before this
## fix the controller consulted only the PKDX resolver, which
## returns "missing" for every MDX mon by design, so every
## bound Moemon follower rendered invisible.)

var _sprite_resolver: PUWFollowerSpriteResolver = null
var _mdx_data: PUWMDXData = null


func _get_sprite_resolver() -> PUWFollowerSpriteResolver:
	if _sprite_resolver == null:
		_sprite_resolver = PUWFollowerSpriteResolver.new()
	return _sprite_resolver


func _get_mdx_data() -> PUWMDXData:
	if _mdx_data == null:
		_mdx_data = PUWMDXData.new()
	return _mdx_data


func _sprite_info_for(slug: String, family: String, form_name: String) -> Dictionary:
	# MDX (Moemon) followers are served by the MDX data layer,
	# never by the PKDX follower resolver: the resolver returns
	# "missing" for family "MDX" by design (it must never lend
	# counterpart PKDX art), and PUWMDXData owns the bound
	# Moemon follower sheets. PKDX routing is unchanged.
	if family == "MDX":
		return _mdx_sprite_info_for(slug, form_name)
	return _get_sprite_resolver().resolve(slug, family, form_name)


## The sprite binding for one MDX follower, in the same
## Dictionary shape PUWFollowerSpriteResolver.resolve returns.
## The slot is the species' MDX mapping slot (the form's own
## slot when form_name matches a form slot, else the first /
## base slot). The follower record decides the classification:
## "bound_local_animated" -> "animated", any other
## "bound_local*" status -> "static-only", "missing" (or no
## mapping / no record) -> "missing" with an empty URL.
func _mdx_sprite_info_for(slug: String, form_name: String) -> Dictionary:
	var mdx: PUWMDXData = _get_mdx_data()
	var slots: Array = mdx.slots_for(slug)
	if slots.is_empty():
		return {
			"classification": "missing",
			"url": "",
			"source": "",
			"animated": false,
			"species": slug,
			"showdown_id": "",
			"is_form": false,
			"family": "MDX",
			"reason": "no_mdx_mapping_for_species",
			"provenance": "none",
			"animation_status": "neon-gap",
			"on_neon_gap_list": true,
		}
	var chosen: Dictionary = slots[0]
	var wanted_form: String = form_name.strip_edges().to_lower()
	if wanted_form != "":
		for entry_value in slots:
			var entry: Dictionary = entry_value
			var entry_form: String = str(entry.get("form", entry.get("form_name", ""))).strip_edges().to_lower()
			if entry_form == wanted_form:
				chosen = entry
				break
	var slot: int = int(chosen.get("slot", 0))
	var record: Dictionary = mdx.follower_sheet_for_slot(slot)
	var status: String = str(record.get("status", "unknown"))
	var sheet: String = str(record.get("sheet", ""))
	if status.begins_with("bound_local") and not sheet.is_empty():
		var is_animated: bool = status == "bound_local_animated"
		return {
			"classification": "animated" if is_animated else "static-only",
			"url": "res://" + sheet,
			"source": "mdx_data_layer",
			"source_id": str(slot),
			"animated": is_animated,
			"species": slug,
			"showdown_id": "",
			"is_form": slots.size() > 1 and chosen != slots[0],
			"family": "MDX",
			"reason": "",
			"provenance": str(record.get("provenance", "mdx-bound-art")),
			"animation_status": "source-animated" if is_animated else "bound-static",
			"mdx_slot": slot,
			"mdx_status": status,
		}
	return {
		"classification": "missing",
		"url": "",
		"source": "",
		"animated": false,
		"species": slug,
		"showdown_id": "",
		"is_form": false,
		"family": "MDX",
		"reason": "mdx_follower_not_bound",
		"provenance": "none",
		"animation_status": "neon-gap",
		"on_neon_gap_list": true,
		"mdx_slot": slot,
		"mdx_status": status,
	}


## The sprite binding for one active follower, as a Dictionary
## with the record's sprite_url / sprite_classification /
## sprite_source / sprite_animated values. Returns {} when
## follower_index is out of range.
func follower_sprite_info(follower_index: int) -> Dictionary:
	if follower_index < 0 or follower_index >= _followers.size():
		return {}
	var record: Dictionary = _followers[follower_index]
	return {
		"url": str(record.get("sprite_url", "")),
		"classification": str(record.get("sprite_classification", "missing")),
		"source": str(record.get("sprite_source", "")),
		"animated": bool(record.get("sprite_animated", false)),
		"provenance": str(record.get("sprite_provenance", "")),
		"animation_status": str(record.get("sprite_animation_status", "")),
		"rig": record.get("sprite_rig", {}),
	}


## The follower sprite coverage classification for one active
## follower: "animated", "static-only" or "missing".
## Returns "" when follower_index is out of range.
func follower_sprite_classification(follower_index: int) -> String:
	if follower_index < 0 or follower_index >= _followers.size():
		return ""
	var record: Dictionary = _followers[follower_index]
	return str(record.get("sprite_classification", "missing"))


## Empty the current selection.
func clear_followers() -> void:
	_followers.clear()
	_behavior.clear()
	_chosen = []


# ----------------------------------------------------------------
# Position tracking
# ----------------------------------------------------------------

## Append the player's latest position to the trail. Only the
## last TRAIL_CAP positions are kept, which is far more than
## 6 followers need.
func record_player_position(pos: Vector2) -> void:
	_trail.append(pos)
	while _trail.size() > TRAIL_CAP:
		_trail.remove_at(0)


## One Vector2 per follower, in follower order. Follower i
## stands (i + 1) steps back from the newest player position,
## or at the oldest known position if the trail is shorter.
## Returns [] when no player position has been recorded.
func follower_positions() -> Array:
	var positions: Array = []
	if _trail.is_empty():
		return positions
	var newest_index: int = _trail.size() - 1
	for i in range(_followers.size()):
		var trail_index: int = newest_index - (i + 1)
		if trail_index < 0:
			trail_index = 0
		var pos_value: Variant = _trail[trail_index]
		if pos_value is Vector2:
			positions.append(pos_value)
		else:
			positions.append(Vector2.ZERO)
	return positions


# ----------------------------------------------------------------
# Locomotion data
# ----------------------------------------------------------------

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_entries = []
	_default_locomotion = FALLBACK_LOCOMOTION
	if not FileAccess.file_exists(DATA_PATH):
		return
	var text: String = FileAccess.get_file_as_string(DATA_PATH)
	var parsed_value: Variant = JSON.parse_string(text)
	if not (parsed_value is Dictionary):
		return
	var parsed: Dictionary = parsed_value
	var seed_value: Variant = parsed.get("pallet_and_route1_seed", [])
	if seed_value is Array:
		_entries = seed_value
	var default_value: Variant = parsed.get("default", {})
	if default_value is Dictionary:
		var default_dict: Dictionary = default_value
		var default_locomotion: String = str(default_dict.get("locomotion", "")).strip_edges()
		if not default_locomotion.is_empty():
			_default_locomotion = default_locomotion


## The registered locomotion for slug + family, or the labeled
## placeholder default when there is no register entry.
func _lookup_locomotion(slug: String, family: String) -> String:
	_ensure_loaded()
	for entry_value in _entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var entry_slug: String = str(entry.get("slug", "")).strip_edges().to_lower()
		var entry_family: String = str(entry.get("family", "")).strip_edges()
		if entry_slug == slug and entry_family.to_upper() == family.to_upper():
			var locomotion: String = str(entry.get("locomotion", "")).strip_edges()
			if not locomotion.is_empty():
				return locomotion
	return _default_locomotion


# ----------------------------------------------------------------
# Slug helpers (same normalization as the evolution manager)
# ----------------------------------------------------------------

static func _slugify(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	out = out.replace("♀", "-f").replace("♂", "-m")
	out = out.replace(" ", "-").replace("'", "").replace(".", "")
	while out.contains("--"):
		out = out.replace("--", "-")
	return out


static func _mon_species_slug(mon: Dictionary) -> String:
	var raw: String = str(mon.get("slug", mon.get("species", mon.get("name", ""))))
	return _slugify(raw)


func _find_party_index_by_slug(party: Array, wanted_slug: String) -> int:
	for i in range(party.size()):
		var mon_value: Variant = party[i]
		if mon_value is Dictionary:
			var mon: Dictionary = mon_value
			if _mon_species_slug(mon) == wanted_slug:
				return i
	return -1

# ================================================================
# FOLLOWER BEHAVIOR LAYER (Worker C, 2026-11-23)
# ================================================================
## Built on the selection/trail code above. Plain rules:
## - COUNT: set_follower_count(n) selects 0..6 followers at
##   runtime from the last party/chosen given to
##   select_followers(). select_followers() with an empty chosen
##   list is now a VALID 0-follower selection (Riley canon
##   2026-11-23: the player chooses how many follow, any number
##   up to 6); this supersedes the old empty-refusal.
## - BODY TYPE: resolved per species from real project data via
##   PUWRideSystem statics (types / weight in data/weight_power
##   .json, habitat in data/species_habitats.json, abilities) and
##   the seed locomotion file: flying_avian locomotion or a
##   Flying type -> "winged"; Levitate ability -> "hover";
##   Water type with sea/waters-edge habitat -> "aquatic";
##   weight < SMALL_BODY_MAX_KG -> "small_body" (PASSENGER:
##   perches on the trainer, no ground slot; SMALL_BODY_MAX_KG
##   is a PUW DESIGN PARAMETER, 3.5 kg: Caterpie 2.9 kg perches,
##   Meowth 4.2 kg walks); serpentine has no data source in the
##   project (no PokeAPI shape data is shipped), so no species
##   resolves to it here -- documented gap, not invented data;
##   everything else -> "ground" (quadruped/biped walkers; the
##   project ships no shape data to split those two).
## - PERSONALITY: the project species data has NO personality /
##   nature field for followers, so state timing is a documented
##   deterministic default: one seeded RNG (set_behavior_seed),
##   seeded per run; no personality dataset is fabricated.
## - PICKUP RATE: the mainline convention is a 10% Pickup check
##   after battle. PUW DESIGN PARAMETER (labeled, not sourced):
##   the same 10% is rolled once per 1.0 s exploration tick while
##   a Pickup follower is in IDLE / WANDER / SCOUT. Items come
##   ONLY from res://systems/followers/pickup_table.json (see
##   that file's source note; no Pickup table existed in the
##   project before it). Finds go into the REAL bag: the
##   MartShop (battle engine v4) bag Dictionary passed to
##   set_bag_shop(), and signal follower_item_found fires.
## - SAVE: follower selection/count is session-only instance
##   state, exactly as before this layer; PUWSaveManager's v1
##   migration carries a "followers" count (1..6) but build_state
##   has no follower key, so no save schema is changed here.
## - CATCH-UP: a follower farther than CATCHUP_TILES may be
##   repositioned to its slot ONLY when its current position is
##   outside the view rect (trainer +/- VIEW_HALF_TILES); while
##   on-view it walks (faster) and never teleports.

signal follower_item_found(follower_index: int, item_slug: String)

const PICKUP_TABLE_PATH: String = "res://systems/followers/pickup_table.json"
const SMALL_BODY_MAX_KG: float = 3.5
const WANDER_RADIUS_TILES: float = 3.0
const SCOUT_RADIUS_TILES: float = 5.0
const LEASH_TILES: float = 6.0
const CATCHUP_TILES: float = 10.0
const VIEW_HALF_TILES: Vector2 = Vector2(12.0, 9.0)
const FOLLOW_SPEED_TILES: float = 7.0
const EXPLORE_SPEED_TILES: float = 3.0
const PICKUP_TICK_SECONDS: float = 1.0
## PUW DESIGN PARAMETER (not sourced): seconds of no progress
## toward its slot before stuck recovery teleports a follower
## INTO ITS OWN SLOT (slot verified non-solid + unoccupied
## first; if blocked, the teleport holds until it frees).
const STUCK_SECONDS: float = 3.0
## PUW design parameter (see header): 10% per exploration tick.
const PICKUP_TICK_CHANCE: float = 0.10
const SLOT_OFFSETS: Array = [
	Vector2(0.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0),
	Vector2(0.0, 2.0), Vector2(-1.0, 2.0), Vector2(1.0, 2.0),
]

var _party: Array = []
var _chosen: Array = []
var _desired_count: int = -1
var _behavior: Array = []
var _behavior_loader: PUWMapLoader = null
var _bag_shop: MartShop = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pickup_bands: Array = []
var _pickup_loaded: bool = false
var _ability_hooks: Dictionary = {}
var _still_time: float = 0.0
var _last_trainer_pos: Vector2 = Vector2.ZERO
var _has_trainer_pos: bool = false


## Register an overworld-ability hook: hook_name -> Callable
## taking (follower_index, delta) and returning void. Pickup is
## registered by default in _init_behavior(); later abilities
## slot in here without restructuring.
func register_overworld_ability_hook(hook_name: String, fn: Callable) -> void:
	_ability_hooks[hook_name.to_lower()] = fn


func _init_behavior() -> void:
	if _ability_hooks.is_empty():
		register_overworld_ability_hook("pickup", Callable(self, "_pickup_hook"))
		register_overworld_ability_hook("honeygather", Callable(self, "_honey_hook"))


func set_behavior_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func set_behavior_loader(loader: PUWMapLoader) -> void:
	_behavior_loader = loader


## The real bag holder (MartShop, battle engine v4): Pickup
## finds increment shop.bag[item_slug].
func set_bag_shop(shop: MartShop) -> void:
	_bag_shop = shop


## Runtime follower count, 0..6, applied to the last selection.
## Returns the resulting active follower count, or -1 when no
## selection exists yet (the count is then stored and applied
## by the next select_followers call).
func set_follower_count(count: int) -> int:
	_desired_count = clampi(count, 0, MAX_FOLLOWERS)
	if _party.is_empty() or _chosen.is_empty():
		if _desired_count == 0:
			_followers.clear()
			_behavior.clear()
			return 0
		return -1
	var saved_chosen: Array = _chosen.duplicate()
	var want: int = mini(_desired_count, saved_chosen.size())
	var chosen_now: Array = saved_chosen.slice(0, want)
	# select_followers re-enters this state; guard by clearing
	# the stored selection marker first is unnecessary because
	# select_followers replaces _chosen with the same prefix.
	var result: Dictionary = select_followers(_party, chosen_now)
	_chosen = saved_chosen
	if bool(result.get("ok", false)):
		return _followers.size()
	return -1


func get_desired_follower_count() -> int:
	if _desired_count >= 0:
		return _desired_count
	return _followers.size()


## Force every follower back to FOLLOW (map change, battle or
## transition start). Reachable from the follower side; live
## wiring / campaign code can call it at transition points.
func notify_transition() -> void:
	for entry_value in _behavior:
		var entry: Dictionary = entry_value
		entry["state"] = "follow"
		entry["state_time"] = 0.0
		entry["emote"] = ""
		entry["emote_ttl"] = 0.0
		entry["point_id"] = ""


func force_behavior_state(follower_index: int, state_name: String) -> void:
	if follower_index < 0 or follower_index >= _behavior.size():
		return
	var entry: Dictionary = _behavior[follower_index]
	entry["state"] = state_name.to_lower()
	entry["state_time"] = 0.0


func behavior_followers() -> Array:
	return _behavior.duplicate(true)


## Body type for a species slug (see header for the data rules).
func body_type_for(slug: String, locomotion: String, ability_name: String) -> String:
	var types: Array = PUWRideSystem.species_types(slug)
	if locomotion == "flying_avian" or types.has("Flying"):
		return "winged"
	var abilities: Array = PUWRideSystem.species_abilities(slug)
	if ability_name.to_lower() == "levitate" or abilities.has("Levitate"):
		return "hover"
	var habitat: String = PUWRideSystem.species_habitat(slug)
	if types.has("Water") and (habitat == "sea" or habitat == "waters-edge"):
		return "aquatic"
	var weight: float = PUWRideSystem.species_weight_kg(slug)
	if weight > 0.0 and weight < SMALL_BODY_MAX_KG:
		return "small_body"
	return "ground"


func _mon_ability(mon: Dictionary) -> String:
	# ACTIVE ability of the INDIVIDUAL only. This is exactly how
	# the battle system resolves it (battle/battle_controller.gd
	# reads mon.get("ability", "") everywhere): the individual's
	# stored "ability" field. Species possible-ability lists
	# NEVER qualify a trigger (Riley refinement 2026-11-23).
	var ability_name: String = str(mon.get("ability", "")).strip_edges()
	if ability_name == "None":
		return ""
	return ability_name


func _rebuild_behavior() -> void:
	_init_behavior()
	_behavior.clear()
	for i in range(_followers.size()):
		var record: Dictionary = _followers[i]
		var mon: Dictionary = {}
		var party_index: int = int(record.get("party_index", -1))
		if party_index >= 0 and party_index < _party.size():
			var mon_value: Variant = _party[party_index]
			if mon_value is Dictionary:
				mon = mon_value
		var ability_name: String = _mon_ability(mon)
		var body_type: String = body_type_for(str(record.get("slug", "")), str(record.get("locomotion", "")), ability_name)
		record["ability"] = ability_name
		record["body_type"] = body_type
		record["domains"] = domains_for(str(record.get("slug", "")))
		record["senses"] = senses_for(str(record.get("slug", "")), ability_name)
		record["level"] = int(mon.get("level", 5))
		_followers[i] = record
		_behavior.append({
			"pos": Vector2.ZERO, "placed": false, "state": "follow",
			"animation": "idle", "target": Vector2.ZERO,
			"state_time": 0.0, "pickup_timer": 0.0,
			"emote": "", "emote_ttl": 0.0, "found_item": "",
			"pending_item": "", "point_id": "", "point_target": Vector2.ZERO,
			"point_pos": Vector2.ZERO, "facing_dir": Vector2.ZERO,
			"visual_offset_y": 0.0, "is_passenger": body_type == "small_body",
		})


func _slot_offset(index: int, facing: String) -> Vector2:
	var base: Vector2 = SLOT_OFFSETS[index % SLOT_OFFSETS.size()]
	match facing:
		"up":
			return Vector2(base.x, -base.y)
		"left":
			return Vector2(base.y, base.x)
		"right":
			return Vector2(-base.y, base.x)
		_:
			return base


func _can_occupy(tile: Vector2i, body_type: String) -> bool:
	return _can_occupy_domains(tile, body_type, [])


## Domain-aware occupancy (Refinement 5d, FOLLOWER_SENSES.md):
## terrain domains are HARD rules. "water" needs water_surface or
## air; "deep_water" (labeled synthetic dive-zone terrain) needs
## deep_dive or air; "ground" needs land or air -- a water-only
## species (domains without land) can never occupy ground. Other
## terrains keep the body-type rules above them. An empty domains
## list (species missing from the generated table) falls back to
## the body-type rules, exactly the pre-refinement behaviour.
func _can_occupy_domains(tile: Vector2i, body_type: String, domains: Array) -> bool:
	if _behavior_loader == null:
		return true
	var terrain: String = _behavior_loader.tile_terrain(tile)
	if not domains.is_empty():
		if terrain == "water":
			return domains.has("water_surface") or domains.has("air")
		if terrain == "deep_water":
			return domains.has("deep_dive") or domains.has("air")
		if terrain == "ground":
			return domains.has("land") or domains.has("air")
	match body_type:
		"winged", "hover":
			return terrain != "solid"
		"aquatic":
			return terrain == "ground" or terrain == "water" or terrain == "deep_water"
		_:
			return terrain == "ground"


func _is_off_view(pos: Vector2, trainer_pos: Vector2) -> bool:
	if _behavior_loader == null:
		return false
	var ts: float = float(_behavior_loader.tile_size_px)
	var dx: float = absf(pos.x - trainer_pos.x) / ts
	var dy: float = absf(pos.y - trainer_pos.y) / ts
	return dx > VIEW_HALF_TILES.x or dy > VIEW_HALF_TILES.y


## One behavior update. Returns one record per active follower:
## {species, pos, state, animation, body_type, emote, ...}.
func behavior_tick(delta: float, trainer_pos: Vector2, facing: String, trainer_moving: bool, in_water_context: bool = false) -> Array:
	_init_behavior()
	if _has_trainer_pos and trainer_pos.distance_to(_last_trainer_pos) > 1.0:
		trainer_moving = true
	_last_trainer_pos = trainer_pos
	_has_trainer_pos = true
	if trainer_moving:
		_still_time = 0.0
	else:
		_still_time += delta
	var ts: float = 8.0
	if _behavior_loader != null:
		ts = float(_behavior_loader.tile_size_px)
	_update_detections(trainer_pos)
	var out: Array = []
	for i in range(_behavior.size()):
		var entry: Dictionary = _behavior[i]
		var record: Dictionary = _followers[i]
		if float(entry.get("emote_ttl", 0.0)) > 0.0:
			entry["emote_ttl"] = float(entry.get("emote_ttl", 0.0)) - delta
			if float(entry.get("emote_ttl", 0.0)) <= 0.0:
				entry["emote"] = ""
		if str(entry.get("pending_item", "")) != "" and str(entry.get("state", "follow")) != "deliver" and str(entry.get("state", "")) != "perch_trainer" and str(entry.get("state", "")) != "perch_env":
			entry["state"] = "deliver"
			entry["state_time"] = 0.0
		var body_type: String = str(record.get("body_type", "ground"))
		var slot: Vector2 = trainer_pos + _slot_offset(i, facing) * ts
		if not bool(entry.get("placed", false)):
			entry["pos"] = slot
			entry["placed"] = true
		var pos: Vector2 = entry.get("pos", slot)
		# Leash / transition return.
		var dist_tiles: float = pos.distance_to(trainer_pos) / ts
		if dist_tiles > LEASH_TILES and str(entry.get("state", "follow")) != "follow":
			entry["state"] = "follow"
			entry["state_time"] = 0.0
		if trainer_moving and str(entry.get("state", "follow")) != "deliver":
			entry["state"] = "follow"
		# Stuck recovery (Riley refinement 2026-11-23): the ONLY
		# teleport. Fires when the follower made no progress
		# toward its slot for STUCK_SECONDS (immediately when it
		# is far off-view, e.g. after a map change). Lands IN
		# ITS OWN SLOT, verified non-solid for its body type and
		# unoccupied; if the slot is blocked it holds and
		# retries next tick. Normal formation keeping is pure
		# steering -- never this teleport.
		var slot_dist_now: float = pos.distance_to(slot) / ts
		var last_slot_dist: float = float(entry.get("last_slot_dist", -1.0))
		if slot_dist_now > 1.0:
			if last_slot_dist >= 0.0 and slot_dist_now >= last_slot_dist - 0.02:
				entry["stuck_time"] = float(entry.get("stuck_time", 0.0)) + delta
			else:
				entry["stuck_time"] = 0.0
			var stuck_limit: float = STUCK_SECONDS
			if dist_tiles > CATCHUP_TILES and _is_off_view(pos, trainer_pos):
				stuck_limit = 0.0
			if float(entry.get("stuck_time", 0.0)) >= stuck_limit and _slot_free_for(i, slot, trainer_pos, ts, body_type):
				pos = slot
				entry["pos"] = pos
				entry["stuck_time"] = 0.0
				dist_tiles = pos.distance_to(trainer_pos) / ts
				slot_dist_now = 0.0
		else:
			entry["stuck_time"] = 0.0
		entry["last_slot_dist"] = slot_dist_now
		# State choice while the trainer is still.
		entry["state_time"] = float(entry.get("state_time", 0.0)) + delta
		if not trainer_moving and _still_time > 0.5 and str(entry.get("state", "follow")) == "follow":
			_pick_explore_state(i, entry, trainer_pos, facing, ts)
		var state: String = str(entry.get("state", "follow"))
		var target: Vector2 = slot
		var speed: float = FOLLOW_SPEED_TILES
		if state == "deliver":
			target = trainer_pos
		elif state == "point":
			target = entry.get("point_target", slot)
			speed = EXPLORE_SPEED_TILES
			var point_pos: Vector2 = entry.get("point_pos", target)
			var to_point: Vector2 = point_pos - pos
			if to_point.length() > 0.01:
				entry["facing_dir"] = to_point.normalized()
			if pos.distance_to(target) <= 2.0:
				entry["animation"] = "idle"
		# Delivery completion: at the trainer, and ONLY in free
		# travel. While the world is busy the follower waits at
		# the trainer's side silently (no bag change, no notice).
		if state == "deliver" and pos.distance_to(trainer_pos) / ts <= 1.6:
			if not _world_busy:
				_complete_delivery(i)
				state = str(entry.get("state", "follow"))
				target = slot
		if state == "wander" or state == "scout":
			target = entry.get("target", slot)
			speed = EXPLORE_SPEED_TILES
			if pos.distance_to(target) <= 2.0 or float(entry.get("state_time", 0.0)) > 6.0:
				entry["state"] = "idle"
				entry["state_time"] = 0.0
				state = "idle"
		elif state == "idle":
			target = pos
			if float(entry.get("state_time", 0.0)) > 3.0:
				entry["state"] = "follow"
				entry["state_time"] = 0.0
				state = "follow"
		# Perched followers hold their anchor and play the
		# perch idle; trainer movement / transitions exit the
		# state through the follow-forcing rules above.
		if state == "perch_trainer" or state == "perch_env":
			if state == "perch_trainer":
				entry["pos"] = trainer_pos + Vector2(3.0, -14.0)
			else:
				entry["pos"] = entry.get("perch_pos", pos)
			entry["animation"] = "perch_idle"
			var perch_merged: Dictionary = record.duplicate()
			var perch_pos: Vector2 = entry.get("pos", pos)
			perch_merged["pos"] = perch_pos
			perch_merged["state"] = state
			perch_merged["animation"] = "perch_idle"
			perch_merged["emote"] = entry.get("emote", "")
			perch_merged["found_item"] = entry.get("found_item", "")
			perch_merged["visual_offset_y"] = -4.0
			perch_merged["is_passenger"] = false
			out.append(perch_merged)
			continue
		# Movement (passengers perch instead of walking).
		var moving: bool = false
		if body_type == "small_body":
			pos = trainer_pos + Vector2(-4.0, -10.0)
			entry["pos"] = pos
		else:
			var want: Vector2 = target
			if state == "idle":
				want = pos
			var to_want: Vector2 = want - pos
			if to_want.length() > 1.0:
				var boost: float = 1.6 if dist_tiles > CATCHUP_TILES else 1.0
				# Speed regulation: ease out inside 1.5 tiles of
				# the target so spacing settles without jitter.
				var ease: float = clampf(to_want.length() / (1.5 * ts), 0.25, 1.0)
				var step_len: float = minf(speed * boost * ease * ts * delta, to_want.length())
				var step: Vector2 = to_want.normalized() * step_len
				var new_pos: Vector2 = _try_step_domains(pos, step, body_type, record.get("domains", []))
				moving = new_pos != pos
				pos = new_pos
				entry["pos"] = pos
		# Separation steering: never share a tile-centre area
		# with the trainer or another follower.
		pos = _separate(i, pos, trainer_pos, ts)
		pos = _separate(i, pos, trainer_pos, ts)
		entry["pos"] = pos
		# Animation from actual motion + locomotion class.
		entry["animation"] = _animation_for(body_type, moving, in_water_context)
		entry["visual_offset_y"] = -6.0 if body_type == "winged" else (-3.0 if body_type == "hover" else 0.0)
		# Ability hooks run in exploration states.
		if state == "idle" or state == "wander" or state == "scout":
			var ability_key: String = str(record.get("ability", "")).to_lower()
			if _ability_hooks.has(ability_key):
				var fn: Callable = _ability_hooks[ability_key]
				fn.call(i, delta)
			_move_trigger_hook(i, delta)
		var merged: Dictionary = record.duplicate()
		merged["pos"] = entry.get("pos", pos)
		merged["state"] = entry.get("state", "follow")
		merged["animation"] = entry.get("animation", "idle")
		merged["emote"] = entry.get("emote", "")
		merged["found_item"] = entry.get("found_item", "")
		merged["visual_offset_y"] = entry.get("visual_offset_y", 0.0)
		merged["is_passenger"] = entry.get("is_passenger", false)
		merged["facing_dir"] = entry.get("facing_dir", Vector2.ZERO)
		merged["point_id"] = entry.get("point_id", "")
		out.append(merged)
	return out


func _slot_free_for(index: int, slot: Vector2, trainer_pos: Vector2, ts: float, body_type: String) -> bool:
	var domains_value: Variant = _followers[index].get("domains", [])
	var domains: Array = []
	if domains_value is Array:
		domains = domains_value
	if _behavior_loader != null and not _can_occupy_domains(_behavior_loader.tile_at_px(slot), body_type, domains):
		return false
	if slot.distance_to(trainer_pos) < ts * 0.8:
		return false
	for j in range(_behavior.size()):
		if j == index:
			continue
		var other: Dictionary = _behavior[j]
		if bool(other.get("placed", false)):
			var other_pos: Vector2 = other.get("pos", Vector2.ZERO)
			if slot.distance_to(other_pos) < ts * 0.8:
				return false
	return true


func _tile_at(_pos: Vector2, fallback: Vector2) -> Vector2i:
	if _behavior_loader != null:
		return _behavior_loader.tile_at_px(fallback)
	return Vector2i.ZERO


func _try_step(pos: Vector2, step: Vector2, body_type: String) -> Vector2:
	if _behavior_loader == null:
		return pos + step
	var full: Vector2 = pos + step
	if _can_occupy(_behavior_loader.tile_at_px(full), body_type):
		return full
	var x_only: Vector2 = pos + Vector2(step.x, 0.0)
	if step.x != 0.0 and _can_occupy(_behavior_loader.tile_at_px(x_only), body_type):
		return x_only
	var y_only: Vector2 = pos + Vector2(0.0, step.y)
	if step.y != 0.0 and _can_occupy(_behavior_loader.tile_at_px(y_only), body_type):
		return y_only
	# Forward probing: steer around the obstacle -- try sliding
	# perpendicular to the blocked step, both ways.
	var perp: Vector2 = Vector2(-step.y, step.x)
	if perp.length() > 0.01:
		var slide_a: Vector2 = pos + perp.normalized() * step.length()
		if _can_occupy(_behavior_loader.tile_at_px(slide_a), body_type):
			return slide_a
		var slide_b: Vector2 = pos - perp.normalized() * step.length()
		if _can_occupy(_behavior_loader.tile_at_px(slide_b), body_type):
			return slide_b
	return pos


## Separation radius in tiles for a follower record, derived
## from body type + real weight data (PUWRideSystem /
## data/weight_power.json): base 0.8 tiles; bulky bodies
## (>= 50 kg, the ride system's land-carry weight line) get
## 1.0; airborne bodies get 0.9 (wing/hover clearance).
func separation_radius_tiles(record: Dictionary) -> float:
	var body_type: String = str(record.get("body_type", "ground"))
	var radius: float = 0.8
	if body_type == "winged" or body_type == "hover":
		radius = 0.9
	var weight: float = PUWRideSystem.species_weight_kg(str(record.get("slug", "")))
	if weight >= 50.0:
		radius = maxf(radius, 1.0)
	return radius


func _separate(index: int, pos: Vector2, trainer_pos: Vector2, ts: float) -> Vector2:
	var self_record: Dictionary = _followers[index]
	var entry: Dictionary = _behavior[index]
	if bool(entry.get("is_passenger", false)):
		return pos
	# Pair separation first...
	for j in range(_behavior.size()):
		if j == index:
			continue
		var other: Dictionary = _behavior[j]
		if bool(other.get("is_passenger", false)) or not bool(other.get("placed", false)):
			continue
		var other_pos: Vector2 = other.get("pos", Vector2.ZERO)
		var d: float = pos.distance_to(other_pos)
		var pair_min: float = ts * maxf(separation_radius_tiles(self_record), separation_radius_tiles(_followers[j]))
		if d < pair_min and d > 0.01:
			var pushed2: Vector2 = other_pos + (pos - other_pos).normalized() * pair_min
			if _behavior_loader == null or _can_occupy(_behavior_loader.tile_at_px(pushed2), str(self_record.get("body_type", "ground"))):
				pos = pushed2
	# ...trainer separation LAST, so a pair push can never leave
	# a follower inside the trainer's radius at end of tick.
	var min_dist: float = ts * separation_radius_tiles(self_record)
	if pos.distance_to(trainer_pos) < min_dist:
		var away: Vector2 = pos - trainer_pos
		if away.length() < 0.01:
			away = Vector2(0.0, 1.0)
		var pushed: Vector2 = trainer_pos + away.normalized() * min_dist
		if _behavior_loader == null or _can_occupy(_behavior_loader.tile_at_px(pushed), str(self_record.get("body_type", "ground"))):
			pos = pushed
	return pos


func _pick_explore_state(index: int, entry: Dictionary, trainer_pos: Vector2, facing: String, ts: float) -> void:
	var record: Dictionary = _followers[index]
	var body_type: String = str(record.get("body_type", "ground"))
	entry["state_time"] = 0.0
	if body_type == "small_body":
		entry["state"] = "idle"
		return
	var roll: float = _rng.randf()
	if body_type == "winged" and roll < 0.35:
		var weight: float = PUWRideSystem.species_weight_kg(str(record.get("slug", "")))
		if weight > 0.0 and weight <= PERCH_TRAINER_MAX_KG:
			entry["state"] = "perch_trainer"
			return
		var perch: Vector2 = find_perch_point(trainer_pos)
		if perch.x >= 0.0:
			entry["state"] = "perch_env"
			entry["perch_pos"] = perch
			entry["target"] = perch
			return
	if (body_type == "winged" or body_type == "hover") and roll < 0.45:
		entry["state"] = "scout"
		var dir: Vector2 = Vector2(0.0, 1.0)
		match facing:
			"up":
				dir = Vector2(0.0, -1.0)
			"left":
				dir = Vector2(-1.0, 0.0)
			"right":
				dir = Vector2(1.0, 0.0)
		var target: Vector2 = trainer_pos + dir * SCOUT_RADIUS_TILES * 0.8 * ts
		if _behavior_loader == null or _can_occupy(_behavior_loader.tile_at_px(target), body_type):
			entry["target"] = target
		else:
			entry["target"] = trainer_pos
		return
	if roll < 0.8:
		entry["state"] = "wander"
		for attempt in range(8):
			var offset: Vector2 = Vector2(_rng.randf_range(-WANDER_RADIUS_TILES, WANDER_RADIUS_TILES), _rng.randf_range(-WANDER_RADIUS_TILES, WANDER_RADIUS_TILES)) * ts
			var candidate: Vector2 = trainer_pos + offset
			if _behavior_loader == null or _can_occupy(_behavior_loader.tile_at_px(candidate), body_type):
				entry["target"] = candidate
				return
		entry["target"] = trainer_pos
		return
	entry["state"] = "idle"


func _animation_for(body_type: String, moving: bool, in_water_context: bool) -> String:
	if body_type == "small_body":
		return "perch_idle"
	if not moving:
		return "hover_idle" if body_type == "hover" else ("fly_idle" if body_type == "winged" else "idle")
	match body_type:
		"winged":
			return "fly"
		"hover":
			return "hover"
		"aquatic":
			return "swim" if in_water_context else "shore_idle"
		_:
			return "walk"


# ----------------------------------------------------------------
# Pickup (first registered overworld-ability hook)
# ----------------------------------------------------------------

func _ensure_pickup_loaded() -> void:
	if _pickup_loaded:
		return
	_pickup_loaded = true
	_pickup_bands = []
	if not FileAccess.file_exists(PICKUP_TABLE_PATH):
		return
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PICKUP_TABLE_PATH))
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var bands_value: Variant = parsed.get("bands", [])
		if bands_value is Array:
			_pickup_bands = bands_value


## Items (with weights) Pickup can find at a level, from the
## sourced band table. Empty when the level has no band.
func pickup_items_for_level(level: int) -> Array:
	_ensure_pickup_loaded()
	for band_value in _pickup_bands:
		if band_value is Dictionary:
			var band: Dictionary = band_value
			if level >= int(band.get("min_level", 0)) and level <= int(band.get("max_level", 0)):
				var items_value: Variant = band.get("items", [])
				if items_value is Array:
					var items: Array = items_value
					return items
	return []


func _pickup_hook(follower_index: int, delta: float) -> void:
	if follower_index < 0 or follower_index >= _behavior.size():
		return
	var entry: Dictionary = _behavior[follower_index]
	entry["pickup_timer"] = float(entry.get("pickup_timer", 0.0)) + delta
	if float(entry.get("pickup_timer", 0.0)) < PICKUP_TICK_SECONDS:
		return
	entry["pickup_timer"] = 0.0
	if _rng.randf() >= PICKUP_TICK_CHANCE:
		return
	var record: Dictionary = _followers[follower_index]
	var items: Array = pickup_items_for_level(int(record.get("level", 5)))
	if items.is_empty():
		return
	var total: int = 0
	for item_value in items:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			total += int(item.get("weight", 0))
	if total <= 0:
		return
	var roll: int = _rng.randi_range(1, total)
	var found: String = ""
	for item_value in items:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			roll -= int(item.get("weight", 0))
			if roll <= 0:
				found = str(item.get("slug", ""))
				break
	if found == "":
		return
	entry["found_item"] = found
	entry["pending_item"] = found
	entry["state"] = "deliver"
	entry["state_time"] = 0.0

# ================================================================
# SCOPE ADDITION (Riley 2026-11-23 07:08-07:09): PERCHING +
# AUTONOMOUS OVERWORLD ABILITIES / MOVES -- SURPRISE, NOT
# ANNOUNCED. No player-facing string in this file names or
# explains any of these mechanics; followers act through
# animation state + signals only (diegetic feedback).
# Researched list: OVERWORLD_ABILITIES.md in the pack.
# ================================================================

signal follower_encounter_triggered(encounter: Dictionary, follower_index: int)
signal follower_encounter_repelled(follower_index: int)

## PUW DESIGN PARAMETER (not sourced): a winged follower at or
## under this weight may perch on the trainer; heavier flyers
## use environmental perch points or keep flying.
const PERCH_TRAINER_MAX_KG: float = 10.0
## PUW DESIGN PARAMETERS (not sourced): autonomous trigger
## chances per 1.0 s exploration tick. Kept rare on purpose.
const SWEET_SCENT_TICK_CHANCE: float = 0.05
const ROAR_TICK_CHANCE: float = 0.05
const HONEY_TICK_CHANCE: float = 0.05
## Canon rates (see OVERWORLD_ABILITIES.md): encounter-rate
## abilities multiply the wild rate x2 (Illuminate / Arena
## Trap) or x0.5 (Stench / White Smoke) in the lead's slot in
## the games; here any ACTIVE follower with the ability applies
## it (documented PUW widening). Type attraction (Static /
## Magnet Pull) forces the attracted type with 50% probability
## when a pool member has it (canon, Gen 4+ form).

var _habitat: PUWHabitatEncounters = null
var _encounter_area: String = ""
var _encounter_party_max: int = 100
var _pending_encounter: Dictionary = {}
var _learnset_moves: Dictionary = {}
var _learnsets_loaded: bool = false


func set_encounter_context(habitat: PUWHabitatEncounters, area_id: String, party_max: int) -> void:
	_habitat = habitat
	_encounter_area = area_id
	_encounter_party_max = party_max


func set_pending_encounter(encounter: Dictionary) -> void:
	_pending_encounter = encounter.duplicate()


func get_pending_encounter() -> Dictionary:
	return _pending_encounter.duplicate()


## Product of the active followers' encounter-rate ability
## multipliers (1.0 when none apply). The overworld loop can
## multiply its per-step habitat chance by this.
func encounter_rate_multiplier() -> float:
	var mult: float = 1.0
	for record_value in _followers:
		var record: Dictionary = record_value
		var ability_key: String = str(record.get("ability", "")).to_lower().replace(" ", "")
		if ability_key == "illuminate" or ability_key == "arenatrap":
			mult *= 2.0
		elif ability_key == "stench" or ability_key == "whitesmoke":
			mult *= 0.5
	return mult


## Type a follower's ability attracts ("Electric" for Static,
## "Steel" for Magnet Pull), "" when none.
func _attracted_type() -> String:
	for record_value in _followers:
		var record: Dictionary = record_value
		var ability_key: String = str(record.get("ability", "")).to_lower().replace(" ", "")
		if ability_key == "static":
			return "Electric"
		if ability_key == "magnetpull":
			return "Steel"
	return ""


func _has_active_ability(ability_key: String) -> bool:
	for record_value in _followers:
		var record: Dictionary = record_value
		if str(record.get("ability", "")).to_lower().replace(" ", "") == ability_key:
			return true
	return false


## Roll an encounter from the local habitat pool with the
## followers' composition influences applied: type attraction
## (50% force when possible), Synchronize nature pass-through,
## Compound Eyes held-item flag. Keen Eye / Intimidate
## repel-below-level and Cute Charm gender influence are NOT
## applied here: habitat pool entries carry no level or gender
## (levels are assigned later by the difficulty layer) -- see
## OVERWORLD_ABILITIES.md (documented-only, with reasons).
func follower_roll_encounter(rng: RandomNumberGenerator) -> Dictionary:
	if _habitat == null or _encounter_area == "":
		return {}
	var pool: Array = _habitat.get_eligible_pool(_encounter_area, _encounter_party_max)
	if pool.is_empty():
		return {}
	var chosen: Dictionary = {}
	var attracted: String = _attracted_type()
	if attracted != "" and rng.randf() < 0.5:
		var subset: Array = []
		for entry_value in pool:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				var types: Array = _habitat.species_types(int(entry.get("species", 0)))
				if types.has(attracted):
					subset.append(entry)
		if not subset.is_empty():
			chosen = subset[rng.randi_range(0, subset.size() - 1)]
	if chosen.is_empty():
		chosen = pool[rng.randi_range(0, pool.size() - 1)]
	var result: Dictionary = chosen.duplicate()
	_habitat.mark_encountered(_encounter_area, int(result.get("species", 0)))
	result["species_slug"] = str(result.get("slug", ""))
	if _has_active_ability("synchronize"):
		result["nature_influenced"] = true
	if _has_active_ability("compoundeyes"):
		result["wild_held_item_bonus"] = true
	return result


func _mon_knows_move(mon: Dictionary, move_slug: String) -> bool:
	# CURRENTLY KNOWN moveset of the INDIVIDUAL only: its
	# slotted "moves" list. Species learnsets NEVER qualify a
	# trigger by themselves (Riley refinement 2026-11-23).
	var moves_value: Variant = mon.get("moves", [])
	if moves_value is Array:
		var moves: Array = moves_value
		for move_value in moves:
			if _slugify(str(move_value)).replace("-", "") == move_slug.replace("-", ""):
				return true
	return false


func _follower_mon(index: int) -> Dictionary:
	if index < 0 or index >= _followers.size():
		return {}
	var record: Dictionary = _followers[index]
	var party_index: int = int(record.get("party_index", -1))
	if party_index >= 0 and party_index < _party.size():
		var mon_value: Variant = _party[party_index]
		if mon_value is Dictionary:
			var mon: Dictionary = mon_value
			return mon
	return {}


## Environmental perch point near the trainer: a solid tile
## (raised obstacle top) with a walkable neighbour, within 4
## tiles. The map data carries NO tree semantics (map JSON
## tiles are unnamed ids; objects are NPCs), so no tile is
## claimed to be a tree -- see OVERWORLD_ABILITIES.md.
func find_perch_point(trainer_pos: Vector2) -> Vector2:
	if _behavior_loader == null:
		return Vector2(-1.0, -1.0)
	var center: Vector2i = _behavior_loader.tile_at_px(trainer_pos)
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var tile: Vector2i = center + Vector2i(dx, dy)
				if not _behavior_loader.is_solid_tile(tile):
					continue
				var neighbours: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				for n_value in neighbours:
					var n: Vector2i = n_value
					if not _behavior_loader.is_solid_tile(tile + n):
						return _behavior_loader.tile_center_px(tile)
	return Vector2(-1.0, -1.0)


func _honey_hook(follower_index: int, delta: float) -> void:
	if follower_index < 0 or follower_index >= _behavior.size():
		return
	var entry: Dictionary = _behavior[follower_index]
	entry["pickup_timer"] = float(entry.get("pickup_timer", 0.0)) + delta
	if float(entry.get("pickup_timer", 0.0)) < PICKUP_TICK_SECONDS:
		return
	entry["pickup_timer"] = 0.0
	if _rng.randf() >= HONEY_TICK_CHANCE:
		return
	entry["found_item"] = "honey"
	entry["pending_item"] = "honey"
	entry["state"] = "deliver"
	entry["state_time"] = 0.0


## Move triggers, run from behavior_tick's exploration branch:
## Sweet Scent (follower knows the move) forces a habitat-pool
## encounter; Roar (follower knows the move) rustles off a
## pending encounter. Both at the rare design chances above.
func _move_trigger_hook(follower_index: int, delta: float) -> void:
	if follower_index < 0 or follower_index >= _behavior.size():
		return
	var entry: Dictionary = _behavior[follower_index]
	entry["move_timer"] = float(entry.get("move_timer", 0.0)) + delta
	if float(entry.get("move_timer", 0.0)) < PICKUP_TICK_SECONDS:
		return
	entry["move_timer"] = 0.0
	var mon: Dictionary = _follower_mon(follower_index)
	if mon.is_empty():
		return
	if not _pending_encounter.is_empty() and _mon_knows_move(mon, "roar"):
		if _rng.randf() < ROAR_TICK_CHANCE:
			_pending_encounter = {}
			show_emote(follower_index, "!", "encounter")
			follower_encounter_repelled.emit(follower_index)
			return
	if _habitat != null and _mon_knows_move(mon, "sweetscent"):
		if _rng.randf() < SWEET_SCENT_TICK_CHANCE:
			var encounter: Dictionary = follower_roll_encounter(_rng)
			if not encounter.is_empty():
				show_emote(follower_index, "!", "encounter")
				follower_encounter_triggered.emit(encounter, follower_index)


## Test/debug helper: place a follower's behavior position
## directly (used by the stuck-recovery test to wall a
## follower into a pocket).
func debug_place_follower(index: int, pos: Vector2) -> void:
	if index < 0 or index >= _behavior.size():
		return
	var entry: Dictionary = _behavior[index]
	entry["pos"] = pos
	entry["placed"] = true
	entry["stuck_time"] = 0.0
	entry["last_slot_dist"] = -1.0

# ================================================================
# PART A (Riley 2026-11-23 07:16): TRANSPORT CARRIES THE TEAM
# + co-op sync state (Part B.1).
# ================================================================

## Teleport-class field actions (the transport kin of
## PUWFieldActions' "teleport").
const TRANSPORT_ACTIONS: Array = ["teleport"]

## Place every follower into its formation slot around a
## destination trainer position (used on transport arrival and
## reusable after warps). Placement rules are the
## stuck-recovery rules: the slot cell must be non-solid for
## the follower's body type and unoccupied (not the trainer,
## not another follower). Fallback when a slot is blocked
## (documented choice): the nearest free formation position --
## the remaining slot offsets, then a ring around the trainer
## in slot order -- and steering settles the follower back to
## its own slot afterwards. Passengers perch on the trainer.
## Returns the placed records.
func transport_followers_to(trainer_pos: Vector2, facing: String) -> Array:
	notify_transition()
	var ts: float = 8.0
	if _behavior_loader != null:
		ts = float(_behavior_loader.tile_size_px)
	var taken: Array = []
	for i in range(_behavior.size()):
		var entry: Dictionary = _behavior[i]
		var record: Dictionary = _followers[i]
		var body_type: String = str(record.get("body_type", "ground"))
		if body_type == "small_body":
			entry["pos"] = trainer_pos + Vector2(-4.0, -10.0)
			entry["placed"] = true
			continue
		var slot: Vector2 = trainer_pos + _slot_offset(i, facing) * ts
		if _slot_free_for(i, slot, trainer_pos, ts, body_type) and not taken.has(slot):
			entry["pos"] = slot
			entry["placed"] = true
			taken.append(slot)
			continue
		# Fallback: nearest free formation position.
		var candidates: Array = []
		for k in range(SLOT_OFFSETS.size()):
			candidates.append(trainer_pos + _slot_offset(k, facing) * ts)
		for ring in range(1, 4):
			for k in range(SLOT_OFFSETS.size()):
				var off_value: Variant = SLOT_OFFSETS[k]
				var off: Vector2 = off_value
				candidates.append(trainer_pos + (off * float(ring + 1)) * ts)
		candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(slot) < b.distance_to(slot))
		var placed_pos: Vector2 = slot
		for cand_value in candidates:
			var cand: Vector2 = cand_value
			if taken.has(cand):
				continue
			# Temporarily check occupancy against taken + trainer.
			var free: bool = cand.distance_to(trainer_pos) >= ts * 0.8
			if free and _behavior_loader != null and not _can_occupy(_behavior_loader.tile_at_px(cand), body_type):
				free = false
			if free:
				for taken_value in taken:
					var taken_pos: Vector2 = taken_value
					if cand.distance_to(taken_pos) < ts * 0.8:
						free = false
						break
			if free:
				placed_pos = cand
				break
		entry["pos"] = placed_pos
		entry["placed"] = true
		taken.append(placed_pos)
	return behavior_followers()


## Set a follower's emote glyph (care / interaction layer).
func set_follower_emote(index: int, glyph: String) -> void:
	show_emote(index, glyph, "interaction")


## Co-op sync state for this team: one record per follower with
## species, position, state, animation and emote. The co-op
## manager carries these for BOTH players (Part B.1).
func coop_sync_state() -> Array:
	var out: Array = []
	for i in range(_behavior.size()):
		var entry: Dictionary = _behavior[i]
		var record: Dictionary = _followers[i]
		var pos: Vector2 = entry.get("pos", Vector2.ZERO)
		out.append({
			"slug": str(record.get("slug", "")),
			"pos_x": pos.x, "pos_y": pos.y,
			"state": str(entry.get("state", "follow")),
			"animation": str(entry.get("animation", "idle")),
			"emote": str(entry.get("emote", "")),
		})
	return out

# ================================================================
# REFINEMENT 5 (Riley 2026-11-23 07:21): EMOTE DISCIPLINE,
# DETECTION + POINTING, PICKUP DELIVERY TIMING, TERRAIN DOMAINS.
# Full derivation + class tables: FOLLOWER_SENSES.md.
# ================================================================

signal follower_item_delivered(follower_index: int, item_slug: String)

## PUW DESIGN PARAMETERS (labeled, not sourced): an emote fades
## after EMOTE_TTL_SECONDS; at most EMOTE_MAX_CONCURRENT emotes
## are visible at once. Emotes are produced ONLY by genuine
## events (interaction / care / find-delivery / detection /
## encounter triggers) through show_emote(); idle, wander,
## scout and formation states NEVER produce one.
const EMOTE_TTL_SECONDS: float = 1.5
const EMOTE_MAX_CONCURRENT: int = 2
const EMOTE_SOURCES: Array = ["interaction", "care", "found_item", "delivery", "detection", "encounter"]
const DOMAINS_PATH: String = "res://systems/followers/follower_domains.json"
## PUW DESIGN PARAMETER: sense range in tiles.
const SENSE_RANGE_TILES: float = 6.0
const POI_SENSES: Dictionary = {
	"hidden_item": ["sight", "smell"],
	"buried": ["smell", "resonance_ground"],
	"machinery": ["resonance_electric", "sight"],
	"presence": ["resonance_psychic", "hearing"],
	"sound_source": ["hearing", "sight"],
}

var _world_busy: bool = false
var _world_busy_reason: String = ""
var _points_of_interest: Array = []
var _domains_by_slug: Dictionary = {}
var _domains_loaded: bool = false


## World busy state (battle / cutscene / story event). Live code
## sets this from its state flags (e.g. PartyScene.in_battle and
## the campaign cutscene flags); followers never interrupt it.
func set_world_busy(busy: bool, reason: String = "") -> void:
	_world_busy = busy
	_world_busy_reason = reason


func is_world_busy() -> bool:
	return _world_busy


## Show an emote from a genuine event source. Returns false when
## the source is not an event source or the concurrent cap is
## already reached. Re-showing on the same follower refreshes it.
func show_emote(index: int, glyph: String, source: String) -> bool:
	if index < 0 or index >= _behavior.size():
		return false
	if not EMOTE_SOURCES.has(source):
		return false
	var entry: Dictionary = _behavior[index]
	if str(entry.get("emote", "")) == "":
		if active_emote_count() >= EMOTE_MAX_CONCURRENT:
			return false
	entry["emote"] = glyph
	entry["emote_ttl"] = EMOTE_TTL_SECONDS
	return true


func active_emote_count() -> int:
	var count: int = 0
	for entry_value in _behavior:
		var entry: Dictionary = entry_value
		if str(entry.get("emote", "")) != "" and float(entry.get("emote_ttl", 0.0)) > 0.0:
			count += 1
	return count


func _ensure_domains_loaded() -> void:
	if _domains_loaded:
		return
	_domains_loaded = true
	_domains_by_slug = {}
	if not FileAccess.file_exists(DOMAINS_PATH):
		return
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOMAINS_PATH))
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var species_value: Variant = parsed.get("species", {})
		if species_value is Dictionary:
			_domains_by_slug = species_value


## Movement domains for a species from the generated table
## (tools/build_follower_domains.py). Empty when unlisted.
func domains_for(slug: String) -> Array:
	_ensure_domains_loaded()
	var value: Variant = _domains_by_slug.get(slug, {})
	if value is Dictionary:
		var entry: Dictionary = value
		var domains_value: Variant = entry.get("domains", [])
		if domains_value is Array:
			var domains: Array = domains_value
			return domains.duplicate()
	return []


func domains_table_size() -> int:
	_ensure_domains_loaded()
	return _domains_by_slug.size()


## Sense classes for one follower (FOLLOWER_SENSES.md):
## sight = ACTIVE Keen Eye / Compound Eyes / Frisk, Flying type,
##   or a species learnset with foresight / mindreader (biology);
## smell = species learnset with odorsleuth;
## hearing = species learnset with uproar / hypervoice, or the
##   ACTIVE ability Soundproof;
## resonance_<type> = the species IS Electric / Psychic / Ground.
## Ability-derived senses read the individual's ACTIVE ability
## only, the same rule as triggers.
func senses_for(slug: String, active_ability: String) -> Array:
	var senses: Array = []
	var ability_key: String = active_ability.to_lower().replace(" ", "")
	if ability_key == "keeneye" or ability_key == "compoundeyes" or ability_key == "frisk":
		senses.append("sight")
	var types: Array = PUWRideSystem.species_types(slug)
	if types.has("Flying"):
		if not senses.has("sight"):
			senses.append("sight")
	if PUWRideSystem.species_learns(slug, "foresight") or PUWRideSystem.species_learns(slug, "mindreader"):
		if not senses.has("sight"):
			senses.append("sight")
	if PUWRideSystem.species_learns(slug, "odorsleuth"):
		senses.append("smell")
	if PUWRideSystem.species_learns(slug, "uproar") or PUWRideSystem.species_learns(slug, "hypervoice") or ability_key == "soundproof":
		senses.append("hearing")
	if types.has("Electric"):
		senses.append("resonance_electric")
	if types.has("Psychic"):
		senses.append("resonance_psychic")
	if types.has("Ground"):
		senses.append("resonance_ground")
	return senses


## Register hidden points of interest: Array of Dictionaries
## {"id": String, "kind": String (see POI_SENSES), "pos": Vector2}.
func set_points_of_interest(points: Array) -> void:
	_points_of_interest = points.duplicate(true)


func get_points_of_interest() -> Array:
	return _points_of_interest.duplicate(true)


## Exactly ONE responder per point: the nearest eligible follower
## (a sense matching the point kind, within SENSE_RANGE_TILES),
## and one follower answers at most one point. The responder's
## target is a tile BESIDE the point (never the point tile), and
## it faces the point. Assignments release when the point is
## removed or the follower is pulled away (trainer moving is
## handled by the follow-forcing in behavior_tick, which clears
## point state through _update_detections next tick).
func _update_detections(trainer_pos: Vector2) -> void:
	var ts: float = 8.0
	if _behavior_loader != null:
		ts = float(_behavior_loader.tile_size_px)
	# Release stale assignments.
	for i in range(_behavior.size()):
		var entry: Dictionary = _behavior[i]
		var pid: String = str(entry.get("point_id", ""))
		if pid == "":
			continue
		var still_there: bool = false
		for point_value in _points_of_interest:
			if point_value is Dictionary and str((point_value as Dictionary).get("id", "")) == pid:
				still_there = true
		if not still_there or str(entry.get("state", "")) != "point":
			entry["point_id"] = ""
			if str(entry.get("state", "")) == "point":
				entry["state"] = "follow"
	if _points_of_interest.is_empty():
		return
	# Sort points by nearest eligible distance for stable claims.
	for point_value in _points_of_interest:
		if not (point_value is Dictionary):
			continue
		var point: Dictionary = point_value
		var pid: String = str(point.get("id", ""))
		if pid == "":
			continue
		var already: bool = false
		for entry_value in _behavior:
			var entry: Dictionary = entry_value
			if str(entry.get("point_id", "")) == pid:
				already = true
		if already:
			continue
		var kind: String = str(point.get("kind", "hidden_item"))
		var wanted_value: Variant = POI_SENSES.get(kind, ["sight", "smell"])
		var wanted: Array = []
		if wanted_value is Array:
			wanted = wanted_value
		var point_pos: Vector2 = point.get("pos", Vector2.ZERO)
		var best: int = -1
		var best_dist: float = 1.0e18
		for i in range(_behavior.size()):
			var entry: Dictionary = _behavior[i]
			if str(entry.get("point_id", "")) != "":
				continue
			if str(entry.get("state", "")) == "deliver":
				continue
			var record: Dictionary = _followers[i]
			var senses_value: Variant = record.get("senses", [])
			var senses: Array = []
			if senses_value is Array:
				senses = senses_value
			var eligible: bool = false
			for sense_value in wanted:
				if senses.has(str(sense_value)):
					eligible = true
			if not eligible:
				continue
			var fpos: Vector2 = entry.get("pos", trainer_pos)
			var dist: float = fpos.distance_to(point_pos) / ts
			if dist <= SENSE_RANGE_TILES and dist < best_dist:
				best_dist = dist
				best = i
		if best < 0:
			continue
		var entry: Dictionary = _behavior[best]
		var record: Dictionary = _followers[best]
		var target: Vector2 = _point_stand_spot(point_pos, record, ts)
		if target.x < 0.0:
			continue
		entry["point_id"] = pid
		entry["point_pos"] = point_pos
		entry["point_target"] = target
		entry["state"] = "point"
		entry["state_time"] = 0.0
		show_emote(best, "?", "detection")


## A stand spot beside the point: a cardinal neighbour tile that
## the responder may occupy, never the point tile itself.
func _point_stand_spot(point_pos: Vector2, record: Dictionary, ts: float) -> Vector2:
	var offsets: Array = [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]
	var domains_value: Variant = record.get("domains", [])
	var domains: Array = []
	if domains_value is Array:
		domains = domains_value
	for off_value in offsets:
		var off: Vector2 = off_value
		var cand: Vector2 = point_pos + off * ts
		if _behavior_loader == null:
			return cand
		if _can_occupy_domains(_behavior_loader.tile_at_px(cand), str(record.get("body_type", "ground")), domains):
			return cand
	return Vector2(-1.0, -1.0)


func _try_step_domains(pos: Vector2, step: Vector2, body_type: String, domains_value: Variant) -> Vector2:
	var domains: Array = []
	if domains_value is Array:
		domains = domains_value
	if _behavior_loader == null or domains.is_empty():
		return _try_step(pos, step, body_type)
	var full: Vector2 = pos + step
	if _can_occupy_domains(_behavior_loader.tile_at_px(full), body_type, domains):
		return full
	var x_only: Vector2 = pos + Vector2(step.x, 0.0)
	if step.x != 0.0 and _can_occupy_domains(_behavior_loader.tile_at_px(x_only), body_type, domains):
		return x_only
	var y_only: Vector2 = pos + Vector2(0.0, step.y)
	if step.y != 0.0 and _can_occupy_domains(_behavior_loader.tile_at_px(y_only), body_type, domains):
		return y_only
	var perp: Vector2 = Vector2(-step.y, step.x)
	if perp.length() > 0.01:
		var slide_a: Vector2 = pos + perp.normalized() * step.length()
		if _can_occupy_domains(_behavior_loader.tile_at_px(slide_a), body_type, domains):
			return slide_a
		var slide_b: Vector2 = pos - perp.normalized() * step.length()
		if _can_occupy_domains(_behavior_loader.tile_at_px(slide_b), body_type, domains):
			return slide_b
	return pos


## Complete a pending delivery: the ONLY moment a found item
## enters the bag (MartShop.add_item, canonical-id keyed) and
## the ONLY moment the found-item notice fires.
func _complete_delivery(index: int) -> void:
	var entry: Dictionary = _behavior[index]
	var item: String = str(entry.get("pending_item", ""))
	if item == "":
		entry["state"] = "follow"
		return
	entry["pending_item"] = ""
	entry["state"] = "follow"
	entry["state_time"] = 0.0
	if _bag_shop != null:
		_bag_shop.add_item(item, 1)
	show_emote(index, "!", "delivery")
	follower_item_found.emit(index, item)
	follower_item_delivered.emit(index, item)
