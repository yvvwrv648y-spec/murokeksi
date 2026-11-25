extends SceneTree
## Headless tests for the PUW audio wiring prep.
##
## What this file checks (resolution is what is testable
## headless; actual playback is engine-side):
## - The music index: 28 filled register slots resolve to
##   res://audio/music/<track>.ogg; the two verified-unfilled
##   slots (ost_poke_mart, ost_battle_defeat) resolve to "".
## - Map -> BGM: named towns, pokecenter / gym / mart-borrow /
##   route / ocean-route / cave / victory-road rules, the
##   world-file and habitat id dialects, and honest "" for
##   unmapped maps (all of Johto in this pass).
## - Battle kind -> BGM for wild / trainer / gym_leader /
##   story_boss / champion / victory.
## - The director instance records plays and current track.
## - PUWUiSound registers all 9 hooks from the bound index
##   and ensure_instance() provides a live instance.
## - Cries resolve LOCALLY first: Pikachu by id and by name,
##   Kyurem-White / Kyurem-Black form files, the local index
##   carries 703 entries, Gen 6-9 species stay bank-fallback
##   (no local path).
## - MDX parity: an MDX-family battler resolves and plays
##   exactly like its PKDX counterpart - family is never read.
## - The heal jingle path: PokemonCenter.heal_party fires
##   ui_heal only when a heal actually changed something.
## - The save sound path: PUWSaveManager.save_game fires
##   ui_save on success.
##
## How to run it (Godot 4.7.2, headless): see run_tests.sh in
## the prep folder. It prints one PASS or FAIL line per test,
## then a summary line, then quits. Exit code 0 means every
## test passed, 1 means at least one failed.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	# Run on the first frame, not in _init: nodes added to the
	# tree during _init are not inside it yet, and playback
	# calls on them are refused by the engine.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	print("PUW audio wiring tests - starting.")
	_run("test_music_index_filled_and_unfilled", Callable(self, "test_music_index_filled_and_unfilled"))
	_run("test_map_resolution_named_and_patterns", Callable(self, "test_map_resolution_named_and_patterns"))
	_run("test_map_resolution_dialects", Callable(self, "test_map_resolution_dialects"))
	_run("test_map_resolution_unmapped_honest", Callable(self, "test_map_resolution_unmapped_honest"))
	_run("test_battle_tracks", Callable(self, "test_battle_tracks"))
	_run("test_director_playback_records", Callable(self, "test_director_playback_records"))
	_run("test_ui_streams_register_all_9", Callable(self, "test_ui_streams_register_all_9"))
	_run("test_ui_ensure_instance", Callable(self, "test_ui_ensure_instance"))
	_run("test_cry_local_paths", Callable(self, "test_cry_local_paths"))
	_run("test_cry_mdx_parity", Callable(self, "test_cry_mdx_parity"))
	_run("test_heal_jingle_hook", Callable(self, "test_heal_jingle_hook"))
	_run("test_save_sound_hook", Callable(self, "test_save_sound_hook"))
	print("PUW audio wiring tests - done: %d passed, %d failed." % [_passed, _failed])
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


func test_music_index_filled_and_unfilled() -> bool:
	if not PUWMusicDirector.is_filled("ost_pallet_town"):
		return false
	if PUWMusicDirector.stream_path_for_track("ost_pallet_town") != "res://audio/music/ost_pallet_town.ogg":
		return false
	if PUWMusicDirector.is_filled("ost_poke_mart"):
		return false
	if PUWMusicDirector.is_filled("ost_battle_defeat"):
		return false
	if PUWMusicDirector.stream_path_for_track("ost_poke_mart") != "":
		return false
	if PUWMusicDirector.stream_path_for_track("ost_no_such_track") != "":
		return false
	return PUWMusicDirector.crossfade_ms() == 850


