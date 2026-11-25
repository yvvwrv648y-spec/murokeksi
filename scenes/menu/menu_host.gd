class_name PUWMenuHost
extends CanvasLayer
## The missing host for the BW2 menu stack (code_prep_input_menus),
## EXTENDED by the ui_screens production: this file is the input
## prep's host verbatim plus the six screens that prep named as
## unbuilt (its §6 item 7) — Pokédex, options, trainer card,
## storage, quest board, VEXA entry. Build 6 takes THIS version
## of the host; every addition is marked "ui_screens:" and the
## original routing is untouched. Build 7 adds the three field
## pick panels (fossil pick, ferry menu, elevator floor-select)
## for build 6 remainder 5; those additions are marked
## "build6_remainders:".
##
## The bound tree ships BW2MenuStack + four finished stack screens
## (X-menu, party, bag, mart) and NO host: nothing instantiated the
## stack, registered a panel, or routed a single signal, so the
## whole BW2 menu was unreachable in play. This host is the glue
## build 6 adds to the real map scene:
##
##   var host := PUWMenuHost.new()
##   add_child(host)            # builds stack + screens in _ready
##   host.save_requested.connect(...)   # bind the real save flow
##   host.bind_state(state)     # ui_screens: forward the save state
##
## Routing contract — everything a screen emits lands somewhere:
##   X-menu party/bag  -> push the real stack panels.
##   X-menu save       -> save_requested (the host does NOT fake a
##                        save; build 6 binds PUWSaveManager).
##   X-menu dex        -> ui_screens: push the Pokédex panel.
##   X-menu settings   -> ui_screens: push the options panel.
##   X-menu map/challenge -> unbuilt_entry(id): no stack panel
##                        exists for these anywhere in the tree,
##                        so the host says so instead of pushing a
##                        dead screen (same honesty rule as
##                        MainScene.menu_target's not_yet_built).
##   Field entries (ui_screens): open_trainer_card(),
##   open_storage(), open_vexa() push their panels the way
##   open_mart() does; open_quest_board(board_id, context)
##   binds the board first. The VEXA screen's
##   simulation_requested is re-emitted as
##   vexa_simulation_requested — the host does not run the
##   simulation (the simulator needs the battle scene as its
##   scene-tree host; build 6 binds the battle flow).
##   party/bag action_chosen and every close_requested are
##                        re-emitted / popped here; the bag's
##                        actions bind to the live-bag bridge
##                        (code_prep_live_bag) at build 6.
## Input: the stack itself already owns B / X / Escape / ui_cancel
## (open + pop). This host adds Start (puw_menu) on the same path,
## and forwards its open_from_touch() for the on-screen button.
##
## audio_buses (code_prep_audio_buses): the host also owns the
## Pokédex cry player — the audio wiring prep's PokemonCryPlayer
## — created in _ready and bound to the dex screen through its
## bind_cry_player hook (the ui_screens production's named
## bind-time seam #1). The player is flagged local_only: a dex
## lookup resolves the bound local cry files and never starts
## a download. Its player rides the "Cries" bus from
## default_bus_layout.tres.

signal save_requested
signal unbuilt_entry(entry_id: String)
signal party_action_chosen(action_id: String, slot: int)
signal bag_action_chosen(action_id: String, item_slug: String)
# build6_remainders (build 6 remainder 5): the three pick-UI
# answers, re-emitted for the game host, which owns the seams
# behind them (run_fossil_choice / run_ferry / change_map).
signal fossil_chosen(pick: String)
signal ferry_chosen(origin: String, dest: String)
signal floor_chosen(map_name: String, warp_id: int)
# ui_screens: the VEXA entry screen's request, re-emitted for
# the battle flow build 6 binds.
signal vexa_simulation_requested(options: Dictionary)

var stack: BW2MenuStack = null
var xmenu: PUWXMenuScreen = null
var party_screen: PUWPartyScreen = null
var bag_screen: PUWBagScreen = null
var mart_screen: PUWMartScreen = null
# ui_screens: the six screens this production adds.
var pokedex_screen: PUWPokedexScreen = null
var options_screen: PUWOptionsScreen = null
var trainer_card_screen: PUWTrainerCardScreen = null
var storage_screen: PUWStorageScreen = null
var quest_board_screen: PUWQuestBoardScreen = null
var vexa_screen: PUWVexaScreen = null
# audio_buses: the Pokédex cry player (see the header note).
var cry_player: PokemonCryPlayer = null

