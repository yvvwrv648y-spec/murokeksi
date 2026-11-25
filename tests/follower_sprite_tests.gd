extends SceneTree
## Headless tests for the PUW follower SPRITE BINDING
## (PUWFollowerSpriteResolver + its wiring in
## PUWFollowerController), built on the 2026-11-23 visual
## coverage audit (files/pokemon-full/visual_coverage.json).
##
## What is proven here:
## (a) A sample of species across all nine generations
##     resolves exactly as the audit's FOLLOWER column says,
##     updated for the route-2 integration: base species with
##     no SpriteCollab sheet are follower "static-only" (the
##     indexed PokeAPI front PNG) -- including species whose
##     BATTLE art is fully animated and species with no
##     verified animated battle sprite at all. Battle art is
##     never credited as follower animation.
## (b) Fabrication guard: across a full sweep of all 1,422
##     index rows, every URL the resolver returns exists
##     verbatim in the index data the test reads independently
##     (main index + follower index).
## (c) Counts after the route-2 integration (2026-11-23):
##     base species 473 animated / 552 static-only / 0 missing;
##     forms 0 / 0 / 397 missing; MDX 0 / 0 / 1,519 missing.
##     UPDATED by the extraction integration build (2026-11-23,
##     Solid Rule): base species 965 animated / 60 engine-rigged /
##     0 static-only / 0 missing -- 473 community SpriteCollab +
##     485 CHUNSOFT SpriteCollab (game sprites, verified the same
##     way, provenance per row) + 7 HGSS overworld (Veekun pack,
##     local files, data/hgss_overworld_index.json). Doduo and
##     Dodrio are animated now (real PMD ground cycles); their
##     FLIGHT treatment stays escalated. Forms and MDX counts
##     through THIS resolver are unchanged (MDX art resolves via
##     PUWMDXData + data/mdx_sprites_index.json, never borrowed).
##     UPDATED by the route-3 rigging integration (2026-11-23):
##     the 552 static-only base species split into 550
##     "engine-rigged" (indexed still + PUW rig definition,
##     provenance engine-rigged) and 2 static-only (Doduo and
##     Dodrio, escalated to Neon: flightless body plan, no
##     usable wings in the still). Suite size stays 9 tests;
##     the sample/barred/count assertions below were updated
##     in place to the rigged truth and the fabrication sweep
##     now also reads data/rig_definitions.json.
##     UPDATED by integration build 2 (2026-11-23): the EBDX
##     overworld index (data/ebdx_follower_index.json,
##     Open-Source EBDX Renovation Project, Eevee Expo resource
##     1831) binds 277 local charset sheets -- the last 60
##     engine-rigged base species upgrade to source-animated
##     (base: 1,025 animated / 0 rigged / 0 static / 0 missing)
##     and 217 of the 397 form rows gain their first follower
##     art (forms: 217 animated / 180 missing). The old
##     engine-rigged sample test is replaced by an EBDX sample
##     test over the same 11 species; the forms-missing sample
##     swaps palkiaorigin (now EBDX-animated) for
##     zygardecomplete (still absent); the fabrication sweep
##     also reads the EBDX index. Suite size stays 9 tests.
##     UPDATED by the consolidation build (2026-11-23): the
##     Willow OW pack index (data/willow_follower_index.json)
##     binds 76 more form followers (27 Gigantamax, 48 Mega /
##     Primal, Mega Lucario Z) -- forms: 293 animated / 104
##     missing; the forms-missing sample and the controller
##     wiring party swap their now-animated Gmax/Mega members
##     for still-missing ones (rillaboomgmax, snorlaxgmax);
##     the future-plugin fixture rides on rillaboomgmax /
##     snorlaxgmax for the same reason; the fabrication sweep
##     also reads the Willow index and the PMD index's first
##     form row. The same build appended 21 PMD SpriteCollab
##     rows (richness upgrades: 20 base species + the
##     gimmighoulroaming form) -- the follower index now
##     carries 979 rows, and miraidon / milcery / falinks
##     leave the EBDX sample because they resolve through PMD
##     now. Two tests are added: (j) Willow form followers,
##     (k) consolidation PMD upgrades. Suite size: 11 tests.
## (d) MDX resolution returns "missing" with no URL for every
##     one of the 1,519 mapping slots (no borrowed counterpart
##     art in the follower path).
## (e) Controller wiring: follower records carry their sprite
##     URL + classification, queryable per follower, and the
##     binding travels into behavior_tick output.
## (f) Plug-in path: an animated entry marked for follower
##     use in an additional index resolves "animated" with its
##     verbatim URL, and a known-dead one (verified false) is
##     never credited. The fixture index is a labeled test file
##     written to user:// -- it is not project data.
## (g) Route 2 (NEW, 2026-11-23): the shipped follower index
##     (data/follower_sprites_index.json, PMD SpriteCollab,
##     CC BY-NC 4.0) classifies its species "animated" with the
##     verbatim Walk URL, source_id "pmd-spritecollab", the
##     AnimData.xml URL and Walk+Idle verified anims -- the
##     sourcing phase's verified samples included (Victini,
##     Snivy, Genesect, Sprigatito, Gholdengo, Pecharunt).
## (h) CHUNSOFT species (UPDATED, extraction build
##     2026-11-23): CHUNSOFT-credited species are IN the follower
##     index since the Solid Rule lifted the rip bar, each row
##     verified (Walk/Idle HTTP 200 + AnimData frames) and
##     credited to CHUNSOFT with its game-sprite provenance
##     recorded. They classify "animated" like the community
##     rows, under source_id "pmd-spritecollab-chunsoft".
## (i) EBDX species (NEW, integration build 2, 2026-11-23):
##     the 60 base species whose only follower treatment was an
##     engine rig now classify "animated" with the verbatim
##     res:// sheet path from data/ebdx_follower_index.json,
##     source_id "ebdx1831", provenance "source-animated".
##     Their rig definitions stay on disk as history; the
##     resolver's animated branch wins by construction.
## (j) Willow form followers (NEW, consolidation build
##     2026-11-23): the 76 Gmax / Mega / Primal / Z-A Mega form
##     followers bound from Willow's OW pack classify
##     "animated" with the verbatim res:// sheet path from
##     data/willow_follower_index.json, source_id
##     "willow-ow-pack"; the deliberately unbound ambiguous
##     sheets (pidgeotmega, the Urshifu Gmax pair) stay
##     missing.
## (k) Consolidation PMD upgrades (NEW, consolidation build
##     2026-11-23): the 21 PMD rows appended from the wave-2
##     intake's new SpriteCollab folders classify "animated"
##     through the PMD index (20 base species richer than the
##     HGSS/EBDX sources that served them, plus the
##     gimmighoulroaming form); the 8 folders with no Walk set
##     were not bound and their species keep resolving through
##     EBDX.
##
## Run: godot --headless --script res://tests/follower_sprite_tests.gd
## Prints PASS/FAIL per test + a summary; exit 0 = all passed.
## Suite size: 11 tests (9 through integration build 2 + 2
## consolidation-build tests).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW follower sprite tests -- starting.")
	_run("test_sample_species_ebdx_animated", Callable(self, "test_sample_species_ebdx_animated"))
	_run("test_spritecollab_animated_sample", Callable(self, "test_spritecollab_animated_sample"))
	_run("test_chunsoft_species_animated", Callable(self, "test_chunsoft_species_animated"))
	_run("test_forms_missing", Callable(self, "test_forms_missing"))
	_run("test_fabrication_guard_sweep", Callable(self, "test_fabrication_guard_sweep"))
	_run("test_counts_match_audit", Callable(self, "test_counts_match_audit"))
	_run("test_mdx_all_missing", Callable(self, "test_mdx_all_missing"))
	_run("test_controller_wiring", Callable(self, "test_controller_wiring"))
	_run("test_future_animated_plugin", Callable(self, "test_future_animated_plugin"))
	_run("test_willow_form_followers", Callable(self, "test_willow_form_followers"))
	_run("test_consolidation_pmd_upgrades", Callable(self, "test_consolidation_pmd_upgrades"))
	print("PUW follower sprite tests -- done: %d passed, %d failed." % [_passed, _failed])
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


