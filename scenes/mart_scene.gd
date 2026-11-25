class_name MartScene
extends Control
## Mart (shop) screen. Root node of mart.tscn.
## Lists the items from complete_item_database.json with a price,
## a Buy button, a Sell button, and your money.
##
## HONEST WARNING ABOUT PRICES: the item database file has NO price
## field on any item. Nothing in the repo gives a real price for
## these items. So this script has a clearly marked placeholder
## price table below (PLACEHOLDER_PRICES). The shop works with it,
## but the numbers are guesses. Replace them with real prices when
## the database gets a "price" field — the code already reads
## item.get("price") first and only falls back to the placeholder
## table when the field is missing.

## Scene to go back to. Default is the Overworld.
static var return_scene_path: String = "res://scenes/overworld.tscn"

const ITEM_DB_PATH: String = "res://systems/inventory/complete_item_database.json"

## PLACEHOLDER PRICES. Not from the database. Standard shop prices
## from the games, used only until real prices exist.
const PLACEHOLDER_PRICES: Dictionary = {
	"poke_ball": 200, "great_ball": 600, "ultra_ball": 1200,
	"quick_ball": 1000, "dusk_ball": 1000, "net_ball": 1000,
	"timer_ball": 1000, "repeat_ball": 1000,
	"potion": 300, "super_potion": 700, "hyper_potion": 1200,
	"max_potion": 2500, "full_restore": 3000,
	"antidote": 100, "paralyze_heal": 200, "burn_heal": 250,
	"awakening": 250, "ice_heal": 250, "full_heal": 600,
	"revive": 1500, "max_revive": 4000,
	"x_attack": 500, "x_defense": 550, "x_speed": 350,
	"thunder_stone": 3000, "fire_stone": 3000, "water_stone": 3000,
	"leaf_stone": 3000, "moon_stone": 3000, "sun_stone": 3000,
	"dusk_stone": 3000, "shiny_stone": 3000, "ice_stone": 3000,
}

@onready var shop_list: ItemList = $MainRow/ShopList
@onready var detail_label: Label = $MainRow/DetailPanel/ItemDetailLabel
@onready var money_label: Label = $MainRow/DetailPanel/MoneyLabel
@onready var message_label: Label = $MainRow/DetailPanel/MessageLabel
@onready var buy_button: Button = $MainRow/DetailPanel/BuyButton
@onready var sell_button: Button = $MainRow/DetailPanel/SellButton
@onready var back_button: Button = $BackButton
@onready var inventory: PUWInventoryManager = $InventoryManager

## Placeholder starting money. Replace with the save file's money
## when a save system hands it over.
var money: int = 3000
var db_items: Array = []
var selected_index: int = -1


func _ready() -> void:
	theme = PUWUiTheme.make_theme()
	_load_item_database()
	_fill_list()
	_refresh_money()
	shop_list.item_selected.connect(_on_item_selected)
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _load_item_database() -> void:
	db_items = []
	if not FileAccess.file_exists(ITEM_DB_PATH):
		message_label.text = "Item database file not found: " + ITEM_DB_PATH
		return
	var file: FileAccess = FileAccess.open(ITEM_DB_PATH, FileAccess.READ)
	if file == null:
		message_label.text = "Could not open the item database file."
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		message_label.text = "Item database file is not in the expected shape."
		return
	var categories: Dictionary = parsed.get("categories", {})
	for category_name in categories.keys():
		var entries: Array = categories[category_name]
		for entry in entries:
			var item: Dictionary = entry.duplicate(true)
			item["category"] = str(category_name)
			db_items.append(item)


func price_of(item: Dictionary) -> int:
	if item.has("price"):
		return int(item.get("price", 0))
	var item_id: String = str(item.get("id", ""))
	if PLACEHOLDER_PRICES.has(item_id):
		return int(PLACEHOLDER_PRICES[item_id])
	return 0


func _held_qty(item_id: String) -> int:
	if inventory.items.has(item_id):
		var held: Dictionary = inventory.items[item_id]
		return int(held.get("qty", 0))
	return 0


func _fill_list() -> void:
	shop_list.clear()
	for item in db_items:
		var item_id: String = str(item.get("id", ""))
		var line: String = str(item.get("name", item_id))
		line += "  -  " + str(price_of(item)) + " coins"
		line += "  (held x" + str(_held_qty(item_id)) + ")"
		shop_list.add_item(line)


func _refresh_money() -> void:
	money_label.text = "Money: " + str(money) + " coins"


func _on_item_selected(index: int) -> void:
	selected_index = index
	if index < 0 or index >= db_items.size():
		return
	var item: Dictionary = db_items[index]
	var item_id: String = str(item.get("id", ""))
	var text: String = str(item.get("name", ""))
	text += "\nCategory: " + str(item.get("category", ""))
	text += "\nPrice: " + str(price_of(item)) + " coins"
	text += "\nSell price: " + str(price_of(item) / 2) + " coins"
	text += "\nHeld: x" + str(_held_qty(item_id))
	text += "\n" + str(item.get("effect", ""))
	detail_label.text = text
	buy_button.disabled = money < price_of(item) or price_of(item) <= 0
	sell_button.disabled = _held_qty(item_id) <= 0


func _on_buy_pressed() -> void:
	if selected_index < 0 or selected_index >= db_items.size():
		message_label.text = "Pick an item first."
		return
	var item: Dictionary = db_items[selected_index]
	var price: int = price_of(item)
	if price <= 0:
		message_label.text = "This item has no price yet, so it cannot be bought."
		return
	if money < price:
		message_label.text = "Not enough money."
		return
	money -= price
	var item_id: String = str(item.get("id", ""))
	if inventory.items.has(item_id):
		var held: Dictionary = inventory.items[item_id]
		held["qty"] = int(held.get("qty", 0)) + 1
	else:
		inventory.items[item_id] = {
			"id": item_id, "name": str(item.get("name", item_id)),
			"category": str(item.get("category", "")), "qty": 1,
			"free_supply": false, "fav": false,
		}
	message_label.text = "Bought 1 " + str(item.get("name", item_id)) + "."
	_fill_list()
	_refresh_money()
	_on_item_selected(selected_index)


func _on_sell_pressed() -> void:
	if selected_index < 0 or selected_index >= db_items.size():
		message_label.text = "Pick an item first."
		return
	var item: Dictionary = db_items[selected_index]
	var item_id: String = str(item.get("id", ""))
	if _held_qty(item_id) <= 0:
		message_label.text = "You do not hold any " + str(item.get("name", item_id)) + "."
		return
	var sell_price: int = price_of(item) / 2
	money += sell_price
	var held: Dictionary = inventory.items[item_id]
	held["qty"] = int(held.get("qty", 0)) - 1
	message_label.text = "Sold 1 " + str(item.get("name", item_id)) + " for " + str(sell_price) + " coins."
	_fill_list()
	_refresh_money()
	_on_item_selected(selected_index)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(return_scene_path)
