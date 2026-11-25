extends SceneTree
## Headless tests for the PUW battle + cutscene SPRITE
## BINDING FIX (2026-11-23): the live battle presentation and
## the cutscene/story display entry point resolve through
## PUWPokemonSpriteBinding over ShinySpriteResolver --
## animated-first, forme-aware, with the resolver's
## unverified-xyani fall-through fixed.
##
## What is proven here:
## (a) Sampled species across generations resolve ANIMATED
##     battle URLs verbatim from the index (read independently
##     by this test), front and back.
## (b) Forme-awareness: a mon whose "forme" is set (Mega,
##     Gmax, Primal, Ultra samples) resolves to the forme's
##     own URL with a different cache key than its base form.
## (c) The name formats the old PUWSpriteLoader missed
##     (Iron-treads, Type: Null, Ho-Oh, Farfetch'd with the
##     curly apostrophe, tapu-koko, Mr. Mime) resolve to the
##     right index row, including via species_slug.
## (d) The 54 rows with no verified animated front never
##     yield the unverified xyani URL. UPDATED by integration
##     build 2 (2026-11-23): 35 of those rows (all forms) now
##     carry a LOCAL animated strip from the Open-Source EBDX
##     Renovation Project (Eevee Expo resource 1831), bound as
##     "ebdx1831" index entries -- for them the animated getter
##     returns the entry's res:// strip path verbatim and the
##     binding classifies "animated". The other 19 rows (14
##     base species + the 5 forms with no EBDX strip) keep the
##     original truth: the animated getter returns "" and the
##     binding returns the verified static fallback (base
##     species) or an honest missing (forms).
## (e) Cutscene binding (PUWCampaignStitch.pokemon_display_for
##     / cutscene_sprite_for_species) returns IDENTICAL
##     resolution to battle for sampled species and formes.
## (f) Fabrication guard: across a full sweep of all 1,422
##     index rows, every URL the binding returns exists
##     verbatim in the index data, none is an unchecked xyani
##     URL, and the classification counts are exactly
##     1,403 animated / 14 static-only / 5 missing (front,
##     non-shiny) -- UPDATED by integration build 2 from
##     1,368 / 14 / 40 (the 35 EBDX strips closed 35 of the 40
##     missing fronts; the 5 still missing are rockruffdusk,
##     ribombeetotem and the 3 non-canon rows).
## (g) The GIF decoder + loader plumbing: a known 1x1 GIF
##     decodes to one 1x1 frame, and loader cache paths carry
##     the resolved URL's own extension (.gif / .png).
##
## Run: godot --headless --script res://tests/battle_sprite_tests.gd
## Prints PASS/FAIL per test + a summary; exit 0 = all passed.
## Suite size: 8 tests (new suite, 2026-11-23).

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

## The 54 index rows with no verified animated front (from
## battle_cutscene_check.md Appendix A, front_normal list).
const FRONT_EXCEPTIONS: Array = [
	"absolmegaz", "baxcaliburmega", "blastoisegmax", "cinderacegmax",
	"darkraimega", "dialgaorigin", "garchompmegaz", "golisopodmega",
	"greninjabond", "heatranmega", "ironboulder", "ironbundle",
	"ironcrown", "ironhands", "ironjugulis", "ironleaves",
	"ironmoth", "ironthorns", "irontreads", "ironvaliant",
	"lucariomegaz", "magearnamega", "magearnaoriginalmega", "miraidon",
	"ogerpon", "ogerponcornerstone", "ogerponcornerstonetera",
	"ogerponhearthflame", "ogerponhearthflametera", "ogerpontealtera",
	"ogerponwellspring", "ogerponwellspringtera", "palkiaorigin",
	"pecharunt", "pichuspikyeared", "pikachuworld", "pokestarufopropu2",
	"ramnarokradiant", "ribombeetotem", "rillaboomgmax", "rockruffdusk",
	"tatsugiricurlymega", "tatsugiridroopymega", "tatsugiristretchymega",
	"terapagos", "terapagosstellar", "terapagosterastal",
	"toxtricitylowkeygmax", "urshifugmax", "urshifurapidstrikegmax",
	"venomiconepilogue", "venusaurgmax", "zeraoramega", "zygardemega",
]

