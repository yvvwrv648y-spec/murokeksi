extends Node3D
## PUW Neon Recovery Branch v0.3.0 — Playable Godot 4.7 2.5D Hybrid Vertical Slice
## Preserves v0.1.0 Node3D + MultiMesh + AnimatedSprite3D + 6-follower + save/load foundation
## Adds: 3 unique enterable Pallet interiors, Riley/Tasha selector, separate PKDX/MDX + atomic uniqueness,
## actual battle sprite staging, person-specific NPC dialogue, and approval-gated BW2 GLB rendering.

const MAP_ROOT = "res://data/maps/"
const SAVE_PATH = "user://puw_hybrid_v001.json"
const PARTY = ["0025_pikachu.png", "0001_bulbasaur.png", "0004_charmander.png", "0007_squirtle.png", "0016_pidgey.png", "0019_rattata.png"]
const PARTY_IDS = [25, 1, 4, 7, 16, 19]
const MAP_IDS = [
	"kanto_pallet_town",
	"kanto_route_1",
	"kanto_viridian_city",
	"kanto_pallet_riley_house_1f",
	"kanto_pallet_rival_house",
	"kanto_pallet_oaks_lab"
]
const SPEED = 4.2

var world_root: Node3D
var actors_root: Node3D
var player_root: Node3D
var player_sprite: AnimatedSprite3D
var camera: Camera3D
var ui_layer: CanvasLayer
var caption: Label
var status: Label
var battle_panel: PanelContainer
var battle_text: Label
var battle_foe_tex: TextureRect
var battle_ally_tex: TextureRect
var protagonist_btn: Button
var bw2_preview_btn: Button

var map_data: Dictionary = {}
var map_id = "kanto_pallet_town"
var protagonist_id = "riley"
var candidate_bw2_preview = true
var follower_count = 2
var followers: Array[Sprite3D] = []
var path_history: Array[Vector3] = []
var mobile_vector = Vector2.ZERO
var battle_active = false
var encounter_number = 0
var battle_target_index = 0
var caught_count = 0
var last_spawn = Vector2(11, 15)
var autosave_clock = 0.0
var portal_cooldown = 0.0
var npc_actors: Array[Dictionary] = []
var dex_ledger: DexAndUniquenessLedger

func _ready() -> void:
	dex_ledger = DexAndUniquenessLedger.new()
	_init_world()
	_init_gui()
	_load_game()
	_load_map(map_id, last_spawn)
	_refresh_followers()
	_update_hud("Playable 2.5D vertical slice ready (WASD/Arrows + Touch; E=Talk/Grass; Q=Encounter)")

func _init_world() -> void:
	world_root = Node3D.new()
	world_root.name = "Chunk_World_3D"
	add_child(world_root)
	actors_root = Node3D.new()
	actors_root.name = "Characters_And_Followers"
	add_child(actors_root)
	var sky = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#293e4d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8d4d2")
	env.ambient_light_energy = 0.85
	sky.environment = env
	add_child(sky)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -28, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.name = "Fixed_BW2_Style_ThreeQuarter_Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16.5
	camera.current = true
	add_child(camera)
	player_root = Node3D.new()
	player_root.name = "Player_AnimatedSprite3D"
	actors_root.add_child(player_root)
	player_sprite = _person_sprite("trainer")
	player_root.add_child(player_sprite)

func _person_sprite(kind: String) -> AnimatedSprite3D:
	var a = AnimatedSprite3D.new()
	a.name = kind.capitalize() + "_PixelSprite"
	var anims = SpriteFrames.new()
	for direction in ["down", "up", "left", "right"]:
		var animation = "walk_" + direction
		anims.add_animation(animation)
		anims.set_animation_speed(animation, 5.5)
		anims.set_animation_loop(animation, true)
		for frame in range(2):
			var base = "player" if kind == "trainer" else "npcs"
			var tex = load("res://assets/%s/%s_%s_%s.png" % [base, kind, direction, str(frame)])
			anims.add_frame(animation, tex)
	a.sprite_frames = anims
	a.animation = "walk_down"
	a.play()
	a.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	a.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	a.pixel_size = 0.040
	a.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	a.position.y = 0.82
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return a

