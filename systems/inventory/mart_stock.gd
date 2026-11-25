class_name PUWMartStock
extends RefCounted
## Per-mart stock (code_prep_kanto_item_fixes, fix F6).
##
## The bound tree had NO per-mart inventory data: MartShop's only
## rule was "sellable iff items_full_compact cost > 0", so every
## shop effectively listed the whole 1,515-item catalogue.
## res://data/mart_stock.json now carries each mart's own stock,
## extracted from held source — pokered data/items/marts.asm
## script_mart clerk lists for Kanto, pokefirered *_Mart_Items
## lists for the Sevii marts — and this loader resolves every
## source constant through PUWItemResolve (the one resolution
## path, Gen-1 TM table included: Celadon 2F's second clerk sells
## TM_<MOVE> constants) and prices through the compact data under
## MartShop.load_prices' exact rule (cost > 0, keyed canonically).
##
## Prices are NEVER taken from this file or invented: a stock
## item with no compact price reports price 0 and is named in
## the result's "unpriced" list. Maps whose source has no clerk
## mart (Celadon 1F receptionist, Celadon 3F's TM18 script-give
## clerk, the elevator) return empty stock with the cause in
## "note" — the honest fallback stays visible. Celadon Roof's
## vending machines are reported under "vending" (with their
## source prices kept as source data), not as clerk stock.

const STOCK_PATH: String = "res://data/mart_stock.json"
const ITEMS_PATH: String = "res://data/items_full_compact.json"

static var _stock_data: Dictionary = {}
static var _stock_loaded: bool = false
static var _prices: Dictionary = {}
static var _prices_loaded: bool = false


static func _ensure_stock() -> void:
	if _stock_loaded:
		return
	_stock_loaded = true
	_stock_data = {}
	if not FileAccess.file_exists(STOCK_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STOCK_PATH))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var maps_value: Variant = data.get("maps", {})
		if maps_value is Dictionary:
			_stock_data = maps_value


## Canonical id -> buy price, built exactly as MartShop
## .load_prices builds its table (compact rows with cost > 0),
## keyed by canonical id so any spelling of a stock item finds
## its price.
static func _ensure_prices() -> void:
	if _prices_loaded:
		return
	_prices_loaded = true
	_prices = {}
	if not FileAccess.file_exists(ITEMS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	var items_value: Variant = data.get("items", [])
	if items_value is Array:
		var items: Array = items_value
		for entry_value in items:
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value
			var slug: String = str(entry.get("slug", ""))
			var cost_value: Variant = entry.get("cost", 0)
			if slug == "" or cost_value == null:
				continue
			var cost: int = int(cost_value)
			if cost <= 0:
				continue
			_prices[PUWItemRegistry.canonical_id_for(slug)] = cost


## The bound buy price of one canonical item (0 = not priced in
## the compact data, hence not sellable under MartShop's rule).
static func price_for(canonical: String) -> int:
	_ensure_prices()
	return int(_prices.get(canonical, 0))


static func _resolve_list(consts: Array) -> Dictionary:
	var items: Array = []
	var unresolved: Array = []
	for const_value in consts:
		var const_name: String = str(const_value)
		var canonical: String = PUWItemResolve.resolve_const(const_name)
		if canonical == "":
			unresolved.append(const_name)
		elif not items.has(canonical):
			items.append(canonical)
	return {"items": items, "unresolved": unresolved}


## One mart's stock:
## {map, found, clerks: [{clerk, items, unresolved}], stock
## (canonical union in first-seen order), unpriced (stock items
## with no compact price), vending, vending_source_prices,
## source, note}
static func stock_for_map(map_name: String) -> Dictionary:
	_ensure_stock()
	_ensure_prices()
	var record_value: Variant = _stock_data.get(map_name, {})
	if not (record_value is Dictionary):
		return {"map": map_name, "found": false, "clerks": [], "stock": [],
			"unpriced": [], "vending": [], "vending_source_prices": {},
			"source": "", "note": "no stock record"}
	var record: Dictionary = record_value
	var clerks: Array = []
	var stock: Array = []
	var clerks_value: Variant = record.get("clerks", [])
	if clerks_value is Array:
		var clerk_rows: Array = clerks_value
		for clerk_value in clerk_rows:
			if not (clerk_value is Dictionary):
				continue
			var clerk: Dictionary = clerk_value
			var consts_value: Variant = clerk.get("items_const", [])
			var consts: Array = consts_value if consts_value is Array else []
			var resolved: Dictionary = _resolve_list(consts)
			clerks.append({"clerk": str(clerk.get("clerk", "")),
				"items": resolved["items"], "unresolved": resolved["unresolved"]})
			var resolved_items: Array = resolved["items"]
			for item_value in resolved_items:
				var item: String = str(item_value)
				if not stock.has(item):
					stock.append(item)
	var unpriced: Array = []
	for item_value in stock:
		var item: String = str(item_value)
		if price_for(item) <= 0:
			unpriced.append(item)
	var vending: Array = []
	var vending_value: Variant = record.get("vending_const", [])
	if vending_value is Array:
		var vending_consts: Array = vending_value
		vending = _resolve_list(vending_consts)["items"]
	var vending_prices_value: Variant = record.get("vending_source_prices", {})
	var vending_prices: Dictionary = vending_prices_value if vending_prices_value is Dictionary else {}
	return {"map": map_name, "found": true, "clerks": clerks, "stock": stock,
		"unpriced": unpriced, "vending": vending,
		"vending_source_prices": vending_prices,
		"source": str(record.get("source", "")), "note": str(record.get("note", ""))}


## Every map with a stock record (the 19 audit mart maps plus
## IndigoPlateauLobby, whose source clerk the audit's name-based
## census did not count).
static func mart_maps() -> Array:
	_ensure_stock()
	var names: Array = _stock_data.keys()
	names.sort()
	return names
