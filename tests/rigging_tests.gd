extends SceneTree
## Headless tests for PUW in-house ENGINE RIGGING (route 3 of
## the animation-completion sourcing plan, 2026-11-23):
## PUWRigPlayer / PUWRigStage / PUWRigRegistry over
## data/rig_definitions.json + data/rig_escalations.json, and
## the rigged classification in PUWFollowerSpriteResolver and
## PUWPokemonSpriteBinding.
##
## What is proven here:
## (1) Universe trichotomy: every species/context resolves to
##     exactly one of source-animated / engine-rigged /
##     neon-gap — NO fourth state — across the full universe
##     (1,025 base + 397 forms + 1,519 MDX, per context).
##     Follower: 473 source-animated / 550 engine-rigged /
##     2 neon-gap base; forms 397 neon-gap; MDX 1,519 neon-gap.
##     UPDATED by the extraction integration build (2026-11-23,
##     Solid Rule): follower base is now 965 source-animated
##     (473 community + 485 CHUNSOFT SpriteCollab + 7 HGSS
##     Veekun) / 60 engine-rigged / 0 neon-gap. Rig definitions
##     still number 550 (they remain as the fallback record);
##     Doduo + Dodrio escalations now cover only their FLIGHT
##     treatment -- their ground cycles are source-animated.
##     The MDX assertions below still read neon-gap through
##     THIS registry: MDX art lives in its own layer
##     (data/mdx_sprites_index.json + PUWMDXData, proven by
##     tests/mdx_sprite_tests.gd), not in the rig registry.
##     Battle (front, non-shiny): 1,368 source-animated /
##     14 engine-rigged / 40 neon-gap.
##     UPDATED by integration build 2 (2026-11-23): the EBDX
##     binding moves the follower counts to 1,025
##     source-animated / 0 engine-rigged / 0 neon-gap base and
##     217 source-animated / 180 neon-gap forms, and the battle
##     counts to 1,403 source-animated / 14 engine-rigged /
##     5 neon-gap. The rig definitions and the escalation list
##     are unchanged (they record the rigging system's own
##     history); the toucannon follower case in (6) now
##     resolves source-animated via EBDX, with its rig
##     definition still asserted through the registry, and the
##     venusaurgmax battle case resolves source-animated via
##     its EBDX strip instead of missing / neon-gap.
##     UPDATED by the consolidation build (2026-11-23): the
##     Willow OW pack binding moves the follower form counts
##     to 293 source-animated / 104 neon-gap (217 EBDX + 76
##     Willow; the PMD index's gimmighoulroaming row was
##     already inside the EBDX 217 and only changes source).
##     Base and battle counts are unchanged.
## (2) Every rigged flyer-class definition carries wing tracks
##     with non-zero flap parameters on idle AND movement;
##     every rigged definition has idle + movement (follower)
##     or idle (battle) tracks whose parts all exist.
## (3) Motion reality: for sampled species per locomotion
##     class, PUWRigPlayer produces measurably different part
##     transforms at sampled times, idle and movement; winged
##     movement flap sweeps > 30 degrees peak to trough.
## (4) The escalation list is exactly the set of candidates
##     with no rig definition (follower: exactly Doduo +
##     Dodrio; battle forms: the 38 partial-slot rows) — no
##     silent drops, no double-counting.
## (5) Fabrication guard: every rig source-art / view URL
##     exists verbatim in data/shiny_sprites_index.json.
## (6) Resolver integration: rigged followers classify
##     "engine-rigged" with the still URL verbatim and the rig
##     attached; battle static-only results for the 14 rigged
##     species carry provenance "engine-rigged" + the rig;
##     Ogerpon (the priority case) included.
## (7) PUWRigStage builds part pivots from a definition and
##     applies measurably different poses at two times.
##
## Run: godot --headless --script res://tests/rigging_tests.gd
## Suite size: 7 tests (new suite, 2026-11-23).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW rigging tests -- starting.")
	_run("test_universe_trichotomy", Callable(self, "test_universe_trichotomy"))
	_run("test_definitions_complete_and_winged", Callable(self, "test_definitions_complete_and_winged"))
	_run("test_motion_reality", Callable(self, "test_motion_reality"))
	_run("test_escalation_exactness", Callable(self, "test_escalation_exactness"))
	_run("test_fabrication_guard_rig_urls", Callable(self, "test_fabrication_guard_rig_urls"))
	_run("test_resolver_integration", Callable(self, "test_resolver_integration"))
	_run("test_rig_stage_applies_motion", Callable(self, "test_rig_stage_applies_motion"))
	print("PUW rigging tests -- done: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("Failed tests: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _expect(cond: bool, what: String) -> bool:
	if not cond:
		print("  check failed: " + what)
	return cond


func _read_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed_value: Variant = JSON.parse_string(text)
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		return parsed
	return {}


# (1) The full universe, both contexts, exactly three states.
func test_universe_trichotomy() -> bool:
	var ok: bool = true
	var registry: PUWRigRegistry = PUWRigRegistry.new()
	var follower_resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var index: Dictionary = _read_json("res://data/shiny_sprites_index.json")
	var rows_value: Variant = index.get("rows", [])
	var rows: Array = rows_value if rows_value is Array else []
	ok = _expect(rows.size() == 1422, "index must carry 1,422 rows") and ok
	var valid: Array = ["source-animated", "engine-rigged", "neon-gap"]
	# Follower context, per row, via the resolver's own status.
	var fol_counts: Dictionary = {"base": {"source-animated": 0, "engine-rigged": 0, "neon-gap": 0},
		"forms": {"source-animated": 0, "engine-rigged": 0, "neon-gap": 0}}
	var bat_counts: Dictionary = {"source-animated": 0, "engine-rigged": 0, "neon-gap": 0}
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var sid: String = str(row.get("showdown_id", ""))
		var is_form: bool = bool(row.get("is_form", false))
		var fres: Dictionary = follower_resolver.resolve_row(row)
		var fstatus: String = str(fres.get("animation_status", ""))
		ok = _expect(valid.has(fstatus), "follower " + sid + " status must be one of the three states, got " + fstatus) and ok
		var bucket: String = "forms" if is_form else "base"
		var fbucket: Dictionary = fol_counts[bucket]
		fbucket[fstatus] = int(fbucket.get(fstatus, 0)) + 1
		var bres: Dictionary = binding.resolve_species(str(row.get("name", sid)), "", false, "battle", false)
		var bstatus: String = str(bres.get("animation_status", ""))
		ok = _expect(valid.has(bstatus), "battle " + sid + " status must be one of the three states, got " + bstatus) and ok
		bat_counts[bstatus] = int(bat_counts.get(bstatus, 0)) + 1
	var fbase: Dictionary = fol_counts["base"]
	ok = _expect(int(fbase.get("source-animated", -1)) == 1025, "follower base source-animated must be 1,025 after the EBDX upgrades (integration build 2), got " + str(fbase.get("source-animated", -1))) and ok
	ok = _expect(int(fbase.get("engine-rigged", -1)) == 0, "follower base engine-rigged must be 0 after the EBDX upgrades (integration build 2), got " + str(fbase.get("engine-rigged", -1))) and ok
	ok = _expect(int(fbase.get("neon-gap", -1)) == 0, "follower base neon-gap must be 0 (Doduo + Dodrio animated via CHUNSOFT ground cycles; flight stays escalated), got " + str(fbase.get("neon-gap", -1))) and ok
	var fforms: Dictionary = fol_counts["forms"]
	ok = _expect(int(fforms.get("source-animated", -1)) == 293, "follower forms source-animated must be 293 (217 EBDX + 76 Willow + the PMD gimmighoulroaming row, consolidation build), got " + str(fforms.get("source-animated", -1))) and ok
	ok = _expect(int(fforms.get("neon-gap", -1)) == 104, "follower forms must be 104 neon-gap after the Willow binding (consolidation build), got " + str(fforms.get("neon-gap", -1))) and ok
	ok = _expect(int(bat_counts.get("source-animated", -1)) == 1403, "battle source-animated must be 1,403 (1,368 + 35 EBDX strips), got " + str(bat_counts.get("source-animated", -1))) and ok
	ok = _expect(int(bat_counts.get("engine-rigged", -1)) == 14, "battle engine-rigged must be 14, got " + str(bat_counts.get("engine-rigged", -1))) and ok
	ok = _expect(int(bat_counts.get("neon-gap", -1)) == 5, "battle neon-gap must be 5, got " + str(bat_counts.get("neon-gap", -1))) and ok
	# MDX: every slot, both contexts, is neon-gap by rule.
	var mdx: Dictionary = _read_json("res://data/mdx_mapping.json")
	var entries_value: Variant = mdx.get("entries", [])
	var entries: Array = entries_value if entries_value is Array else []
	ok = _expect(entries.size() == 1519, "MDX mapping must carry 1,519 slots") and ok
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var slug: String = str(entry.get("species_slug", ""))
		var mres: Dictionary = follower_resolver.resolve(slug, "MDX")
		ok = _expect(str(mres.get("animation_status", "")) == "neon-gap", "MDX follower " + slug + " must be neon-gap") and ok
		ok = _expect(registry.animation_status("battle", slug, "missing", "MDX") == "neon-gap", "MDX battle " + slug + " must be neon-gap") and ok
	return ok


# (2) Definition completeness + the winged bar.
func test_definitions_complete_and_winged() -> bool:
	var ok: bool = true
	var data: Dictionary = _read_json("res://data/rig_definitions.json")
	var follower_value: Variant = data.get("follower", {})
	var follower: Dictionary = follower_value if follower_value is Dictionary else {}
	var battle_value: Variant = data.get("battle", {})
	var battle: Dictionary = battle_value if battle_value is Dictionary else {}
	ok = _expect(follower.size() == 550, "follower rig definitions must be 550, got " + str(follower.size())) and ok
	ok = _expect(battle.size() == 14, "battle rig definitions must be 14, got " + str(battle.size())) and ok
	for sid_value in follower:
		var sid: String = str(sid_value)
		var def_value: Variant = follower[sid]
		if not (def_value is Dictionary):
			continue
		var def: Dictionary = def_value
		ok = _expect(str(def.get("provenance", "")) == "engine-rigged", sid + " provenance must be engine-rigged") and ok
		var parts_value: Variant = def.get("parts", {})
		var parts: Dictionary = parts_value if parts_value is Dictionary else {}
		var tracks_value: Variant = def.get("tracks", {})
		var tracks: Dictionary = tracks_value if tracks_value is Dictionary else {}
		ok = _expect(tracks.has("idle") and tracks.has("movement"), sid + " follower rig must have idle + movement tracks") and ok
		for track_name in ["idle", "movement"]:
			var track_value: Variant = tracks.get(track_name, {})
			var track: Dictionary = track_value if track_value is Dictionary else {}
			ok = _expect(not track.is_empty(), sid + " " + track_name + " track must not be empty") and ok
			var any_motion: bool = false
			for part_name_value in track:
				var part_name: String = str(part_name_value)
				ok = _expect(parts.has(part_name), sid + " track part " + part_name + " must exist in parts") and ok
				var entry_value: Variant = track[part_name]
				if entry_value is Dictionary:
					var entry: Dictionary = entry_value
					if str(entry.get("kind", "none")) != "none" and (float(entry.get("amp", 0.0)) != 0.0 or str(entry.get("kind", "")) == "roll"):
						any_motion = true
			ok = _expect(any_motion, sid + " " + track_name + " track must contain real motion") and ok
		if str(def.get("locomotion_class", "")) == "avian_winged":
			for track_name in ["idle", "movement"]:
				var track_value: Variant = tracks.get(track_name, {})
				var track: Dictionary = track_value if track_value is Dictionary else {}
				for wing in ["wing_left", "wing_right"]:
					ok = _expect(parts.has(wing), sid + " winged rig must define " + wing) and ok
					var wentry_value: Variant = track.get(wing, {})
					var wentry: Dictionary = wentry_value if wentry_value is Dictionary else {}
					ok = _expect(str(wentry.get("kind", "")) == "flap", sid + " " + track_name + " " + wing + " must be a flap track") and ok
					ok = _expect(float(wentry.get("amp", 0.0)) > 0.0 and float(wentry.get("freq_hz", 0.0)) > 0.0, sid + " " + track_name + " " + wing + " flap parameters must be non-zero") and ok
			var move_value: Variant = tracks.get("movement", {})
			var move_track: Dictionary = move_value if move_value is Dictionary else {}
			var wl_value: Variant = move_track.get("wing_left", {})
			var wl: Dictionary = wl_value if wl_value is Dictionary else {}
			ok = _expect(float(wl.get("amp", 0.0)) >= 20.0, sid + " movement flap amplitude must be >= 20 degrees, got " + str(wl.get("amp", 0.0))) and ok
	for sid_value in battle:
		var sid: String = str(sid_value)
		var def_value: Variant = battle[sid]
		if not (def_value is Dictionary):
			continue
		var def: Dictionary = def_value
		var tracks_value: Variant = def.get("tracks", {})
		var tracks: Dictionary = tracks_value if tracks_value is Dictionary else {}
		ok = _expect(tracks.has("idle"), sid + " battle rig must have an idle track") and ok
		var views_value: Variant = def.get("views", {})
		var views: Dictionary = views_value if views_value is Dictionary else {}
		ok = _expect(views.has("front") and views.has("back"), sid + " battle rig must cover front + back still views") and ok
	return ok


# (3) Motion reality per class.
func test_motion_reality() -> bool:
	var ok: bool = true
	var registry: PUWRigRegistry = PUWRigRegistry.new()
	# One named sample per locomotion class (all rigged species).
	var samples: Dictionary = {
		"avian_winged": "charizard", "quadruped": "tauros",
		"upright_biped": "machamp", "hover_levitator": "gastly",
		"aquatic_finned": "horsea", "serpentine": "arbok",
		"wheeled_rolling": "electrode", "small_body": "caterpie",
		"sessile": "weepinbell",
	}
	for class_value in samples:
		var cls: String = str(class_value)
		var sid: String = str(samples[cls])
		var def: Dictionary = registry.follower_rig(sid)
		ok = _expect(not def.is_empty(), sid + " must have a follower rig") and ok
		ok = _expect(str(def.get("locomotion_class", "")) == cls, sid + " class must be " + cls + ", got " + str(def.get("locomotion_class", ""))) and ok
		for track_name in ["idle", "movement"]:
			var a: Dictionary = PUWRigPlayer.sample(def, track_name, 0.0)
			var b: Dictionary = PUWRigPlayer.sample(def, track_name, 0.19)
			var c: Dictionary = PUWRigPlayer.sample(def, track_name, 0.43)
			var dist: float = maxf(PUWRigPlayer.sample_distance(a, b), PUWRigPlayer.sample_distance(a, c))
			ok = _expect(dist > 0.003, sid + " " + track_name + " poses must measurably differ over time, dist " + str(dist)) and ok
	# Wing flap sweep: over one movement period, wing rotation
	# must sweep more than 30 degrees peak to trough.
	var char_def: Dictionary = registry.follower_rig("charizard")
	var tracks_value: Variant = char_def.get("tracks", {})
	var tracks: Dictionary = tracks_value if tracks_value is Dictionary else {}
	var move_value: Variant = tracks.get("movement", {})
	var move_track: Dictionary = move_value if move_value is Dictionary else {}
	var wl_value: Variant = move_track.get("wing_left", {})
	var wl: Dictionary = wl_value if wl_value is Dictionary else {}
	var freq: float = float(wl.get("freq_hz", 1.0))
	var min_rot: float = 1e9
	var max_rot: float = -1e9
	for i in range(21):
		var t: float = float(i) / 20.0 / freq
		var sampled: Dictionary = PUWRigPlayer.sample(char_def, "movement", t)
		var part_value: Variant = sampled.get("wing_left", {})
		var part_entry: Dictionary = part_value if part_value is Dictionary else {}
		var rot: float = float(part_entry.get("rotation_deg", 0.0))
		min_rot = minf(min_rot, rot)
		max_rot = maxf(max_rot, rot)
	ok = _expect(max_rot - min_rot > 30.0, "charizard movement flap must sweep > 30 degrees, got " + str(max_rot - min_rot)) and ok
	# Battle idle is real motion too (Ogerpon, the priority case).
	var oger_def: Dictionary = registry.battle_rig("ogerpon")
	ok = _expect(not oger_def.is_empty(), "ogerpon must have a battle rig") and ok
	var oa: Dictionary = PUWRigPlayer.sample(oger_def, "idle", 0.0)
	var ob: Dictionary = PUWRigPlayer.sample(oger_def, "idle", 0.37)
	ok = _expect(PUWRigPlayer.sample_distance(oa, ob) > 0.003, "ogerpon battle idle poses must differ over time") and ok
	return ok


# (4) Escalations == candidates with no rig, exactly.
func test_escalation_exactness() -> bool:
	var ok: bool = true
	var registry: PUWRigRegistry = PUWRigRegistry.new()
	var esc_data: Dictionary = _read_json("res://data/rig_escalations.json")
	var esc_value: Variant = esc_data.get("escalations", [])
	var esc: Array = esc_value if esc_value is Array else []
	var fol_esc: Array = []
	var battle_slot_esc: Array = []
	for entry_value in esc:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		ok = _expect(not str(entry.get("reason", "")).is_empty(), "every escalation must carry a reason") and ok
		if str(entry.get("context", "")) == "follower":
			fol_esc.append(str(entry.get("showdown_id", "")))
		elif str(entry.get("context", "")) == "battle" and str(entry.get("scope", "")) == "slot":
			battle_slot_esc.append(str(entry.get("showdown_id", "")))
	fol_esc.sort()
	ok = _expect(fol_esc == ["dodrio", "doduo"], "follower escalations must be exactly Doduo + Dodrio, got " + str(fol_esc)) and ok
	ok = _expect(registry.follower_rig_count() + fol_esc.size() == 552, "rigged + escalated follower candidates must total 552") and ok
	for sid_value in fol_esc:
		var sid: String = str(sid_value)
		ok = _expect(not registry.has_follower_rig(sid), sid + " escalated must have no rig definition") and ok
		ok = _expect(registry.is_escalated(sid, "follower"), sid + " must be on the escalation list") and ok
	ok = _expect(battle_slot_esc.size() == 38, "battle form slot escalations must be 38, got " + str(battle_slot_esc.size())) and ok
	for sid_value in battle_slot_esc:
		var sid: String = str(sid_value)
		ok = _expect(not registry.has_battle_rig(sid), "form " + sid + " must have no battle rig (no stills to rig)") and ok
	ok = _expect(esc.size() == 40, "total escalations must be 40, got " + str(esc.size())) and ok
	return ok


# (5) Fabrication guard over rig URLs.
func test_fabrication_guard_rig_urls() -> bool:
	var ok: bool = true
	var index: Dictionary = _read_json("res://data/shiny_sprites_index.json")
	var rows_value: Variant = index.get("rows", [])
	var rows: Array = rows_value if rows_value is Array else []
	var all_urls: Dictionary = {}
	for row_value in rows:
		if row_value is Dictionary:
			var row: Dictionary = row_value
			var sprites_value: Variant = row.get("sprites", [])
			if sprites_value is Array:
				var sprites: Array = sprites_value
				for entry_value in sprites:
					if entry_value is Dictionary:
						var entry: Dictionary = entry_value
						var url: String = str(entry.get("url", ""))
						if not url.is_empty():
							all_urls[url] = true
	var data: Dictionary = _read_json("res://data/rig_definitions.json")
	for section in ["follower", "battle"]:
		var defs_value: Variant = data.get(section, {})
		var defs: Dictionary = defs_value if defs_value is Dictionary else {}
		for sid_value in defs:
			var sid: String = str(sid_value)
			var def_value: Variant = defs[sid]
			if not (def_value is Dictionary):
				continue
			var def: Dictionary = def_value
			var art_url: String = str(def.get("source_art_url", ""))
			if not art_url.is_empty():
				ok = _expect(all_urls.has(art_url), section + " " + sid + " source art URL must be verbatim in the index") and ok
			var views_value: Variant = def.get("views", {})
			if views_value is Dictionary:
				var views: Dictionary = views_value
				for view_value in views:
					var vurl: String = str(views[view_value])
					ok = _expect(all_urls.has(vurl), section + " " + sid + " view URL must be verbatim in the index") and ok
	return ok


# (6) Resolver + binding integration.
func test_resolver_integration() -> bool:
	var ok: bool = true
	var follower_resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var char_f: Dictionary = follower_resolver.resolve("charizard")
	ok = _expect(str(char_f.get("classification", "")) == "animated", "charizard follower must be animated (CHUNSOFT SpriteCollab sheet, extraction build), got " + str(char_f.get("classification", ""))) and ok
	ok = _expect(str(char_f.get("provenance", "")) == "source-animated", "charizard follower provenance must be source-animated") and ok
	ok = _expect(str(char_f.get("source_id", "")) == "pmd-spritecollab-chunsoft", "charizard follower source must be the CHUNSOFT SpriteCollab row") and ok
	# Toucannon was the engine-rigged follower case until
	# integration build 2: its EBDX charset sheet is bound now,
	# so it resolves source-animated via the EBDX index. Its
	# rig definition still exists in the registry (history /
	# fallback record) and is asserted there directly.
	var touc_f: Dictionary = follower_resolver.resolve("toucannon")
	ok = _expect(str(touc_f.get("classification", "")) == "animated", "toucannon follower must be animated (EBDX sheet, integration build 2), got " + str(touc_f.get("classification", ""))) and ok
	ok = _expect(str(touc_f.get("provenance", "")) == "source-animated", "toucannon follower provenance must be source-animated") and ok
	ok = _expect(str(touc_f.get("source_id", "")) == "ebdx1831", "toucannon follower source must be the EBDX index row") and ok
	ok = _expect(bool(touc_f.get("animated", false)), "toucannon follower must flag animated") and ok
	var touc_rig: Dictionary = PUWRigRegistry.new().follower_rig("toucannon")
	ok = _expect(str(touc_rig.get("locomotion_class", "")) == "avian_winged", "toucannon rig class must be avian_winged") and ok
	var doduo_f: Dictionary = follower_resolver.resolve("doduo")
	ok = _expect(str(doduo_f.get("classification", "")) == "animated", "doduo follower must be animated (CHUNSOFT ground cycle, extraction build), got " + str(doduo_f.get("classification", ""))) and ok
	ok = _expect(str(doduo_f.get("animation_status", "")) == "source-animated", "doduo status must be source-animated; only its FLIGHT treatment stays escalated") and ok
	var victini_f: Dictionary = follower_resolver.resolve("victini")
	ok = _expect(str(victini_f.get("classification", "")) == "animated", "victini follower must stay source-animated (SpriteCollab)") and ok
	ok = _expect(str(victini_f.get("animation_status", "")) == "source-animated", "victini status must be source-animated") and ok
	# Battle: the 8 no-animated species + the 6 gen5ani species
	# carry rigs on their still presentation; classification
	# stays static-only (honest art), provenance engine-rigged.
	for sid in ["irontreads", "ironbundle", "ironjugulis", "ironleaves", "ogerpon", "ironboulder", "ironcrown", "pecharunt", "ironhands", "miraidon", "terapagos"]:
		var bres: Dictionary = binding.resolve_species(sid, "", false, "battle", false)
		ok = _expect(str(bres.get("classification", "")) == "static-only", sid + " battle art must stay static-only, got " + str(bres.get("classification", ""))) and ok
		ok = _expect(str(bres.get("provenance", "")) == "engine-rigged", sid + " battle provenance must be engine-rigged") and ok
		ok = _expect(str(bres.get("animation_status", "")) == "engine-rigged", sid + " battle status must be engine-rigged") and ok
		var rig_value: Variant = bres.get("rig", {})
		ok = _expect(rig_value is Dictionary and not (rig_value as Dictionary).is_empty(), sid + " battle result must carry its rig definition") and ok
	var pika_b: Dictionary = binding.resolve_species("pikachu", "", false, "battle", false)
	ok = _expect(str(pika_b.get("classification", "")) == "animated" and str(pika_b.get("animation_status", "")) == "source-animated", "pikachu battle must stay source-animated") and ok
	var gmax_b: Dictionary = binding.resolve_species("venusaurgmax", "", false, "battle", false)
	ok = _expect(str(gmax_b.get("classification", "")) == "animated" and str(gmax_b.get("animation_status", "")) == "source-animated", "venusaurgmax battle must be animated / source-animated via its EBDX strip (integration build 2), got " + str(gmax_b.get("classification", "")) + " / " + str(gmax_b.get("animation_status", ""))) and ok
	return ok


# (7) The stage builds real part pivots and moves them.
func test_rig_stage_applies_motion() -> bool:
	var ok: bool = true
	var registry: PUWRigRegistry = PUWRigRegistry.new()
	var def: Dictionary = registry.follower_rig("charizard")
	var img: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.8, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var stage: PUWRigStage = PUWRigStage.new()
	ok = _expect(stage.build(tex, def), "rig stage must build from a texture + definition") and ok
	ok = _expect(stage.get_child_count() >= 5, "charizard stage must build at least 5 part pivots, got " + str(stage.get_child_count())) and ok
	var wing_pivot: Node2D = null
	for child in stage.get_children():
		if child is Node2D:
			wing_pivot = child
			break
	stage.set_track("movement")
	var tex_size: Vector2 = Vector2(96.0, 96.0)
	stage.apply_sample(PUWRigPlayer.sample(def, "movement", 0.0), tex_size)
	var first_rotations: Array = []
	for child in stage.get_children():
		var node: Node2D = child
		first_rotations.append(node.rotation_degrees)
	stage.apply_sample(PUWRigPlayer.sample(def, "movement", 0.13), tex_size)
	var moved: bool = false
	var idx: int = 0
	for child in stage.get_children():
		var node: Node2D = child
		if absf(node.rotation_degrees - float(first_rotations[idx])) > 0.5:
			moved = true
		idx += 1
	ok = _expect(moved, "applying a later sample must measurably move a part pivot") and ok
	stage.free()
	return ok
