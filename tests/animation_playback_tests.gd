extends SceneTree
## Animation playback tests (binding build 5, 2026-11-24).
## Run: godot --headless --script res://tests/animation_playback_tests.gd
##
## Riley's order: animations ON, no still sprites dressed as
## animation. This suite proves it, per class:
##
## (1) PKDX battle census: every LOCAL animated entry in
##     data/shiny_sprites_index.json (verified_local_file,
##     res://) resolves to a file on disk holding >= 2 real
##     frames — strip geometry for PNG strips, an exact GIF
##     block-walk frame count for GIFs. Any still-only file
##     claiming animation fails the suite loudly, by name.
## (2) PKDX coverage floors: rows with a local animated front
##     / back meet the build-5 bound totals recorded in the
##     index's own counts block.
## (3) Playback: the sprite loader plays an EBDX strip and a
##     bound GIF with ADVANCING frame indices; the resolver
##     serves the local file (not a streamed URL) for sampled
##     rows in all four view/shiny combinations.
## (4) State animation: PUWBattleAnim idle actually moves a
##     node and is stopped by a non-idle state (the rig the
##     battle scene now calls in production).
## (5) Battle scene: the shipped battle.tscn presents the
##     demo battlers with multi-frame sprites whose frames
##     advance, and presents an MDX mon with its own MDX art
##     plus engine motion (procedural idle or rig stage).
## (6) MDX census: all 1,519 slots carry a battle record
##     whose files exist and whose "motion" field names one
##     of the wired playback kinds (build 5: 645 procedural
##     CTRL, 874 engine-rigged; build 6 A-19/A-30: 645
##     procedural CTRL, 89 engine-rigged, 785 rig_template),
##     with the build-5 animation_kind
##     field agreeing. A rig-stage sample proves part
##     transforms change over time.
## (7) Followers: PUWFollowerRenderer presents an EBDX
##     charset, an HGSS frame set and an MDX walk atlas with
##     advancing walk frames; every locally bound follower
##     sheet named by the indexes exists on disk.
## (8) Player cast: the cast rig builds a multi-frame walk
##     clip for a protagonist (regression guard for the one
##     class that was already wired).

var _passed: int = 0
var _failed: int = 0
var _fail_names: Array = []
# Parity certification counters (Riley 2026-11-24 05:29 CST):
# PKDX and MDX are counted and reported separately, never blended.
var _pkdx_front_rows: int = 0
var _pkdx_back_rows: int = 0
var _pkdx_entries: int = 0
var _mdx_procedural: int = 0
var _mdx_rigged: int = 0
var _mdx_rigged_template: int = 0
var _mdx_follower_bound: int = 0
var _pkdx_charset_rows: int = 0


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


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


static func _pattern_for(shiny: bool, is_back: bool) -> String:
	if shiny and is_back:
		return "ani-back-shiny"
	if shiny:
		return "ani-shiny"
	if is_back:
		return "ani-back"
	return "ani"


static func _local_entry(row: Dictionary, shiny: bool, is_back: bool) -> Dictionary:
	var pattern: String = _pattern_for(shiny, is_back)
	var view: String = "back" if is_back else "front"
	var entries: Variant = row.get("sprites", [])
	if entries is Array:
		var list: Array = entries
		for entry_value in list:
			if not (entry_value is Dictionary):
				continue
			var entry: Dictionary = entry_value
			if str(entry.get("pattern", "")) != pattern:
				continue
			if bool(entry.get("shiny", false)) != shiny:
				continue
			if str(entry.get("view", "")) != view:
				continue
			if not bool(entry.get("animated", false)):
				continue
			if not bool(entry.get("verified_local_file", false)):
				continue
			if not str(entry.get("url", "")).begins_with("res://"):
				continue
			return entry
	return {}


static func _gif_frame_count(bytes: PackedByteArray) -> int:
	if bytes.size() < 14:
		return 0
	var pos: int = 13
	var packed: int = int(bytes[10])
	if packed & 0x80:
		pos += 3 * (1 << ((packed & 0x07) + 1))
	var frames: int = 0
	while pos < bytes.size():
		var tag: int = int(bytes[pos])
		pos += 1
		if tag == 0x3B:
			break
		elif tag == 0x21:
			pos += 1
			pos = _skip_sub_blocks(bytes, pos)
		elif tag == 0x2C:
			frames += 1
			if pos + 9 > bytes.size():
				break
			var ipacked: int = int(bytes[pos + 8])
			pos += 9
			if ipacked & 0x80:
				pos += 3 * (1 << ((ipacked & 0x07) + 1))
			pos += 1
			pos = _skip_sub_blocks(bytes, pos)
		else:
			break
	return frames


