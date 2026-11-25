extends SceneTree
## Binding build 6 / A-30 evidence: MDX slot 650 (chespin), a
## rig_template slot, presented through the real battle scene.
## Asserts (1) the bound index carries slot 650 with battle
## motion "rig_template"; (2) presenting an MDX chespin as the
## enemy battler starts its presentation — the engine-procedural
## idle via the A-30 branch (BattleAnims idle playing on the
## enemy holder); (3) the PUWRigStage part-cut path is NOT used
## for this slot (the rig stage stays unused/invisible), which
## is what distinguishes the A-30 branch from the engine-rigged
## path.
## Run: godot --headless --script res://tests/rig_template_playback_tests.gd

var _passed: int = 0
var _failed: int = 0
var _fail_names: Array = []


func _init() -> void:
	_run.call_deferred()


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		_fail_names.append(name)
		print("FAIL: ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	# (1) Index state for slot 650.
	var index_text: String = FileAccess.get_file_as_string("res://data/mdx_sprites_index.json")
	var parsed: Variant = JSON.parse_string(index_text)
	var slot650: Dictionary = {}
	if parsed is Dictionary:
		var top: Dictionary = parsed
		var slots_value: Variant = top.get("slots", [])
		if slots_value is Array:
			var slots: Array = slots_value
			for entry_value in slots:
				if entry_value is Dictionary:
					var entry: Dictionary = entry_value
					if int(entry.get("slot", -1)) == 650:
						slot650 = entry
						break
	_check("slot650_present", not slot650.is_empty())
	_check("slot650_is_chespin", str(slot650.get("species_slug", "")) == "chespin")
	var battle: Dictionary = slot650.get("battle", {})
	_check("slot650_motion_rig_template", str(battle.get("motion", "")) == "rig_template")

	# (2)+(3) Live presentation through the battle scene.
	var packed: PackedScene = load("res://scenes/battle.tscn")
	_check("battle_scene_loads", packed != null)
	if packed != null:
		var builder: PUWTeamBuilder = PUWTeamBuilder.new()
		var base_mon: Dictionary = builder.build_mon("Chespin", 10, "singles")
		var mdx_data: PUWMDXData = PUWMDXData.new()
		var mdx_mon: Dictionary = mdx_data.build_mdx_mon(base_mon)
		BattleScene.pending_player_party = [builder.build_mon("Pikachu", 12, "singles")]
		BattleScene.pending_enemy_party = [mdx_mon]
		var scene: Node = packed.instantiate()
		root.add_child(scene)
		await _wait(1.4)
		var mdx_sprite: AnimatedSprite2D = scene.get("enemy_sprite2d")
		_check("chespin_sprite_present", mdx_sprite != null and mdx_sprite.sprite_frames != null)
		var idle_on: bool = false
		if root != null and root.has_node("BattleAnims"):
			var anims = root.get_node("BattleAnims")
			var holder: Node2D = scene.get("enemy_mon")
			idle_on = anims.has_method("is_idle_playing") and bool(anims.is_idle_playing(holder))
		_check("chespin_state_motion_started", idle_on)
		var stage: PUWRigStage = scene.get("enemy_rig_stage")
		_check("chespin_no_partcut_rig_stage", stage == null or not stage.visible)
		scene.queue_free()
		await _frames(3)
		BattleScene.pending_player_party = []
		BattleScene.pending_enemy_party = []
	print("RIG_TEMPLATE_PLAYBACK: %d passed, %d failed" % [_passed, _failed])
	if not _fail_names.is_empty():
		print("FAILURES: ", ", ".join(_fail_names))
	quit(1 if _failed > 0 else 0)
