class_name MartShop
extends Node
## Poke Mart shop logic for Pokemon Ultimate World, battle engine v4.
## Plain rules, no made-up numbers. Buy prices come from the items
## file (items_full_compact.json): only items with a cost above 0 are
## sold in shops. An item with cost 0 (key items, Master Ball) is
## never sold. Sell-back is half the buy price, rounded down, which
## is the rule the standard games use.
##
## money is the trainer's money. bag maps an item slug to how many
## the trainer owns. prices maps an item slug to its buy price.

const MAX_STACK: int = 999
const MAX_SLOTS: int = 999

var money: int = 0
var bag: Dictionary = {}
var prices: Dictionary = {}
var names: Dictionary = {}
## Free supply trainers (data/supply_trainers.json): trainer id ->
## {"name": String, "role": String, "stock": Array of slugs,
## "claim_counts": Dictionary slug -> how many one claim gives}.
var supply_trainers: Dictionary = {}


## ------------------------------------------------------------------
## Canonical bag API (item-integrity pass, Riley 2026-11-23).
## The bag keys on the CANONICAL item id from PUWItemRegistry:
## granting the same item through two different source spellings
## or source rows (for example "poke-ball" and its Let's Go source
## row "lapoke-ball") lands in ONE stack with the quantities
## summed — the same item can never sit in the bag twice.
## buy/sell/claim below also store under the canonical key; for
## ordinary slugs the canonical id IS the slug, so their behaviour
## is unchanged. Followers call add_item / count_item /
## consume_item (and may still write bag[slug] directly, which
## count_item and consume_item account for by summing every bag
## key that resolves to the same canonical id).
## ------------------------------------------------------------------

## The canonical registry id for any source spelling of an item.
func canonical_id(item_id: String) -> String:
	return PUWItemRegistry.canonical_id_for(item_id)

## How many of an item the bag holds, summed across the canonical
## stack and any legacy/variant keys that resolve to the same
## canonical item.
func count_item(item_id: String) -> int:
	var target: String = canonical_id(item_id)
	var total: int = 0
	for key_value in bag.keys():
		var key: String = str(key_value)
		if canonical_id(key) == target:
			total += int(bag[key_value])
	return total

## Add qty of an item to the bag under its canonical id. Returns
## the usual result dict. Refused (nothing changes) past
## MAX_STACK for the stack or MAX_SLOTS distinct stacks.
func add_item(item_id: String, qty: int) -> Dictionary:
	if qty < 1:
		return _result(false, "", "You need to add at least 1.")
	var key: String = canonical_id(item_id)
	var owned: int = int(bag.get(key, 0))
	if owned + qty > MAX_STACK:
		return _result(false, "", "You can only carry " + str(MAX_STACK) + " of one item.")
	if not bag.has(key) and count_item(item_id) <= 0 and bag.size() >= MAX_SLOTS:
		return _result(false, "", "Your bag is full.")
	bag[key] = owned + qty
	var line: String = "Added " + str(qty) + " " + display_name(key) + " to the bag."
	return _result(true, line, "")

## Take qty of an item out of the bag. Consumes the canonical
## stack first, then any variant keys for the same canonical
## item. Returns false and changes nothing when the bag holds
## fewer than qty in total.
func consume_item(item_id: String, qty: int = 1) -> bool:
	if qty < 1:
		return false
	if count_item(item_id) < qty:
		return false
	var target: String = canonical_id(item_id)
	var remaining: int = qty
	var ordered_keys: Array = []
	if bag.has(target):
		ordered_keys.append(target)
	for key_value in bag.keys():
		var key: String = str(key_value)
		if key != target and canonical_id(key) == target:
			ordered_keys.append(key)
	for key_value in ordered_keys:
		if remaining <= 0:
			break
		var key: String = str(key_value)
		var have: int = int(bag.get(key, 0))
		var take: int = mini(have, remaining)
		if take <= 0:
			continue
		if have - take <= 0:
			bag.erase(key)
		else:
			bag[key] = have - take
		remaining -= take
	return remaining <= 0


## Sell-back price for one item: half the buy price, rounded down.
## Returns 0 when the buy price is 0 or less (the item is not sold).
static func sell_price(buy_price: int) -> int:
	if buy_price <= 0:
		return 0
	return buy_price / 2