static func _skip_sub_blocks(bytes: PackedByteArray, pos: int) -> int:
	while pos < bytes.size():
		var n: int = int(bytes[pos])
		pos += 1 + n
		if n == 0:
			break
	return pos


static func _file_frame_count(path: String) -> int:
	if path.to_lower().ends_with(".gif"):
		return _gif_frame_count(FileAccess.get_file_as_bytes(path))
	var image: Image = Image.new()
	if image.load(path) != OK:
		return 0
	var w: int = image.get_width()
	var h: int = image.get_height()
	if h <= 0 or w % h != 0:
		return 0
	return w / h


func _run() -> void:
	await _frames(2)
	_test_pkdx_census()
	await _test_resolver_local_first()
	await _test_state_animation()
	await _test_battle_scene()
	_test_mdx_census()
	await _test_rig_stage_motion()
	await _test_followers()
	_test_player_cast()
	_test_parity_report()
	print("SUMMARY: %d passed, %d failed" % [_passed, _failed])
	if not _fail_names.is_empty():
		print("Failed checks: ", _fail_names)
	quit(1 if _failed > 0 else 0)


func _test_pkdx_census() -> void:
	var index: Dictionary = _read_json("res://data/shiny_sprites_index.json")
	var rows: Array = index.get("rows", [])
	_check("pkdx_index_rows_1422", rows.size() == 1422)
	var entries_checked: int = 0
	var violations: Array = []
	var front_rows: Dictionary = {}
	var back_rows: Dictionary = {}
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var sid: String = str(row.get("showdown_id", ""))
		for is_back in [false, true]:
			for shiny in [false, true]:
				var entry: Dictionary = _local_entry(row, shiny, is_back)
				if entry.is_empty():
					continue
				entries_checked += 1
				var url: String = str(entry.get("url", ""))
				if not FileAccess.file_exists(url):
					violations.append(sid + " missing file " + url)
					continue
				var frames: int = _file_frame_count(url)
				if frames < 2:
					violations.append(sid + " still-only local entry " + url + " frames=" + str(frames))
				if is_back:
					back_rows[sid] = true
				else:
					front_rows[sid] = true
	_check("pkdx_local_entries_all_multiframe", violations.is_empty())
	for v in violations.slice(0, 10):
		print("  violation: ", v)
	_check("pkdx_local_entries_checked_5000+", entries_checked >= 5000)
	_pkdx_entries = entries_checked
	_pkdx_front_rows = front_rows.size()
	_pkdx_back_rows = back_rows.size()
	var counts: Dictionary = index.get("counts", {})
	_check("pkdx_front_local_rows_match_counts", front_rows.size() == int(counts.get("local_animated_front_rows_build6", -1)))
	_check("pkdx_back_local_rows_match_counts", back_rows.size() == int(counts.get("local_animated_back_rows_build6", -1)))
	_check("pkdx_front_local_rows_floor_1380", front_rows.size() >= 1380)
	_check("pkdx_back_local_rows_floor_1220", back_rows.size() >= 1220)