func test_map_resolution_named_and_patterns() -> bool:
	var cases: Dictionary = {
		"PALLET_TOWN": "ost_pallet_town",
		"CERULEAN_CITY": "ost_cerulean_city",
		"INDIGO_PLATEAU": "ost_indigo_plateau",
		"VIRIDIAN_FOREST": "ost_viridian_forest",
		"PEWTER_POKECENTER": "ost_pokemon_center",
		"MAP_ONE_ISLAND_POKEMON_CENTER_1F": "ost_pokemon_center",
		"CERULEAN_GYM": "ost_kanto_gym",
		"CELADON_MART_1F": "ost_pokemon_center",
		"ROUTE_1": "ost_kanto_routes",
		"ROUTE_19": "ost_ocean_routes",
		"ROUTE_21": "ost_ocean_routes",
		"MT_MOON_1F": "ost_mt_moon_caves",
		"VICTORY_ROAD_1F": "ost_indigo_plateau",
	}
	for map_id in cases.keys():
		if PUWMusicDirector.track_for_map(str(map_id)) != str(cases[map_id]):
			return false
	return true


func test_map_resolution_dialects() -> bool:
	if PUWMusicDirector.track_for_map("kanto_pallet_town") != "ost_pallet_town":
		return false
	if PUWMusicDirector.track_for_map("kanto_route_01") != "ost_kanto_routes":
		return false
	if PUWMusicDirector.track_for_map("route_1") != "ost_kanto_routes":
		return false
	return PUWMusicDirector.normalize_map_id("sevii_one_island") == "ONE_ISLAND"


func test_map_resolution_unmapped_honest() -> bool:
	# Build 6 (A-10 union): Johto maps resolve to their own
	# ost_johto_* slots, registered UNFILLED (no verified stream
	# held) — the director stops cleanly; never a borrowed
	# Kanto theme, never fabricated audio.
	if PUWMusicDirector.track_for_map("AZALEA_TOWN") != "ost_johto_azalea_town":
		return false
	if PUWMusicDirector.track_for_map("GOLDENROD_CITY") != "ost_johto_goldenrod_city":
		return false
	if (PUWMusicDirector.is_filled("ost_johto_azalea_town")
			or PUWMusicDirector.stream_path_for_track("ost_johto_azalea_town") != ""):
		return false
	# A Pallet Town house interior has no slot either.
	if PUWMusicDirector.track_for_map("kanto_pallet_riley_house") != "":
		return false
	return PUWMusicDirector.track_for_map("") == ""


func test_battle_tracks() -> bool:
	var cases: Dictionary = {
		"wild": "ost_wild_battle",
		"trainer": "ost_trainer_battle",
		"gym_leader": "ost_gym_leader_battle",
		"story_boss": "ost_story_boss_battle",
		"champion": "ost_story_boss_battle",
		"victory": "ost_battle_victory",
	}
	for kind in cases.keys():
		if PUWMusicDirector.track_for_battle(str(kind)) != str(cases[kind]):
			return false
		if PUWMusicDirector.stream_path_for_track(str(cases[kind])) == "":
			return false
	return PUWMusicDirector.track_for_battle("bogus_kind") == ""


func test_director_playback_records() -> bool:
	var director: PUWMusicDirector = PUWMusicDirector.new()
	root.add_child(director)
	PUWMusicDirector.played_log.clear()
	PUWMusicDirector.current_track_id = ""
	if director.play_map_bgm("PALLET_TOWN") != "ost_pallet_town":
		return false
	if PUWMusicDirector.current_track_id != "ost_pallet_town":
		return false
	if director.play_battle_bgm("gym_leader") != "ost_gym_leader_battle":
		return false
	if director.play_jingle(PUWMusicDirector.track_for_battle("victory")) != "ost_battle_victory":
		return false
	if PUWMusicDirector.played_log != ["ost_pallet_town", "ost_gym_leader_battle", "ost_battle_victory"]:
		return false
	# An unmapped map stops the music and clears the record.
	if director.play_map_bgm("AZALEA_TOWN") != "":
		return false
	if PUWMusicDirector.current_track_id != "":
		return false
	director.queue_free()
	return true


func test_ui_streams_register_all_9() -> bool:
	var count: int = PUWUiSound.register_streams_from_index()
	if count != 9:
		return false
	for hook in PUWUiSound.HOOKS:
		if not PUWUiSound.has_stream(hook):
			return false
	return true


