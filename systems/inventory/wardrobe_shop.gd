class_name PUWWardrobeShop
extends RefCounted
## Wardrobe shop for Pokemon Ultimate World: buying, owning and
## wearing the layered outfits registered in
## systems/cast/wardrobe_registry.json.
##
## Canon (Riley, 2026-11-23 18:42 CST): clothes are BUYABLE
## in-game — a wardrobe economy riding the shop system. This
## class follows the MartShop patterns (same result-dict shape,
## same plain-English refusal reasons, money handled the same
## way) with three wardrobe-specific rules:
##
## 1. Money is the MartShop's money. buy() checks and deducts
##    shop.money, so the wardrobe spends from the one wallet
##    the game already has. Nothing goes into the shop's bag:
##    owned clothes are NOT consumable bag items.
## 2. Owned clothes live on the character profile as a wardrobe
##    list: profile["wardrobe"], an Array of catalog ids on the
##    character Dictionary (the one PUWCharacterSetup builds and
##    the save manager persists inside story_flags). Buying an
##    outfit already on the list is refused — you own clothes,
##    you don't stack them.
## 3. Wearing follows the layered-outfit canon: an outfit is
##    wearable in a context only when its layer set exists
##    there. The registry records that per outfit as
##    wearable_contexts; a context recorded "signature_fallback"
##    has NO layer for the outfit (the signature outfit shows
##    there instead), so wearing the outfit in that context is
##    refused. A direction list means the layer exists for
##    those directions; "bound_layered" and "signature" mean
##    the layer exists.
##
## Catalog entries are seeded ONLY from outfits that actually
## exist in the wardrobe registry (signature outfits included
## as not-for-sale: they are owned by default and never sold).
## Each entry is scoped to one cast id — the art for
## custom_female streetwear does not exist for custom_male —
## so buy()/wear() check the profile's "cast_id".
##
## PRICES — DESIGN CONSTANTS, NOT SOURCED DATA: no registry
## anywhere in the project carries a price for an outfit, so
## every price here comes from DESIGN_PRICE_BANDS below, a
## Bossy-set band per layer slot (2026-11-23). Within a band
## the price steps with how many contexts the outfit's layer
## set covers. Each entry says so in its "price_basis" field;
## no price in this catalog is presented as sourced.

const REGISTRY_PATH: String = "res://systems/cast/wardrobe_registry.json"

## The contexts an outfit can be worn in, in the registry's
## own order.
const CONTEXTS: Array = [
	"overworld_walk", "overworld_run", "idle", "swim",
	"battle", "ride", "bike"
]

## The one layer slot every registered outfit occupies: the
## layered engine composites exactly one outfit layer over the
## base body (plus the hair layer), so each registry outfit is
## a single outfit-layer good. The field is carried on every
## entry so single-piece goods (the slots in
## ProtagonistCanon.CLOTHING_SLOTS) can join the catalog later
## without a shape change.
const OUTFIT_LAYER_SLOT: String = "outfit"

## DESIGN CONSTANT price bands by layer slot: [low, high] in
## the game's money. See the header: these are design numbers,
## not sourced prices.
const DESIGN_PRICE_BANDS: Dictionary = {"outfit": [2000, 4000]}

## Catalog id -> entry Dictionary. Built by load_catalog().
var catalog: Dictionary = {}


## The design-constant price for a good on layer_slot whose
## layer set covers covered_contexts contexts: top of the
## band at 6 or more contexts, the middle at 5, the bottom
## at 4 or fewer.
static func design_price(layer_slot: String, covered_contexts: int) -> int:
	var band_value: Variant = DESIGN_PRICE_BANDS.get(layer_slot, [2000, 4000])
	var band: Array = band_value
	var low: int = int(band[0])
	var high: int = int(band[1])
	if covered_contexts >= 6:
		return high
	if covered_contexts == 5:
		return (low + high) / 2
	return low


## A plain readable name for an outfit id, e.g. "gothic_glam"
## becomes "Gothic Glam" (MartShop.display_name's rule, for
## the registry's underscore spelling).
static func display_name_for(outfit_id: String) -> String:
	var parts: Array = outfit_id.split("_")
	var words: Array = []
	for part in parts:
		var word: String = str(part)
		if word == "":
			continue
		words.append(word.capitalize())
	return " ".join(words)