func _test_resolver_local_first() -> void:
	var resolver: ShinySpriteResolver = ShinySpriteResolver.new()
	var front: String = resolver.get_normal_sprite_url("absol", false)
	_check("resolver_absol_front_local", front.begins_with("res://art/battle_fronts_ebdx/"))
	var back: String = resolver.get_normal_sprite_url("absol", true)
	_check("resolver_absol_back_local", back.begins_with("res://art/battle_backs_ebdx/"))
	var front_shiny: String = resolver.get_shiny_sprite_url("absol", false)
	_check("resolver_absol_front_shiny_local", front_shiny.begins_with("res://art/battle_fronts_ebdx/shiny/"))
	var back_shiny: String = resolver.get_shiny_sprite_url("absol", true)
	_check("resolver_absol_back_shiny_local", back_shiny.begins_with("res://art/battle_backs_ebdx/shiny/"))
	# A GIF-bound row (found from the index itself) resolves
	# to its local GIF.
	var index: Dictionary = _read_json("res://data/shiny_sprites_index.json")
	var gif_row: String = ""
	var rows: Array = index.get("rows", [])
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var entry: Dictionary = _local_entry(row, false, false)
		if not entry.is_empty() and str(entry.get("url", "")).ends_with(".gif"):
			gif_row = str(row.get("showdown_id", ""))
			break
	_check("gif_bound_row_exists", not gif_row.is_empty())
	if not gif_row.is_empty():
		var gif_url: String = resolver.get_normal_sprite_url(gif_row, false)
		_check("resolver_gif_row_local_gif", gif_url.begins_with("res://art/battle_gifs/") and gif_url.ends_with(".gif"))
		# And the loader actually plays it with advancing frames.
		var loader: PUWSpriteLoader = PUWSpriteLoader.new()
		root.add_child(loader)
		var target: AnimatedSprite2D = AnimatedSprite2D.new()
		root.add_child(target)
		loader.get_url_sprite(gif_url, "playback_gif", target, Callable())
		await _frames(3)
		_check("gif_sprite_frames_multiframe", target.sprite_frames != null and target.sprite_frames.get_frame_count("default") >= 2)
		var f0: int = target.frame
		await _wait(0.35)
		_check("gif_sprite_frame_advances", target.frame != f0 or target.frame_progress > 0.0)
		target.queue_free()
		loader.queue_free()
	# An EBDX strip through the loader, likewise.
	var loader2: PUWSpriteLoader = PUWSpriteLoader.new()
	root.add_child(loader2)
	var target2: AnimatedSprite2D = AnimatedSprite2D.new()
	root.add_child(target2)
	loader2.get_url_sprite(front, "playback_strip", target2, Callable())
	await _frames(3)
	# The loader must slice the strip into exactly as many frames
	# as the file itself holds (measured here from the file; the
	# absol front strip measures 69 frames — an earlier draft of
	# this check hardcoded 62 from a different strip and was
	# corrected in build 5).
	_check("strip_sprite_frames_match_file", target2.sprite_frames != null and target2.sprite_frames.get_frame_count("default") == _file_frame_count(front))
	var s0: int = target2.frame
	var sp0: float = target2.frame_progress
	await _wait(0.35)
	# Frame index OR frame progress must move (an index-only
	# compare reads a full-cycle wrap as "frozen").
	_check("strip_sprite_frame_advances", target2.frame != s0 or absf(target2.frame_progress - sp0) > 0.001)
	target2.queue_free()
	loader2.queue_free()


func _test_state_animation() -> void:
	var anims: PUWBattleAnim = PUWBattleAnim.new()
	root.add_child(anims)
	var node: Node2D = Node2D.new()
	node.position = Vector2(100, 100)
	root.add_child(node)
	anims.play_state_animation(node, "idle")
	await _frames(2)
	_check("state_idle_playing", anims.is_idle_playing(node))
	var y0: float = node.position.y
	await _wait(0.7)
	_check("state_idle_moves_node", absf(node.position.y - y0) > 0.1)
	anims.play_state_animation(node, "hurt")
	await _frames(2)
	_check("state_hurt_stops_idle", not anims.is_idle_playing(node))
	node.queue_free()
	anims.queue_free()


