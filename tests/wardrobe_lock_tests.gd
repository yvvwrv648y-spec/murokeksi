extends SceneTree
## Headless tests for the PUW identity lock + wardrobe economy
## prep (Riley canon, 2026-11-23 18:42 CST): the body preset +
## identity chosen at creation are locked for the save; hair,
## eyes, skin and clothes stay changeable; clothes are buyable
## in-game through a wardrobe that rides the MartShop money.
##
## Code under test:
## - PUWCharacterSetup (patched systems/character/
##   character_setup.gd): finish() finalizes the profile;
##   identity + body_silhouette refuse changes afterwards via
##   set_value()/set_value_result(); the lock persists through
##   PUWSaveManager save/load; old saves without the
##   "profile_finalized" key finalize on load.
## - PUWWardrobeShop (new systems/inventory/wardrobe_shop.gd):
##   catalog seeded from the real systems/cast/
##   wardrobe_registry.json; buy/own/wear against MartShop
##   money; owned clothes live on the profile's wardrobe list,
##   never in the bag; wearing is refused where the outfit has
##   no layer set (the registry's "signature_fallback").
##
## How to run it (Godot 4.7, headless):
##   godot --headless --script res://tests/wardrobe_lock_tests.gd
## Prints one PASS or FAIL line per check, then a summary, then
## quits. Exit code 0 means every check passed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW wardrobe + identity lock tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/wardrobe_lock_tests.gd")
		quit(1)
		return
	_run("test_unfinalized_accepts_everything", Callable(self, "test_unfinalized_accepts_everything"))
	_run("test_locked_profile_rejects_identity_and_body", Callable(self, "test_locked_profile_rejects_identity_and_body"))
	_run("test_locked_profile_accepts_customization", Callable(self, "test_locked_profile_accepts_customization"))
	_run("test_save_round_trip_keeps_lock", Callable(self, "test_save_round_trip_keeps_lock"))
	_run("test_old_save_finalizes_on_load", Callable(self, "test_old_save_finalizes_on_load"))
	_run("test_wardrobe_key_survives_setup_round_trip", Callable(self, "test_wardrobe_key_survives_setup_round_trip"))
	_run("test_catalog_seeded_from_registry", Callable(self, "test_catalog_seeded_from_registry"))
	_run("test_buy_adds_to_wardrobe_once", Callable(self, "test_buy_adds_to_wardrobe_once"))
	_run("test_buy_refusals", Callable(self, "test_buy_refusals"))
	_run("test_wear_context_rules", Callable(self, "test_wear_context_rules"))
	print("SUMMARY: %d passed, %d failed." % [_passed, _failed])
	if not _failed_names.is_empty():
		print("FAILED: " + ", ".join(_failed_names))
	quit(0 if _failed == 0 else 1)


func _run(test_name: String, fn: Callable) -> void:
	fn.call()


func _check(test_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: " + test_name + (" — " + detail if detail != "" else ""))
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name + (" — " + detail if detail != "" else ""))


## A complete, unfinalized setup with known values.
func _complete_setup() -> PUWCharacterSetup:
	var setup: PUWCharacterSetup = PUWCharacterSetup.new()
	setup.set_value("identity", "Femboy")
	setup.set_value("pronouns", "he/him")
	setup.set_value("body_silhouette", "femboy")
	setup.set_value("face", "soft")
	setup.set_value("eyes", "green")
	setup.set_value("heterochromia", false)
	setup.set_value("hair_style", "medium")
	setup.set_value("hair_color", "blonde")
	setup.set_value("clothing", "streetwear")
	setup.set_value("signature_ball", "signature ball")
	setup.set_value("confirm", "confirmed")
	return setup


## A complete character dict as an OLD (pre-lock) save would
## hold it: every step value, no "profile_finalized" key.
func _old_save_character() -> Dictionary:
	return {
		"identity": "Female",
		"pronouns": "she/her",
		"body_silhouette": "female",
		"face": "soft",
		"eyes": "blue",
		"heterochromia": true,
		"hair_style": "long",
		"hair_color": "black",
		"clothing": "athletic",
		"signature_ball": "signature ball",
		"confirm": "confirmed",
	}


func _loaded_registry() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string("res://systems/cast/wardrobe_registry.json")
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


# ------------------------------------------------------------------
# Identity lock
# ------------------------------------------------------------------