# pp_max (A-43): the party picker + move picker chain the bag's
# target flow drives; registered as third panel "move_picker".
var party_picker_screen: PUWPartyPickerScreen = null
var move_picker_screen: PUWMovePickerScreen = null
# build6_remainders (remainder 5): the field pick panels —
# fossil pick, ferry destination menu, elevator floor-select.
# Unlike the X-menu panels these open from the field (the
# game host's story hand-offs / elevator bg_events), so their
# open_* entries push ONLY the pick panel, never the xmenu.
var fossil_pick_screen: PUWFossilPickScreen = null
var ferry_menu_screen: PUWFerryMenuScreen = null
var elevator_floor_screen: PUWElevatorFloorScreen = null
var _pending_target: Dictionary = {"action": "", "slug": "", "slot": -1}
# A-49: the map the menu is bound on (game host sets it); the
# mart opens with that map's stock when the lane holds one.
var _current_map: String = ""

var _state: Dictionary = {}


func _ready() -> void:
	stack = BW2MenuStack.new()
	stack.name = "BW2MenuStack"
	add_child(stack)
	xmenu = PUWXMenuScreen.new()
	xmenu.name = "XMenuScreen"
	stack.add_child(xmenu)
	party_screen = PUWPartyScreen.new()
	party_screen.name = "PartyScreen"
	stack.add_child(party_screen)
	bag_screen = PUWBagScreen.new()
	bag_screen.name = "BagScreen"
	stack.add_child(bag_screen)
	mart_screen = PUWMartScreen.new()
	mart_screen.name = "MartScreen"
	stack.add_child(mart_screen)
	stack.register_panel("xmenu", xmenu)
	stack.register_panel("party", party_screen)
	stack.register_panel("bag", bag_screen)
	stack.register_panel("mart", mart_screen)
	xmenu.entry_chosen.connect(_on_xmenu_entry)
	xmenu.close_requested.connect(func() -> void: stack.pop_panel())
	party_screen.close_requested.connect(func() -> void: stack.pop_panel())
	party_screen.action_chosen.connect(
		func(action_id: String, slot: int) -> void: party_action_chosen.emit(action_id, slot))
	bag_screen.close_requested.connect(func() -> void: stack.pop_panel())
	bag_screen.action_chosen.connect(
		func(action_id: String, slug: String) -> void: bag_action_chosen.emit(action_id, slug))
	mart_screen.close_requested.connect(func() -> void: stack.pop_panel())
	# ui_screens: construct + register the six new panels.
	pokedex_screen = PUWPokedexScreen.new()
	pokedex_screen.name = "PokedexScreen"
	stack.add_child(pokedex_screen)
	options_screen = PUWOptionsScreen.new()
	options_screen.name = "OptionsScreen"
	stack.add_child(options_screen)
	trainer_card_screen = PUWTrainerCardScreen.new()
	trainer_card_screen.name = "TrainerCardScreen"
	stack.add_child(trainer_card_screen)
	storage_screen = PUWStorageScreen.new()
	storage_screen.name = "StorageScreen"
	stack.add_child(storage_screen)
	quest_board_screen = PUWQuestBoardScreen.new()
	quest_board_screen.name = "QuestBoardScreen"
	stack.add_child(quest_board_screen)
	vexa_screen = PUWVexaScreen.new()
	vexa_screen.name = "VexaScreen"
	stack.add_child(vexa_screen)
	stack.register_panel("pokedex", pokedex_screen)
	stack.register_panel("options", options_screen)
	stack.register_panel("trainer_card", trainer_card_screen)
	stack.register_panel("storage", storage_screen)
	stack.register_panel("quest_board", quest_board_screen)
	stack.register_panel("vexa", vexa_screen)
	pokedex_screen.close_requested.connect(func() -> void: stack.pop_panel())
	options_screen.close_requested.connect(func() -> void: stack.pop_panel())
	trainer_card_screen.close_requested.connect(func() -> void: stack.pop_panel())
	storage_screen.close_requested.connect(func() -> void: stack.pop_panel())
	quest_board_screen.close_requested.connect(func() -> void: stack.pop_panel())
	vexa_screen.close_requested.connect(func() -> void: stack.pop_panel())
	vexa_screen.simulation_requested.connect(
		func(options: Dictionary) -> void: vexa_simulation_requested.emit(options))
	# audio_buses: create the dex cry player and bind it to the
	# Pokédex screen. local_only first, so the player can never
	# download regardless of when the first press lands.
	cry_player = PokemonCryPlayer.new()
	cry_player.name = "PokedexCryPlayer"
	cry_player.local_only = true
	add_child(cry_player)
	pokedex_screen.bind_cry_player(cry_player)
	# pp_max (A-43): construct + register the two picker panels
	# and wire the bag target flow exactly as the bind contract
	# prescribes (the pp_max suite's host, made production).
	party_picker_screen = PUWPartyPickerScreen.new()
	party_picker_screen.name = "PartyPickerScreen"
	stack.add_child(party_picker_screen)
	move_picker_screen = PUWMovePickerScreen.new()
	move_picker_screen.name = "MovePickerScreen"
	stack.add_child(move_picker_screen)
	stack.register_panel("party_picker", party_picker_screen)
	stack.register_panel("move_picker", move_picker_screen)
	bag_screen.bag_target_requested.connect(_on_bag_target_requested)
	party_picker_screen.target_chosen.connect(_on_picker_target_chosen)
	party_picker_screen.picker_cancelled.connect(
		func() -> void: stack.pop_panel())
	move_picker_screen.move_chosen.connect(_on_move_chosen)
	move_picker_screen.picker_cancelled.connect(
		func() -> void: stack.pop_panel())
	# build6_remainders (remainder 5): construct + register the
	# three field pick panels and route their answers: a pick
	# pops the panel and re-emits for the game host; a cancel
	# just pops (nothing was chosen, nothing is consumed).
	fossil_pick_screen = PUWFossilPickScreen.new()
	fossil_pick_screen.name = "FossilPickScreen"
	stack.add_child(fossil_pick_screen)
	ferry_menu_screen = PUWFerryMenuScreen.new()
	ferry_menu_screen.name = "FerryMenuScreen"
	stack.add_child(ferry_menu_screen)
	elevator_floor_screen = PUWElevatorFloorScreen.new()
	elevator_floor_screen.name = "ElevatorFloorScreen"
	stack.add_child(elevator_floor_screen)
	stack.register_panel("fossil_pick", fossil_pick_screen)
	stack.register_panel("ferry_menu", ferry_menu_screen)
	stack.register_panel("elevator", elevator_floor_screen)
	fossil_pick_screen.fossil_chosen.connect(_on_fossil_chosen)
	fossil_pick_screen.picker_cancelled.connect(
		func() -> void: stack.pop_panel())
	ferry_menu_screen.ferry_chosen.connect(_on_ferry_chosen)
	ferry_menu_screen.picker_cancelled.connect(
		func() -> void: stack.pop_panel())
	elevator_floor_screen.floor_chosen.connect(_on_floor_chosen)
	elevator_floor_screen.picker_cancelled.connect(
		func() -> void: stack.pop_panel())