## The 35 exception rows closed by LOCAL EBDX strips at
## integration build 2 (2026-11-23): each carries an
## "ebdx1831" sprite entry whose res:// path the animated
## getter returns. The other 19 FRONT_EXCEPTIONS rows (14 base
## species + rockruffdusk, ribombeetotem, pokestarufopropu2,
## ramnarokradiant, venomiconepilogue) keep the empty-getter
## truth.
const EBDX_CLOSED_EXCEPTIONS: Array = [
	"absolmegaz", "baxcaliburmega", "blastoisegmax", "cinderacegmax",
	"darkraimega", "dialgaorigin", "garchompmegaz", "golisopodmega",
	"greninjabond", "heatranmega", "lucariomegaz", "magearnamega",
	"magearnaoriginalmega", "ogerponcornerstone", "ogerponcornerstonetera",
	"ogerponhearthflame", "ogerponhearthflametera", "ogerpontealtera",
	"ogerponwellspring", "ogerponwellspringtera", "palkiaorigin",
	"pichuspikyeared", "pikachuworld", "rillaboomgmax",
	"tatsugiricurlymega", "tatsugiridroopymega", "tatsugiristretchymega",
	"terapagosstellar", "terapagosterastal", "toxtricitylowkeygmax",
	"urshifugmax", "urshifurapidstrikegmax", "venusaurgmax",
	"zeraoramega", "zygardemega",
]


func _init() -> void:
	print("PUW battle sprite tests -- starting.")
	_run("test_animated_samples_across_gens", Callable(self, "test_animated_samples_across_gens"))
	_run("test_forme_change_refresh", Callable(self, "test_forme_change_refresh"))
	_run("test_previously_missing_name_formats", Callable(self, "test_previously_missing_name_formats"))
	_run("test_exception_rows_no_xyani", Callable(self, "test_exception_rows_no_xyani"))
	_run("test_cutscene_matches_battle", Callable(self, "test_cutscene_matches_battle"))
	_run("test_fabrication_guard_sweep", Callable(self, "test_fabrication_guard_sweep"))
	_run("test_gif_decoder_and_loader_paths", Callable(self, "test_gif_decoder_and_loader_paths"))
	_run("test_honest_missing_and_static_fallback", Callable(self, "test_honest_missing_and_static_fallback"))
	print("PUW battle sprite tests -- done: %d passed, %d failed." % [_passed, _failed])
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
## of any resolver: showdown_id -> row.
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


## One sprite entry URL from a row, read directly from the
## index data by the test (never via the resolver).
func _expected_url(row: Dictionary, source: String, pattern: String) -> String:
	var sprites_value: Variant = row.get("sprites", [])
	if sprites_value is Array:
		var sprites: Array = sprites_value
		for entry_value in sprites:
			if entry_value is Dictionary:
				var entry: Dictionary = entry_value
				if str(entry.get("source", "")) == source and str(entry.get("pattern", "")) == pattern:
					return str(entry.get("url", ""))
	return ""


# (a) Animated samples across generations, front and back,
# normal and shiny: the binding's URL is the index's own
# verified animated entry, verbatim.
func test_animated_samples_across_gens() -> bool:
	var ok: bool = true
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var by_id: Dictionary = _index_rows_by_id()
	var sample: Array = [
		"bulbasaur", "charizard", "pikachu", "gengar",
		"cyndaquil", "ampharos", "mudkip", "gardevoir",
		"turtwig", "lucario", "snivy", "volcarona",
		"chespin", "greninja", "rowlet", "mimikyu",
		"grookey", "toxtricity", "sprigatito", "tinkaton",
	]
	for species_value in sample:
		var species: String = str(species_value)
		var row: Dictionary = by_id.get(species, {})
		var front: Dictionary = binding.resolve_species(species, "", false, "battle", false)
		ok = _expect(str(front.get("classification", "")) == "animated", species + " battle front must be animated, got " + str(front.get("classification", ""))) and ok
		ok = _expect(str(front.get("url", "")) == _expected_url(row, "showdown", "ani"), species + " front URL must be the index ani URL verbatim") and ok
		ok = _expect(bool(front.get("animated", false)), species + " must flag animated") and ok
		var back: Dictionary = binding.resolve_species(species, "", false, "battle", true)
		ok = _expect(str(back.get("classification", "")) == "animated", species + " battle back must be animated") and ok
		ok = _expect(str(back.get("url", "")) == _expected_url(row, "showdown", "ani-back"), species + " back URL must be the index ani-back URL verbatim") and ok
		var shiny_front: Dictionary = binding.resolve_species(species, "", true, "battle", false)
		ok = _expect(str(shiny_front.get("url", "")) == _expected_url(row, "showdown", "ani-shiny"), species + " shiny front URL must be the index ani-shiny URL verbatim") and ok
	return ok


