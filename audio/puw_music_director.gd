class_name PUWMusicDirector
extends Node
## The one entry point for background music (BGM) and event
## jingles. Scenes call the instance methods here and never touch
## AudioStreamPlayers directly, the same house pattern as
## PUWUiSound for menu SE.
##
## Resolution is static and data-driven, so it can be tested
## headless without any playback:
##   track_for_map("PALLET_TOWN")     -> "ost_pallet_town"
##   track_for_battle("gym_leader")   -> "ost_gym_leader_battle"
##   stream_path_for_track(track_id)  -> "res://audio/music/....ogg"
##                                       or "" when the slot is one
##                                       of the two verified-unfilled
##                                       register slots.
## Data files (bound by the audio wiring build):
##   res://data/audio/music_index.json - the 30 register slots from
##     audio/original_soundtrack_manifest.json, each marked filled
##     with its selected file (OST_MAPPING_V2 winners) or unfilled.
##   res://data/audio/map_music.json - map id_const -> track id,
##     generated from the held mapping's rules. Maps with no entry
##     honestly resolve to "" (no music change); Johto maps carry
##     no assignments in this pass because no Johto OST mapping
##     exists in held material.
##
## Playback is instance-side: a scene adds one PUWMusicDirector
## child and calls play_map_bgm(its own map id) in _ready. Scene
## changes recreate the overworld scene, whose _ready starts its
## map track again - that is how map music "resumes" after a
## battle, with no cross-scene state to keep.

const INDEX_PATH: String = "res://data/audio/music_index.json"
const MAP_MUSIC_PATH: String = "res://data/audio/map_music.json"

## Audio bus layout prep (code_prep_audio_buses): both players
## ride the "Music" bus from default_bus_layout.tres, so the
## options screen's Music toggle (PUWGameSettings.apply_audio,
## which addresses buses by name) mixes the director with
## everything else on that bus. The jingle channel is
## music-family — the victory jingle is a register music
## track — so it shares the bus rather than riding SFX.
const BGM_BUS: String = "Music"

## Battle kind -> register track. "champion" shares the story
## boss slot: Kanto's story boss IS the Champion battle, whose
## authentic theme (Final Battle (Rival)) holds that slot.
const BATTLE_TRACKS: Dictionary = {
	"wild": "ost_wild_battle",
	"trainer": "ost_trainer_battle",
	"gym_leader": "ost_gym_leader_battle",
	"story_boss": "ost_story_boss_battle",
	"champion": "ost_story_boss_battle",
	"victory": "ost_battle_victory",
}

static var _data_loaded: bool = false
static var _tracks: Dictionary = {}
static var _map_music: Dictionary = {}
static var _crossfade_ms: int = 850
## The track the director last resolved for playback, and every
## track played, in order. Diagnostics / QA only, mirroring
## PUWUiSound.played_log.
static var current_track_id: String = ""
static var played_log: Array[String] = []

var _bgm_player: AudioStreamPlayer = null
var _jingle_player: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_players()


## Create the two players on first use (the cry player's own
## pattern), so a director added to a scene and used in the
## same frame still plays.
func _ensure_players() -> void:
	if _bgm_player == null:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.name = "BgmPlayer"
		_bgm_player.bus = BGM_BUS
		add_child(_bgm_player)
	if _jingle_player == null:
		_jingle_player = AudioStreamPlayer.new()
		_jingle_player.name = "JinglePlayer"
		_jingle_player.bus = BGM_BUS
		add_child(_jingle_player)


## Load both data files once. Missing files leave the tables
## empty, and every resolution then honestly returns "".
static func _ensure_data() -> void:
	if _data_loaded:
		return
	_data_loaded = true
	if FileAccess.file_exists(INDEX_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
		if parsed is Dictionary:
			var index: Dictionary = parsed
			var tracks_value: Variant = index.get("tracks", {})
			if tracks_value is Dictionary:
				_tracks = tracks_value
			_crossfade_ms = int(index.get("crossfade_ms", 850))
	if FileAccess.file_exists(MAP_MUSIC_PATH):
		var parsed_map: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_MUSIC_PATH))
		if parsed_map is Dictionary:
			var map_music: Dictionary = parsed_map
			var maps_value: Variant = map_music.get("maps", {})
			if maps_value is Dictionary:
				_map_music = maps_value


## The register's crossfade length in milliseconds (850 in the
## soundtrack register). Playback uses it as the fade-in length.
static func crossfade_ms() -> int:
	_ensure_data()
	return _crossfade_ms