## The test's OWN read of the shipped sprite index, independent
## of the resolver: showdown_id -> row.
func _index_rows_by_id() -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://data/shiny_sprites_index.json")
	var parsed_value: Variant = JSON.parse_string(text)
	var by_id: Dictionary = {}
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var rows_value: Variant = parsed.get("rows", [])
		if rows_value is Array:
			var rows: Array = rows_value
			for row_value in rows:
				if row_value is Dictionary:
					var row: Dictionary = row_value
					by_id[str(row.get("showdown_id", ""))] = row
	return by_id


## The PokeAPI front PNG URL recorded on a row, read directly
## from the index data by the test (never via the resolver).
func _expected_front_url(row: Dictionary) -> String:
	var sprites_value: Variant = row.get("sprites", [])
	if sprites_value is Array:
		var sprites: Array = sprites_value
		for entry_value in sprites:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				if str(entry.get("source", "")) == "pokeapi" and str(entry.get("pattern", "")) == "front":
					return str(entry.get("url", ""))
	return ""


## The test's OWN read of the shipped EBDX follower index:
## showdown_id -> row.
func _ebdx_index_rows_by_id() -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://data/ebdx_follower_index.json")
	var parsed_value: Variant = JSON.parse_string(text)
	var by_id: Dictionary = {}
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var rows_value: Variant = parsed.get("rows", [])
		if rows_value is Array:
			var rows: Array = rows_value
			for row_value in rows:
				if row_value is Dictionary:
					var row: Dictionary = row_value
					by_id[str(row.get("showdown_id", ""))] = row
	return by_id


# (i) EBDX sample (integration build 2, 2026-11-23): the 11
# species this test used to prove as engine-rigged are exactly
# the species the EBDX audit's Table B upgrades. Each now
# classifies "animated" with the verbatim res:// sheet path
# from the EBDX follower index, source_id "ebdx1831" and
# provenance "source-animated" -- genuine charset walk cycles
# replace the engine rigs (the rig definitions remain on disk
# as history; the resolver's animated branch wins).
func test_sample_species_ebdx_animated() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var ebdx_by_id: Dictionary = _ebdx_index_rows_by_id()
	ok = _expect(ebdx_by_id.size() == 277, "EBDX follower index must carry 277 rows (60 base + 217 forms), got " + str(ebdx_by_id.size())) and ok
	# Consolidation build (2026-11-23): miraidon, milcery and
	# falinks left this sample -- their richer PMD SpriteCollab
	# sets are bound now and the PMD index loads first, so they
	# resolve through PMD (proven in
	# test_consolidation_pmd_upgrades). The 8 species below are
	# still served by EBDX (three of them -- irontreads,
	# toucannon, stunfisk -- are exactly the species whose new
	# PMD folders carry no Walk set and were not bound).
	var sample: Array = [
		"irontreads", "ironjugulis",
		"ironboulder", "ironcrown",
		"toucannon", "zarude",
		"stunfisk", "frillish",
	]
	for species_value in sample:
		var species: String = str(species_value)
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "animated", species + " follower classification must be animated (EBDX), got " + str(result.get("classification", ""))) and ok
		ok = _expect(bool(result.get("animated", false)), species + " must be flagged animated as a follower") and ok
		ok = _expect(str(result.get("source_id", "")) == "ebdx1831", species + " source_id must be ebdx1831, got " + str(result.get("source_id", ""))) and ok
		ok = _expect(str(result.get("provenance", "")) == "source-animated", species + " provenance must be source-animated") and ok
		var row: Dictionary = ebdx_by_id.get(species, {})
		ok = _expect(not row.is_empty(), "EBDX index must carry a row for " + species) and ok
		ok = _expect(str(result.get("url", "")) == _expected_walk_url(row), species + " follower URL must be the EBDX index Walk entry verbatim (the res:// sheet path)") and ok
		var anims_value: Variant = result.get("verified_anims", [])
		var anims: Array = anims_value if anims_value is Array else []
		ok = _expect(anims.has("Walk"), species + " verified anims must include Walk") and ok
	return ok


