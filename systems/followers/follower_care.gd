class_name PUWFollowerCare
extends RefCounted
## Pokemon interaction / care layer (Worker C, Part B,
## 2026-11-23). Player-initiated care (talk / feed / groom /
## treats) acts on the REAL friendship system: the individual's
## own "friendship" value (falling back to "happiness"), the
## exact field pokemon/evolution/evolution_manager.gd reads
## (_friendship_of: "friendship" first, then "happiness").
## Friendship is clamped to the canon 0..255 range. The canon
## friendship-evolution threshold referenced by the brief is
## 160 (Gen 8+ form).
##
## AMOUNTS: no shipped game gives per-action numbers for
## talk/groom, so these are PUW DESIGN CONSTANTS, labeled as
## such: TALK +2, GROOM +3, FEED/TREAT +5 (feeding is the
## strongest because it consumes a real item). Feeding/treats
## consume the item from the REAL bag (MartShop.bag, the
## battle-engine-v4 bag) -- berries are the food items the item
## data defines (items_full_compact.json: oran-berry and 93
## other berry/food entries; there is no dedicated "treat"
## item, so berries ARE the treats). No item -> the action
## refuses honestly and grants nothing.
##
## ANTI-FARM (PUW design constants): free actions cool down
## per Pokemon: TALK_COOLDOWN_SECONDS 30, GROOM 60. Feeding is
## limited by item consumption instead.
##
## Pokemon <-> Pokemon interactions: the project data provides
## NO relationship/nature dataset for followers, so interaction
## kinds come from a documented deterministic seeded default
## (rng passed in), never a fabricated dataset. Interactions
## are occasional (INTERACTION_TICK_CHANCE per tick, PUW
## design constant) and diegetic: an event record + an emote
## glyph from EMOTES (data table, extensible; glyphs are plain
## text/unicode the engine renders -- no new art).

const FRIENDSHIP_MAX: int = 255
const TALK_GAIN: int = 2
const GROOM_GAIN: int = 3
const FEED_GAIN: int = 5
const TALK_COOLDOWN_SECONDS: float = 30.0
const GROOM_COOLDOWN_SECONDS: float = 60.0
const INTERACTION_TICK_CHANCE: float = 0.02
const INTERACTION_KINDS: Array = ["play", "greeting", "rivalry", "rest_together"]

const EMOTES: Dictionary = {
	"talk": "♪",
	"groom": "♪",
	"feed": "♥",
	"treat": "♥",
	"play": "♥",
	"greeting": "♪",
	"rivalry": "!",
	"rest_together": "Z",
	"curious": "?",
	"found_item": "!",
	"perch": "♪",
}

var _cooldowns: Dictionary = {} # mon key -> {action: ready_at}


static func emote_for(kind: String) -> String:
	return str(EMOTES.get(kind, "?"))


static func friendship_of(mon: Dictionary) -> int:
	if mon.has("friendship") and mon.get("friendship") != null:
		return int(mon.get("friendship", 0))
	if mon.has("happiness") and mon.get("happiness") != null:
		return int(mon.get("happiness", 0))
	return 0


static func _apply_gain(mon: Dictionary, gain: int) -> int:
	# SHADOW ROUTING (Orre code prep, ORRE_BUILD_PREP.md SS4.3.1,
	# labeled design position): care points earned by a Shadow
	# follower route into its Heart Gauge instead of the
	# friendship track -- talk / groom / treat open the heart.
	# The gauge reduction is returned as the "gain" so callers
	# report the same shape; the mon's friendship is untouched
	# while it is Shadow, and normal routing resumes the moment
	# it is purified (PUWShadowSystem.is_shadow goes false).
	if PUWShadowSystem.is_shadow(mon):
		var routed: Dictionary = PUWShadowSystem.apply_care_points(mon, gain)
		return int(routed.get("applied", 0))
	var before: int = friendship_of(mon)
	var after: int = clampi(before + gain, 0, FRIENDSHIP_MAX)
	mon["friendship"] = after
	return after - before