func _test_battle_scene() -> void:
	var packed: PackedScene = load("res://scenes/battle.tscn")
	_check("battle_scene_loads", packed != null)
	if packed == null:
		return
	BattleScene.pending_player_party = []
	BattleScene.pending_enemy_party = []
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await _wait(1.4)
	var enemy_sprite: AnimatedSprite2D = scene.get("enemy_sprite2d")
	var player_sprite: AnimatedSprite2D = scene.get("player_sprite2d")
	_check("scene_enemy_sprite_multiframe", enemy_sprite != null and enemy_sprite.sprite_frames != null and enemy_sprite.sprite_frames.get_frame_count("default") >= 2)
	_check("scene_player_sprite_multiframe", player_sprite != null and player_sprite.sprite_frames != null and player_sprite.sprite_frames.get_frame_count("default") >= 2)
	if enemy_sprite != null and enemy_sprite.sprite_frames != null:
		var e0: int = enemy_sprite.frame
		var ep0: float = enemy_sprite.frame_progress
		await _wait(0.35)
		_check("scene_enemy_frame_advances", enemy_sprite.frame != e0 or absf(enemy_sprite.frame_progress - ep0) > 0.001)
	if root != null and root.has_node("BattleAnims"):
		var anims = root.get_node("BattleAnims")
		var enemy_holder: Node2D = scene.get("enemy_mon")
		_check("scene_enemy_idle_playing", anims.has_method("is_idle_playing") and bool(anims.is_idle_playing(enemy_holder)))
	scene.queue_free()
	await _frames(3)
	# MDX presentation: an MDX Bulbasaur as the enemy battler.
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var base_mon: Dictionary = builder.build_mon("Bulbasaur", 10, "singles")
	var mdx_data: PUWMDXData = PUWMDXData.new()
	var mdx_mon: Dictionary = mdx_data.build_mdx_mon(base_mon)
	BattleScene.pending_player_party = [builder.build_mon("Pikachu", 12, "singles")]
	BattleScene.pending_enemy_party = [mdx_mon]
	var scene2: Node = packed.instantiate()
	root.add_child(scene2)
	await _wait(1.4)
	var mdx_sprite: AnimatedSprite2D = scene2.get("enemy_sprite2d")
	_check("scene_mdx_sprite_present", mdx_sprite != null and mdx_sprite.sprite_frames != null)
	var mdx_stage: PUWRigStage = scene2.get("enemy_rig_stage")
	var mdx_motion_on: bool = false
	if root != null and root.has_node("BattleAnims"):
		var anims2 = root.get_node("BattleAnims")
		var holder2: Node2D = scene2.get("enemy_mon")
		mdx_motion_on = anims2.has_method("is_idle_playing") and bool(anims2.is_idle_playing(holder2))
	if mdx_stage != null and mdx_stage.visible:
		mdx_motion_on = true
	_check("scene_mdx_motion_on", mdx_motion_on)
	scene2.queue_free()
	await _frames(3)
	BattleScene.pending_player_party = []
	BattleScene.pending_enemy_party = []


func _test_mdx_census() -> void:
	var index: Dictionary = _read_json("res://data/mdx_sprites_index.json")
	var slots: Array = index.get("slots", [])
	_check("mdx_slots_1519", slots.size() == 1519)
	var procedural: int = 0
	var rigged: int = 0
	var rigged_template: int = 0
	var bad: Array = []
	for slot_value in slots:
		if not (slot_value is Dictionary):
			continue
		var slot: Dictionary = slot_value
		var battle: Dictionary = slot.get("battle", {})
		var motion: String = str(battle.get("motion", ""))
		var kind: String = str(battle.get("animation_kind", ""))
		# Build 6 census counts by animation_kind (the index's
		# own classification). The (motion, kind) pairing must be
		# one of the four wired pairings — the 66 forme-kit slots
		# pair the procedural driver with the engine_rigged kind
		# by their lane's design.
		var pairing: String = motion + "|" + kind
		if not ["bw2-engine-procedural-ctrl|engine_procedural_ctrl",
				"bw2-engine-procedural-ctrl|engine_rigged",
				"engine-rigged_on_receipt|engine_rigged",
				"rig_template|rig_template"].has(pairing):
			bad.append(str(slot.get("slot", "?")) + " unwired pairing " + pairing)
		if kind == "engine_procedural_ctrl":
			procedural += 1
		elif kind == "engine_rigged":
			rigged += 1
		elif kind == "rig_template":
			rigged_template += 1
		var views: Dictionary = battle.get("views", {})
		for view_key in ["front", "front_shiny", "back", "back_shiny"]:
			var rel: String = str(views.get(view_key, ""))
			if rel.is_empty() or not FileAccess.file_exists("res://" + rel):
				bad.append(str(slot.get("slot", "?")) + " missing view " + view_key)
	_mdx_procedural = procedural
	_mdx_rigged = rigged
	_mdx_rigged_template = rigged_template
	_check("mdx_motion_split_645_89_785", procedural == 645
		and rigged == 89 and rigged_template == 785)
	_check("mdx_all_slots_wired_kinds", bad.is_empty())
	for b in bad.slice(0, 10):
		print("  violation: ", b)


