class_name PUWStateBagInventory
extends PUWInventoryManager
## State-bag inventory adapter (code prep
## code_prep_item_engine_gaps, closing gap G3 of
## code_prep_item_target/PREP_REPORT.md).
##
## PUWItemServices (hyper_train / relearn_move) and
## ItemEngine.use_tera_shard were written against
## PUWInventoryManager — a Node that keeps its OWN items
## dictionary, demo-seeded with 20 Poké Balls, 15 Potions and
## friends. Nothing connected that dictionary to the save:
## services run against it trained, taught and charged a demo
## inventory the player never sees.
##
## This adapter IS a PUWInventoryManager (so every bound
## service signature accepts it unchanged) whose counts live
## in the real bag: the state["bag"] dictionary of a
## PUWSaveManager state, read and written through PUWLiveBag
## (code_prep_live_bag), the one bridge that owns the state's
## id dialect — an item's two spellings are one stack, zero
## counts are erased, new stacks are created under the
## canonical id.
##
## The base class's demo seed is discarded in _init and the
## inherited items dictionary is never read or written by any
## override: there is no demo inventory anywhere in this
## class's path. get_by_category is rebuilt from the live
## state's holdings in the base class's entry shape.

var _state: Dictionary = {}


func _init(state: Dictionary = {}) -> void:
	_state = state
	items = {}


## Re-point the adapter at another state dict (e.g. after a
## load). The counts follow the new state's bag immediately.
func bind_state(state: Dictionary) -> void:
	_state = state


## How many of an item the STATE holds (0 when absent).
func count_item(item_id: String) -> int:
	return PUWLiveBag.count_in_state(_state, item_id)


## Add qty of an item to the state bag. Returns the new total.
func add_item(item_id: String, qty: int) -> int:
	return PUWLiveBag.grant_to_state(_state, item_id, qty)


## Take qty of an item out of the state bag. Returns false and
## changes nothing when the total held is short.
func consume_item(item_id: String, qty: int = 1) -> bool:
	return PUWLiveBag.consume_from_state(_state, item_id, qty)


## The base class's category listing, served from the live
## state: one entry per held item whose REGISTRY category is
## the requested one, in the base class's entry shape.
func get_by_category(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row_value in PUWLiveBag.holdings_for_screen(_state):
		var row: Dictionary = row_value
		var slug: String = str(row.get("slug", ""))
		var entry: Dictionary = PUWItemRegistry.get_entry(slug)
		if str(entry.get("category", "")) != category:
			continue
		out.append({
			"id": slug,
			"name": str(entry.get("name", slug)),
			"category": category,
			"qty": int(row.get("qty", 0)),
			"free_supply": false,
			"fav": false,
		})
	return out