## The test's OWN read of the shipped follower index:
## showdown_id -> row.
func _follower_index_rows_by_id() -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://data/follower_sprites_index.json")
	var parsed_value: Variant = JSON.parse_string(text)
	var by_id: Dictionary = {}
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var rows_value: Variant = parsed.get("rows", [])
		if rows_value is Array:
			var rows: Array = rows_value
			for row_value in rows:
				if row_value is Dictionary:
					var row: Dictionary = row_value
					by_id[str(row.get("showdown_id", ""))] = row
	return by_id


## The Walk URL recorded on a follower-index row, read directly
## from the index data by the test (never via the resolver).
func _expected_walk_url(row: Dictionary) -> String:
	var sprites_value: Variant = row.get("sprites", [])
	if sprites_value is Array:
		var sprites: Array = sprites_value
		for entry_value in sprites:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				if str(entry.get("anim", "")) == "Walk":
					return str(entry.get("url", ""))
	return ""


# (g) Route 2: SpriteCollab species classify "animated" with
# the verbatim index Walk URL, the pmd-spritecollab source id,
# the AnimData.xml URL and Walk+Idle verified. Sample = the
# sourcing phase's verified samples + Arceus (the accepted
# set's boundary species).
func test_spritecollab_animated_sample() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var by_id: Dictionary = _follower_index_rows_by_id()
	ok = _expect(by_id.size() == 979, "follower index must carry 979 rows (487 community + 492 CHUNSOFT after the consolidation build appended 21 rows), got " + str(by_id.size())) and ok
	var sample: Array = [
		"arceus", "victini", "snivy", "genesect",
		"sprigatito", "gholdengo", "pecharunt",
	]
	for species_value in sample:
		var species: String = str(species_value)
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "animated", species + " follower classification must be animated, got " + str(result.get("classification", ""))) and ok
		ok = _expect(bool(result.get("animated", false)), species + " must be flagged animated as a follower") and ok
		ok = _expect(str(result.get("source_id", "")) == "pmd-spritecollab", species + " source_id must be pmd-spritecollab, got " + str(result.get("source_id", ""))) and ok
		var row: Dictionary = by_id.get(species, {})
		ok = _expect(not row.is_empty(), "follower index must carry a row for " + species) and ok
		ok = _expect(str(result.get("url", "")) == _expected_walk_url(row), species + " follower URL must be the index Walk URL verbatim") and ok
		ok = _expect(str(result.get("anim_data_url", "")) == str(row.get("anim_data_url", "")), species + " AnimData.xml URL must match the index row verbatim") and ok
		var anims_value: Variant = result.get("verified_anims", [])
		var anims: Array = anims_value if anims_value is Array else []
		ok = _expect(anims.has("Walk") and anims.has("Idle"), species + " verified anims must include Walk and Idle") and ok
		ok = _expect(not bool(result.get("partial", true)), species + " must not be flagged partial") and ok
	return ok


# (h) CHUNSOFT-credited species (extraction build, Solid
# Rule): present in the follower index under source_id
# "pmd-spritecollab-chunsoft", verified like the community
# rows, and they classify "animated" with the verbatim Walk
# URL. (Before the Solid Rule these species were barred from
# the index as game rips and classified engine-rigged.)
func test_chunsoft_species_animated() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var follower_by_id: Dictionary = _follower_index_rows_by_id()
	var sample: Array = [
		"bulbasaur", "charizard", "pikachu", "mewtwo",
		"chikorita", "totodile", "torchic", "piplup",
	]
	for species_value in sample:
		var species: String = str(species_value)
		ok = _expect(follower_by_id.has(species), species + " is CHUNSOFT-credited and must now be in the follower index") and ok
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "animated", species + " (CHUNSOFT) follower classification must be animated, got " + str(result.get("classification", ""))) and ok
		ok = _expect(str(result.get("source_id", "")) == "pmd-spritecollab-chunsoft", species + " source_id must be pmd-spritecollab-chunsoft, got " + str(result.get("source_id", ""))) and ok
		var follower_row: Dictionary = follower_by_id.get(species, {})
		ok = _expect(str(result.get("url", "")) == _expected_walk_url(follower_row), species + " (CHUNSOFT) URL must be its follower-index Walk URL verbatim") and ok
	return ok