func _make_mat(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _init_gui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root = Control.new()
	root.name = "Touch_And_HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)
	caption = _make_label(root, Vector2(18, 12), Vector2(900, 34), 21)
	status = _make_label(root, Vector2(18, 46), Vector2(1050, 32), 16)
	_button(root, "↑", Vector2(115, 515), Vector2(69, 60), func(): mobile_vector.y = -1.0, func(): mobile_vector.y = 0.0)
	_button(root, "←", Vector2(46, 578), Vector2(69, 60), func(): mobile_vector.x = -1.0, func(): mobile_vector.x = 0.0)
	_button(root, "↓", Vector2(115, 578), Vector2(69, 60), func(): mobile_vector.y = 1.0, func(): mobile_vector.y = 0.0)
	_button(root, "→", Vector2(184, 578), Vector2(69, 60), func(): mobile_vector.x = 1.0, func(): mobile_vector.x = 0.0)
	_tap(root, "ENCOUNTER", Vector2(1020, 543), Vector2(240, 54), _start_battle)
	_tap(root, "FOLLOW -", Vector2(1020, 470), Vector2(112, 50), func(): _set_follower_count(follower_count - 1))
	_tap(root, "FOLLOW +", Vector2(1140, 470), Vector2(120, 50), func(): _set_follower_count(follower_count + 1))
	_tap(root, "SAVE", Vector2(1140, 18), Vector2(120, 44), _save_game)
	protagonist_btn = _tap(root, "HERO: RILEY", Vector2(960, 18), Vector2(170, 44), _toggle_protagonist)
	bw2_preview_btn = _tap(root, "BW2 GLB: ON", Vector2(960, 70), Vector2(300, 40), _toggle_bw2_preview)
	_tap(root, "TALK / GRASS", Vector2(1020, 607), Vector2(240, 47), _talk_to_npc)

	battle_panel = PanelContainer.new()
	battle_panel.position = Vector2(230, 110)
	battle_panel.size = Vector2(820, 380)
	battle_panel.visible = false
	root.add_child(battle_panel)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color("#16232e")
	bg.border_color = Color("#9db3aa")
	bg.set_border_width_all(3)
	battle_panel.add_theme_stylebox_override("panel", bg)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	battle_panel.add_child(box)

	var stage = HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 140)
	box.add_child(stage)
	battle_ally_tex = TextureRect.new()
	battle_ally_tex.custom_minimum_size = Vector2(160, 160)
	battle_ally_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	battle_ally_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(battle_ally_tex)
	battle_foe_tex = TextureRect.new()
	battle_foe_tex.custom_minimum_size = Vector2(160, 160)
	battle_foe_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	battle_foe_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(battle_foe_tex)

	battle_text = Label.new()
	battle_text.add_theme_font_size_override("font_size", 20)
	battle_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(battle_text)
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(actions)
	_battle_button(actions, "ATTACK (test)", _test_attack)
	_battle_button(actions, "CAPTURE (test)", _test_capture)
	_battle_button(actions, "RUN", _end_battle)