# (b) Forme-awareness: setting mon["forme"] re-resolves to
# the forme's own art and changes the cache key the battle
# scene keys on. Mega + Gmax + Primal + Ultra samples.
func test_forme_change_refresh() -> bool:
	var ok: bool = true
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var by_id: Dictionary = _index_rows_by_id()
	var cases: Array = [
		{"species": "Charizard", "forme": "Charizard-Mega-X", "row": "charizardmegax"},
		{"species": "Charizard", "forme": "Charizard-Gmax", "row": "charizardgmax"},
		{"species": "Gengar", "forme": "Gengar-Gmax", "row": "gengargmax"},
		{"species": "Groudon", "forme": "Groudon-Primal", "row": "groudonprimal"},
		{"species": "Kyogre", "forme": "Kyogre-Primal", "row": "kyogreprimal"},
		{"species": "Necrozma", "forme": "Necrozma-Ultra", "row": "necrozmaultra"},
		{"species": "Lucario", "forme": "Lucario-Mega", "row": "lucariomega"},
	]
	for case_value in cases:
		var case_data: Dictionary = case_value
		var base_mon: Dictionary = {"species": str(case_data["species"]), "shiny": false}
		var forme_mon: Dictionary = {"species": str(case_data["species"]), "forme": str(case_data["forme"]), "shiny": false}
		var base_result: Dictionary = binding.resolve_for_mon(base_mon, "battle", false)
		var forme_result: Dictionary = binding.resolve_for_mon(forme_mon, "battle", false)
		var row: Dictionary = by_id.get(str(case_data["row"]), {})
		ok = _expect(str(forme_result.get("showdown_id", "")) == str(case_data["row"]), str(case_data["forme"]) + " must resolve to its own row") and ok
		ok = _expect(str(forme_result.get("classification", "")) == "animated", str(case_data["forme"]) + " must be animated") and ok
		ok = _expect(str(forme_result.get("url", "")) == _expected_url(row, "showdown", "ani"), str(case_data["forme"]) + " URL must be the forme's index ani URL verbatim") and ok
		ok = _expect(str(forme_result.get("url", "")) != str(base_result.get("url", "")), str(case_data["forme"]) + " URL must differ from the base form's") and ok
		ok = _expect(str(forme_result.get("cache_key", "")) != str(base_result.get("cache_key", "")), str(case_data["forme"]) + " cache key must differ from the base form's (forme-change refresh)") and ok
		# Back view (the player's side) is forme-aware too.
		var forme_back: Dictionary = binding.resolve_for_mon(forme_mon, "battle", true)
		ok = _expect(str(forme_back.get("url", "")) == _expected_url(row, "showdown", "ani-back"), str(case_data["forme"]) + " back URL must be the forme's ani-back URL") and ok
	# A partial forme value combines with the species.
	var partial: Dictionary = binding.resolve_for_mon({"species": "Urshifu", "forme": "Rapid-Strike", "shiny": false}, "battle", false)
	ok = _expect(str(partial.get("showdown_id", "")) == "urshifurapidstrike", "partial forme Rapid-Strike must combine with Urshifu, got " + str(partial.get("showdown_id", ""))) and ok
	return ok