func test_unfinalized_accepts_everything() -> void:
	var setup: PUWCharacterSetup = PUWCharacterSetup.new()
	var all_ok: bool = true
	all_ok = setup.set_value("identity", "Male") and all_ok
	all_ok = setup.set_value("identity", "Femboy") and all_ok
	all_ok = setup.set_value("body_silhouette", "male") and all_ok
	all_ok = setup.set_value("body_silhouette", "femboy") and all_ok
	all_ok = setup.set_value("pronouns", "he/him") and all_ok
	all_ok = setup.set_value("face", "soft") and all_ok
	all_ok = setup.set_value("eyes", "green") and all_ok
	all_ok = setup.set_value("heterochromia", true) and all_ok
	all_ok = setup.set_value("hair_style", "medium") and all_ok
	all_ok = setup.set_value("hair_color", "blonde") and all_ok
	all_ok = setup.set_value("clothing", "streetwear") and all_ok
	all_ok = setup.set_value("signature_ball", "signature ball") and all_ok
	all_ok = setup.set_value("confirm", "confirmed") and all_ok
	_check("unfinalized: every step accepts values, identity/body change freely", all_ok and not setup.is_finalized() and setup.is_complete())
	var bad: Dictionary = setup.set_value_result("identity", "Not An Option")
	_check("unfinalized: non-canon identity still refused, with a reason", not bool(bad.get("ok", true)) and str(bad.get("reason", "")) != "")
	var unknown: Dictionary = setup.set_value_result("nope", "x")
	_check("unfinalized: unknown step refused, with a reason", not bool(unknown.get("ok", true)) and str(unknown.get("reason", "")) != "")


func test_locked_profile_rejects_identity_and_body() -> void:
	var setup: PUWCharacterSetup = _complete_setup()
	_check("locked: finish() finalizes a complete profile", setup.finish() and setup.is_finalized())
	var identity_result: Dictionary = setup.set_value_result("identity", "Female")
	_check("locked: identity change refused via result", not bool(identity_result.get("ok", true)))
	_check("locked: identity refusal carries a plain reason", str(identity_result.get("reason", "")).contains("locked"))
	_check("locked: identity change refused via bool API", not setup.set_value("identity", "Female"))
	_check("locked: identity value unchanged", str(setup.get_value("identity")) == "Femboy")
	var body_result: Dictionary = setup.set_value_result("body_silhouette", "female")
	_check("locked: body preset change refused, with reason", not bool(body_result.get("ok", true)) and str(body_result.get("reason", "")).contains("locked"))
	_check("locked: body preset value unchanged", str(setup.get_value("body_silhouette")) == "femboy")
	var built: Dictionary = setup.build_character()
	_check("locked: built character stamped profile_finalized", bool(built.get("profile_finalized", false)))


func test_locked_profile_accepts_customization() -> void:
	var setup: PUWCharacterSetup = _complete_setup()
	setup.finish()
	var ok: bool = true
	ok = setup.set_value("hair_style", "long waves") and ok
	ok = setup.set_value("hair_color", "copper") and ok
	ok = setup.set_value("eyes", "left green, right amber") and ok
	ok = setup.set_value("heterochromia", true) and ok
	ok = setup.set_value("heterochromia", "left #2563eb, right #b45309") and ok
	ok = setup.set_value("clothing", "athletic") and ok
	ok = setup.set_value("face", "sharp") and ok
	ok = setup.set_value("pronouns", "he/they") and ok
	_check("locked: hair, eyes, heterochromia, clothing, face, pronouns stay changeable", ok)
	var built: Dictionary = setup.build_character()
	_check("locked: customization lands in the built character", str(built.get("hair_color", "")) == "copper" and str(built.get("clothing", "")) == "athletic" and str(built.get("identity", "")) == "Femboy")


func test_save_round_trip_keeps_lock() -> void:
	PUWSaveManager.delete_save()
	var setup: PUWCharacterSetup = _complete_setup()
	setup.finish()
	var state: Dictionary = {"story_flags": {}}
	_check("round trip: save_character writes the save", setup.save_character(state))
	var loaded: Dictionary = PUWSaveManager.load_game()
	var flags_value: Variant = loaded.get("story_flags", {})
	var character: Dictionary = {}
	if flags_value is Dictionary:
		var flags: Dictionary = flags_value
		var character_value: Variant = flags.get("character_setup", {})
		if character_value is Dictionary:
			var stored: Dictionary = character_value
			character = stored
	_check("round trip: saved character carries the finalized stamp", bool(character.get("profile_finalized", false)))
	var restored: PUWCharacterSetup = PUWCharacterSetup.new()
	_check("round trip: load_character restores a complete profile", restored.load_character(character))
	_check("round trip: lock is live after load", restored.is_finalized())
	_check("round trip: identity still refused after load", not restored.set_value("identity", "Male"))
	_check("round trip: hair still changeable after load", restored.set_value("hair_color", "silver"))
	PUWSaveManager.delete_save()


