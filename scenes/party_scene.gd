class_name PartyScene
extends Control
## Party screen. Root node of party.tscn.
## Shows 6 slots: name, level, HP bar, and a sprite placeholder
## box for each party member.
## Out of battle: picking a slot makes that Pokemon the lead (slot 1).
## In battle (set PartyScene.in_battle = true first): picking a
## slot writes the slot number into BattleScene.pending_switch_index
## and goes back to the battle scene, which then calls
## BattleController.execute_switch. The Battle scene sets in_battle
## and party for you when you press its Party button.
## Sprites are placeholder colored boxes. Real sprite pictures need
## ShinySpriteResolver plus a picture loader, which is not built yet.

## Scene to go back to. Default is the Overworld.
static var return_scene_path: String = "res://scenes/overworld.tscn"
## True when this screen was opened from a battle.
static var in_battle: bool = false
## The party to show. Set by the caller. Empty means a demo party.
static var party: Array = []

@onready var slot_boxes: Array = [
	$SlotList/Slot1, $SlotList/Slot2, $SlotList/Slot3,
	$SlotList/Slot4, $SlotList/Slot5, $SlotList/Slot6,
]
@onready var message_label: Label = $MessageLabel
@onready var back_button: Button = $BackButton
@onready var party_panel: PartyScreenController = $PartyPanel
@onready var party_manager: PartyAndStorageManager = $PartyManager

var sprites: ShinySpriteResolver = ShinySpriteResolver.new()


func _ready() -> void:
	theme = PUWUiTheme.make_theme()
	party_panel.open_panel()
	if party.is_empty():
		party = _demo_party()
	if party_manager.party.is_empty():
		party_manager.party = party
	# Load the sprite index if the data file is in the project.
	# The pictures are still placeholders; this only warms the
	# resolver up so get_sprite_url works when a loader is added.
	if FileAccess.file_exists("res://data/shiny_sprites_index.json"):
		sprites.load_from("res://data/shiny_sprites_index.json")
	_refresh_slots()
	back_button.pressed.connect(_on_back_pressed)
	for i in slot_boxes.size():
		var box: HBoxContainer = slot_boxes[i]
		var btn: Button = box.get_node("SelectButton")
		btn.pressed.connect(_on_slot_pressed.bind(i))


func _demo_party() -> Array:
	return [{
		"name": "Pikachu", "species": "Pikachu", "level": 12,
		"hp": 35, "max_hp": 35, "types": ["electric"],
		"moves": ["Thunder Shock", "Quick Attack", "Tail Whip", "Growl"],
		"status": "", "held_item": "", "shiny": false,
	}]


func _refresh_slots() -> void:
	for i in slot_boxes.size():
		var box: HBoxContainer = slot_boxes[i]
		var name_label: Label = box.get_node("NameLabel")
		var level_label: Label = box.get_node("LevelLabel")
		var hp_bar: ProgressBar = box.get_node("HPBar")
		var hp_label: Label = box.get_node("HPLabel")
		var btn: Button = box.get_node("SelectButton")
		if i < party.size():
			var mon: Dictionary = party[i]
			name_label.text = str(mon.get("name", mon.get("species", "Pokemon")))
			level_label.text = "Lv " + str(mon.get("level", 1))
			var hp: int = int(mon.get("hp", 0))
			var max_hp: int = maxi(1, int(mon.get("max_hp", 1)))
			PUWUiTheme.update_hp_bar(hp_bar, hp, max_hp)
			hp_label.text = str(hp) + " / " + str(max_hp)
			btn.disabled = hp <= 0
			if i == 0:
				btn.text = "Lead"
			else:
				btn.text = "Select"
		else:
			name_label.text = "Empty slot"
			level_label.text = ""
			hp_bar.max_value = 1
			hp_bar.value = 0
			hp_label.text = ""
			btn.disabled = true
			btn.text = "Select"


func _on_slot_pressed(slot: int) -> void:
	if slot < 0 or slot >= party.size():
		return
	var mon: Dictionary = party[slot]
	if int(mon.get("hp", 0)) <= 0:
		message_label.text = str(mon.get("name", "That Pokemon")) + " has fainted and cannot fight."
		return
	if in_battle:
		if slot == 0:
			message_label.text = str(mon.get("name", "That Pokemon")) + " is already fighting."
			return
		# Hand the choice back to the Battle scene.
		BattleScene.pending_switch_index = slot
		in_battle = false
		party_panel.close_panel()
		get_tree().change_scene_to_file(return_scene_path)
		return
	# Out of battle: the picked Pokemon becomes the lead.
	if slot != 0:
		var lead: Dictionary = party[0]
		party[0] = mon
		party[slot] = lead
		party_manager.party = party
		message_label.text = str(mon.get("name", "Pokemon")) + " is now the lead."
		_refresh_slots()


func _on_back_pressed() -> void:
	in_battle = false
	party_panel.close_panel()
	get_tree().change_scene_to_file(return_scene_path)
