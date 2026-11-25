Pokemon Ultimate World - Battle Engine v3 Scenes
================================================
Plain simple English. Godot 4.3. All 5 scenes are new files.
RC1 had no Battle, Bag, Mart, Party or Overworld scene at all.

WHERE EACH FILE GOES
--------------------
Copy all 10 files into res://scenes/ in the project:

  battle.tscn        +  battle_scene.gd       (class BattleScene)
  bag.tscn           +  bag_scene.gd          (class BagScene)
  mart.tscn          +  mart_scene.gd         (class MartScene)
  party.tscn         +  party_scene.gd        (class PartyScene)
  overworld.tscn     +  overworld_scene.gd    (class OverworldScene)

Note: an older guide said to put the Battle scene in res://battle/.
This package puts all 5 scenes together in res://scenes/ instead,
next to res://scenes/main.tscn. Pick one place and keep it the same
in every script. The scripts in this package all say res://scenes/.

SCRIPTS EACH SCENE NEEDS
------------------------
These scripts must already be in the project or the scenes will not load.
"RC1" means the file was already in the RC1 repo. "v3" means it comes
from the battle-engine-v3 package. "romhacks" means it comes from the
romhacks-cheats-mods pack.

Battle scene (battle.tscn):
  - res://battle/battle_controller.gd (RC1, class BattleController)
      v3 replaces this file with the new turn-loop version.
  - res://battle/presentation/battle_stage_controller.gd (RC1,
    class BattleStageController)
  - ItemEngine, MoveEffects, PUWGimmicks (v3, RefCounted helpers)
  - PUWSmartAI (romhacks, smart_ai.gd) - the v3 BattleController
    calls it when the trainer AI gives no action.
  - BattleAnims autoload (romhacks, battle_anim.gd) - optional.
    The scene checks has_node("/root/BattleAnims") first, so the
    battle still works if the autoload is not set up yet.
  - The BattleController also needs the RC1 scripts it already
    calls: MoveDatabase, TurnResolver, AbilityEngine,
    StatusAndFieldEngine, CompetitiveTrainerAI, PUWBattleEngine.

Bag scene (bag.tscn):
  - res://interface/inventory/inventory_controller.gd (RC1,
    class EmptyStartBagController)
  - res://systems/inventory/inventory_manager.gd (RC1,
    class PUWInventoryManager)
  - res://systems/inventory/complete_item_database.json (RC1)
  - ItemEngine (v3) for using items.

Mart scene (mart.tscn):
  - res://systems/inventory/inventory_manager.gd (RC1,
    class PUWInventoryManager)
  - res://systems/inventory/complete_item_database.json (RC1)
  - No other script. There is no Mart script in RC1, so the shop
    logic lives in mart_scene.gd itself.

Party scene (party.tscn):
  - res://interface/party/party_controller.gd (RC1,
    class PartyScreenController)
  - res://systems/party/party_and_storage_manager.gd (RC1,
    class PartyAndStorageManager)
  - ShinySpriteResolver (v3) - only warms up here; see below.

Overworld scene (overworld.tscn):
  - No other script. Movement and the wild-battle trigger live in
    overworld_scene.gd itself.

HOW THE SCENES CONNECT TO EACH OTHER
------------------------------------
The Overworld is the hub. Its menu buttons open the Bag, Party
and Mart scenes. Walking into the tall grass patch starts a wild
battle in the Battle scene.

Scenes pass data with static variables on the scene classes,
because changing scenes throws the old scene away. The pattern is:

  1. Set the statics on the next scene's class.
  2. Call get_tree().change_scene_to_file("res://scenes/xxx.tscn").
  3. The new scene reads the statics in _ready and clears them.

The exact handoffs:
  - Overworld -> Battle: BattleScene.pending_player_party and
    BattleScene.pending_enemy_party (the wild Pokemon).
  - Battle -> Bag: BagScene.target_mon (the fighting Pokemon) and
    BagScene.return_scene_path ("res://scenes/battle.tscn").
  - Battle -> Party: PartyScene.party, PartyScene.in_battle = true,
    PartyScene.return_scene_path ("res://scenes/battle.tscn").
  - Party -> Battle: PartyScene writes the picked slot number into
    BattleScene.pending_switch_index, then goes back. The Battle
    scene reads it in _ready and calls
    BattleController.execute_switch.
  - Overworld -> Bag / Party / Mart: return_scene_path is set to
    "res://scenes/overworld.tscn" first.
  - Battle -> Overworld: the Back button goes straight to
    "res://scenes/overworld.tscn".
  - The shared party list lives in PartyScene.party. The Overworld
    fills it with a demo Pikachu if it is empty. Later, the save
    system should own the party instead of this static variable.