func test_old_save_finalizes_on_load() -> void:
	var restored: PUWCharacterSetup = PUWCharacterSetup.new()
	_check("old save: complete pre-lock character loads", restored.load_character(_old_save_character()))
	_check("old save: finalize-on-load turns the lock on", restored.is_finalized())
	_check("old save: identity refused after load", not restored.set_value("identity", "Male"))
	_check("old save: body preset refused after load", not restored.set_value("body_silhouette", "male"))
	_check("old save: hair still changeable after load", restored.set_value("hair_style", "bob"))
	var built: Dictionary = restored.build_character()
	_check("old save: next build stamps profile_finalized", bool(built.get("profile_finalized", false)))


func test_wardrobe_key_survives_setup_round_trip() -> void:
	var character: Dictionary = _old_save_character()
	character["profile_finalized"] = true
	character["cast_id"] = "custom_female"
	character["wardrobe"] = ["custom_female_streetwear"]
	var restored: PUWCharacterSetup = PUWCharacterSetup.new()
	restored.load_character(character)
	var built: Dictionary = restored.build_character()
	var wardrobe_value: Variant = built.get("wardrobe", [])
	var wardrobe_ok: bool = false
	if wardrobe_value is Array:
		var wardrobe: Array = wardrobe_value
		wardrobe_ok = wardrobe.has("custom_female_streetwear")
	_check("extras: wardrobe list survives a setup load/build round trip", wardrobe_ok and str(built.get("cast_id", "")) == "custom_female")


# ------------------------------------------------------------------
# Wardrobe catalog + economy
# ------------------------------------------------------------------

func test_catalog_seeded_from_registry() -> void:
	var wardrobe_shop: PUWWardrobeShop = PUWWardrobeShop.new()
	var count: int = wardrobe_shop.load_catalog(_loaded_registry())
	_check("catalog: seeded from the real registry (22 outfits incl. 6 signature)", count == 22, "count=" + str(count))
	var streetwear: Dictionary = wardrobe_shop.entry_for("custom_female_streetwear")
	_check("catalog: custom_female_streetwear exists as a real entry", not streetwear.is_empty())
	_check("catalog: entry shape carries id/name/price/slot/cast/contexts", str(streetwear.get("id", "")) == "custom_female_streetwear" and str(streetwear.get("display_name", "")) == "Streetwear" and str(streetwear.get("layer_slot", "")) == "outfit" and str(streetwear.get("cast_id", "")) == "custom_female")
	var price: int = int(streetwear.get("price", 0))
	_check("catalog: price is inside the labeled design band", price >= 2000 and price <= 4000 and str(streetwear.get("price_basis", "")) == "design_constant_band", "price=" + str(price))
	var contexts_value: Variant = streetwear.get("contexts", [])
	var contexts: Array = []
	if contexts_value is Array:
		var raw_contexts: Array = contexts_value
		contexts = raw_contexts
	_check("catalog: streetwear has a battle layer but no bike layer (registry truth)", contexts.has("battle") and not contexts.has("bike"))
	var futa_swim: Dictionary = wardrobe_shop.entry_for("custom_futanari_swimwear")
	var futa_contexts_value: Variant = futa_swim.get("contexts", [])
	var futa_contexts: Array = []
	if futa_contexts_value is Array:
		var raw_futa: Array = futa_contexts_value
		futa_contexts = raw_futa
	_check("catalog: futanari swimwear has no swim layer (signature_fallback in registry)", not futa_contexts.has("swim") and futa_contexts.has("battle"))
	var lounge: Dictionary = wardrobe_shop.entry_for("riley_lounge")
	_check("catalog: riley_lounge seeded from the registry", not lounge.is_empty() and str(lounge.get("display_name", "")) == "Lounge")
	var signature: Dictionary = wardrobe_shop.entry_for("custom_female_signature")
	_check("catalog: signature outfits are catalogued but never for sale", not signature.is_empty() and not bool(signature.get("for_sale", true)) and int(signature.get("price", -1)) == 0)
	_check("catalog: file loader builds the same catalog", PUWWardrobeShop.new().load_catalog_file() == 22)


func test_buy_adds_to_wardrobe_once() -> void:
	var wardrobe_shop: PUWWardrobeShop = PUWWardrobeShop.new()
	wardrobe_shop.load_catalog(_loaded_registry())
	var entry: Dictionary = wardrobe_shop.entry_for("custom_female_streetwear")
	var price: int = int(entry.get("price", 0))
	var profile: Dictionary = {"cast_id": "custom_female", "wardrobe": []}
	var shop: MartShop = MartShop.new()
	shop.money = price + 500
	var result: Dictionary = wardrobe_shop.buy(profile, shop, "custom_female_streetwear")
	_check("buy: first buy succeeds", bool(result.get("ok", false)), str(result.get("reason", "")))
	_check("buy: money deducted exactly once", shop.money == 500)
	_check("buy: outfit lands on the profile wardrobe list", wardrobe_shop.wardrobe_of(profile).has("custom_female_streetwear"))
	_check("buy: outfit does NOT enter the shop bag", shop.bag.is_empty())
	_check("buy: owns() agrees after buying", wardrobe_shop.owns(profile, "custom_female_streetwear"))
	var second: Dictionary = wardrobe_shop.buy(profile, shop, "custom_female_streetwear")
	_check("buy: second buy refused (already owned)", not bool(second.get("ok", true)) and str(second.get("reason", "")).contains("already own"))
	_check("buy: refused second buy takes no money", shop.money == 500)
	_check("buy: wardrobe still holds exactly one copy", wardrobe_shop.wardrobe_of(profile).count("custom_female_streetwear") == 1)