# (a/c) Forms: forms with no bound follower sheet are follower
# "missing" with no URL -- including forms whose battle art is
# animated. (palkiaorigin, ogerponwellspring and
# terapagosterastal left this sample at integration build 2:
# their EBDX follower sheets ARE bound (audit Table C), so
# they classify animated now; zygardecomplete, mewtwomegax
# and aegislashblade take their places -- the EBDX pack ships
# no follower sheets for them. Consolidation build
# (2026-11-23): venusaurgmax, charizardmegax and mewtwomegax
# leave the sample too -- their Willow OW pack sheets ARE
# bound now; rillaboomgmax, snorlaxgmax and latiasmega take
# their places (snorlaxgmax exists in the Willow pack only as
# a Non-Follower sheet, so it stays honestly missing).)
func test_forms_missing() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var sample: Array = [
		"rillaboomgmax", "snorlaxgmax", "zygardecomplete",
		"latiasmega", "aegislashblade", "greninjabond",
	]
	for species_value in sample:
		var species: String = str(species_value)
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "missing", species + " (form) follower classification must be missing, got " + str(result.get("classification", ""))) and ok
		ok = _expect(str(result.get("url", "")) == "", species + " (form) must return no URL") and ok
	# The same form reached through the explicit form argument.
	var via_form: Dictionary = resolver.resolve("rillaboom", "PKDX", "gmax")
	ok = _expect(str(via_form.get("classification", "")) == "missing", "rillaboom + form gmax must be missing, got " + str(via_form.get("classification", ""))) and ok
	ok = _expect(str(via_form.get("url", "")) == "", "rillaboom + form gmax must return no URL (no base-species fallback)") and ok
	# An unknown species is missing too, never invented.
	var unknown: Dictionary = resolver.resolve("notarealspecies")
	ok = _expect(str(unknown.get("classification", "")) == "missing", "unknown species must be missing") and ok
	ok = _expect(str(unknown.get("url", "")) == "", "unknown species must return no URL") and ok
	return ok


