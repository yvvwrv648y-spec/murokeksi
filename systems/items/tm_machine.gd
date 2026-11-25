class_name PUWTMMachine
extends RefCounted
## TM Machine (SV) — code prep, staging only.
## Model (sourced, see PREP_REPORT): select a TM recipe ->
## pay materials (up to 3 species materials, per-recipe
## quantities) + LP -> craft exactly one TM item -> the TM is
## used through batch 5's PUWItemServices.teach_machine,
## unchanged. Recipe record shape follows the held pkNX SV
## schema ShopWazamachineData {WazaNo, WazaItemID, LP, Cond,
## Item01..03/ItemNum01..03}: {tm_id, move, lp, materials:
## [{material_id, qty}], unlock_cond}.
## HONEST DATA STATE: the held sources carry the schema and
## the full SV TM list (230) but NOT the recipe rows, so every
## shipped recipe has lp == null and no materials and is
## flagged recipe_status == "stub_unsourced_costs". Crafting a
## stubbed recipe is REFUSED (reason "recipe_stubbed") — no
## cost is ever invented. A sourced data drop flips the flag
## per recipe and crafting opens with no code change.
## LP seam: LP lives on a plain wallet dict {"lp": int} owned
## by the save state. No staged system awards or spends LP
## today (grep-verified: no LP/league-points code exists in
## the staged project), so lp_add/lp_spend here are the seam;
## the bind wiring is: battle/league reward sites call
## lp_add, the machine UI calls craft. Named in the report.
## Atomicity: craft validates EVERYTHING (recipe known, not
## stubbed, all materials held in full, LP sufficient) before
## consuming anything; consumption itself uses the inventory's
## own all-or-nothing consume_item after the pre-check, so a
## refusal never partially consumes.

const STUB_STATUS := "stub_unsourced_costs"

static func load_registry(path: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}

static func recipe_for(registry: Dictionary, tm_id: String) -> Dictionary:
	var recipes: Array = registry.get("recipes", [])
	for raw in recipes:
		var r: Dictionary = raw
		if str(r.get("tm_id", "")) == tm_id:
			return r
	return {}

static func is_stubbed(recipe: Dictionary) -> bool:
	return recipe.is_empty() or str(recipe.get("recipe_status", "")) == STUB_STATUS or recipe.get("lp") == null

static func material_record(registry: Dictionary, material_id: String) -> Dictionary:
	var mats: Array = registry.get("materials", [])
	for raw in mats:
		var m: Dictionary = raw
		if str(m.get("material_id", "")) == material_id:
			return m
	return {}

## Species a material drops from, as transcribed (item-name
## provenance in the data file). "" when unknown. Drop RATE is
## not held anywhere and is never returned or invented.
static func drop_source_species(registry: Dictionary, material_id: String) -> String:
	var m: Dictionary = material_record(registry, material_id)
	return str(m.get("drop_source_species", ""))

static func can_craft(registry: Dictionary, tm_id: String, inventory: PUWInventoryManager, wallet: Dictionary) -> Dictionary:
	var r: Dictionary = recipe_for(registry, tm_id)
	if r.is_empty():
		return {"ok": false, "reason": "no_recipe"}
	if is_stubbed(r):
		return {"ok": false, "reason": "recipe_stubbed"}
	if inventory == null:
		return {"ok": false, "reason": "no_inventory"}
	var mats: Array = r.get("materials", [])
	for raw in mats:
		var m: Dictionary = raw
		if inventory.count_item(str(m.get("material_id", ""))) < int(m.get("qty", 0)):
			return {"ok": false, "reason": "insufficient_materials", "material": str(m.get("material_id", ""))}
	if int(wallet.get("lp", 0)) < int(r.get("lp", 0)):
		return {"ok": false, "reason": "insufficient_lp"}
	return {"ok": true}

## Atomic craft: on success consumes exactly the recipe's
## materials + LP and grants exactly one TM item; on any
## refusal consumes nothing and grants nothing.
static func craft(registry: Dictionary, tm_id: String, inventory: PUWInventoryManager, wallet: Dictionary, logs: Array) -> Dictionary:
	var check: Dictionary = can_craft(registry, tm_id, inventory, wallet)
	if not bool(check.get("ok", false)):
		return check
	var r: Dictionary = recipe_for(registry, tm_id)
	var mats: Array = r.get("materials", [])
	for raw in mats:
		var m: Dictionary = raw
		inventory.consume_item(str(m.get("material_id", "")), int(m.get("qty", 0)))
	wallet["lp"] = int(wallet.get("lp", 0)) - int(r.get("lp", 0))
	inventory.add_item(tm_id, 1)
	logs.append("Crafted " + tm_id.to_upper() + " (" + str(r.get("move", "")) + ")!")
	return {"ok": true, "tm": tm_id, "move": str(r.get("move", ""))}

# --- LP wallet seam (bind wiring named in the report) ---
static func lp_add(wallet: Dictionary, amount: int) -> int:
	wallet["lp"] = maxi(0, int(wallet.get("lp", 0))) + maxi(0, amount)
	var now: int = int(wallet["lp"])
	return now

static func lp_spend(wallet: Dictionary, amount: int) -> bool:
	if int(wallet.get("lp", 0)) < amount:
		return false
	wallet["lp"] = int(wallet.get("lp", 0)) - amount
	return true

## SV machine->move table for batch 5's teaching service,
## built from this registry (SV-only; per-version separation:
## never merge with another version's table).
static func sv_machine_table(registry: Dictionary) -> Dictionary:
	var table: Dictionary = {}
	var recipes: Array = registry.get("recipes", [])
	for raw in recipes:
		var r: Dictionary = raw
		table[str(r.get("tm_id", ""))] = str(r.get("move", ""))
	return table

## Teach hand-off: delegates to batch 5's teach_machine
## unchanged, with the SV table built above.
static func teach_crafted(mon: Dictionary, tm_id: String, registry: Dictionary, can_learn: Callable, forget_index: int, logs: Array) -> Dictionary:
	return PUWItemServices.teach_machine(mon, tm_id, sv_machine_table(registry), can_learn, forget_index, logs)