func _make_label(root: Control, at: Vector2, size_px: Vector2, font_size: int) -> Label:
	var label = Label.new()
	label.position = at
	label.size = size_px
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#e4e9e9"))
	label.add_theme_color_override("font_shadow_color", Color("#16252f"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(label)
	return label

func _tap(root: Control, label: String, at: Vector2, size_px: Vector2, fn: Callable) -> Button:
	var b = Button.new()
	b.text = label
	b.position = at
	b.size = size_px
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(fn)
	root.add_child(b)
	return b

func _button(root: Control, label: String, at: Vector2, size_px: Vector2, on: Callable, off: Callable) -> void:
	var b = Button.new()
	b.text = label
	b.position = at
	b.size = size_px
	b.add_theme_font_size_override("font_size", 28)
	b.button_down.connect(on)
	b.button_up.connect(off)
	root.add_child(b)

func _battle_button(container: HBoxContainer, label: String, fn: Callable) -> void:
	var b = Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(180, 52)
	b.pressed.connect(fn)
	container.add_child(b)

func _toggle_protagonist() -> void:
	protagonist_id = "tasha" if protagonist_id == "riley" else "riley"
	var prof = ProtagonistRegistry.get_profile(protagonist_id)
	protagonist_btn.text = "HERO: " + str(prof.get("display_name", "Riley")).to_upper()
	_save_game()
	_update_hud("Active protagonist: %s (spec lock active)" % prof.get("display_name", "Riley"))

func _toggle_bw2_preview() -> void:
	candidate_bw2_preview = not candidate_bw2_preview
	bw2_preview_btn.text = "BW2 GLB: " + ("ON" if candidate_bw2_preview else "OFF")
	_load_map(map_id, Vector2(player_root.position.x, player_root.position.z))

func _load_map(new_id: String, at: Vector2) -> void:
	var path = MAP_ROOT + new_id + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Map missing: " + path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid map JSON: " + path)
		return
	map_data = parsed
	map_id = new_id
	portal_cooldown = 0.65
	for child in world_root.get_children():
		child.queue_free()
	for actor in npc_actors:
		if is_instance_valid(actor["root"]):
			actor["root"].queue_free()
	npc_actors.clear()
	_build_map_geometry()
	_spawn_authored_bw2_props()
	_spawn_map_npcs()
	player_root.position = Vector3(at.x, 0.0, at.y)
	path_history.clear()
	for n in range(180):
		path_history.append(player_root.position)
	camera.position = player_root.position + Vector3(10.5, 18.0, 16.5)
	camera.look_at(player_root.position + Vector3(0, 0.8, 0), Vector3.UP)
	_update_hud("Entered " + str(map_data.get("display_name", map_id)))

func _build_map_geometry() -> void:
	var grid = map_data["collision_grid"]
	var is_interior = map_data.has("interior_archetype")
	var colors = {
		0: Color("#c9b997") if is_interior else Color("#b2b18b"),
		1: Color("#463d39") if is_interior else Color("#4a7253"),
		2: Color("#3c7c99"),
		3: Color("#987e55"),
		4: Color("#6b9a62")
	}
	for tile_type in [0, 1, 2, 3, 4]:
		var tiles: Array[Vector2i] = []
		for z in range(grid.size()):
			for x in range(grid[z].size()):
				if int(grid[z][x]) == tile_type:
					tiles.append(Vector2i(x, z))
		if tiles.is_empty():
			continue
		var cube = BoxMesh.new()
		cube.size = Vector3(1.025, 0.10, 1.025)
		cube.material = _make_mat(colors[tile_type])
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = cube
		multimesh.instance_count = tiles.size()
		for i in range(tiles.size()):
			var tile = tiles[i]
			multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(tile.x, -0.08, tile.y)))
		var layer = MultiMeshInstance3D.new()
		layer.name = "3D_Tile_Instances_Type_%s" % str(tile_type)
		layer.multimesh = multimesh
		world_root.add_child(layer)
		if not is_interior and tile_type == 1:
			for tile in tiles:
				if (tile.x * 13 + tile.y * 7) % 17 == 0:
					_make_tree(Vector3(tile.x, 0, tile.y))
		elif not is_interior and tile_type == 4:
			for tile in tiles:
				if (tile.x * 11 + tile.y * 3) % 7 == 0:
					_make_grass_clump(Vector3(tile.x, 0, tile.y))

func _spawn_authored_bw2_props() -> void:
	if not (candidate_bw2_preview or BW2ArtIntakeLoader.is_candidate_pack_approved()):
		return
	var props: Array = map_data.get("authored_props_candidate", [])
	if props.is_empty() and map_id == "kanto_pallet_town":
		props = [
			{"prop_id": "pallet_home_ext", "glb_ref": "res://assets_candidate/bw2_recovered/environments_glb/thouse_01.glb", "tile_xy": [6, 6]},
			{"prop_id": "pallet_rival_ext", "glb_ref": "res://assets_candidate/bw2_recovered/environments_glb/thouse_01.glb", "tile_xy": [15, 6]},
			{"prop_id": "pallet_lab_ext", "glb_ref": "res://assets_candidate/bw2_recovered/environments_glb/pc_01.glb", "tile_xy": [14, 12]},
			{"prop_id": "pallet_fountain", "glb_ref": "res://assets_candidate/bw2_recovered/environments_glb/fountain_01.glb", "tile_xy": [10, 10]}
		]
	for p in props:
		var glb_path = str(p.get("glb_ref", ""))
		if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
			continue
		var res = ResourceLoader.load(glb_path)
		if res is PackedScene:
			var inst = res.instantiate()
			var xy = p.get("tile_xy", [5, 5])
			inst.position = Vector3(float(xy[0]), 0.0, float(xy[1]))
			world_root.add_child(inst)