# (b) Fabrication guard + per-row truth over the full index:
# every returned URL exists verbatim in the index data (main
# index + follower index + HGSS index + EBDX index + Willow
# index, all read independently here). Base rows in a follower
# index return exactly their Walk entry and classify animated;
# form rows in the EBDX or Willow index (or the PMD index's
# gimmighoulroaming row) do the same; other form rows
# return "".
func test_fabrication_guard_sweep() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var text: String = FileAccess.get_file_as_string("res://data/shiny_sprites_index.json")
	var parsed_value: Variant = JSON.parse_string(text)
	if not (parsed_value is Dictionary):
		return _expect(false, "test could not read the sprite index")
	var parsed: Dictionary = parsed_value
	var rows_value: Variant = parsed.get("rows", [])
	if not (rows_value is Array):
		return _expect(false, "sprite index has no rows list")
	var rows: Array = rows_value
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
	var follower_by_id: Dictionary = _follower_index_rows_by_id()
	var hgss_by_id: Dictionary = {}
	var hgss_text: String = FileAccess.get_file_as_string("res://data/hgss_overworld_index.json")
	var hgss_parsed_value: Variant = JSON.parse_string(hgss_text)
	if hgss_parsed_value is Dictionary:
		var hgss_parsed: Dictionary = hgss_parsed_value
		var hgss_rows_value: Variant = hgss_parsed.get("rows", [])
		if hgss_rows_value is Array:
			var hgss_rows: Array = hgss_rows_value
			for hgss_row_value in hgss_rows:
				if hgss_row_value is Dictionary:
					var hgss_row: Dictionary = hgss_row_value
					hgss_by_id[str(hgss_row.get("showdown_id", ""))] = hgss_row
					var hgss_sprites_value: Variant = hgss_row.get("sprites", [])
					if hgss_sprites_value is Array:
						var hgss_sprites: Array = hgss_sprites_value
						for hgss_entry_value in hgss_sprites:
							if hgss_entry_value is Dictionary:
								var hgss_entry: Dictionary = hgss_entry_value
								var hgss_url: String = str(hgss_entry.get("url", ""))
								if not hgss_url.is_empty():
									all_urls[hgss_url] = true
	for follower_id_value in follower_by_id:
		var follower_row: Dictionary = follower_by_id[follower_id_value]
		var fsprites_value: Variant = follower_row.get("sprites", [])
		if fsprites_value is Array:
			var fsprites: Array = fsprites_value
			for fentry_value in fsprites:
				if fentry_value is Dictionary:
					var fentry: Dictionary = fentry_value
					var furl: String = str(fentry.get("url", ""))
					if not furl.is_empty():
						all_urls[furl] = true
	# Integration build 2: the EBDX follower index joins the
	# guard set (its Walk entries are res:// sheet paths).
	var ebdx_by_id: Dictionary = _ebdx_index_rows_by_id()
	for ebdx_id_value in ebdx_by_id:
		var ebdx_row: Dictionary = ebdx_by_id[ebdx_id_value]
		var esprites_value: Variant = ebdx_row.get("sprites", [])
		if esprites_value is Array:
			var esprites: Array = esprites_value
			for eentry_value in esprites:
				if eentry_value is Dictionary:
					var eentry: Dictionary = eentry_value
					var eurl: String = str(eentry.get("url", ""))
					if not eurl.is_empty():
						all_urls[eurl] = true
	# Consolidation build: the Willow follower index joins
	# the guard set the same way.
	var willow_by_id: Dictionary = _willow_index_rows_by_id()
	for willow_id_value in willow_by_id:
		var willow_row: Dictionary = willow_by_id[willow_id_value]
		var wsprites_value: Variant = willow_row.get("sprites", [])
		if wsprites_value is Array:
			var wsprites: Array = wsprites_value
			for wentry_value in wsprites:
				if wentry_value is Dictionary:
					var wentry: Dictionary = wentry_value
					var wurl: String = str(wentry.get("url", ""))
					if not wurl.is_empty():
						all_urls[wurl] = true
	ok = _expect(rows.size() == 1422, "index must carry 1,422 rows, got " + str(rows.size())) and ok
	var rig_text: String = FileAccess.get_file_as_string("res://data/rig_definitions.json")
	var rig_parsed_value: Variant = JSON.parse_string(rig_text)
	var rig_ids: Dictionary = {}
	if rig_parsed_value is Dictionary:
		var rig_parsed: Dictionary = rig_parsed_value
		var rig_follower_value: Variant = rig_parsed.get("follower", {})
		if rig_follower_value is Dictionary:
			rig_ids = rig_follower_value
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var showdown_id: String = str(row.get("showdown_id", ""))
		var result: Dictionary = resolver.resolve(showdown_id)
		var url: String = str(result.get("url", ""))
		if not url.is_empty():
			ok = _expect(all_urls.has(url), "fabrication guard: resolver URL for " + showdown_id + " is not verbatim in the index") and ok
		if bool(row.get("is_form", false)):
			if follower_by_id.has(showdown_id):
				var pmd_form_row: Dictionary = follower_by_id[showdown_id]
				ok = _expect(str(result.get("classification", "")) == "animated", "form " + showdown_id + " is in the follower index and must be animated") and ok
				ok = _expect(url == _expected_walk_url(pmd_form_row), "form " + showdown_id + " URL must be its follower-index Walk URL verbatim") and ok
			elif willow_by_id.has(showdown_id):
				var willow_form_row: Dictionary = willow_by_id[showdown_id]
				ok = _expect(str(result.get("classification", "")) == "animated", "form " + showdown_id + " is in the Willow index and must be animated") and ok
				ok = _expect(url == _expected_walk_url(willow_form_row), "form " + showdown_id + " URL must be its Willow-index Walk entry verbatim") and ok
			elif ebdx_by_id.has(showdown_id):
				var ebdx_form_row: Dictionary = ebdx_by_id[showdown_id]
				ok = _expect(str(result.get("classification", "")) == "animated", "form " + showdown_id + " is in the EBDX index and must be animated") and ok
				ok = _expect(url == _expected_walk_url(ebdx_form_row), "form " + showdown_id + " URL must be its EBDX-index Walk entry verbatim") and ok
			else:
				ok = _expect(str(result.get("classification", "")) == "missing" and url == "", "form " + showdown_id + " must be missing with no URL") and ok
		elif follower_by_id.has(showdown_id):
			var follower_row: Dictionary = follower_by_id[showdown_id]
			ok = _expect(str(result.get("classification", "")) == "animated", "base " + showdown_id + " is in the follower index and must be animated") and ok
			ok = _expect(url == _expected_walk_url(follower_row), "base " + showdown_id + " URL must be its follower-index Walk URL verbatim") and ok
		elif hgss_by_id.has(showdown_id):
			var hgss_row: Dictionary = hgss_by_id[showdown_id]
			ok = _expect(str(result.get("classification", "")) == "animated", "base " + showdown_id + " is in the HGSS index and must be animated") and ok
			ok = _expect(url == _expected_walk_url(hgss_row), "base " + showdown_id + " URL must be its HGSS-index Walk entry verbatim") and ok
		elif ebdx_by_id.has(showdown_id):
			var ebdx_base_row: Dictionary = ebdx_by_id[showdown_id]
			ok = _expect(str(result.get("classification", "")) == "animated", "base " + showdown_id + " is in the EBDX index and must be animated") and ok
			ok = _expect(url == _expected_walk_url(ebdx_base_row), "base " + showdown_id + " URL must be its EBDX-index Walk entry verbatim") and ok
		elif rig_ids.has(showdown_id):
			ok = _expect(str(result.get("classification", "")) == "engine-rigged", "base " + showdown_id + " has a rig definition and must be engine-rigged") and ok
			ok = _expect(url == _expected_front_url(row), "base " + showdown_id + " URL must be its own index front PNG (rig source art)") and ok
		else:
			ok = _expect(str(result.get("classification", "")) == "static-only", "base " + showdown_id + " must be static-only (escalated rigging candidate)") and ok
			ok = _expect(url == _expected_front_url(row), "base " + showdown_id + " URL must be its own index front PNG") and ok
	return ok


