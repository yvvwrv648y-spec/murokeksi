extends SceneTree
## PUW engine-rigging VISUAL QA renderer (offline tool, not game
## code): streams the indexed stills for one sample species per
## locomotion class through the REAL rig system (PUWRigRegistry
## definitions + PUWRigStage part pivots + PUWRigPlayer samples)
## and captures contact sheets at sampled motion phases.
##
## Run (needs a display for rendering; use xvfb):
##   xvfb-run -a godot --rendering-driver opengl3 \
##     --script res://tools/render_rig_contact_sheets.gd
## Output: res://art_contact_sheets/rigging/*.png
## Sheets are labeled engine-rigged samples in the folder index.

const OUT_DIR: String = "res://art_contact_sheets/rigging"
const CELL: int = 208
const COLS: int = 4

var _http: HTTPRequest


func _init() -> void:
	_run.call_deferred()


func _fetch_texture(url: String) -> Texture2D:
	# Local sample cache first (the sandbox blocks Godot's TLS;
	# the handful of sample stills is pre-cached by curl, the
	# same streamed art the game itself uses).
	var cache_path: String = "res://tools/rig_sheet_cache/" + url.get_file()
	if FileAccess.file_exists(cache_path):
		var cached: Image = Image.load_from_file(cache_path)
		if cached != null:
			return ImageTexture.create_from_image(cached)
	if _http == null:
		_http = HTTPRequest.new()
		get_root().add_child(_http)
	var err: int = _http.request(url)
	if err != OK:
		return null
	var result: Array = await _http.request_completed
	if int(result[1]) != 200:
		return null
	var bytes: PackedByteArray = result[3]
	var img: Image = Image.new()
	var load_err: int = img.load_png_from_buffer(bytes)
	if load_err != OK:
		return null
	return ImageTexture.create_from_image(img)


func _sheet(species: String, context: String, file_name: String, label: String) -> void:
	var registry: PUWRigRegistry = PUWRigRegistry.new()
	var def: Dictionary = registry.follower_rig(species) if context == "follower" else registry.battle_rig(species)
	if def.is_empty():
		print("SHEET SKIP (no rig): ", species)
		return
	var url: String = str(def.get("source_art_url", ""))
	var tex: Texture2D = await _fetch_texture(url)
	if tex == null:
		print("SHEET SKIP (fetch failed): ", species, " ", url)
		return
	var tracks: Array = ["idle", "movement"] if context == "follower" else ["idle"]
	var rows: int = tracks.size()
	var world: Node2D = Node2D.new()
	get_root().add_child(world)
	var bg: Polygon2D = Polygon2D.new()
	bg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(COLS * CELL, rows * CELL + 28), Vector2(COLS * CELL, 0)])
	bg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(COLS * CELL, 0), Vector2(COLS * CELL, rows * CELL + 28), Vector2(0, rows * CELL + 28)])
	bg.color = Color(0.12, 0.12, 0.16, 1.0)
	world.add_child(bg)
	var title: Label = Label.new()
	title.text = label + "  [engine-rigged sample]"
	title.position = Vector2(8, rows * CELL + 4)
	world.add_child(title)
	var tex_size: Vector2 = Vector2(tex.get_width(), tex.get_height())
	var tracks_def_value: Variant = def.get("tracks", {})
	var tracks_def: Dictionary = tracks_def_value if tracks_def_value is Dictionary else {}
	for r in range(rows):
		var track_name: String = str(tracks[r])
		var track_value: Variant = tracks_def.get(track_name, {})
		var track: Dictionary = track_value if track_value is Dictionary else {}
		var body_value: Variant = track.get("wing_left", track.get("body", track.get("seg_0", {})))
		var body_entry: Dictionary = body_value if body_value is Dictionary else {}
		var freq: float = maxf(float(body_entry.get("freq_hz", 1.0)), 0.1)
		for c in range(COLS):
			var t: float = float(c) * 0.25 / freq
			var stage: PUWRigStage = PUWRigStage.new()
			world.add_child(stage)
			stage.build(tex, def)
			stage.position = Vector2(c * CELL + CELL * 0.5, r * CELL + CELL * 0.5)
			stage.scale = Vector2(1.8, 1.8)
			stage.apply_sample(PUWRigPlayer.sample(def, track_name, t), tex_size)
			var cell_label: Label = Label.new()
			cell_label.text = track_name + " t=" + str(snappedf(t, 0.01)) + "s"
			cell_label.position = Vector2(c * CELL + 6, r * CELL + 4)
			world.add_child(cell_label)
	await process_frame
	await process_frame
	var img: Image = get_root().get_texture().get_image()
	var crop: Image = img.get_region(Rect2i(0, 0, COLS * CELL, rows * CELL + 28))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path: String = OUT_DIR + "/" + file_name
	crop.save_png(path)
	print("SHEET SAVED: ", path)
	world.queue_free()
	await process_frame


func _run() -> void:
	get_root().size = Vector2i(COLS * CELL, 2 * CELL + 28)
	await _sheet("charizard", "follower", "rig_winged_charizard.png", "Charizard - avian_winged follower (wings flap on movement row)")
	await _sheet("tauros", "follower", "rig_quadruped_tauros.png", "Tauros - quadruped follower (stride + tail swish)")
	await _sheet("machamp", "follower", "rig_biped_machamp.png", "Machamp - upright_biped follower (arm swing + stride)")
	await _sheet("gastly", "follower", "rig_hover_gastly.png", "Gastly - hover_levitator follower (hover bob extremes)")
	await _sheet("horsea", "follower", "rig_aquatic_horsea.png", "Horsea - aquatic_finned follower (swim undulation)")
	await _sheet("arbok", "follower", "rig_serpentine_arbok.png", "Arbok - serpentine follower (body wave)")
	await _sheet("electrode", "follower", "rig_rolling_electrode.png", "Electrode - wheeled_rolling follower (roll)")
	await _sheet("caterpie", "follower", "rig_small_caterpie.png", "Caterpie - small_body follower (perch bob / hop)")
	await _sheet("weepinbell", "follower", "rig_sessile_weepinbell.png", "Weepinbell - sessile follower (sway / hop shuffle)")
	await _sheet("ogerpon", "battle", "rig_battle_ogerpon.png", "Ogerpon - battle idle rig (priority case)")
	await _sheet("ironjugulis", "battle", "rig_battle_ironjugulis.png", "Iron Jugulis - battle idle rig (avian_winged)")
	print("RIG CONTACT SHEETS DONE")
	quit(0)