func _test_rig_stage_motion() -> void:
	# A static MDX slot whose species carries a rig definition:
	# the rig stage must change part transforms over time.
	var mdx_data: PUWMDXData = PUWMDXData.new()
	mdx_data.load_sprite_index()
	var registry: PUWRigRegistry = PUWRigRegistry.new()
	var chosen_slot: int = 0
	var chosen_def: Dictionary = {}
	var chosen_path: String = ""
	for slot in range(1, 1520):
		var record: Dictionary = mdx_data.battle_sprite_for_slot(slot)
		if not str(record.get("motion", "")).begins_with("engine-rigged"):
			continue
		var entry: Dictionary = mdx_data.sprite_entry_for_slot(slot)
		var slug: String = str(entry.get("species_slug", ""))
		var def: Dictionary = registry.definition_for_rig(registry.follower_rig(slug))
		if def.is_empty():
			def = registry.definition_for_rig(registry.battle_rig(slug))
		if def.is_empty():
			continue
		chosen_slot = slot
		chosen_def = def
		var views: Dictionary = record.get("views", {})
		chosen_path = str(views.get("front", ""))
		break
	_check("rig_sample_slot_found", chosen_slot > 0)
	if chosen_slot == 0:
		return
	var image: Image = Image.new()
	_check("rig_sample_still_loads", image.load("res://" + chosen_path) == OK)
	var stage: PUWRigStage = PUWRigStage.new()
	root.add_child(stage)
	_check("rig_stage_builds", stage.build(ImageTexture.create_from_image(image), chosen_def))
	stage.set_track("idle")
	var sample0: Dictionary = PUWRigPlayer.sample(chosen_def, "idle", 0.0)
	var sample1: Dictionary = PUWRigPlayer.sample(chosen_def, "idle", 0.6)
	_check("rig_sample_transforms_change", str(sample0) != str(sample1))
	stage.queue_free()


