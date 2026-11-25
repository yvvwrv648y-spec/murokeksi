class_name PUWInventoryManager
extends Node
## Section 14: 11-category modern inventory with search, sort, favourites, and free standard training supplies.

const CATEGORIES: PackedStringArray = [
	"medicine", "poke_balls", "battle_items", "berries", "key_items",
	"evolution_items", "held_items", "technical_items", "collectibles", "materials", "supplies"
]

var items: Dictionary = {
	"poke_ball": {"id": "poke_ball", "name": "Poké Ball", "category": "poke_balls", "qty": 20, "free_supply": true, "fav": true},
	"great_ball": {"id": "great_ball", "name": "Great Ball", "category": "poke_balls", "qty": 10, "free_supply": true, "fav": false},
	"potion": {"id": "potion", "name": "Potion", "category": "medicine", "qty": 15, "free_supply": true, "fav": true},
	"oran_berry": {"id": "oran_berry", "name": "Oran Berry", "category": "berries", "qty": 8, "free_supply": false, "fav": false},
	"town_map": {"id": "town_map", "name": "Kanto Town Map", "category": "key_items", "qty": 1, "free_supply": false, "fav": true}
}

## Canonical bag API (item-integrity pass, Riley 2026-11-23):
## same contract as MartShop's — ids resolve through
## PUWItemRegistry, so two source spellings of one item share
## ONE entry here too. Existing entries and get_by_category are
## unchanged.

## How many of an item are held (0 when absent).
func count_item(item_id: String) -> int:
	var key: String = PUWItemRegistry.canonical_id_for(item_id)
	if items.has(key):
		var held: Dictionary = items[key]
		return int(held.get("qty", 0))
	return 0

## Add qty of an item, creating the entry from the registry
## (name/category) when it is not held yet. Returns the new qty.
func add_item(item_id: String, qty: int) -> int:
	if qty < 1:
		return count_item(item_id)
	var key: String = PUWItemRegistry.canonical_id_for(item_id)
	if items.has(key):
		var held: Dictionary = items[key]
		held["qty"] = int(held.get("qty", 0)) + qty
		items[key] = held
		return int(held.get("qty", 0))
	var entry: Dictionary = PUWItemRegistry.get_entry(key)
	var created: Dictionary = {
		"id": key,
		"name": str(entry.get("name", key)),
		"category": str(entry.get("category", "supplies")),
		"qty": qty, "free_supply": false, "fav": false,
	}
	items[key] = created
	return qty

## Take qty of an item out. Returns false and changes nothing
## when fewer than qty are held; the entry is removed at 0.
func consume_item(item_id: String, qty: int = 1) -> bool:
	if qty < 1:
		return false
	var key: String = PUWItemRegistry.canonical_id_for(item_id)
	if count_item(item_id) < qty:
		return false
	var held: Dictionary = items[key]
	var left: int = int(held.get("qty", 0)) - qty
	if left <= 0:
		items.erase(key)
	else:
		held["qty"] = left
		items[key] = held
	return true


func get_by_category(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in items.keys():
		var it: Dictionary = items[k]
		if str(it.get("category", "")) == category:
			out.append(it)
	return out
