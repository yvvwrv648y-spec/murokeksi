class_name PUWGameSettings
extends RefCounted
## Game settings model (ui_screens production, build 6 binds).
##
## The bound tree had NO settings storage at all: the only
## settings artefact was the stub ChallengeAndAudioSettingsController
## shell (open/close panel, no values). This class is the missing
## model, following the established additive-key pattern
## (PUWQuestBoard.ensure_quests / PUWSaveManager's additive keys):
## settings live in the save state under the "settings" key, so
## they persist through the real save flow with no schema change.
##
## Fields (all four are presentation DESIGN CONSTANTS with the
## defaults below; no source game value is claimed for them):
##   text_speed       "slow" | "mid" | "fast"   (default "mid")
##   music_on         bool                      (default true)
##   sfx_on           bool                      (default true)
##   battle_animation bool                      (default true)
##
## Consumers:
## - Text speed: chars_per_second() maps the speed to the
##   typewriter rate the dialogue box runs at. "mid" = 60 cps is
##   PUWDialogueBox's bound CHARS_PER_SECOND constant, so the
##   default changes nothing until the player changes it; build 6
##   passes text_speed_cps(state) into the box.
## - Sound toggles: apply_audio() mutes/unmutes the AudioServer
##   buses the audio wiring uses. The audio prep found NO bus
##   layout file in the bound tree and every bound player on the
##   "Master" bus; apply_audio() therefore targets the dedicated
##   buses BY NAME ("Music"/"BGM" for music, "SFX"/"SE" for
##   effects) and reports exactly which buses it found and set.
##   A bus that does not exist is reported unapplied, never
##   faked, and Master is never muted (muting Master would kill
##   both channels and lie about which toggle did it). Build 6
##   ships the bus layout (default_bus_layout.tres with Music +
##   SFX buses routed to Master) and re-points the music
##   director / UI sound players at them.
## - Battle animation: animations_enabled(state) is the playback
##   contract. Build 5's playback entry points (BattleAnims
##   play_state_animation callers and the follower renderer)
##   check it and fall back to the static frame when it is
##   false — the same static art the game shipped with, so OFF
##   is a presentation choice, never missing art.

const STATE_KEY: String = "settings"

const TEXT_SPEED_SLOW: String = "slow"
const TEXT_SPEED_MID: String = "mid"
const TEXT_SPEED_FAST: String = "fast"
const TEXT_SPEEDS: Array[String] = [TEXT_SPEED_SLOW, TEXT_SPEED_MID, TEXT_SPEED_FAST]

## Typewriter rates per speed. "mid" matches PUWDialogueBox's
## bound CHARS_PER_SECOND (60.0); slow/fast are design constants
## at half / double that rate.
const CPS_SLOW: float = 30.0
const CPS_MID: float = 60.0
const CPS_FAST: float = 120.0

const MUSIC_BUS_NAMES: Array[String] = ["Music", "BGM"]
const SFX_BUS_NAMES: Array[String] = ["SFX", "SE"]

static func defaults() -> Dictionary:
	return {
		"text_speed": TEXT_SPEED_MID,
		"music_on": true,
		"sfx_on": true,
		"battle_animation": true,
	}


## The settings dict merged over the defaults (no write to the
## state). Unknown / wrong-typed stored values fall back to the
## default for that field.
static func get_settings(state: Dictionary) -> Dictionary:
	var out: Dictionary = defaults()
	var stored_value: Variant = state.get(STATE_KEY, {})
	if stored_value is Dictionary:
		var stored: Dictionary = stored_value
		var speed: String = str(stored.get("text_speed", TEXT_SPEED_MID))
		if TEXT_SPEEDS.has(speed):
			out["text_speed"] = speed
		for key in ["music_on", "sfx_on", "battle_animation"]:
			var value: Variant = stored.get(key, out[key])
			if typeof(value) == TYPE_BOOL:
				out[key] = value
	return out


## Ensure state["settings"] exists in the merged shape and
## return it. The stored dict is the one in the state (mutating
## the return value mutates the save-to-be).
static func ensure_settings(state: Dictionary) -> Dictionary:
	var merged: Dictionary = get_settings(state)
	state[STATE_KEY] = merged
	return merged


## Set one field (validated) in the state's settings and return
## the settings dict. Unknown keys / values are refused and the
## current settings are returned unchanged.
static func set_value(state: Dictionary, key: String, value: Variant) -> Dictionary:
	var settings: Dictionary = ensure_settings(state)
	match key:
		"text_speed":
			var speed: String = str(value)
			if TEXT_SPEEDS.has(speed):
				settings["text_speed"] = speed
		"music_on", "sfx_on", "battle_animation":
			if typeof(value) == TYPE_BOOL:
				settings[key] = value
	state[STATE_KEY] = settings
	return settings


static func text_speed(state: Dictionary) -> String:
	return str(get_settings(state).get("text_speed", TEXT_SPEED_MID))


static func chars_per_second(speed: String) -> float:
	match speed:
		TEXT_SPEED_SLOW:
			return CPS_SLOW
		TEXT_SPEED_FAST:
			return CPS_FAST
	return CPS_MID


static func text_speed_cps(state: Dictionary) -> float:
	return chars_per_second(text_speed(state))


## The next speed in the slow -> mid -> fast -> slow cycle.
static func next_text_speed(speed: String) -> String:
	var index: int = TEXT_SPEEDS.find(speed)
	if index < 0:
		return TEXT_SPEED_MID
	return TEXT_SPEEDS[(index + 1) % TEXT_SPEEDS.size()]


static func music_on(state: Dictionary) -> bool:
	return bool(get_settings(state).get("music_on", true))


static func sfx_on(state: Dictionary) -> bool:
	return bool(get_settings(state).get("sfx_on", true))


## THE PLAYBACK CONTRACT: true when battle/field animation
## playback runs; false when playback falls back to static
## frames. Read from the state's settings every call, so an
## options change takes effect on the next animation start.
static func animations_enabled(state: Dictionary) -> bool:
	return bool(get_settings(state).get("battle_animation", true))


static func _find_bus(names: Array[String]) -> String:
	for bus_name in names:
		if AudioServer.get_bus_index(bus_name) >= 0:
			return bus_name
	return ""


## Apply the sound toggles to the AudioServer buses that exist.
## Returns {"music_bus": String, "sfx_bus": String,
## "music_applied": bool, "sfx_applied": bool} — a bus name is
## "" and its applied flag false when no bus by either known
## name exists (reported honestly; see the header).
static func apply_audio(state: Dictionary) -> Dictionary:
	var settings: Dictionary = get_settings(state)
	var music_bus: String = _find_bus(MUSIC_BUS_NAMES)
	var sfx_bus: String = _find_bus(SFX_BUS_NAMES)
	var music_applied: bool = false
	var sfx_applied: bool = false
	if music_bus != "":
		AudioServer.set_bus_mute(AudioServer.get_bus_index(music_bus), not bool(settings.get("music_on", true)))
		music_applied = true
	if sfx_bus != "":
		AudioServer.set_bus_mute(AudioServer.get_bus_index(sfx_bus), not bool(settings.get("sfx_on", true)))
		sfx_applied = true
	return {
		"music_bus": music_bus,
		"sfx_bus": sfx_bus,
		"music_applied": music_applied,
		"sfx_applied": sfx_applied,
	}