func _make_tree(at: Vector3) -> void:
	var root = Node3D.new()
	root.position = at
	world_root.add_child(root)
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 0.85
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.40
	trunk.material_override = _make_mat(Color("#6a594a"))
	root.add_child(trunk)
	var leaves = MeshInstance3D.new()
	var canopy = SphereMesh.new()
	canopy.radius = 0.62
	canopy.height = 1.24
	canopy.radial_segments = 7
	canopy.rings = 4
	leaves.mesh = canopy
	leaves.position.y = 1.32
	leaves.material_override = _make_mat(Color("#366b52"))
	root.add_child(leaves)

func _make_grass_clump(at: Vector3) -> void:
	var clump = MeshInstance3D.new()
	var blade = CylinderMesh.new()
	blade.top_radius = 0.03
	blade.bottom_radius = 0.18
	blade.height = 0.42
	clump.mesh = blade
	clump.material_override = _make_mat(Color("#8fbe73"))
	clump.position = at + Vector3(0, 0.18, 0)
	world_root.add_child(clump)

func _spawn_map_npcs() -> void:
	var i = 0
	for npc in map_data.get("npcs", []):
		if typeof(npc) != TYPE_DICTIONARY:
			continue
		var xy = npc.get("tile_xy", npc.get("xy", [5, 5]))
		var root = Node3D.new()
		root.name = "NPC_" + str(npc.get("npc_id", "unnamed"))
		root.position = Vector3(float(xy[0]), 0, float(xy[1]))
		actors_root.add_child(root)
		var sprite = _person_sprite("healer" if str(npc.get("role", "")) == "healer" else "vendor")
		root.add_child(sprite)
		npc_actors.append({
			"root": root,
			"sprite": sprite,
			"timer": 0.8 + i * 0.4,
			"dir": Vector2.ZERO,
			"home": root.position,
			"display_name": str(npc.get("display_name", npc.get("npc_id", "NPC"))),
			"dialogue": str(npc.get("dialogue", "Hello from Pokémon Ultimate World!"))
		})
		i += 1

func _refresh_followers() -> void:
	for f in followers:
		if is_instance_valid(f):
			f.queue_free()
	followers.clear()
	for i in range(follower_count):
		var f = Sprite3D.new()
		f.name = "Follower_%s" % str(i + 1)
		f.texture = load("res://assets/pokemon/overworld/" + PARTY[i])
		f.pixel_size = 0.042
		f.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		f.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		f.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		f.position = player_root.position + Vector3(0, 0.70, 0)
		actors_root.add_child(f)
		followers.append(f)
	_update_hud("Party followers: %s / 6" % str(follower_count))

func _set_follower_count(n: int) -> void:
	follower_count = clampi(n, 1, 6)
	_refresh_followers()
	_save_game()

func _tile_at(pos: Vector3) -> int:
	var grid = map_data.get("collision_grid", [])
	var x = roundi(pos.x)
	var z = roundi(pos.z)
	if z < 0 or z >= grid.size() or x < 0 or x >= grid[z].size():
		return 1
	return int(grid[z][x])

func _walkable(pos: Vector3) -> bool:
	return _tile_at(pos) not in [1, 2]