## ui_screens: forward the real save state to the screens
## that bind it. Called by the map host when the menu is
## bound (and again whenever the state is replaced, e.g.
## after a load). The quest board binds per board through
## open_quest_board(); party/bag keep their own bind paths
## (live-bag prep), untouched here.
func bind_state(state: Dictionary) -> void:
	_state = state
	pokedex_screen.bind_state(state)
	options_screen.bind_state(state)
	trainer_card_screen.bind_state(state)
	storage_screen.bind_state(state)
	vexa_screen.bind_state(state)


## Open or close the menu — the one entry point for Start, the
## on-screen touch button, and tests.
func toggle_menu() -> void:
	stack.handle_b_button()


func open_mart() -> void:
	# A-49: mart scenes load stock via PUWMartStock.stock_for_map
	# for the map the menu is bound on; maps without a stock
	# record keep the screen's default stock.
	if _current_map != "" and mart_screen != null:
		var stock: Dictionary = PUWMartStock.stock_for_map(_current_map)
		if bool(stock.get("found", false)):
			mart_screen.set_map_stock(_current_map)
	if stack.depth() == 0:
		stack.push_panel("xmenu")
	stack.push_panel("mart")


## A-49: the game host records the map the menu is bound on
## (boot / warp), so open_mart can load that map's stock.
func bind_map(map_name: String) -> void:
	_current_map = map_name


## A-43 (pp_max host hand-over): the bag asked for a target
## Pokemon — remember the pending use and push the party picker.
func _on_bag_target_requested(action_id: String, slug: String) -> void:
	_pending_target = {"action": action_id, "slug": slug, "slot": -1}
	stack.push_panel("party_picker")
	party_picker_screen.present_target(_state, action_id, slug)


