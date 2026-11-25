class_name BagScene
extends Control
## Bag screen. Root node of bag.tscn.
## Shows every item from complete_item_database.json in an ItemList.
## How many of each item you hold comes from PUWInventoryManager
## (the manager starts with a small stock: Poke Balls, Potions and
## a Town Map). Items you hold 0 of are shown but cannot be used.
## Use calls ItemEngine.use_battle_item on target_mon. Set
## BagScene.target_mon and BagScene.return_scene_path before you
## open this scene; the Battle scene does this for you.

## The Pokemon the used item is applied to. Set by the caller.
static var target_mon: Dictionary = {}
## Scene to go back to. Default is the Overworld.
static var return_scene_path: String = "res://scenes/overworld.tscn"
## Use context for ItemEngine.use_battle_item's context items
## (binding build 4, code_prep_items merge step 3a). Callers
## supply what they hold — "party", "badges",
## "species_abilities", "hidden_ability", "move" — and the bag
## passes it through; an item whose context is missing refuses
## cleanly inside the engine and changes nothing. The Battle
## scene supplies "party" (see BattleScene._on_bag_pressed).
static var use_context: Dictionary = {}
## The caller's save state, read only for the Tera Shard route
## gate (PUWGimmickUnlocks). Empty means every gimmick flag is
## locked, so the route stays closed until a state-bearing
## caller sets this.
static var save_state: Dictionary = {}

const ITEM_DB_PATH: String = "res://systems/inventory/complete_item_database.json"

@onready var item_list: ItemList = $MainRow/ItemList
@onready var detail_label: Label = $MainRow/DetailPanel/ItemDetailLabel
@onready var message_label: Label = $MainRow/DetailPanel/MessageLabel
@onready var use_button: Button = $MainRow/DetailPanel/UseButton
@onready var back_button: Button = $BackButton
@onready var bag_panel: EmptyStartBagController = $BagPanel
@onready var inventory: PUWInventoryManager = $InventoryManager

var db_items: Array = []
var selected_index: int = -1


func _ready() -> void:
	theme = PUWUiTheme.make_theme()
	bag_panel.open_panel()
	_load_item_database()
	_fill_list()
	item_list.item_selected.connect(_on_item_selected)
	use_button.pressed.connect(_on_use_pressed)
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


func _fill_list() -> void:
	item_list.clear()
	for item in db_items:
		var item_id: String = str(item.get("id", ""))
		var qty: int = _held_qty(item_id)
		var line: String = str(item.get("name", item_id)) + "  x" + str(qty)
		if qty <= 0:
			line += "  (not held)"
		item_list.add_item(line)


func _held_qty(item_id: String) -> int:
	if inventory.items.has(item_id):
		var held: Dictionary = inventory.items[item_id]
		return int(held.get("qty", 0))
	return 0


func _on_item_selected(index: int) -> void:
	selected_index = index
	if index < 0 or index >= db_items.size():
		return
	var item: Dictionary = db_items[index]
	var text: String = str(item.get("name", ""))
	text += "\nCategory: " + str(item.get("category", ""))
	text += "\nHeld: x" + str(_held_qty(str(item.get("id", ""))))
	text += "\n" + str(item.get("effect", ""))
	detail_label.text = text
	use_button.disabled = _held_qty(str(item.get("id", ""))) <= 0


func _on_use_pressed() -> void:
	if selected_index < 0 or selected_index >= db_items.size():
		message_label.text = "Pick an item first."
		return
	var item: Dictionary = db_items[selected_index]
	var item_id: String = str(item.get("id", ""))
	if _held_qty(item_id) <= 0:
		message_label.text = "You do not hold any " + str(item.get("name", item_id)) + "."
		return
	if target_mon.is_empty():
		message_label.text = "No Pokemon is selected to use this on. Open the Bag from battle."
		return
	var logs: Array = []
	# Tera Shards route to use_tera_shard (they cost 50, not 1),
	# gated on the Terastallization unlock flag (code_prep_items
	# merge step 3a). The engine consumes the shards itself
	# through the inventory manager, so this path returns before
	# the single-item decrement below.
	if ItemEngine.tera_type_for_shard(item_id) != "":
		var flags: Dictionary = PUWGimmickUnlocks.read_flags(save_state)
		if not bool(flags.get("terastallization", false)):
			message_label.text = "Terastallization is not unlocked yet."
			return
		if not ItemEngine.use_tera_shard(item_id, target_mon, inventory, logs):
			message_label.text = "It will not have any effect here."
			for line in logs:
				message_label.text += "\n" + str(line)
			return
		message_label.text = "Used " + str(item.get("name", item_id)) + "."
		for line in logs:
			message_label.text += "\n" + str(line)
		_fill_list()
		_on_item_selected(selected_index)
		return
	# Ordinary items: pass the caller's use context through to
	# the engine (merge step 3a); growth_rate is derived from
	# the target when the caller did not supply it.
	var context: Dictionary = use_context.duplicate(true)
	if not context.has("growth_rate") and target_mon.has("growth_rate"):
		context["growth_rate"] = target_mon.get("growth_rate")
	var used: bool = ItemEngine.use_battle_item(item_id, target_mon, logs, context)
	if not used:
		message_label.text = "It will not have any effect here."
		for line in logs:
			message_label.text += "\n" + str(line)
		return
	# Take one out of the bag.
	var held: Dictionary = inventory.items[item_id]
	held["qty"] = int(held.get("qty", 1)) - 1
	for line in logs:
		message_label.text += "\n" + str(line)
	message_label.text = "Used " + str(item.get("name", item_id)) + "."
	_fill_list()
	_on_item_selected(selected_index)


func _on_back_pressed() -> void:
	bag_panel.close_panel()
	get_tree().change_scene_to_file(return_scene_path)