## Build the catalog from a parsed wardrobe_registry.json
## Dictionary. Every outfit registered for every character
## becomes one entry (signature outfits included, marked
## not-for-sale). Returns how many entries were built.
func load_catalog(registry_data: Dictionary) -> int:
	catalog.clear()
	var count: int = 0
	var characters_value: Variant = registry_data.get("characters", {})
	if not (characters_value is Dictionary):
		return 0
	var characters: Dictionary = characters_value
	for cast_value in characters.keys():
		var cast_id: String = str(cast_value)
		var character_value: Variant = characters[cast_value]
		if not (character_value is Dictionary):
			continue
		var character: Dictionary = character_value
		var outfits_value: Variant = character.get("outfits", {})
		if not (outfits_value is Dictionary):
			continue
		var outfits: Dictionary = outfits_value
		for outfit_value in outfits.keys():
			var outfit_id: String = str(outfit_value)
			var outfit_data_value: Variant = outfits[outfit_value]
			if not (outfit_data_value is Dictionary):
				continue
			var outfit_data: Dictionary = outfit_data_value
			var entry: Dictionary = _catalog_entry(cast_id, outfit_id, outfit_data)
			catalog[str(entry.get("id", ""))] = entry
			count += 1
	return count


## Build the catalog straight from a JSON file path. Returns
## how many entries were built (0 when the file is missing or
## does not parse).
func load_catalog_file(path: String = REGISTRY_PATH) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return 0
	var data: Dictionary = parsed
	return load_catalog(data)


## One catalog entry from one registry outfit record.
func _catalog_entry(cast_id: String, outfit_id: String, outfit_data: Dictionary) -> Dictionary:
	var contexts: Array = []
	var contexts_value: Variant = outfit_data.get("wearable_contexts", {})
	if contexts_value is Dictionary:
		var recorded: Dictionary = contexts_value
		for context_value in CONTEXTS:
			var context: String = str(context_value)
			if not recorded.has(context):
				continue
			var mark: Variant = recorded[context]
			if mark is Array:
				var directions: Array = mark
				if not directions.is_empty():
					contexts.append(context)
			elif str(mark) == "bound_layered" or str(mark) == "signature":
				contexts.append(context)
			# "signature_fallback" (or any other mark) means NO
			# layer for this outfit in this context: the outfit
			# is not wearable there.
	var for_sale: bool = outfit_id != "signature"
	var price: int = 0
	var price_basis: String = "not_for_sale"
	if for_sale:
		price = design_price(OUTFIT_LAYER_SLOT, contexts.size())
		price_basis = "design_constant_band"
	return {
		"id": cast_id + "_" + outfit_id,
		"display_name": display_name_for(outfit_id),
		"price": price,
		"price_basis": price_basis,
		"layer_slot": OUTFIT_LAYER_SLOT,
		"cast_id": cast_id,
		"outfit_id": outfit_id,
		"contexts": contexts,
		"for_sale": for_sale,
		"source": REGISTRY_PATH,
	}


## All catalog ids, in build order.
func catalog_ids() -> Array:
	return catalog.keys()


## The catalog entry for an id (a copy), or an empty
## Dictionary when the id is not in the catalog.
func entry_for(item_id: String) -> Dictionary:
	if not catalog.has(item_id):
		return {}
	var entry: Dictionary = catalog[item_id]
	return entry.duplicate(true)


## True when the id is in the catalog at all.
func has_entry(item_id: String) -> bool:
	return catalog.has(item_id)


## The profile's owned catalog ids (a copy of its wardrobe
## list). The signature outfit is owned by default and is not
## stored on the list; see owns().
func wardrobe_of(profile: Dictionary) -> Array:
	var wardrobe_value: Variant = profile.get("wardrobe", [])
	if wardrobe_value is Array:
		var wardrobe: Array = wardrobe_value
		return wardrobe.duplicate()
	return []


