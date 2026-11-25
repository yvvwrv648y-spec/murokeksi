class_name PUWBikes
extends RefCounted
## Bicycles for Pokemon Ultimate World: solo Acro/Mach ride modes,
## per-cast solo bike themes, and the strictly co-op-locked tandem
## system. Logic and data only -- no art.
##
## Sources (verbatim project data files, installed from the custom
## work bundle):
## - systems/transportation/bicycle_registry.json: the 6 solo bikes
##   (Riley, Tasha, and the four Custom presets) + tandems,
##   and the co-op two-seater rule.
## - systems/transportation/tandem_pose_and_movement_spec.json:
##   the 11-entry passenger pose matrix, the movement speeds
##   (sneak 2.2 / walk 4.0 / run 8.0 / acro 10.67 / mach 16.0
##   tiles per second), the tandem co-op lock, and the
##   ZERO_DEFAULT_REVERSION outfit preservation rule.

const REGISTRY_PATH: String = "res://systems/transportation/bicycle_registry.json"
const SPEC_PATH: String = "res://systems/transportation/tandem_pose_and_movement_spec.json"

const MODE_SOLO_ACRO: String = "solo_acro"
const MODE_SOLO_MACH: String = "solo_mach"

## Outfit preservation is a data rule from the spec, exposed as a
## flag so riders/mounters must honor it: mounting a bike NEVER
## reverts the rider's outfit, swimwear, colors, or body sliders
## to a default.
const ZERO_DEFAULT_REVERSION: bool = true