## True when the register slot has a selected file bound.
static func is_filled(track_id: String) -> bool:
	_ensure_data()
	var entry_value: Variant = _tracks.get(track_id, {})
	if entry_value is Dictionary:
		return bool((entry_value as Dictionary).get("filled", false))
	return false


## res:// path of a track's bound file, "" for unfilled or
## unknown slots (ost_poke_mart and ost_battle_defeat are the
## register's two verified-unfilled slots).
static func stream_path_for_track(track_id: String) -> String:
	_ensure_data()
	var entry_value: Variant = _tracks.get(track_id, {})
	if not (entry_value is Dictionary):
		return ""
	var entry: Dictionary = entry_value
	if not bool(entry.get("filled", false)):
		return ""
	var file: String = str(entry.get("file", ""))
	if file == "":
		return ""
	return "res://" + file


## Normalize a map identifier to the id_const dialect the map
## music table is keyed on. Accepts the scene dialect
## ("PALLET_TOWN", "ROUTE_1"), the world-file dialect
## ("kanto_pallet_town", "kanto_route_01", "sevii_one_island")
## and plain lowercase names.
static func normalize_map_id(map_id: String) -> String:
	var id: String = map_id.strip_edges().to_upper()
	if id.begins_with("KANTO_"):
		id = id.trim_prefix("KANTO_")
	elif id.begins_with("SEVII_"):
		id = id.trim_prefix("SEVII_")
	# World-file route stems are zero-padded (route_01); the
	# id_const dialect is unpadded (ROUTE_1).
	if id.begins_with("ROUTE_0"):
		id = "ROUTE_" + id.trim_prefix("ROUTE_0")
	return id


## The BGM track for a map, "" when the held mapping assigns
## none. Silence is an honest answer here, never a guess.
static func track_for_map(map_id: String) -> String:
	_ensure_data()
	var entry_value: Variant = _map_music.get(normalize_map_id(map_id), {})
	if entry_value is Dictionary:
		return str((entry_value as Dictionary).get("track", ""))
	return ""


## The BGM track for a battle kind: wild / trainer / gym_leader /
## story_boss / champion / victory. "" for unknown kinds.
static func track_for_battle(kind: String) -> String:
	var track_value: Variant = BATTLE_TRACKS.get(kind.strip_edges().to_lower(), "")
	return str(track_value)


## Play a track on the BGM channel. Returns the resolved track
## id ("" when the track is unknown or unfilled, in which case
## nothing plays). Records the play in played_log either way
## the resolution succeeds.
func play_track(track_id: String) -> String:
	var path: String = stream_path_for_track(track_id)
	if path == "":
		return ""
	_ensure_players()
	var stream: AudioStream = ResourceLoader.load(path) as AudioStream
	if stream == null:
		return ""
	current_track_id = track_id
	played_log.append(track_id)
	_bgm_player.stream = stream
	_bgm_player.volume_db = -24.0
	_bgm_player.play()
	var tween: Tween = create_tween()
	var seconds: float = float(crossfade_ms()) / 1000.0
	tween.tween_property(_bgm_player, "volume_db", 0.0, seconds)
	return track_id


## Start the BGM for the map the caller is showing. A map with
## no assigned track stops the music: entering an unmapped
## interior must not leak the previous area's theme.
func play_map_bgm(map_id: String) -> String:
	var track_id: String = track_for_map(map_id)
	if track_id == "":
		stop_bgm()
		current_track_id = ""
		return ""
	# Build 6 (A-10 union): a map may resolve to a registered but
	# UNFILLED slot (the Johto ost_johto_* set — no verified stream
	# held). That is the same honesty case as an unmapped map: stop
	# the music rather than leak the previous area's theme.
	if stream_path_for_track(track_id) == "":
		stop_bgm()
		current_track_id = ""
		return ""
	return play_track(track_id)


## Start the BGM for a battle kind (see track_for_battle).
func play_battle_bgm(kind: String) -> String:
	var track_id: String = track_for_battle(kind)
	if track_id == "":
		return ""
	return play_track(track_id)


## Play a one-shot jingle (e.g. the victory track) on the jingle
## channel, leaving the BGM channel's stream in place.
func play_jingle(track_id: String) -> String:
	var path: String = stream_path_for_track(track_id)
	if path == "":
		return ""
	_ensure_players()
	var stream: AudioStream = ResourceLoader.load(path) as AudioStream
	if stream == null:
		return ""
	played_log.append(track_id)
	_jingle_player.stream = stream
	_jingle_player.play()
	return track_id


func stop_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stop()