func _physics_process(delta: float) -> void:
	if portal_cooldown > 0.0:
		portal_cooldown = maxf(0.0, portal_cooldown - delta)
	if battle_active:
		return
	var movement = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A): movement.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): movement.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): movement.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): movement.y += 1.0
	movement = movement.limit_length(1.0)
	if mobile_vector.length() > 0.01:
		movement = mobile_vector.normalized()
	var motion = Vector3(movement.x, 0, movement.y) * SPEED * delta
	if motion.length() > 0.001:
		var next_x = player_root.position + Vector3(motion.x, 0, 0)
		if _walkable(next_x): player_root.position.x = next_x.x
		var next_z = player_root.position + Vector3(0, 0, motion.z)
		if _walkable(next_z): player_root.position.z = next_z.z
		var direction = "down"
		if absf(movement.x) >= absf(movement.y):
			direction = "right" if movement.x > 0 else "left"
		else:
			direction = "down" if movement.y > 0 else "up"
		var next_anim = "walk_" + direction
		if player_sprite.animation != next_anim:
			player_sprite.play(next_anim)
		if portal_cooldown <= 0.0:
			_try_map_transition(movement)
	else:
		player_sprite.stop()
	var to = player_root.position + Vector3(10.5, 18.0, 16.5)
	camera.position = camera.position.lerp(to, clampf(delta * 8.0, 0, 1))
	camera.look_at(player_root.position + Vector3(0, 0.8, 0), Vector3.UP)
	_move_followers(delta)
	_update_npcs(delta)
	autosave_clock += delta
	if autosave_clock > 14.0:
		_save_game()
		autosave_clock = 0.0

func _move_followers(delta: float) -> void:
	if path_history.is_empty():
		path_history.append(player_root.position)
	if path_history[0].distance_to(player_root.position) > 0.15:
		path_history.push_front(player_root.position)
		if path_history.size() > 280:
			path_history.resize(280)
	for i in range(followers.size()):
		var step = mini((i + 1) * 8, path_history.size() - 1)
		var target = path_history[step] + Vector3(0, 0.65 + sin(float(Time.get_ticks_msec()) / 150.0 + i) * 0.03, 0)
		followers[i].position = followers[i].position.lerp(target, clampf(delta * 9.0, 0, 1))