# (c) The loader's old name misses resolve through the
# binding: TeamBuilder-style names, display names, and the
# species_slug field the loader ignored.
func test_previously_missing_name_formats() -> bool:
	var ok: bool = true
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var by_id: Dictionary = _index_rows_by_id()
	var cases: Array = [
		{"mon": {"species": "Iron-treads", "species_slug": "iron-treads"}, "row": "irontreads"},
		{"mon": {"species": "Iron Treads"}, "row": "irontreads"},
		{"mon": {"species": "Type: Null"}, "row": "typenull"},
		{"mon": {"species": "type-null", "species_slug": "type-null"}, "row": "typenull"},
		{"mon": {"species": "Ho-Oh"}, "row": "hooh"},
		{"mon": {"species": "Farfetch’d"}, "row": "farfetchd"},
		{"mon": {"species": "tapu-koko"}, "row": "tapukoko"},
		{"mon": {"species": "Tapu Koko"}, "row": "tapukoko"},
		{"mon": {"species": "Mr. Mime"}, "row": "mrmime"},
		{"mon": {"species": "mr-mime", "species_slug": "mr-mime"}, "row": "mrmime"},
		{"mon": {"species": "Flabébé"}, "row": "flabebe"},
		{"mon": {"species": "zygarde-50", "species_slug": "zygarde-50"}, "row": "zygarde"},
		{"mon": {"species": "Porygon-Z"}, "row": "porygonz"},
		{"mon": {"species": "Kommo-o"}, "row": "kommoo"},
	]
	for case_value in cases:
		var case_data: Dictionary = case_value
		var mon: Dictionary = case_data["mon"]
		var result: Dictionary = binding.resolve_for_mon(mon, "battle", false)
		var label: String = str(mon.get("species", ""))
		ok = _expect(str(result.get("showdown_id", "")) == str(case_data["row"]), label + " must resolve to row " + str(case_data["row"]) + ", got " + str(result.get("showdown_id", ""))) and ok
		ok = _expect(str(result.get("classification", "")) != "missing" or str(case_data["row"]) == "irontreads", label + " must not be missing") and ok
		if str(case_data["row"]) == "irontreads":
			# Iron Treads has no verified animated front: the
			# honest result is the index's static front PNG.
			var row: Dictionary = by_id.get("irontreads", {})
			ok = _expect(str(result.get("classification", "")) == "static-only", "Iron Treads must be static-only, got " + str(result.get("classification", ""))) and ok
			ok = _expect(str(result.get("url", "")) == _expected_url(row, "pokeapi", "front"), "Iron Treads URL must be the index front PNG verbatim") and ok
	return ok


# (d) The 54 exception rows: the animated front getter never
# returns the unverified xyani URL, and the binding never
# surfaces a xyani URL either. Split by integration build 2:
# the 35 EBDX-closed rows return their local strip path and
# classify animated; the other 19 keep the original truth --
# the getter returns "", base species fall back to their
# indexed still, forms are honestly missing.
func test_exception_rows_no_xyani() -> bool:
	var ok: bool = true
	var resolver: ShinySpriteResolver = ShinySpriteResolver.new()
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var by_id: Dictionary = _index_rows_by_id()
	ok = _expect(FRONT_EXCEPTIONS.size() == 54, "the exception list must carry 54 rows") and ok
	ok = _expect(EBDX_CLOSED_EXCEPTIONS.size() == 35, "the EBDX-closed list must carry 35 rows") and ok
	for id_value in FRONT_EXCEPTIONS:
		var sid: String = str(id_value)
		var row: Dictionary = by_id.get(sid, {})
		var display_name: String = str(row.get("name", sid))
		var animated_url: String = resolver.get_normal_sprite_url(display_name, false)
		ok = _expect(not animated_url.contains("/xyani/"), sid + " animated getter must not return an xyani URL, got " + animated_url) and ok
		var result: Dictionary = binding.resolve_species(display_name, "", false, "battle", false)
		var url: String = str(result.get("url", ""))
		ok = _expect(not url.contains("/xyani/"), sid + " binding must not return an xyani URL") and ok
		if EBDX_CLOSED_EXCEPTIONS.has(sid):
			var ebdx_url: String = _expected_url(row, "ebdx1831", "ani")
			ok = _expect(not ebdx_url.is_empty(), sid + " must carry an ebdx1831 ani entry in the index") and ok
			ok = _expect(animated_url == ebdx_url, sid + " animated front must be its EBDX strip path verbatim, got " + animated_url) and ok
			ok = _expect(str(result.get("classification", "")) == "animated", "form " + sid + " must classify animated via its EBDX strip, got " + str(result.get("classification", ""))) and ok
			ok = _expect(url == ebdx_url, "form " + sid + " binding URL must be its EBDX strip path verbatim") and ok
		else:
			ok = _expect(animated_url == "", sid + " animated front must be honestly empty, got " + animated_url) and ok
			if bool(row.get("is_form", false)):
				ok = _expect(str(result.get("classification", "")) == "missing" and url == "", "form " + sid + " must be honestly missing (no sprite at all), got " + str(result.get("classification", ""))) and ok
			else:
				ok = _expect(str(result.get("classification", "")) == "static-only", "base " + sid + " must fall back to static-only, got " + str(result.get("classification", ""))) and ok
				ok = _expect(url == _expected_url(row, "pokeapi", "front"), "base " + sid + " fallback must be the index front PNG verbatim") and ok
		# The resolver's own best-url getter must not hand back
		# the dead xyani URL for these rows either.
		var best: String = resolver.get_sprite_url(display_name, false, false)
		ok = _expect(not best.contains("/xyani/"), sid + " get_sprite_url must not return an xyani URL") and ok
	return ok