## A plain readable name for an item slug, e.g. "poke-ball" becomes
## "Poke Ball". Uses the display name when one was loaded, else
## builds it from the slug.
func display_name(item_id: String) -> String:
	if names.has(item_id):
		return str(names[item_id])
	var parts: Array = item_id.split("-")
	var words: Array = []
	for part in parts:
		var word: String = str(part)
		if word == "":
			continue
		words.append(word.capitalize())
	return " ".join(words)


## Load buy prices from item dicts with "slug" and "cost". Only items
## with a cost above 0 are loaded (cost 0 means not sold in shops).
## A "display_name" on a dict is kept for log lines when present.
## Returns how many items were loaded.
func load_prices(items: Array) -> int:
	var count: int = 0
	for entry in items:
		if not (entry is Dictionary):
			continue
		var item: Dictionary = entry
		var slug: String = str(item.get("slug", ""))
		if slug == "":
			continue
		var cost_value = item.get("cost", 0)
		if cost_value == null:
			continue
		var cost: int = int(cost_value)
		if cost <= 0:
			continue
		prices[slug] = cost
		var shown: String = str(item.get("display_name", ""))
		if shown != "":
			names[slug] = shown
		count += 1
	return count


## True when the shop sells the item, the amount is at least 1, and
## the trainer has enough money for the whole amount.
func can_afford(item_id: String, qty: int) -> bool:
	if qty < 1:
		return false
	if not prices.has(item_id):
		return false
	var price: int = int(prices[item_id])
	return money >= price * qty


## Build the result dict every buy and sell returns. bag is a copy,
## so changing the returned dict never changes the shop's own bag.
func _result(ok: bool, log: String, reason: String) -> Dictionary:
	return {"ok": ok, "money": money, "bag": bag.duplicate(), "log": log, "reason": reason}


## Buy qty of an item. On success the money is taken and the items
## go in the bag. On failure nothing changes and reason says why
## in plain English.
func buy(item_id: String, qty: int) -> Dictionary:
	if qty < 1:
		return _result(false, "", "You need to buy at least 1.")
	if not prices.has(item_id):
		return _result(false, "", "That item is not sold here.")
	var price: int = int(prices[item_id])
	var total: int = price * qty
	var bag_key: String = canonical_id(item_id)
	var owned: int = int(bag.get(bag_key, 0))
	if owned + qty > MAX_STACK:
		return _result(false, "", "You can only carry " + str(MAX_STACK) + " of one item.")
	if not bag.has(bag_key) and bag.size() >= MAX_SLOTS:
		return _result(false, "", "Your bag is full.")
	if money < total:
		return _result(false, "", "You don't have enough money for that.")
	money -= total
	bag[bag_key] = owned + qty
	var line: String = "Bought " + str(qty) + " " + display_name(item_id) + " for " + str(total) + ". Money left: " + str(money) + "."
	return _result(true, line, "")


## Load the free supply trainers from a parsed supply_trainers.json
## Dictionary (a "trainers" list of {id, name, role, stock,
## claim_counts}). Returns how many trainers were loaded.
func load_supply_trainers(data: Dictionary) -> int:
	var count: int = 0
	var trainers_value: Variant = data.get("trainers", [])
	if not (trainers_value is Array):
		return 0
	var trainers: Array = trainers_value
	for entry in trainers:
		if not (entry is Dictionary):
			continue
		var trainer: Dictionary = entry
		var trainer_id: String = str(trainer.get("id", ""))
		if trainer_id == "":
			continue
		var stock: Array = []
		var stock_value: Variant = trainer.get("stock", [])
		if stock_value is Array:
			var raw_stock: Array = stock_value
			for raw_slug in raw_stock:
				var slug: String = str(raw_slug)
				if slug != "" and not stock.has(slug):
					stock.append(slug)
		var claim_counts: Dictionary = {}
		var counts_value: Variant = trainer.get("claim_counts", {})
		if counts_value is Dictionary:
			var raw_counts: Dictionary = counts_value
			for slug_key in raw_counts.keys():
				claim_counts[str(slug_key)] = int(raw_counts[slug_key])
		supply_trainers[trainer_id] = {
			"name": str(trainer.get("name", "")),
			"role": str(trainer.get("role", "")),
			"stock": stock,
			"claim_counts": claim_counts,
		}
		count += 1
	return count


