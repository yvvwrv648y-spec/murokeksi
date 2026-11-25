extends Node
## Audio bus layout + cry-player binding prep tests.
##
## Drives the REAL patched files against the REAL modules:
## - default_bus_layout.tres, applied by the engine from the
##   test project's [audio] setting (the exact section this
##   prep's patched/project.godot adds): Master + Music / SFX /
##   Cries / UI, every bus sent to Master, volumes neutral.
## - PUWMusicDirector (bus-patched copy): BGM + jingle players
##   ride "Music", stream assignment asserted on a real play.
## - PUWUiSound (bus-patched copy): its four players ride "UI";
##   the 9-hook registration is unchanged.
## - PUWGameSettings.apply_audio + the real PUWOptionsScreen
##   (ui_screens production, unmodified): the Music / SFX
##   toggles now find their buses by name and flip the real
##   AudioServer mutes; Master is never touched.
## - PUWMenuHost (this prep's copy): owns a PokemonCryPlayer
##   flagged local_only and binds it to the real
##   PUWPokedexScreen; a caught Bulbasaur's Cry press plays
##   the bound local file through it; MDX-family mons resolve
##   and play identically to PKDX (family is never read); an
##   uncovered species returns false with no HTTPRequest ever
##   created and nothing downloaded.
##
## Prints one PASS/FAIL line per check and a final
## AUDIO_BUS_TESTS summary; exit code = failures (capped).

var _pass: int = 0
var _fail: int = 0
var _failures: Array[String] = []


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("PASS ", name)
	else:
		_fail += 1
		_failures.append(name + (" :: " + detail if detail != "" else ""))
		print("FAIL ", name, " :: ", detail)


## A real save state in PUWSaveManager's own shape (the
## ui_screens fixture): party of 3, 3 seen / 1 caught.
func _real_state() -> Dictionary:
	var party: Array = [
		{"species": "bulbasaur", "name": "Bulbasaur", "level": 5},
		{"species": "squirtle", "name": "Squirtle", "level": 5},
		{"species": "pikachu", "name": "Pikachu", "level": 6},
	]
	return PUWSaveManager.build_state(
		party, [], {}, 12345,
		[{"name": "Boulder Badge"}, {"name": "Cascade Badge"}],
		["bulbasaur", "squirtle", "pikachu"], ["bulbasaur"],
		{}, {"name": "Riley"})


func _ready() -> void:
	await get_tree().process_frame
	_test_bus_layout()
	_test_director()
	await _test_ui_sound()
	await _test_host()
	await get_tree().process_frame
	await get_tree().process_frame
	print("AUDIO_BUS_TESTS passed=", _pass, " failed=", _fail)
	for failure in _failures:
		print("FAILED: ", failure)
	get_tree().quit(mini(_fail, 125))


# ------------------------------------------------------------------
# The layout file + the engine-applied bus structure
# ------------------------------------------------------------------

func _test_bus_layout() -> void:
	var layout: Resource = ResourceLoader.load("res://default_bus_layout.tres")
	_check("layout_loads", layout is AudioBusLayout,
		"loaded=" + str(layout))
	# The applied structure is the engine's own truth: five
	# buses on the server, named as the layout names them.
	_check("layout_bus_count", AudioServer.get_bus_count() == 5,
		"server_buses=" + str(AudioServer.get_bus_count()))
	var names: Array[String] = ["Music", "SFX", "Cries", "UI"]
	var names_ok: bool = true
	for i in names.size():
		if AudioServer.get_bus_name(i + 1) != names[i]:
			names_ok = false
	_check("layout_bus_names", names_ok)
	# The resource itself carries the same names, sends and
	# neutral volumes in its own bus/N property fields.
	var resource_ok: bool = layout is AudioBusLayout
	if layout is AudioBusLayout:
		for i in names.size():
			var idx: int = i + 1
			var name_value: Variant = layout.get("bus/%d/name" % idx)
			var send_value: Variant = layout.get("bus/%d/send" % idx)
			var vol_value: Variant = layout.get("bus/%d/volume_db" % idx)
			if str(name_value) != names[i] or str(send_value) != "Master":
				resource_ok = false
			if vol_value is float and absf(float(vol_value)) > 0.01:
				resource_ok = false
	_check("layout_resource_fields", resource_ok)
	_check("bus_index_master", AudioServer.get_bus_index("Master") == 0,
		"master=" + str(AudioServer.get_bus_index("Master")))
	_check("bus_index_music", AudioServer.get_bus_index("Music") == 1,
		"music=" + str(AudioServer.get_bus_index("Music")))
	_check("bus_index_sfx", AudioServer.get_bus_index("SFX") == 2,
		"sfx=" + str(AudioServer.get_bus_index("SFX")))
	_check("bus_index_cries", AudioServer.get_bus_index("Cries") == 3,
		"cries=" + str(AudioServer.get_bus_index("Cries")))
	_check("bus_index_ui", AudioServer.get_bus_index("UI") == 4,
		"ui=" + str(AudioServer.get_bus_index("UI")))
	var sends_ok: bool = true
	for idx in range(1, 5):
		if str(AudioServer.get_bus_send(idx)) != "Master":
			sends_ok = false
	_check("bus_sends_master", sends_ok)
	var neutral_ok: bool = true
	for idx in range(0, 5):
		if absf(AudioServer.get_bus_volume_db(idx)) > 0.01:
			neutral_ok = false
		if AudioServer.is_bus_mute(idx) or AudioServer.is_bus_solo(idx):
			neutral_ok = false
	_check("bus_volumes_neutral", neutral_ok)