# (c) Counts across the whole index + MDX, exactly as audited.
func test_counts_match_audit() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var counts: Dictionary = resolver.classification_counts()
	var base_counts: Dictionary = counts.get("base", {})
	var form_counts: Dictionary = counts.get("forms", {})
	var mdx_counts: Dictionary = counts.get("mdx", {})
	ok = _expect(int(base_counts.get("animated", -1)) == 1025, "base animated must be 1,025 (978 via the PMD index after the consolidation upgrades, 47 EBDX-only; HGSS rows retained as fallback data), got " + str(base_counts.get("animated", -1))) and ok
	ok = _expect(int(base_counts.get("engine-rigged", -1)) == 0, "base engine-rigged must be 0 after the EBDX upgrades (integration build 2), got " + str(base_counts.get("engine-rigged", -1))) and ok
	ok = _expect(int(base_counts.get("static-only", -1)) == 0, "base static-only must be 0 (Doduo + Dodrio animated via CHUNSOFT ground cycles), got " + str(base_counts.get("static-only", -1))) and ok
	ok = _expect(int(base_counts.get("missing", -1)) == 0, "base missing must be 0, got " + str(base_counts.get("missing", -1))) and ok
	ok = _expect(int(form_counts.get("animated", -1)) == 293, "form animated must be 293 (217 EBDX + 76 Willow + the PMD gimmighoulroaming row, consolidation build), got " + str(form_counts.get("animated", -1))) and ok
	ok = _expect(int(form_counts.get("static-only", -1)) == 0, "form static-only must be 0") and ok
	ok = _expect(int(form_counts.get("missing", -1)) == 104, "form missing must be 104 (the still-unbound forms stay an honest gap), got " + str(form_counts.get("missing", -1))) and ok
	ok = _expect(int(mdx_counts.get("animated", -1)) == 0, "MDX animated must be 0") and ok
	ok = _expect(int(mdx_counts.get("static-only", -1)) == 0, "MDX static-only must be 0") and ok
	ok = _expect(int(mdx_counts.get("missing", -1)) == 1519, "MDX missing must be 1,519, got " + str(mdx_counts.get("missing", -1))) and ok
	ok = _expect(int(counts.get("total_rows", -1)) == 1422, "total index rows must be 1,422") and ok
	return ok


# (d) Every MDX slot in the mapping resolves missing, no URL.
func test_mdx_all_missing() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var text: String = FileAccess.get_file_as_string("res://data/mdx_mapping.json")
	var parsed_value: Variant = JSON.parse_string(text)
	if not (parsed_value is Dictionary):
		return _expect(false, "test could not read the MDX mapping")
	var parsed: Dictionary = parsed_value
	var entries_value: Variant = parsed.get("entries", [])
	if not (entries_value is Array):
		return _expect(false, "MDX mapping has no entries list")
	var entries: Array = entries_value
	ok = _expect(entries.size() == 1519, "MDX mapping must carry 1,519 slots, got " + str(entries.size())) and ok
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var slug: String = str(entry.get("species_slug", ""))
		var result: Dictionary = resolver.resolve(slug, "MDX")
		ok = _expect(str(result.get("classification", "")) == "missing", "MDX slot " + slug + " must resolve missing") and ok
		ok = _expect(str(result.get("url", "")) == "", "MDX slot " + slug + " must return no URL (no borrowed counterpart art)") and ok
	return ok


# (e) Controller wiring: records carry the binding, it is
# queryable per follower, and it travels into behavior output.
func test_controller_wiring() -> bool:
	var ok: bool = true
	var controller: PUWFollowerController = PUWFollowerController.new()
	var party: Array = [
		{"name": "Pikachu", "species": "Pikachu", "level": 10, "ability": "Static", "moves": ["Thunder Shock"]},
		{"name": "Bulbasaur", "species": "Bulbasaur", "family": "MDX", "level": 9, "ability": "Overgrow", "moves": ["Vine Whip"]},
		{"name": "Rillaboom", "species": "Rillaboom", "form": "Gmax", "level": 30, "ability": "Overgrow", "moves": ["Razor Leaf"]},
	]
	var result: Dictionary = controller.select_followers(party, [0, 1, 2])
	ok = _expect(bool(result.get("ok", false)), "selecting the wiring party must succeed") and ok
	var followers: Array = controller.get_followers()
	ok = _expect(followers.size() == 3, "expected 3 follower records") and ok
	if followers.size() == 3:
		var pikachu: Dictionary = followers[0]
		ok = _expect(str(pikachu.get("sprite_classification", "")) == "animated", "Pikachu follower must be animated (CHUNSOFT SpriteCollab sheet)") and ok
		ok = _expect(str(pikachu.get("sprite_url", "")).ends_with("/0025/Walk-Anim.png"), "Pikachu follower URL must be its SpriteCollab Walk sheet, got " + str(pikachu.get("sprite_url", ""))) and ok
		ok = _expect(bool(pikachu.get("sprite_animated", false)), "Pikachu follower must be flagged animated") and ok
		var mdx: Dictionary = followers[1]
		ok = _expect(str(mdx.get("sprite_classification", "")) == "missing", "MDX follower must be missing, got " + str(mdx.get("sprite_classification", ""))) and ok
		ok = _expect(str(mdx.get("sprite_url", "")) == "", "MDX follower must carry no sprite URL") and ok
		var gmax: Dictionary = followers[2]
		ok = _expect(str(gmax.get("sprite_classification", "")) == "missing", "Gmax form follower must be missing") and ok
		ok = _expect(str(gmax.get("sprite_url", "")) == "", "Gmax form follower must carry no sprite URL") and ok
	ok = _expect(controller.follower_sprite_classification(0) == "animated", "follower_sprite_classification(0) must be animated") and ok
	ok = _expect(controller.follower_sprite_classification(1) == "missing", "follower_sprite_classification(1) must be missing") and ok
	ok = _expect(controller.follower_sprite_classification(9) == "", "out-of-range classification must be empty") and ok
	var info: Dictionary = controller.follower_sprite_info(0)
	ok = _expect(str(info.get("classification", "")) == "animated" and not str(info.get("url", "")).is_empty(), "follower_sprite_info(0) must carry the animated binding") and ok
	# The binding travels with the behavior-layer output records.
	var ticked: Array = controller.behavior_tick(0.016, Vector2(100.0, 100.0), "down", false)
	ok = _expect(ticked.size() == 3, "behavior_tick must return 3 records") and ok
	if ticked.size() == 3:
		var first_tick: Dictionary = ticked[0]
		var second_tick: Dictionary = ticked[1]
		ok = _expect(str(first_tick.get("sprite_classification", "")) == "animated", "behavior output must carry Pikachu's classification") and ok
		ok = _expect(str(second_tick.get("sprite_classification", "")) == "missing", "behavior output must carry the MDX follower's missing classification") and ok
	controller.free()
	return ok