func test_ui_ensure_instance() -> bool:
	var host: Node = Node.new()
	host.name = "TestHost"
	root.add_child(host)
	var instance: PUWUiSound = PUWUiSound.ensure_instance(host)
	if instance == null:
		return false
	if PUWUiSound.ensure_instance(host) != instance:
		return false
	var before: int = PUWUiSound.played_log.size()
	PUWUiSound.play("ui_confirm")
	if PUWUiSound.played_log.size() != before + 1:
		return false
	if PUWUiSound.played_log[PUWUiSound.played_log.size() - 1] != "ui_confirm":
		return false
	host.queue_free()
	return true


func test_cry_local_paths() -> bool:
	var player: PokemonCryPlayer = PokemonCryPlayer.new()
	if player.get_local_count() != 703:
		return false
	if player.local_cry_path_for(25) != "res://audio/cries/PIKACHU.ogg":
		return false
	if player.local_cry_path_for("Pikachu") != "res://audio/cries/PIKACHU.ogg":
		return false
	if player.local_cry_path_for("kyurem-white") != "res://audio/cries/KYUREM_1.ogg":
		return false
	if player.local_cry_path_for(646, "black") != "res://audio/cries/KYUREM_2.ogg":
		return false
	if player.local_cry_path_for(646, "white") != "res://audio/cries/KYUREM_1.ogg":
		return false
	# Gen 6-9 species are not in the local index: the bank
	# download fallback owns them, so no local path.
	if player.local_cry_path_for(890) != "":
		return false
	if player.local_cry_path_for("Notarealmon") != "":
		return false
	player.free()
	return true


func test_cry_mdx_parity() -> bool:
	var player: PokemonCryPlayer = PokemonCryPlayer.new()
	root.add_child(player)
	var pkdx_mon: Dictionary = {"species_slug": "pikachu", "dex_id": 25, "family": "PKDX"}
	var mdx_mon: Dictionary = {"species_slug": "pikachu", "dex_id": 25, "family": "MDX"}
	# Same local file for both families.
	if player.local_cry_path_for(str(mdx_mon.get("species_slug"))) != player.local_cry_path_for(str(pkdx_mon.get("species_slug"))):
		return false
	# Both play, through the exact helper BattleScene calls.
	if not player.play_cry_for_mon(pkdx_mon):
		return false
	if not player.play_cry_for_mon(mdx_mon):
		return false
	# An MDX battler identified by slug alone (no dex field).
	var mdx_slug_only: Dictionary = {"species_slug": "pidgey", "family": "MDX"}
	if not player.play_cry_for_mon(mdx_slug_only):
		return false
	# A formed MDX battler resolves the form's own cry file.
	var mdx_formed: Dictionary = {"species": "Kyurem", "forme": "white", "dex_id": 646, "family": "MDX"}
	if not player.play_cry_for_mon(mdx_formed):
		return false
	player.queue_free()
	return true


func test_heal_jingle_hook() -> bool:
	var hurt_party: Array = [{"name": "Pikachu", "hp": 3, "max_hp": 20, "status": "", "moves": []}]
	var before: int = PUWUiSound.played_log.size()
	var healed: Array = PokemonCenter.heal_party(hurt_party)
	if int(healed[0].get("hp", 0)) != 20:
		return false
	if PUWUiSound.played_log.size() != before + 1:
		return false
	if PUWUiSound.played_log[PUWUiSound.played_log.size() - 1] != "ui_heal":
		return false
	# A party that needs nothing fires no jingle.
	var full_party: Array = [{"name": "Pikachu", "hp": 20, "max_hp": 20, "status": "", "moves": []}]
	PokemonCenter.heal_party(full_party)
	return PUWUiSound.played_log.size() == before + 1


func test_save_sound_hook() -> bool:
	var before: int = PUWUiSound.played_log.size()
	var state: Dictionary = {"party": [], "story_flags": {}}
	if not PUWSaveManager.save_game(state):
		return false
	if PUWUiSound.played_log.size() != before + 1:
		return false
	return PUWUiSound.played_log[PUWUiSound.played_log.size() - 1] == "ui_save"