# ------------------------------------------------------------------
# Music director on the Music bus
# ------------------------------------------------------------------

func _test_director() -> void:
	var director := PUWMusicDirector.new()
	add_child(director)
	PUWMusicDirector.played_log.clear()
	PUWMusicDirector.current_track_id = ""
	_check("director_plays_map_track",
		director.play_map_bgm("PALLET_TOWN") == "ost_pallet_town",
		"current=" + PUWMusicDirector.current_track_id)
	_check("director_bgm_bus", director._bgm_player != null
		and director._bgm_player.bus == "Music",
		"bus=" + (director._bgm_player.bus if director._bgm_player != null else "<null>"))
	_check("director_bgm_stream", director._bgm_player != null
		and director._bgm_player.stream != null
		and director._bgm_player.stream.resource_path == "res://audio/music/ost_pallet_town.ogg",
		"stream=" + str(director._bgm_player.stream))
	_check("director_jingle_plays",
		director.play_jingle(PUWMusicDirector.track_for_battle("victory")) == "ost_battle_victory")
	_check("director_jingle_bus", director._jingle_player != null
		and director._jingle_player.bus == "Music",
		"bus=" + (director._jingle_player.bus if director._jingle_player != null else "<null>"))
	_check("director_jingle_stream", director._jingle_player != null
		and director._jingle_player.stream != null
		and director._jingle_player.stream.resource_path == "res://audio/music/ost_battle_victory.ogg",
		"stream=" + str(director._jingle_player.stream))
	director.queue_free()


# ------------------------------------------------------------------
# UI sound players on the UI bus
# ------------------------------------------------------------------

func _test_ui_sound() -> void:
	var host_node := Node.new()
	host_node.name = "UiSoundHost"
	add_child(host_node)
	var instance: PUWUiSound = PUWUiSound.ensure_instance(host_node)
	await get_tree().process_frame
	_check("ui_sound_players_exist", instance != null and instance._players.size() == 4,
		"players=" + (str(instance._players.size()) if instance != null else "<null>"))
	var buses_ok: bool = instance != null
	if instance != null:
		for player_value in instance._players:
			var player: AudioStreamPlayer = player_value
			if player.bus != "UI":
				buses_ok = false
	_check("ui_sound_players_on_ui_bus", buses_ok)
	_check("ui_sound_registration_unchanged",
		PUWUiSound.register_streams_from_index() == 9,
		"registered=" + str(PUWUiSound.register_streams_from_index()))
	host_node.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------------------
# The real menu host: options toggles end-to-end + the dex cry
# ------------------------------------------------------------------