func _mon_key(mon: Dictionary) -> String:
	return str(mon.get("slug", mon.get("species", mon.get("name", "?")))) + "#" + str(mon.get("party_index", mon.get("nickname", "")))


func _cooling(mon: Dictionary, action: String, now: float, cooldown: float) -> bool:
	var key: String = _mon_key(mon)
	var per_mon_value: Variant = _cooldowns.get(key, {})
	if per_mon_value is Dictionary:
		var per_mon: Dictionary = per_mon_value
		return now < float(per_mon.get(action, -1.0e9)) + cooldown
	return false


func _stamp(mon: Dictionary, action: String, now: float) -> void:
	var key: String = _mon_key(mon)
	var per_mon: Dictionary = {}
	var existing_value: Variant = _cooldowns.get(key, {})
	if existing_value is Dictionary:
		var existing: Dictionary = existing_value
		per_mon = existing
	per_mon[action] = now
	_cooldowns[key] = per_mon


## Talk to a Pokemon: +TALK_GAIN friendship, cooldown-gated.
func talk(mon: Dictionary, now: float) -> Dictionary:
	if _cooling(mon, "talk", now, TALK_COOLDOWN_SECONDS):
		return {"ok": false, "reason": "cooldown", "gain": 0, "emote": ""}
	var gain: int = _apply_gain(mon, TALK_GAIN)
	_stamp(mon, "talk", now)
	return {"ok": true, "reason": "", "gain": gain, "emote": emote_for("talk"), "friendship": friendship_of(mon)}


## Groom a Pokemon: +GROOM_GAIN friendship, cooldown-gated.
func groom(mon: Dictionary, now: float) -> Dictionary:
	if _cooling(mon, "groom", now, GROOM_COOLDOWN_SECONDS):
		return {"ok": false, "reason": "cooldown", "gain": 0, "emote": ""}
	var gain: int = _apply_gain(mon, GROOM_GAIN)
	_stamp(mon, "groom", now)
	return {"ok": true, "reason": "", "gain": gain, "emote": emote_for("groom"), "friendship": friendship_of(mon)}


## Feed a Pokemon a food item from the real bag (MartShop):
## consumes exactly 1 of item_slug and grants +FEED_GAIN.
## Refuses (no gain, no consumption) when the bag holds none.
func feed(mon: Dictionary, shop: MartShop, item_slug: String) -> Dictionary:
	if shop == null or int(shop.bag.get(item_slug, 0)) <= 0:
		return {"ok": false, "reason": "no_item", "gain": 0, "emote": ""}
	shop.bag[item_slug] = int(shop.bag.get(item_slug, 0)) - 1
	if int(shop.bag[item_slug]) <= 0:
		shop.bag.erase(item_slug)
	var gain: int = _apply_gain(mon, FEED_GAIN)
	return {"ok": true, "reason": "", "gain": gain, "emote": emote_for("feed"), "friendship": friendship_of(mon), "item": item_slug}


## A treat is a feed with a berry (the food items the data
## defines; see header).
func treat(mon: Dictionary, shop: MartShop, berry_slug: String = "oran-berry") -> Dictionary:
	var result: Dictionary = feed(mon, shop, berry_slug)
	if bool(result.get("ok", false)):
		result["emote"] = emote_for("treat")
	return result


## One autonomous-interaction tick over a set of follower
## indices (can span two co-op teams: pass combined records).
## Returns an event Dictionary or {} when nothing happens.
## Event: {"a": int, "b": int, "kind": String, "emote": String}
## with indices into the combined records array.
func tick_interaction(record_count: int, rng: RandomNumberGenerator) -> Dictionary:
	if record_count < 2:
		return {}
	if rng.randf() >= INTERACTION_TICK_CHANCE:
		return {}
	var a: int = rng.randi_range(0, record_count - 1)
	var b: int = rng.randi_range(0, record_count - 1)
	if b == a:
		b = (b + 1) % record_count
	var kind: String = str(INTERACTION_KINDS[rng.randi_range(0, INTERACTION_KINDS.size() - 1)])
	return {"a": a, "b": b, "kind": kind, "emote": emote_for(kind)}