func test_buy_refusals() -> void:
	var wardrobe_shop: PUWWardrobeShop = PUWWardrobeShop.new()
	wardrobe_shop.load_catalog(_loaded_registry())
	var entry: Dictionary = wardrobe_shop.entry_for("custom_male_athletic")
	var price: int = int(entry.get("price", 0))
	var broke_profile: Dictionary = {"cast_id": "custom_male", "wardrobe": []}
	var broke_shop: MartShop = MartShop.new()
	broke_shop.money = price - 1
	var broke: Dictionary = wardrobe_shop.buy(broke_profile, broke_shop, "custom_male_athletic")
	_check("buy: insufficient funds refused", not bool(broke.get("ok", true)) and str(broke.get("reason", "")).contains("enough money"))
	_check("buy: insufficient funds changes nothing", broke_shop.money == price - 1 and wardrobe_shop.wardrobe_of(broke_profile).is_empty())
	var rich_shop: MartShop = MartShop.new()
	rich_shop.money = 100000
	var wrong_cast: Dictionary = wardrobe_shop.buy(broke_profile, rich_shop, "custom_female_athletic")
	_check("buy: another character's outfit refused", not bool(wrong_cast.get("ok", true)) and str(wrong_cast.get("reason", "")).contains("different character"))
	var unknown: Dictionary = wardrobe_shop.buy(broke_profile, rich_shop, "custom_male_does_not_exist")
	_check("buy: unknown outfit refused", not bool(unknown.get("ok", true)))
	var signature: Dictionary = wardrobe_shop.buy(broke_profile, rich_shop, "custom_male_signature")
	_check("buy: signature outfit is not for sale", not bool(signature.get("ok", true)) and rich_shop.money == 100000)


func test_wear_context_rules() -> void:
	var wardrobe_shop: PUWWardrobeShop = PUWWardrobeShop.new()
	wardrobe_shop.load_catalog(_loaded_registry())
	var profile: Dictionary = {"cast_id": "custom_female", "wardrobe": ["custom_female_streetwear"]}
	var worn: Dictionary = wardrobe_shop.wear(profile, "custom_female_streetwear", "battle")
	_check("wear: owned outfit wears in a context with a layer", bool(worn.get("ok", false)) and str(profile.get("current_outfit", "")) == "custom_female_streetwear")
	var bike: Dictionary = wardrobe_shop.wear(profile, "custom_female_streetwear", "bike")
	_check("wear: context with no layer set is refused (bike)", not bool(bike.get("ok", true)) and str(bike.get("reason", "")).contains("signature outfit"))
	_check("wear: refused wear changes nothing", str(profile.get("current_outfit", "")) == "custom_female_streetwear" and str(profile.get("current_context", "")) == "battle")
	var unowned: Dictionary = wardrobe_shop.wear(profile, "custom_female_athletic", "battle")
	_check("wear: unowned outfit refused", not bool(unowned.get("ok", true)) and str(unowned.get("reason", "")).contains("don't own"))
	var signature_wear: Dictionary = wardrobe_shop.wear(profile, "custom_female_signature", "bike")
	_check("wear: signature outfit (owned by default) wears anywhere", bool(signature_wear.get("ok", false)))
	var futa_profile: Dictionary = {"cast_id": "custom_futanari", "wardrobe": ["custom_futanari_swimwear"]}
	var swim: Dictionary = wardrobe_shop.wear(futa_profile, "custom_futanari_swimwear", "swim")
	_check("wear: futanari swimwear refused in swim (no swim layer in registry)", not bool(swim.get("ok", true)))
	var swim_ok: Dictionary = wardrobe_shop.wear(futa_profile, "custom_futanari_swimwear", "overworld_walk")
	_check("wear: futanari swimwear wears on the overworld (layer exists)", bool(swim_ok.get("ok", false)))
	_check("wear: can_wear_in_context matches the registry truth", wardrobe_shop.can_wear_in_context("custom_female_streetwear", "battle") and not wardrobe_shop.can_wear_in_context("custom_female_streetwear", "bike"))