func _update_npcs(delta: float) -> void:
	for npc in npc_actors:
		npc["timer"] -= delta
		if npc["timer"] <= 0:
			var choices = [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
			npc["dir"] = choices[randi() % choices.size()]
			npc["timer"] = randf_range(1.2, 3.2)
		var root: Node3D = npc["root"]
		var move = Vector3(npc["dir"].x, 0, npc["dir"].y) * delta * 0.35
		if root.position.distance_to(npc["home"]) < 1.8 and _walkable(root.position + move):
			root.position += move

func _try_map_transition(dir: Vector2) -> void:
	var pos = player_root.position
	var width = int(map_data.get("width", 24))
	var height = int(map_data.get("height", 20))
	for conn in map_data.get("connections", []):
		# Interior portal / exit mat transition
		var portal_xy = conn.get("trigger_xy", conn.get("tile_xy", null))
		if portal_xy is Array and portal_xy.size() == 2:
			if absf(pos.x - float(portal_xy[0])) < 0.75 and absf(pos.z - float(portal_xy[1])) < 0.75:
				var tgt = conn.get("target_entry_xy", [5, 5])
				_load_map(str(conn.get("target_map_id", map_id)), Vector2(float(tgt[0]), float(tgt[1])))
				_refresh_followers()
				_save_game()
				return
		# Edge map transition
		var direction = str(conn.get("direction", ""))
		var crossing = direction == "north" and dir.y < -0.05 and pos.z <= 0.8
		crossing = crossing or direction == "south" and dir.y > 0.05 and pos.z >= height - 1.8
		crossing = crossing or direction == "east" and dir.x > 0.05 and pos.x >= width - 1.8
		crossing = crossing or direction == "west" and dir.x < -0.05 and pos.x <= 0.8
		if not crossing:
			continue
		var valid = false
		for tile in conn.get("from_tiles", []):
			if absf(pos.x - float(tile[0])) < 0.8 and absf(pos.z - float(tile[1])) < 1.1:
				valid = true
		if valid:
			var tgt2 = conn.get("target_entry_xy", [11, 8])
			_load_map(str(conn.get("target_map_id", map_id)), Vector2(float(tgt2[0]), float(tgt2[1])))
			_refresh_followers()
			_save_game()
			return

func _talk_to_npc() -> void:
	for npc in npc_actors:
		var root: Node3D = npc["root"]
		if player_root.position.distance_to(root.position) < 2.2:
			_update_hud("%s: %s" % [npc["display_name"], npc["dialogue"]])
			return
	if _tile_at(player_root.position) == 4:
		_start_battle()
		return
	_update_hud("No NPC nearby (step into tall grass and press E to test encounter)")

func _start_battle() -> void:
	if battle_active:
		return
	battle_active = true
	battle_panel.visible = true
	encounter_number += 1
	battle_target_index = (encounter_number * 7 + int(player_root.position.x)) % PARTY.size()
	var foe_file = PARTY[battle_target_index]
	var foe_id = PARTY_IDS[battle_target_index]
	dex_ledger.record_seen(DexAndUniquenessLedger.FAMILY_POKEMON, foe_id)
	battle_ally_tex.texture = load("res://assets/pokemon/battle_back/" + PARTY[0])
	battle_foe_tex.texture = load("res://assets/pokemon/battle_front/" + foe_file)
	var hero = ProtagonistRegistry.get_profile(protagonist_id).get("display_name", "Riley")
	battle_text.text = "%s vs Wild %s (PKDX #%04d)
[TEST BATTLE | Live Moemon Encounters: OFF]" % [hero, foe_file.get_basename(), foe_id]

func _test_attack() -> void:
	if not battle_active:
		return
	var hero = ProtagonistRegistry.get_profile(protagonist_id).get("display_name", "Riley")
	battle_text.text = "%s's lead attacked! Wild %s took damage.
(Full Gen I-IX damage engine scheduled for P2)" % [hero, PARTY[battle_target_index].get_basename()]

func _test_capture() -> void:
	if not battle_active:
		return
	var success = (encounter_number * 31 + battle_target_index * 17) % 100 < 55
	var foe_id = PARTY_IDS[battle_target_index]
	if success:
		caught_count += 1
		dex_ledger.record_caught(DexAndUniquenessLedger.FAMILY_POKEMON, foe_id)
	battle_text.text = "Capture attempt on #%04d: %s | PKDX Caught: %d | MDX Caught: %d" % [
		foe_id, ("SUCCESS!" if success else "Broke free!"), dex_ledger.pkdx_caught.size(), dex_ledger.mdx_caught.size()
	]
	_save_game()

func _end_battle() -> void:
	battle_active = false
	battle_panel.visible = false
	_update_hud("Returned to 2.5D world")

func _update_hud(note: String) -> void:
	if caption == null:
		return
	var display = str(map_data.get("display_name", map_id))
	var hero = ProtagonistRegistry.get_profile(protagonist_id).get("display_name", "Riley")
	caption.text = "PUW RECOVERY v0.3.0  |  %s  |  %s" % [display, hero]
	status.text = "FOLLOWERS %d/6 • PKDX %d • MDX %d • %s" % [
		follower_count, dex_ledger.pkdx_caught.size(), dex_ledger.mdx_caught.size(), note
	]

func _save_game() -> void:
	var save = {
		"version": 1,
		"map_id": map_id,
		"protagonist_id": protagonist_id,
		"position": [player_root.position.x, player_root.position.z],
		"followers": follower_count,
		"caught": caught_count,
		"encounters": encounter_number,
		"dex_ledger": dex_ledger.to_save_dict()
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(save))
	_update_hud("Saved checkpoint")

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var save = JSON.parse_string(f.get_as_text())
	if typeof(save) != TYPE_DICTIONARY or int(save.get("version", 0)) != 1:
		return
	var possible = str(save.get("map_id", "kanto_pallet_town"))
	if possible in MAP_IDS:
		map_id = possible
	protagonist_id = str(save.get("protagonist_id", "riley"))
	if protagonist_btn != null:
		protagonist_btn.text = "HERO: " + protagonist_id.to_upper()
	var xy = save.get("position", [11, 15])
	if xy is Array and xy.size() == 2:
		last_spawn = Vector2(float(xy[0]), float(xy[1]))
	follower_count = clampi(int(save.get("followers", 2)), 1, 6)
	caught_count = maxi(int(save.get("caught", 0)), 0)
	encounter_number = maxi(int(save.get("encounters", 0)), 0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_talk_to_npc()
		elif event.keycode == KEY_Q:
			_start_battle()
		elif event.keycode == KEY_TAB:
			_toggle_protagonist()
		elif event.keycode == KEY_ESCAPE and battle_active:
			_end_battle()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			_set_follower_count(event.keycode - KEY_1 + 1)