func _test_host() -> void:
	var state: Dictionary = _real_state()
	var host := PUWMenuHost.new()
	add_child(host)
	await get_tree().process_frame
	host.bind_state(state)

	# The cry player binding (this prep's menu_host addition).
	_check("host_cry_player_exists", host.cry_player != null)
	_check("host_cry_player_local_only", host.cry_player != null
		and host.cry_player.local_only,
		"local_only=" + (str(host.cry_player.local_only) if host.cry_player != null else "<null>"))
	_check("host_cry_player_bound_to_dex", host.cry_player != null
		and host.pokedex_screen._cry_player == host.cry_player)
	_check("host_cry_player_on_cries_bus", host.cry_player != null
		and host.cry_player._player != null
		and host.cry_player._player.bus == "Cries",
		"bus=" + (host.cry_player._player.bus if host.cry_player != null and host.cry_player._player != null else "<null>"))

	# Options: the model now finds both buses by name.
	var applied: Dictionary = PUWGameSettings.apply_audio(state)
	_check("apply_audio_finds_buses",
		str(applied.get("music_bus", "")) == "Music"
		and str(applied.get("sfx_bus", "")) == "SFX"
		and bool(applied.get("music_applied", false))
		and bool(applied.get("sfx_applied", false)),
		str(applied))
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	# Options: the Music toggle flips the real bus mute, and
	# the screen stops reporting a missing bus.
	host.options_screen.toggle_music()
	_check("options_music_toggle_mutes_bus",
		AudioServer.is_bus_mute(music_idx)
		and not PUWGameSettings.music_on(state),
		"muted=" + str(AudioServer.is_bus_mute(music_idx)))
	_check("options_music_message_applied",
		host.options_screen.message_text() == "Music Off.",
		"msg=" + host.options_screen.message_text())
	host.options_screen.toggle_music()
	_check("options_music_toggle_unmutes_bus",
		not AudioServer.is_bus_mute(music_idx)
		and PUWGameSettings.music_on(state))
	_check("options_music_message_on",
		host.options_screen.message_text() == "Music On.",
		"msg=" + host.options_screen.message_text())
	# Options: the SFX toggle, same path; Master never muted.
	host.options_screen.toggle_sfx()
	_check("options_sfx_toggle_mutes_bus",
		AudioServer.is_bus_mute(sfx_idx)
		and not PUWGameSettings.sfx_on(state),
		"muted=" + str(AudioServer.is_bus_mute(sfx_idx)))
	_check("options_sfx_message_applied",
		host.options_screen.message_text() == "Sound effects Off.",
		"msg=" + host.options_screen.message_text())
	host.options_screen.toggle_sfx()
	_check("options_sfx_toggle_unmutes_bus",
		not AudioServer.is_bus_mute(sfx_idx)
		and PUWGameSettings.sfx_on(state))
	_check("options_master_never_muted", not AudioServer.is_bus_mute(0))

	# The dex cry, PKDX: select the caught Bulbasaur and press.
	var cries: Array = []
	host.pokedex_screen.cry_requested.connect(
		func(slug: String) -> void: cries.append(slug))
	var found: int = -1
	for i in host.pokedex_screen.entry_count():
		host.pokedex_screen.select_entry(i)
		if str(host.pokedex_screen.selected_entry().get("slug", "")) == "bulbasaur":
			found = i
			break
	_check("dex_bulbasaur_found", found >= 0)
	host.pokedex_screen.press_cry()
	_check("dex_cry_emitted", cries == ["bulbasaur"], str(cries))
	_check("dex_cry_plays_local_file", host.cry_player != null
		and host.cry_player._player != null
		and host.cry_player._player.stream != null
		and host.cry_player._player.stream.resource_path == "res://audio/cries/BULBASAUR.ogg",
		"stream=" + str(host.cry_player._player.stream if host.cry_player != null else null))
	_check("dex_cry_no_unbound_message",
		host.pokedex_screen.message_text() != "No cry player is bound yet.",
		"msg=" + host.pokedex_screen.message_text())

	# MDX parity through the same bound player: family is
	# never read, so an MDX mon resolves and plays exactly
	# like its PKDX counterpart.
	var player: PokemonCryPlayer = host.cry_player
	_check("cry_pkdx_plays", player != null
		and player.play_cry_for_mon({"species_slug": "pikachu", "dex_id": 25, "family": "PKDX"})
		and player._player.stream != null
		and player._player.stream.resource_path == "res://audio/cries/PIKACHU.ogg",
		"stream=" + str(player._player.stream if player != null else null))
	_check("cry_mdx_plays_identically", player != null
		and player.play_cry_for_mon({"species_slug": "pikachu", "dex_id": 25, "family": "MDX"})
		and player._player.stream != null
		and player._player.stream.resource_path == "res://audio/cries/PIKACHU.ogg",
		"stream=" + str(player._player.stream if player != null else null))
	_check("cry_mdx_slug_only", player != null
		and player.play_cry_for_mon({"species_slug": "pidgey", "family": "MDX"})
		and player._player.stream != null
		and player._player.stream.resource_path == "res://audio/cries/PIDGEY.ogg",
		"stream=" + str(player._player.stream if player != null else null))
	_check("cry_mdx_formed", player != null
		and player.play_cry_for_mon({"species": "Kyurem", "forme": "white", "dex_id": 646, "family": "MDX"})
		and player._player.stream != null
		and player._player.stream.resource_path == "res://audio/cries/KYUREM_1.ogg",
		"stream=" + str(player._player.stream if player != null else null))

	# Local-only: a species the local index does not cover
	# (Eternatus, dex 890 — bank-only) is refused with no
	# download machinery ever engaged.
	_check("cry_local_only_refuses_uncovered", player != null
		and not player.play_cry_for_mon({"species": "eternatus", "dex_id": 890}),
		"played an uncovered species")
	_check("cry_local_only_no_request_created", player != null
		and player._request == null
		and player._downloading.is_empty(),
		"request=" + str(player._request if player != null else null))
	_check("cry_local_only_no_cache_file",
		not FileAccess.file_exists("user://cries_cache/890.ogg"))
	host.queue_free()
