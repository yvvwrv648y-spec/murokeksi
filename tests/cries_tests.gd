extends SceneTree
## Offline tests for the Pokemon Ultimate World cries manager.
##
## What this file checks:
## - The cry bank loads with all 1,025 species.
## - A dex id and a species name give the same cry link.
## - The link for Pikachu (id 25) is the real PokeAPI cries link.
## - An unknown species gives an empty link.
## - A cache path lives under user:// and an uncached cry
##   reports that it is not cached.
## - Playing an unknown species cry returns false.
##
## No test uses the network. Downloads are not started here.
##
## How to run it (Godot 4.7, headless):
## Put cries_manager.gd at res://pokemon/cries/cries_manager.gd,
## cries_bank.json at res://audio/cries/cries_bank.json, and this
## file at res://tests/cries_tests.gd, then run:
##   godot --headless --script res://tests/cries_tests.gd
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed.

const EXPECTED_PIKACHU_URL: String = "https://raw.githubusercontent.com/PokeAPI/cries/main/cries/pokemon/latest/25.ogg"

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []
var _player: PokemonCryPlayer = null


func _init() -> void:
	print("PUW cries manager tests - starting.")
	_player = PokemonCryPlayer.new()
	_run("test_bank_loads_1025_entries", Callable(self, "test_bank_loads_1025_entries"))
	_run("test_url_by_id_and_by_name_match", Callable(self, "test_url_by_id_and_by_name_match"))
	_run("test_pikachu_url_is_real_pokeapi_url", Callable(self, "test_pikachu_url_is_real_pokeapi_url"))
	_run("test_name_normalization_mr_mime", Callable(self, "test_name_normalization_mr_mime"))
	_run("test_unknown_species_returns_empty_url", Callable(self, "test_unknown_species_returns_empty_url"))
	_run("test_cache_path_and_is_cached", Callable(self, "test_cache_path_and_is_cached"))
	_run("test_play_cry_unknown_returns_false", Callable(self, "test_play_cry_unknown_returns_false"))
	_player.free()
	_player = null
	print("PUW cries manager tests - done: %d passed, %d failed." % [_passed, _failed])
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


func test_bank_loads_1025_entries() -> bool:
	return _player.get_bank_count() == 1025


func test_url_by_id_and_by_name_match() -> bool:
	var by_id: String = _player.cry_url_for(25)
	var by_name: String = _player.cry_url_for("Pikachu")
	var by_string_id: String = _player.cry_url_for("25")
	return by_id != "" and by_id == by_name and by_id == by_string_id


func test_pikachu_url_is_real_pokeapi_url() -> bool:
	return _player.cry_url_for(25) == EXPECTED_PIKACHU_URL


func test_name_normalization_mr_mime() -> bool:
	var by_display: String = _player.cry_url_for("Mr. Mime")
	var by_slug: String = _player.cry_url_for("mr-mime")
	var by_id: String = _player.cry_url_for(122)
	return by_id != "" and by_display == by_id and by_slug == by_id


func test_unknown_species_returns_empty_url() -> bool:
	return _player.cry_url_for("Notarealmon") == "" and _player.cry_url_for(9999) == ""


func test_cache_path_and_is_cached() -> bool:
	var path: String = _player.cache_path_for(1025)
	if not path.begins_with("user://"):
		return false
	if not path.ends_with("1025.ogg"):
		return false
	return _player.is_cached(1025) == false


func test_play_cry_unknown_returns_false() -> bool:
	return _player.play_cry("Notarealmon") == false
