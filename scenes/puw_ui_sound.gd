class_name PUWUiSound
extends Node
## Single entry point for every menu sound hook (MENU_AUDIT_AND_REBUILD_SPEC
## §3.0 "Sound hooks"). Screens and the menu stack call
## PUWUiSound.play("ui_cursor") and never touch AudioStreamPlayers
## directly. ui_cursor is throttled to one play per 60 ms so
## fast list scrolling does not stack the cursor SE.
##
## Audio wiring build: the registration this file always waited
## for now exists. register_streams_from_index() loads the bound
## FRLG audio index (res://data/frlg_audio_index.json), whose
## ui_sounds table maps every one of the 9 hooks to its bound
## file under res://audio/effects/, and registers the real
## streams. _ready() runs it, and ensure_instance() lets a host
## scene (the menu stack) guarantee a live instance exists -
## before this build, no scene contained a PUWUiSound node and
## register_stream() had no callers, so every hook was a silent
## no-op that only recorded the call in played_log.

const HOOKS: Array[String] = [
	"ui_cursor", "ui_confirm", "ui_cancel", "ui_open", "ui_close",
	"ui_error", "ui_buy", "ui_heal", "ui_save",
]
const CURSOR_THROTTLE_MSEC: int = 60
const INDEX_PATH: String = "res://data/frlg_audio_index.json"

## Audio bus layout prep (code_prep_audio_buses): the menu SE
## players ride the "UI" bus from default_bus_layout.tres.
## Menu hooks are interface sound, not world sound effects,
## so they mix on their own bus; the options screen's toggles
## address "Music" and "SFX" and neither mutes this bus.
const UI_BUS: String = "UI"

static var _instance: PUWUiSound = null
static var _streams: Dictionary = {}
static var _index_registered: bool = false
## Every hook played, in order. QA/diagnostics only.
static var played_log: Array[String] = []

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _last_cursor_msec: int = -1000


func _ready() -> void:
	_instance = self
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.bus = UI_BUS
		add_child(player)
		_players.append(player)
	register_streams_from_index()


## Guarantee a live PUWUiSound instance exists under parent.
## Returns the instance (the existing one when there is one).
static func ensure_instance(parent: Node) -> PUWUiSound:
	if _instance != null:
		return _instance
	var created: PUWUiSound = PUWUiSound.new()
	created.name = "PUWUiSound"
	parent.add_child(created)
	return created


## Register the real FRLG streams for every hook the bound
## index maps. Returns how many hooks hold a stream after the
## call. Idempotent: later calls just report the count.
static func register_streams_from_index() -> int:
	if _index_registered:
		return _streams.size()
	_index_registered = true
	if not FileAccess.file_exists(INDEX_PATH):
		return _streams.size()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not (parsed is Dictionary):
		return _streams.size()
	var ui_value: Variant = (parsed as Dictionary).get("ui_sounds", {})
	if not (ui_value is Dictionary):
		return _streams.size()
	var ui_sounds: Dictionary = ui_value
	for hook in HOOKS:
		var path: String = str(ui_sounds.get(hook, ""))
		if path == "":
			continue
		var stream: AudioStream = ResourceLoader.load("res://" + path) as AudioStream
		if stream != null:
			register_stream(hook, stream)
	return _streams.size()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


## The audio binding build calls this once per hook with the real
## stream (FRLG SE inventory fits are listed in the soundtrack
## lane's AUDIO_EXTRACTION.md sound map).
static func register_stream(hook: String, stream: AudioStream) -> void:
	_streams[hook] = stream


static func has_stream(hook: String) -> bool:
	return _streams.has(hook)


static func play(hook: String) -> void:
	played_log.append(hook)
	if _instance == null:
		return
	_instance._play_now(hook)


func _play_now(hook: String) -> void:
	if hook == "ui_cursor":
		var now: int = Time.get_ticks_msec()
		if now - _last_cursor_msec < CURSOR_THROTTLE_MSEC:
			return
		_last_cursor_msec = now
	if not _streams.has(hook):
		return
	var stream: AudioStream = _streams[hook] as AudioStream
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.play()