# (f) Future plug-in proof, with a labeled test fixture index
# written to user:// (NOT project data): a follower-marked
# animated entry resolves animated with its verbatim URL; a
# follower-marked animated entry that is a known dead link is
# never credited and the species falls back to static-only.
func test_future_animated_plugin() -> bool:
	# UPDATED by integration build 2 (2026-11-23): the fixture
	# used to ride on irontreads / ironboulder, back when those
	# species had no shipped follower art. Both are EBDX-bound
	# now (every base species is), so the fixture rides on two
	# forms with no shipped follower sheet instead -- the
	# plug-in proof is unchanged: a verified follower-marked
	# entry in an additional index resolves animated with its
	# verbatim URL, and a known-dead entry is never credited
	# (the dead-entry form falls back to its honest state:
	# missing, no URL -- form rows carry no still).
	# UPDATED by the consolidation build (2026-11-23): the
	# fixture's two forms swap again for the same reason --
	# venusaurgmax and charizardmegax are Willow-bound now, so
	# the fixture rides on rillaboomgmax / snorlaxgmax, which
	# still have no shipped follower sheet.
	var ok: bool = true
	var fixture: Dictionary = {
		"rows": [
			{
				"showdown_id": "rillaboomgmax", "sprite_slug": "rillaboom-gmax", "is_form": true,
				"sprites": [
					{"source": "test-overworld", "pattern": "overworld", "context": "follower", "url": "https://example.invalid/overworld/pikachu.gif", "animated": true, "verified_http_200": true, "shiny": false, "view": "front"},
				],
			},
			{
				"showdown_id": "snorlaxgmax", "sprite_slug": "snorlax-gmax", "is_form": true,
				"sprites": [
					{"source": "test-overworld", "pattern": "overworld", "context": "follower", "url": "https://example.invalid/overworld/bulbasaur.gif", "animated": true, "verified_http_200": false, "shiny": false, "view": "front"},
				],
			},
		],
	}
	var path: String = "user://follower_sprite_fixture_index.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _expect(false, "could not write the fixture index")
	file.store_string(JSON.stringify(fixture))
	file.close()
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	ok = _expect(resolver.load_follower_index_from(path), "fixture follower index must load") and ok
	var animated_result: Dictionary = resolver.resolve("rillaboomgmax")
	ok = _expect(str(animated_result.get("classification", "")) == "animated", "follower-marked animated entry must classify animated, got " + str(animated_result.get("classification", ""))) and ok
	ok = _expect(str(animated_result.get("url", "")) == "https://example.invalid/overworld/pikachu.gif", "animated URL must be the fixture URL verbatim") and ok
	ok = _expect(bool(animated_result.get("animated", false)), "animated result must flag animated true") and ok
	var dead_result: Dictionary = resolver.resolve("snorlaxgmax")
	ok = _expect(str(dead_result.get("classification", "")) == "missing", "known-dead animated entry must not be credited; snorlaxgmax stays honestly missing, got " + str(dead_result.get("classification", ""))) and ok
	ok = _expect(str(dead_result.get("url", "")) == "", "snorlaxgmax must return no URL (the dead fixture entry is not credited)") and ok
	return ok


## The test's OWN read of the shipped Willow follower index:
## showdown_id -> row.
func _willow_index_rows_by_id() -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://data/willow_follower_index.json")
	var parsed_value: Variant = JSON.parse_string(text)
	var by_id: Dictionary = {}
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var rows_value: Variant = parsed.get("rows", [])
		if rows_value is Array:
			var rows: Array = rows_value
			for row_value in rows:
				if row_value is Dictionary:
					var row: Dictionary = row_value
					by_id[str(row.get("showdown_id", ""))] = row
	return by_id


# (j) Willow form followers (consolidation build, 2026-11-23):
# the 76 form followers bound from Willow's "Gmax, Mega and
# Primal OW Sprites Pack + Extras" (Eevee Expo resource 1475)
# classify "animated" with the verbatim res:// sheet path from
# data/willow_follower_index.json and source_id
# "willow-ow-pack". The two deliberately unbound ambiguous
# cases (pidgeotmega via the misnamed PIDGEOTTO_1.png sheet,
# the Urshifu Gmax pair the wave-2 audit missed) stay missing.
func test_willow_form_followers() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var willow_by_id: Dictionary = _willow_index_rows_by_id()
	ok = _expect(willow_by_id.size() == 76, "Willow follower index must carry 76 rows (27 Gmax + 48 Mega/Primal + Mega Lucario Z), got " + str(willow_by_id.size())) and ok
	var sample: Array = [
		"venusaurgmax", "charizardmegax", "mewtwomegay",
		"kyogreprimal", "groudonprimal", "lucariomegaz",
		"corviknightgmax", "gengarmega", "toxtricitygmax",
	]
	for species_value in sample:
		var species: String = str(species_value)
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "animated", species + " follower classification must be animated (Willow), got " + str(result.get("classification", ""))) and ok
		ok = _expect(bool(result.get("animated", false)), species + " must be flagged animated as a follower") and ok
		ok = _expect(str(result.get("source_id", "")) == "willow-ow-pack", species + " source_id must be willow-ow-pack, got " + str(result.get("source_id", ""))) and ok
		ok = _expect(str(result.get("provenance", "")) == "source-animated", species + " provenance must be source-animated") and ok
		var row: Dictionary = willow_by_id.get(species, {})
		ok = _expect(not row.is_empty(), "Willow index must carry a row for " + species) and ok
		ok = _expect(str(result.get("url", "")) == _expected_walk_url(row), species + " follower URL must be the Willow index Walk entry verbatim (the res:// sheet path)") and ok
		var anims_value: Variant = result.get("verified_anims", [])
		var anims: Array = anims_value if anims_value is Array else []
		ok = _expect(anims.has("Walk"), species + " verified anims must include Walk") and ok
	for missing_value in ["pidgeotmega", "urshifugmax", "urshifurapidstrikegmax"]:
		var missing_species: String = str(missing_value)
		var missing_result: Dictionary = resolver.resolve(missing_species)
		ok = _expect(str(missing_result.get("classification", "")) == "missing", missing_species + " must stay missing (deliberately unbound, flagged in the Willow index), got " + str(missing_result.get("classification", ""))) and ok
		ok = _expect(str(missing_result.get("url", "")) == "", missing_species + " must return no URL") and ok
	return ok