# (e) Cutscene == battle: the campaign stitch's Pokemon
# display entry points return the identical URL,
# classification and cache key as the battle context for the
# same mon -- one resolver, no separate path.
func test_cutscene_matches_battle() -> bool:
	var ok: bool = true
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var mons: Array = [
		{"species": "Pikachu", "shiny": false},
		{"species": "Charizard", "forme": "Charizard-Mega-X", "shiny": false},
		{"species": "Venusaur", "forme": "Venusaur-Gmax", "shiny": false},
		{"species": "Iron-treads", "species_slug": "iron-treads", "shiny": false},
		{"species": "Groudon", "forme": "Groudon-Primal", "shiny": true},
		{"species": "Miraidon", "shiny": false},
	]
	for mon_value in mons:
		var mon: Dictionary = mon_value
		var battle: Dictionary = binding.resolve_for_mon(mon, "battle", false)
		var cutscene: Dictionary = PUWCampaignStitch.pokemon_display_for(mon)
		var label: String = str(mon.get("species", "")) + "/" + str(mon.get("forme", ""))
		ok = _expect(str(cutscene.get("context", "")) == "cutscene", label + " stitch result must carry the cutscene context") and ok
		ok = _expect(str(cutscene.get("url", "")) == str(battle.get("url", "")), label + " cutscene URL must equal battle URL") and ok
		ok = _expect(str(cutscene.get("classification", "")) == str(battle.get("classification", "")), label + " cutscene classification must equal battle") and ok
		ok = _expect(str(cutscene.get("cache_key", "")) == str(battle.get("cache_key", "")), label + " cutscene cache key must equal battle") and ok
	# The species-level stitch entry point agrees too.
	var via_species: Dictionary = PUWCampaignStitch.cutscene_sprite_for_species("Charizard", "Charizard-Mega-X")
	var battle_forme: Dictionary = binding.resolve_for_mon({"species": "Charizard", "forme": "Charizard-Mega-X"}, "battle", false)
	ok = _expect(str(via_species.get("url", "")) == str(battle_forme.get("url", "")), "cutscene_sprite_for_species must match battle for Charizard-Mega-X") and ok
	ok = _expect(str(via_species.get("classification", "")) == "animated", "Charizard-Mega-X cutscene must be animated") and ok
	return ok


# (f) Fabrication guard + counts over the full index: every
# URL returned for every one of the 1,422 rows (front,
# non-shiny, by display name) exists verbatim in the index
# data read independently here; no URL is an unchecked xyani
# URL; the counts match the check's verified numbers.
func test_fabrication_guard_sweep() -> bool:
	var ok: bool = true
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
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
	ok = _expect(rows.size() == 1422, "index must carry 1,422 rows, got " + str(rows.size())) and ok
	var counts: Dictionary = {"animated": 0, "static-only": 0, "missing": 0}
	for row_value in rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var display_name: String = str(row.get("name", ""))
		var result: Dictionary = binding.resolve_species(display_name, "", false, "battle", false)
		var url: String = str(result.get("url", ""))
		var classification: String = str(result.get("classification", ""))
		counts[classification] = int(counts.get(classification, 0)) + 1
		ok = _expect(str(result.get("showdown_id", "")) == str(row.get("showdown_id", "")), "row " + str(row.get("showdown_id", "")) + " must resolve to itself, got " + str(result.get("showdown_id", ""))) and ok
		if not url.is_empty():
			ok = _expect(all_urls.has(url), "fabrication guard: binding URL for " + str(row.get("showdown_id", "")) + " is not verbatim in the index") and ok
			ok = _expect(not url.contains("/sprites/xyani/"), "binding URL for " + str(row.get("showdown_id", "")) + " must not be an unchecked xyani URL") and ok
	ok = _expect(int(counts.get("animated", -1)) == 1403, "animated count must be 1,403 (1,368 + 35 EBDX strips), got " + str(counts.get("animated", -1))) and ok
	ok = _expect(int(counts.get("static-only", -1)) == 14, "static-only count must be 14, got " + str(counts.get("static-only", -1))) and ok
	ok = _expect(int(counts.get("missing", -1)) == 5, "missing count must be 5 (rockruffdusk, ribombeetotem, 3 non-canon rows), got " + str(counts.get("missing", -1))) and ok
	return ok