func _test_followers() -> void:
	var renderer: PUWFollowerRenderer = PUWFollowerRenderer.new()
	root.add_child(renderer)
	# EBDX charset (amoonguss row, from the index itself).
	var ebdx: Dictionary = _read_json("res://data/ebdx_follower_index.json")
	var ebdx_row: Dictionary = _row_by_id(ebdx.get("rows", []), "amoonguss")
	_check("follower_ebdx_row_found", not ebdx_row.is_empty())
	if not ebdx_row.is_empty():
		var layout: Dictionary = ebdx_row.get("sheet_layout", {})
		_check("follower_ebdx_charset_presents", renderer.present_charset(str(ebdx_row.get("sheet_url", "")), layout))
		renderer.set_moving(true)
		renderer.set_facing("down")
		await _frames(2)
		var sprite: AnimatedSprite2D = renderer.sprite_node()
		_check("follower_ebdx_walk_4_frames", sprite.sprite_frames != null and sprite.sprite_frames.get_frame_count("walk_down") == 4)
		var w0: int = sprite.frame
		var wp0: float = sprite.frame_progress
		await _wait(0.4)
		_check("follower_ebdx_walk_advances", sprite.frame != w0 or absf(sprite.frame_progress - wp0) > 0.001)
	# HGSS frame files (beedrill row).
	var hgss: Dictionary = _read_json("res://data/hgss_overworld_index.json")
	var hgss_row: Dictionary = _row_by_id(hgss.get("rows", []), "beedrill")
	_check("follower_hgss_row_found", not hgss_row.is_empty())
	if not hgss_row.is_empty():
		var frames_by_dir: Dictionary = hgss_row.get("frames", {})
		_check("follower_hgss_presents", renderer.present_frame_files(frames_by_dir, false))
		renderer.set_moving(true)
		renderer.set_facing("down")
		await _frames(2)
		var sprite2: AnimatedSprite2D = renderer.sprite_node()
		_check("follower_hgss_walk_2_frames", sprite2.sprite_frames != null and sprite2.sprite_frames.get_frame_count("walk_down") == 2)
		var h0: int = sprite2.frame
		var hp0: float = sprite2.frame_progress
		await _wait(0.4)
		_check("follower_hgss_walk_advances", sprite2.frame != h0 or absf(sprite2.frame_progress - hp0) > 0.001)
	# MDX walk atlas (slot 1).
	var mdx_data: PUWMDXData = PUWMDXData.new()
	var follower1: Dictionary = mdx_data.follower_sheet_for_slot(1)
	_check("follower_mdx_slot1_bound", str(follower1.get("status", "")) == "bound_local_animated")
	if not follower1.is_empty():
		_check("follower_mdx_atlas_presents", renderer.present_mdx_atlas(str(follower1.get("sheet", ""))))
		renderer.set_moving(true)
		renderer.set_facing("down")
		await _frames(2)
		var sprite3: AnimatedSprite2D = renderer.sprite_node()
		_check("follower_mdx_walk_4_frames", sprite3.sprite_frames != null and sprite3.sprite_frames.get_frame_count("walk_down") == 4)
		var m0: int = sprite3.frame
		var mp0: float = sprite3.frame_progress
		await _wait(0.4)
		_check("follower_mdx_walk_advances", sprite3.frame != m0 or absf(sprite3.frame_progress - mp0) > 0.001)
	renderer.queue_free()
	# Existence sweep: every locally bound follower sheet the
	# indexes name must exist on disk.
	var missing: int = 0
	for idx_path in ["res://data/ebdx_follower_index.json", "res://data/willow_follower_index.json"]:
		var idx: Dictionary = _read_json(idx_path)
		var rows2: Array = idx.get("rows", [])
		_pkdx_charset_rows += rows2.size()
		for row_value in rows2:
			if not (row_value is Dictionary):
				continue
			var row: Dictionary = row_value
			var sheet: String = str(row.get("sheet_url", ""))
			if sheet.is_empty() or not FileAccess.file_exists(sheet):
				missing += 1
	_check("follower_charset_sheets_all_exist", missing == 0)
	var mdx_missing: int = 0
	var mdx_index: Dictionary = _read_json("res://data/mdx_sprites_index.json")
	var mdx_slots: Array = mdx_index.get("slots", [])
	for slot_value in mdx_slots:
		if not (slot_value is Dictionary):
			continue
		var slot: Dictionary = slot_value
		var follower: Dictionary = slot.get("follower", {})
		if str(follower.get("status", "")) == "bound_local_animated":
			_mdx_follower_bound += 1
			var sheet_path: String = str(follower.get("sheet", ""))
			if sheet_path.is_empty() or not FileAccess.file_exists("res://" + sheet_path):
				mdx_missing += 1
	_check("follower_mdx_sheets_all_exist", mdx_missing == 0)


func _row_by_id(rows: Array, showdown_id: String) -> Dictionary:
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		if str(row.get("showdown_id", "")) == showdown_id:
			return row
	return {}


func _test_parity_report() -> void:
	# PARITY CERTIFICATION (Riley 2026-11-24 05:29 CST): Moemon /
	# Pokémon parity is a certification line. PKDX and MDX counts
	# are printed and checked separately — no blended figure.
	print("PARITY PKDX battle: front %d/1422 rows local multi-frame, back %d/1422 rows, %d local entries frame-verified" % [_pkdx_front_rows, _pkdx_back_rows, _pkdx_entries])
	print("PARITY MDX battle: %d engine-procedural + %d engine-rigged + %d rig-template = %d/1519 slots with wired motion (art is single-keyframe at source; no multi-frame MDX battle data exists in any held source)" % [_mdx_procedural, _mdx_rigged, _mdx_rigged_template, _mdx_procedural + _mdx_rigged + _mdx_rigged_template])
	print("PARITY followers: PKDX local charset rows %d (EBDX + Willow indexes), MDX bound follower sheets %d/1519 slots" % [_pkdx_charset_rows, _mdx_follower_bound])
	_check("parity_pkdx_battle_front_floor", _pkdx_front_rows >= 1380)
	_check("parity_mdx_battle_motion_complete", _mdx_procedural + _mdx_rigged + _mdx_rigged_template == 1519)
	_check("parity_mdx_follower_bound_floor_1403", _mdx_follower_bound >= 1403)


func _test_player_cast() -> void:
	var built: Dictionary = PUWCastRigLoader.build_frames("riley", "walk")
	_check("cast_riley_walk_builds", str(built.get("status", "")) == "loaded")
	_check("cast_walk_clip_multiframe", int(built.get("frame_count", 0)) >= 2 and built.get("frames", null) != null)