# (k) Consolidation PMD upgrades (2026-11-23): the 21 PMD
# SpriteCollab rows appended from the wave-2 intake's new
# species folders classify "animated" through the PMD index --
# 20 base species whose PMD sets are richer than the HGSS/EBDX
# sources that served them before, plus the gimmighoulroaming
# form (folder 0999's only set depicts the Roaming form; it is
# bound to the form row, not to base gimmighoul). Six CHUNSOFT
# sets declare Idle in AnimData but ship no Idle-Anim.png;
# their rows carry the Walk entry only and are flagged partial.
# The 8 folders with no Walk set were not bound: their species
# keep resolving through EBDX.
func test_consolidation_pmd_upgrades() -> bool:
	var ok: bool = true
	var resolver: PUWFollowerSpriteResolver = PUWFollowerSpriteResolver.new()
	var by_id: Dictionary = _follower_index_rows_by_id()
	var community_sample: Array = ["miraidon", "milcery", "falinks", "pyroar", "jellicent", "orthworm"]
	for species_value in community_sample:
		var species: String = str(species_value)
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "animated", species + " follower classification must be animated (PMD upgrade), got " + str(result.get("classification", ""))) and ok
		ok = _expect(str(result.get("source_id", "")) == "pmd-spritecollab", species + " source_id must be pmd-spritecollab, got " + str(result.get("source_id", ""))) and ok
		var row: Dictionary = by_id.get(species, {})
		ok = _expect(not row.is_empty(), "follower index must carry the consolidation row for " + species) and ok
		ok = _expect(str(result.get("url", "")) == _expected_walk_url(row), species + " follower URL must be its follower-index Walk URL verbatim") and ok
		ok = _expect(not bool(result.get("partial", true)), species + " must not be flagged partial") and ok
	var chunsoft_sample: Array = ["beedrill", "dragonair", "lileep"]
	for species_value in chunsoft_sample:
		var species: String = str(species_value)
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "animated", species + " follower classification must be animated (CHUNSOFT PMD upgrade), got " + str(result.get("classification", ""))) and ok
		ok = _expect(str(result.get("source_id", "")) == "pmd-spritecollab-chunsoft", species + " source_id must be pmd-spritecollab-chunsoft, got " + str(result.get("source_id", ""))) and ok
		var row: Dictionary = by_id.get(species, {})
		ok = _expect(str(result.get("url", "")) == _expected_walk_url(row), species + " follower URL must be its follower-index Walk URL verbatim") and ok
		ok = _expect(bool(result.get("partial", false)), species + " must be flagged partial (its CHUNSOFT set ships no Idle-Anim.png)") and ok
	var hitmonchan_result: Dictionary = resolver.resolve("hitmonchan")
	ok = _expect(str(hitmonchan_result.get("source_id", "")) == "pmd-spritecollab-chunsoft", "hitmonchan source_id must be pmd-spritecollab-chunsoft, got " + str(hitmonchan_result.get("source_id", ""))) and ok
	ok = _expect(not bool(hitmonchan_result.get("partial", true)), "hitmonchan must not be flagged partial (its set ships an Idle sheet)") and ok
	var roaming_result: Dictionary = resolver.resolve("gimmighoulroaming")
	ok = _expect(str(roaming_result.get("classification", "")) == "animated", "gimmighoulroaming follower classification must be animated (PMD form row), got " + str(roaming_result.get("classification", ""))) and ok
	ok = _expect(str(roaming_result.get("source_id", "")) == "pmd-spritecollab", "gimmighoulroaming source_id must be pmd-spritecollab, got " + str(roaming_result.get("source_id", ""))) and ok
	var chest_result: Dictionary = resolver.resolve("gimmighoul")
	ok = _expect(str(chest_result.get("source_id", "")) == "ebdx1831", "base gimmighoul (Chest form) must keep its EBDX sheet, got " + str(chest_result.get("source_id", ""))) and ok
	var ebdx_kept: Array = ["stunfisk", "aromatisse", "toucannon", "dolliv", "grafaiai", "irontreads", "gougingfire", "ragingbolt"]
	for species_value in ebdx_kept:
		var species: String = str(species_value)
		var result: Dictionary = resolver.resolve(species)
		ok = _expect(str(result.get("classification", "")) == "animated", species + " must stay animated via EBDX (its PMD folder has no Walk set), got " + str(result.get("classification", ""))) and ok
		ok = _expect(str(result.get("source_id", "")) == "ebdx1831", species + " source_id must stay ebdx1831, got " + str(result.get("source_id", ""))) and ok
	return ok