# (g) Decoder + loader plumbing: the known 43-byte 1x1
# transparent GIF decodes to exactly one 1x1 frame; a corrupt
# input fails honestly; loader cache paths take the resolved
# URL's extension, so animated GIFs and still PNGs cache as
# different files for the same row.
func test_gif_decoder_and_loader_paths() -> bool:
	var ok: bool = true
	var gif_bytes: PackedByteArray = PackedByteArray([
		0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00,
		0x80, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x21,
		0xF9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00,
		0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44,
		0x01, 0x00, 0x3B,
	])
	var decoded: Dictionary = PUWGifDecoder.decode(gif_bytes)
	ok = _expect(bool(decoded.get("ok", false)), "the 1x1 GIF fixture must decode") and ok
	ok = _expect(int(decoded.get("width", 0)) == 1 and int(decoded.get("height", 0)) == 1, "decoded size must be 1x1") and ok
	var frames: Array = decoded.get("frames", [])
	ok = _expect(frames.size() == 1, "decoded frame count must be 1, got " + str(frames.size())) and ok
	var bad: Dictionary = PUWGifDecoder.decode(PackedByteArray([0x00, 0x01, 0x02, 0x03]))
	ok = _expect(not bool(bad.get("ok", true)), "corrupt bytes must not decode") and ok
	var loader: PUWSpriteLoader = PUWSpriteLoader.new()
	var gif_path: String = loader.cache_path_for_key("pikachu_front", "https://play.pokemonshowdown.com/sprites/ani/pikachu.gif")
	ok = _expect(gif_path.ends_with("pikachu_front.gif"), "animated cache path must end .gif, got " + gif_path) and ok
	var png_path: String = loader.cache_path_for_key("pikachu_front", "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png")
	ok = _expect(png_path.ends_with("pikachu_front.png"), "still cache path must end .png, got " + png_path) and ok
	# The loader resolves its legacy path through the binding.
	var via_loader: Dictionary = loader.binding().resolve_species("pikachu", "", false, "battle", false)
	ok = _expect(str(via_loader.get("classification", "")) == "animated", "loader binding must resolve pikachu animated") and ok
	loader.free()
	return ok


# Honest ends of the scale: an unknown species is missing
# with no URL (never invented), a front-only Mega's back view
# is missing (no back art, no still for a form), and its front
# view is animated -- the 24 front-only Megas behave exactly
# this way.
func test_honest_missing_and_static_fallback() -> bool:
	var ok: bool = true
	var binding: PUWPokemonSpriteBinding = PUWPokemonSpriteBinding.new()
	var unknown: Dictionary = binding.resolve_species("notarealspecies", "", false, "battle", false)
	ok = _expect(str(unknown.get("classification", "")) == "missing", "unknown species must be missing") and ok
	ok = _expect(str(unknown.get("url", "")) == "", "unknown species must return no URL") and ok
	var front_only_front: Dictionary = binding.resolve_species("Barbaracle-Mega", "", false, "battle", false)
	ok = _expect(str(front_only_front.get("classification", "")) == "animated", "Barbaracle-Mega front must be animated") and ok
	var front_only_back: Dictionary = binding.resolve_species("Barbaracle-Mega", "", false, "battle", true)
	ok = _expect(str(front_only_back.get("classification", "")) == "missing", "Barbaracle-Mega back must be honestly missing (front-only Mega), got " + str(front_only_back.get("classification", ""))) and ok
	ok = _expect(str(front_only_back.get("url", "")) == "", "Barbaracle-Mega back must return no URL") and ok
	# Miraidon: no verified normal animated front, but its
	# shiny front DOES have a verified Gen-5-style animated
	# entry -- shiny resolves animated, normal static-only.
	var miraidon_normal: Dictionary = binding.resolve_species("Miraidon", "", false, "battle", false)
	ok = _expect(str(miraidon_normal.get("classification", "")) == "static-only", "Miraidon normal front must be static-only") and ok
	var miraidon_shiny: Dictionary = binding.resolve_species("Miraidon", "", true, "battle", false)
	ok = _expect(str(miraidon_shiny.get("classification", "")) == "animated", "Miraidon shiny front must be animated (verified gen5ani-shiny), got " + str(miraidon_shiny.get("classification", ""))) and ok
	ok = _expect(str(miraidon_shiny.get("url", "")).contains("/gen5ani-shiny/"), "Miraidon shiny URL must be the verified gen5ani-shiny entry") and ok
	return ok