## True when the profile owns the catalog entry: signature
## outfits are owned by default by their own cast; bought
## outfits are owned when their id is on the profile's
## wardrobe list.
func owns(profile: Dictionary, item_id: String) -> bool:
	if not catalog.has(item_id):
		return false
	var entry: Dictionary = catalog[item_id]
	if str(entry.get("cast_id", "")) != str(profile.get("cast_id", "")):
		return false
	if not bool(entry.get("for_sale", false)):
		return true
	return wardrobe_of(profile).has(item_id)


## True when the entry's layer set exists in the context
## (the layered-outfit canon's wearability rule).
func can_wear_in_context(item_id: String, context: String) -> bool:
	if not catalog.has(item_id):
		return false
	var entry: Dictionary = catalog[item_id]
	var contexts_value: Variant = entry.get("contexts", [])
	if contexts_value is Array:
		var contexts: Array = contexts_value
		return contexts.has(context)
	return false


## Build the result dict every buy returns, MartShop-style.
## wardrobe is a copy, so changing the returned dict never
## changes the profile.
func _buy_result(ok: bool, profile: Dictionary, shop: MartShop, log: String, reason: String) -> Dictionary:
	return {"ok": ok, "money": shop.money, "wardrobe": wardrobe_of(profile), "log": log, "reason": reason}


## Buy one outfit for the profile, paying from the shop's
## money. On success the money is taken and the outfit's id
## joins the profile's wardrobe list (never the shop's bag).
## On failure nothing changes and reason says why in plain
## English: unknown or not-for-sale outfit, an outfit made
## for a different character, already owned, or not enough
## money.
func buy(profile: Dictionary, shop: MartShop, item_id: String) -> Dictionary:
	if not catalog.has(item_id):
		return _buy_result(false, profile, shop, "", "That outfit is not sold here.")
	var entry: Dictionary = catalog[item_id]
	if not bool(entry.get("for_sale", false)):
		return _buy_result(false, profile, shop, "", "That outfit is not sold here.")
	if str(entry.get("cast_id", "")) != str(profile.get("cast_id", "")):
		return _buy_result(false, profile, shop, "", "That outfit is made for a different character.")
	if owns(profile, item_id):
		return _buy_result(false, profile, shop, "", "You already own that outfit.")
	var price: int = int(entry.get("price", 0))
	if shop.money < price:
		return _buy_result(false, profile, shop, "", "You don't have enough money for that.")
	shop.money -= price
	var wardrobe: Array = wardrobe_of(profile)
	wardrobe.append(item_id)
	profile["wardrobe"] = wardrobe
	var line: String = "Bought the " + str(entry.get("display_name", item_id)) + " outfit for " + str(price) + ". Money left: " + str(shop.money) + "."
	return _buy_result(true, profile, shop, line, "")


## Build the result dict every wear returns.
func _wear_result(ok: bool, profile: Dictionary, log: String, reason: String) -> Dictionary:
	return {"ok": ok, "current_outfit": str(profile.get("current_outfit", "")), "log": log, "reason": reason}


## Wear an owned outfit in a context. On success the
## profile's "current_outfit" (and "current_context") change.
## Refused — changing nothing — when the outfit is unknown,
## made for a different character, not owned yet, the context
## is not a wearing context, or the outfit has no layer set
## in that context (the signature outfit is worn there
## instead, per the layered-outfit canon).
func wear(profile: Dictionary, item_id: String, context: String) -> Dictionary:
	if not catalog.has(item_id):
		return _wear_result(false, profile, "", "That outfit does not exist.")
	var entry: Dictionary = catalog[item_id]
	if str(entry.get("cast_id", "")) != str(profile.get("cast_id", "")):
		return _wear_result(false, profile, "", "That outfit is made for a different character.")
	if not owns(profile, item_id):
		return _wear_result(false, profile, "", "You don't own that outfit yet.")
	if not CONTEXTS.has(context):
		return _wear_result(false, profile, "", "That is not a place an outfit can be worn.")
	if not can_wear_in_context(item_id, context):
		return _wear_result(false, profile, "", "The " + str(entry.get("display_name", item_id)) + " outfit has no " + context + " layer, so your signature outfit is worn there instead.")
	profile["current_outfit"] = item_id
	profile["current_context"] = context
	var line: String = "You are now wearing the " + str(entry.get("display_name", item_id)) + " outfit."
	return _wear_result(true, profile, line, "")