WHAT EACH SCENE DOES
-------------------
Battle: shows both active Pokemon (name, level, HP bar), 4 move
buttons, Run / Bag / Party / Back buttons, and a battle log.
Pressing a move button calls BattleController.run_turn with
{"type": "move", "move_name": <the move>} and the controller's
field_state, then updates the HP bars from the result and writes
the log lines. Run calls run_turn with {"type": "run"}. When the
result status is player_won, enemy_won, fled or caught, the
battle is marked over and the move buttons stop working.

Bag: lists all 58 items from complete_item_database.json in an
ItemList, with how many you hold next to each name. The held
counts come from PUWInventoryManager, which starts with a small
stock (Poke Balls, Potions, Town Map). Picking an item shows its
effect text. Use calls ItemEngine.use_battle_item on target_mon
and takes one out of the bag. Items you hold 0 of cannot be used.

Mart: lists the same 58 items with a price, a Buy button, a Sell
button (half price), and your money. Buying adds one to the
inventory manager. Selling takes one out. See the price warning
below.

Party: shows 6 slots with name, level, HP bar and a sprite box.
Out of battle, picking a slot makes that Pokemon the lead.
In battle, picking a slot switches to it through the Battle scene
(see the handoff above). Fainted Pokemon cannot be picked.

Overworld: WASD or arrow keys move the player (CharacterBody2D,
speed 200). A Camera2D on the player follows it. The green tall
grass patch is an Area2D; walking into it starts a wild battle
against a random Pidgey or Rattata (level 5). There is a 5 second
wait after each trigger so it does not start again at once.

WHAT IS PLACEHOLDER (NOT REAL YET)
----------------------------------
  - Sprites: every Pokemon picture is a plain colored box. No
    sprite files are loaded. The Party scene loads the shiny
    sprite index file if it exists, but nothing draws the picture
    yet. A picture loader is still needed.
  - Demo parties: if you open the Battle or Party scene with no
    party handed over, a demo Pikachu (level 12) is used, and a
    demo wild Pidgey (level 10) for the enemy. The Overworld
    wild table is Pidgey and Rattata, both level 5.
  - Mart prices: the item database file has NO price field on any
    item, so there are no real prices anywhere in the repo. The
    Mart uses a clearly marked placeholder price table
    (PLACEHOLDER_PRICES in mart_scene.gd). The code already reads
    item.get("price") first, so when the database gets real
    prices, the placeholders stop being used. Do not treat the
    placeholder prices as real data.
  - Mart money: starts at 3000 coins, a placeholder. The save
    system should hand over the real money later.
  - Overworld map: flat green ground, one grass patch, no walls,
    no towns, no NPCs. The real Kanto maps are JSON files in
    world/regions/kanto/maps/ and have not been turned into a
    TileMap yet. The empty TileMapLayer node in overworld.tscn
    is where the real map goes.
  - Input: project.godot has no custom input actions. Movement
    uses Godot's built-in ui_left / ui_right / ui_up / ui_down
    actions plus the W, A, S, D keys read directly.
  - Returning from a battle puts the player back at the map start
    point, not where the battle started.
  - Battle move pictures: only play if the BattleAnims autoload
    is set up and the move has an animation. Otherwise the
    battle works with no picture.

WHAT WAS CHECKED
----------------
  - All 5 controller scripts use tabs only, no spaces for indent.
  - No script uses := on a Variant value. Every value from a
    Dictionary, an Array, or an untyped return has an explicit
    type written out (var x: Type = ...). Godot's headless check
    treats := from a Variant as an error, so this matters.
  - The Battle scene was checked with the Godot 4.3 headless
    import in the reference project (see the build report for
    the exact result). The known missing res://scenes/main.tscn
    error is expected and is not from these files.