## A-43: a target was picked. A "use" of a move-choice item
## (PP Up / PP Max class) does NOT resolve yet — the move
## picker goes on the same stack as the third panel and the
## resolution waits for move_chosen. Everything else resolves
## at once through PUWItemTarget, the picker pops, and the
## bag reports the result.
func _on_picker_target_chosen(slot: int) -> void:
	_pending_target["slot"] = slot
	var action: String = str(_pending_target.get("action", ""))
	var slug: String = str(_pending_target.get("slug", ""))
	if action == "use" and PUWItemTarget.requires_move_choice(slug):
		stack.push_panel("move_picker")
		move_picker_screen.present_moves(_state, slug, slot)
		return
	var result: Dictionary = {}
	if action == "give":
		result = PUWItemTarget.give_to_mon(_state, slug, slot)
	elif action == "take":
		result = PUWItemTarget.take_from_mon(_state, slot)
	else:
		result = PUWItemTarget.use_on_mon(_state, slug, slot)
	stack.pop_panel()
	bag_screen.apply_target_result(action, slug, result)


## A-43: the move was picked — resolve with the move, pop the
## move picker AND the party picker, and report through the
## bag. (move_refused: nothing — the picker stays open.)
func _on_move_chosen(move_name: String) -> void:
	var slug: String = str(_pending_target.get("slug", ""))
	var slot: int = int(_pending_target.get("slot", -1))
	var result: Dictionary = PUWItemTarget.use_on_mon(
		_state, slug, slot, {"move": move_name})
	stack.pop_panel()
	stack.pop_panel()
	bag_screen.apply_target_result("use", slug, result)


## build6_remainders (remainder 5): field pick entries. The
## game host calls these from its story hand-offs (fossil /
## ferry) and its elevator bg_event branch. Each pushes ONLY
## its pick panel — the menu is closed in the field, and the
## pop on pick/cancel returns straight to play.
func open_fossil_pick() -> void:
	stack.push_panel("fossil_pick")
	fossil_pick_screen.present_pick()


func open_ferry_menu(options: Dictionary) -> void:
	stack.push_panel("ferry_menu")
	ferry_menu_screen.present_options(options)


func open_elevator(building: Dictionary, current_map: String) -> void:
	stack.push_panel("elevator")
	elevator_floor_screen.present_floors(building, current_map)


func _on_fossil_chosen(pick: String) -> void:
	stack.pop_panel()
	fossil_chosen.emit(pick)


func _on_ferry_chosen(origin: String, dest: String) -> void:
	stack.pop_panel()
	ferry_chosen.emit(origin, dest)


func _on_floor_chosen(map_name: String, warp_id: int) -> void:
	stack.pop_panel()
	floor_chosen.emit(map_name, warp_id)


# ui_screens: field entries, same push pattern as open_mart().
func open_trainer_card() -> void:
	if stack.depth() == 0:
		stack.push_panel("xmenu")
	stack.push_panel("trainer_card")


func open_storage() -> void:
	if stack.depth() == 0:
		stack.push_panel("xmenu")
	stack.push_panel("storage")


func open_vexa() -> void:
	if stack.depth() == 0:
		stack.push_panel("xmenu")
	stack.push_panel("vexa")


## ui_screens: the quest board is per settlement — bind the
## board (and the caller's world context) before pushing.
func open_quest_board(board_id: String, context: Dictionary = {}) -> void:
	quest_board_screen.bind_context(context)
	quest_board_screen.bind_board(_state, board_id)
	if stack.depth() == 0:
		stack.push_panel("xmenu")
	stack.push_panel("quest_board")


func is_open() -> bool:
	return stack != null and stack.depth() > 0


func _unhandled_input(event: InputEvent) -> void:
	if PUWInputInteraction.menu_pressed(event):
		toggle_menu()
		get_viewport().set_input_as_handled()


func _on_xmenu_entry(entry_id: String) -> void:
	match entry_id:
		"party":
			stack.push_panel("party")
		"bag":
			stack.push_panel("bag")
		"save":
			save_requested.emit()
		# ui_screens: these two X-menu entries now have panels.
		"dex":
			stack.push_panel("pokedex")
		"settings":
			stack.push_panel("options")
		_:
			unbuilt_entry.emit(entry_id)