## Load the free supply trainers straight from a JSON file path.
## Returns how many trainers were loaded (0 when the file is
## missing or does not parse).
func load_supply_trainers_file(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return 0
	var data: Dictionary = parsed
	return load_supply_trainers(data)


## True when the trainer exists and stocks the item.
func trainer_stocks(trainer_id: String, item_id: String) -> bool:
	if not supply_trainers.has(trainer_id):
		return false
	var trainer: Dictionary = supply_trainers[trainer_id]
	var stock_value: Variant = trainer.get("stock", [])
	if stock_value is Array:
		var stock: Array = stock_value
		return stock.has(item_id)
	return false


## Claim a free item from a supply trainer. Ordinary supplies and
## lawful healing are FREE in every starting settlement, so a
## claim costs 0 and never touches money. Claims are infinite:
## the same item can be claimed again and again. One claim gives
## 1 of the item, or the trainer's claim_counts amount for it
## (Tera Shards from Vance give 50). The result is the usual buy
## result dict plus "cost" (always 0), "qty", "trainer_id" and
## "item". Claiming an item the trainer does not stock, or from
## a trainer that does not exist, is refused and changes nothing.
func claim(trainer_id: String, item_id: String) -> Dictionary:
	if not supply_trainers.has(trainer_id):
		return _claim_result(false, "", "That supply trainer does not exist.", trainer_id, item_id, 0)
	var trainer: Dictionary = supply_trainers[trainer_id]
	if not trainer_stocks(trainer_id, item_id):
		return _claim_result(false, "", "That item is not in this trainer's free stock.", trainer_id, item_id, 0)
	var qty: int = 1
	var counts_value: Variant = trainer.get("claim_counts", {})
	if counts_value is Dictionary:
		var counts: Dictionary = counts_value
		if counts.has(item_id):
			qty = maxi(1, int(counts[item_id]))
	var bag_key: String = canonical_id(item_id)
	var owned: int = int(bag.get(bag_key, 0))
	if owned + qty > MAX_STACK:
		return _claim_result(false, "", "You can only carry " + str(MAX_STACK) + " of one item.", trainer_id, item_id, 0)
	if not bag.has(bag_key) and bag.size() >= MAX_SLOTS:
		return _claim_result(false, "", "Your bag is full.", trainer_id, item_id, 0)
	bag[bag_key] = owned + qty
	var trainer_name: String = str(trainer.get("name", trainer_id))
	var line: String = "Claimed " + str(qty) + " " + display_name(item_id) + " free from " + trainer_name + "."
	return _claim_result(true, line, "", trainer_id, item_id, qty)


## The result dict for a claim: the usual shop result plus the
## free-claim fields.
func _claim_result(ok: bool, log: String, reason: String, trainer_id: String, item_id: String, qty: int) -> Dictionary:
	var result: Dictionary = _result(ok, log, reason)
	result["cost"] = 0
	result["qty"] = qty
	result["trainer_id"] = trainer_id
	result["item"] = item_id
	return result


## Sell qty of an item from the bag. Pays half the buy price per
## item, rounded down. On failure nothing changes and reason says
## why in plain English. Items with no buy price cannot be sold.
func sell(item_id: String, qty: int) -> Dictionary:
	if qty < 1:
		return _result(false, "", "You need to sell at least 1.")
	var bag_key: String = canonical_id(item_id)
	if not bag.has(bag_key):
		return _result(false, "", "You don't have any of that item.")
	var owned: int = int(bag[bag_key])
	if qty > owned:
		return _result(false, "", "You only have " + str(owned) + " of that item.")
	if not prices.has(item_id):
		return _result(false, "", "That item can't be sold here.")
	var price: int = int(prices[item_id])
	var gained: int = sell_price(price) * qty
	money += gained
	if owned - qty <= 0:
		bag.erase(bag_key)
	else:
		bag[bag_key] = owned - qty
	var line: String = "Sold " + str(qty) + " " + display_name(item_id) + " for " + str(gained) + "."
	return _result(true, line, "")