static func _load_json(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func registry_data() -> Dictionary:
	return _load_json(REGISTRY_PATH)


static func spec_data() -> Dictionary:
	return _load_json(SPEC_PATH)


## Speed in tiles per second for a ride mode, read from the spec's
## official_movement_physics (bike_acro 10.67, bike_mach 16.0).
## Returns 0.0 for an unknown mode.
static func speed_for(mode: String) -> float:
	var spec: Dictionary = spec_data()
	var physics: Dictionary = spec.get("official_movement_physics", {})
	var key: String = ""
	if mode == MODE_SOLO_ACRO:
		key = "bike_acro"
	elif mode == MODE_SOLO_MACH:
		key = "bike_mach"
	else:
		return 0.0
	var entry: Dictionary = physics.get(key, {})
	return float(entry.get("tiles_per_sec", 0.0))


## On-foot / bike movement speeds from the same spec table:
## sneak 2.2, walk 4.0, run 8.0, acro 10.67, mach 16.0.
static func movement_speeds() -> Dictionary:
	var spec: Dictionary = spec_data()
	var physics: Dictionary = spec.get("official_movement_physics", {})
	var out: Dictionary = {}
	for key_value: Variant in physics.keys():
		var key: String = str(key_value)
		var entry: Dictionary = physics[key]
		out[key] = float(entry.get("tiles_per_sec", 0.0))
	return out


## Registry bicycle entry by id ("" -> empty Dictionary).
static func _bicycle_entry(bicycle_id: String) -> Dictionary:
	var data: Dictionary = registry_data()
	var bicycles: Array = data.get("bicycles", [])
	for entry_value: Variant in bicycles:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == bicycle_id:
			return entry
	return {}


## The solo bicycle id for a cast member, from the registry:
## riley -> riley_solo, tasha -> tasha_solo, and each Custom
## preset -> its own solo bike (custom_fem_solo,
## custom_masc_solo, custom_femboy_solo, custom_futanari_solo).
## The Femboy and Futanari presets shared custom_fem_solo until
## the 2026-11-23 registry addendum gave them their own entries.
static func solo_bicycle_id_for(cast_id: String) -> String:
	match cast_id:
		"riley":
			return "riley_solo"
		"tasha":
			return "tasha_solo"
		"custom_female":
			return "custom_fem_solo"
		"custom_male":
			return "custom_masc_solo"
		"custom_femboy":
			return "custom_femboy_solo"
		"custom_futanari":
			return "custom_futanari_solo"
	return ""


## The solo bike theme for a cast member, verbatim from
## bicycle_registry.json.
static func solo_theme_for(cast_id: String) -> String:
	var entry: Dictionary = _bicycle_entry(solo_bicycle_id_for(cast_id))
	return str(entry.get("theme", ""))


## --- Bike classes and capacities (Phase 3) ---
## Every solo bike in bicycle_registry.json carries a "class"
## ("acro" or "mach") and a "capacities" list. PUW design decision
## recorded in the registry: riley_solo + custom_fem_solo are acro,
## tasha_solo + custom_masc_solo are mach. The capacities mirror
## the original games' Acro Bike (bunny hop, wheelie, narrow rails)
## and Mach Bike (top speed, muddy slopes). Tandem entries carry
## NO class and NO capacities -- tandem rules are unchanged.
## Addendum (2026-11-23, recorded in the registry note):
## custom_futanari_solo is acro and custom_femboy_solo is mach,
## balancing the six solo bikes three acro / three mach.
const CLASS_ACRO: String = "acro"
const CLASS_MACH: String = "mach"
const CAP_BUNNY_HOP: String = "bunny_hop"
const CAP_WHEELIE: String = "wheelie"
const CAP_RAIL_RIDE: String = "rail_ride"
const CAP_TOP_SPEED: String = "top_speed"
const CAP_MUDDY_SLOPE_CLIMB: String = "muddy_slope_climb"


## Canonical capacity set for a class, in registry order.
static func capacities_for_class(bike_class: String) -> Array:
	if bike_class == CLASS_ACRO:
		return [CAP_BUNNY_HOP, CAP_WHEELIE, CAP_RAIL_RIDE]
	if bike_class == CLASS_MACH:
		return [CAP_TOP_SPEED, CAP_MUDDY_SLOPE_CLIMB]
	return []


## Class of any registry bicycle ("" for tandems / unknown ids).
static func bike_class_for(bicycle_id: String) -> String:
	var entry: Dictionary = _bicycle_entry(bicycle_id)
	return str(entry.get("class", ""))


## Capacities of any registry bicycle, verbatim from the registry
## (empty for tandems / unknown ids).
static func capacities_for_bike(bicycle_id: String) -> Array:
	var entry: Dictionary = _bicycle_entry(bicycle_id)
	var caps: Array = entry.get("capacities", [])
	return caps.duplicate()


static func bike_has_capacity(bicycle_id: String, capacity: String) -> bool:
	return capacities_for_bike(bicycle_id).has(capacity)


## Capacities of the solo bike owned by a cast member.
static func solo_capacities_for(cast_id: String) -> Array:
	return capacities_for_bike(solo_bicycle_id_for(cast_id))


## Class implied by a ride mode: MODE_SOLO_ACRO -> "acro",
## MODE_SOLO_MACH -> "mach", anything else -> "". The player
## controller's movement-mode names for the same rides
## ("bike_acro" / "bike_mach", its SPEEDS keys) are accepted too,
## so capacity checks work through either naming scheme.
static func class_for_mode(mode: String) -> String:
	if mode == MODE_SOLO_ACRO or mode == "bike_acro":
		return CLASS_ACRO
	if mode == MODE_SOLO_MACH or mode == "bike_mach":
		return CLASS_MACH
	return ""


## Capacities implied by a ride mode (empty on foot).
static func capacities_for_mode(mode: String) -> Array:
	return capacities_for_class(class_for_mode(mode))


## Tandem is strictly locked unless 2-player co-op is active
## (bicycle_registry.json coop_tandem_rule +
## tandem spec tandem_coop_lock). No exceptions.
static func tandem_available(coop_active: bool) -> bool:
	return coop_active


## The tandem bicycle id for a driver cast member: the registry's
## two-seater owned by the driver (the displayed bike belongs to
## the player in control / front seat).
static func tandem_bicycle_id_for(driver_cast_id: String) -> String:
	match driver_cast_id:
		"riley":
			return "riley_tandem"
		"tasha":
			return "tasha_tandem"
		"custom_female":
			return "custom_fem_tandem"
		"custom_male":
			return "custom_masc_tandem"
		"custom_femboy":
			return "custom_femboy_tandem"
		"custom_futanari":
			return "custom_futanari_tandem"
	return ""


## The tandem theme for a driver, verbatim from the registry.
static func tandem_theme(driver_cast_id: String) -> String:
	var entry: Dictionary = _bicycle_entry(tandem_bicycle_id_for(driver_cast_id))
	return str(entry.get("theme", ""))


## Passenger pose for a (driver, passenger) pairing from the
## spec's 11-entry passenger_pose_matrix. The matrix is keyed by
## the PASSENGER behind the DRIVER ("<passenger>_behind_<driver>"),
## with custom passengers covered by the single "custom_behind_any"
## entry. Returns the matrix entry {intimacy, pose} verbatim, or
## an empty Dictionary for a pairing the matrix does not name.
static func pose_for(driver: String, passenger: String) -> Dictionary:
	var spec: Dictionary = spec_data()
	var matrix: Dictionary = spec.get("passenger_pose_matrix", {})
	# The matrix names only riley/tasha as individual passengers;
	# every Custom passenger is covered by the single
	# "custom_behind_any" entry.
	if passenger.begins_with("custom"):
		var custom_entry: Dictionary = matrix.get("custom_behind_any", {})
		return custom_entry
	var driver_token: String = _pose_token(driver)
	var passenger_token: String = _pose_token(passenger)
	var key: String = passenger_token + "_behind_" + driver_token
	var entry: Dictionary = matrix.get(key, {})
	return entry


## All pose matrix keys (11 entries), for coverage checks.
static func pose_matrix_keys() -> Array:
	var spec: Dictionary = spec_data()
	var matrix: Dictionary = spec.get("passenger_pose_matrix", {})
	var keys: Array = matrix.keys()
	keys.sort()
	return keys


static func _pose_token(cast_or_identity: String) -> String:
	match cast_or_identity:
		"riley":
			return "riley"
		"tasha":
			return "tasha"
		"custom_female":
			return "female"
		"custom_male":
			return "male"
		"custom_femboy":
			return "femboy"
		"custom_futanari":
			return "futanari"
		"custom":
			return "custom"
	return cast_or_identity


## --- Rotom Bike water re-fit (mechanics prep F5, 2026-11-24) ---
## Canon ruling (Bossy, 2026-11-24): the Rotom Bike's water
## mode is a RE-FIT of a bicycle the player already has, NOT a
## 13th registry bicycle -- the registry above stays at exactly
## 12 bicycles (6 solo + 6 tandem) and gains no entry. The
## "rotom-bike" key item (item database id "rotom-bike";
## ITEM_AUDIT.md flagged it unimplemented) re-fits whichever
## bicycle is mounted: while the player's bag holds the item,
## a mounted bike crosses water like a water ride mode. The
## surf field-action gate still applies first -- the player
## controller runs PUWFieldActions before consulting this.
const ROTOM_BIKE_ITEM_ID: String = "rotom-bike"
const ROTOM_BIKE_ITEM_ID_ALT: String = "rotom_bike"


## True when the bag (the save state's flat item_id -> count
## Dictionary, the same shape PUWCampaignStitch reads for the
## Omni Ring) holds the Rotom Bike key item.
static func rotom_refit_available(state: Dictionary) -> bool:
	var bag_value: Variant = state.get("bag", {})
	if not (bag_value is Dictionary):
		return false
	var bag: Dictionary = bag_value
	return int(bag.get(ROTOM_BIKE_ITEM_ID, 0)) > 0 or int(bag.get(ROTOM_BIKE_ITEM_ID_ALT, 0)) > 0


## True when bicycle_id is a real registry bicycle AND its
## rider's state holds the Rotom Bike re-fit item, so the
## mounted bike may cross water. Tandems have no class and are
## never water-capable through the re-fit.
static func water_capable(bicycle_id: String, state: Dictionary) -> bool:
	if bicycle_id == "" or bike_class_for(bicycle_id) == "":
		return false
	return rotom_refit_available(state)


## The outfit preservation rule as data, straight from the spec:
## {flag: ZERO_DEFAULT_REVERSION, rule: <verbatim spec text>}.
static func outfit_preservation() -> Dictionary:
	var spec: Dictionary = spec_data()
	return {
		"zero_default_reversion": ZERO_DEFAULT_REVERSION,
		"rule": str(spec.get("outfit_preservation_rule", "")),
	}
