class_name PUWCharacterSetup
extends Node
## Guided character setup: the 11-step flow named in
## PUW_UI_UX_SPEC.md ("Character Setup (11-step guided flow)"),
## decomposing the creator separations in
## PUW_CHARACTER_CANON.md / characters/protagonist_canon.json:
## identity, pronouns, body silhouette, face, eyes (incl.
## heterochromia), and modular swappable clothing, plus hair
## style/color, a signature ball, and a final confirm step.
##
## Data and flow only: this class holds the chosen values and
## the step navigation. It draws nothing and loads no art.
##
## IDENTITY LOCK (Riley canon, 2026-11-23 18:42 CST): the body
## preset and the identity a player chooses at creation are
## LOCKED for that save — no switching genders mid-save. The
## lock takes hold when the profile is finalized (finish()).
## From then on set_value()/set_value_result() refuse the
## "identity" and "body_silhouette" steps with a plain reason
## (a refusal result, never a throw), while hair style, hair
## color, eyes, heterochromia, clothing and every other step
## stay changeable for the life of the save.
##
## Saving: save_character(state) stores the built character as a
## nested Dictionary under the "character_setup" key of the
## state's story_flags Dictionary, then persists the whole state
## through PUWSaveManager.save_game(). The save manager's
## build_state() deep-copies story_flags and its writer
## JSON-serializes the payload, so a nested dict is held exactly
## as built; no JSON-string workaround is needed. The built
## character carries the lock additively as "profile_finalized"
## (see PROFILE_FINALIZED_KEY and load_character()'s
## finalize-on-load rule for saves written before the key
## existed).

const STEP_IDS: Array = [
	"identity",
	"pronouns",
	"body_silhouette",
	"face",
	"eyes",
	"heterochromia",
	"hair_style",
	"hair_color",
	"clothing",
	"signature_ball",
	"confirm"
]

## The canon identity options, transcribed verbatim from
## PUW_CHARACTER_CANON.md (Custom Character entry).
const IDENTITY_OPTIONS: Array = [
	"Male",
	"Female",
	"Nonbinary",
	"Trans man",
	"Trans woman",
	"Femboy",
	"Futanari",
	"Custom",
	"Prefer not to specify"
]

## The steps the identity lock covers once the profile is
## finalized: the identity itself and the body preset step
## ("body_silhouette" is the creator step the body preset is
## chosen on; PUWCastRegistry.BODY_PRESETS lists the four
## preset ids). Every step NOT listed here — pronouns, face,
## eyes, heterochromia, hair_style, hair_color, clothing,
## signature_ball — stays settable after finalizing.
const LOCKED_AFTER_FINALIZE_STEPS: Array = ["identity", "body_silhouette"]

## Additive key stamped into the built character Dictionary:
## true once the profile has been finalized. Saves written
## before this key existed do not carry it; load_character()
## treats a complete character without the key as finalized
## (finalize-on-load — see its note).
const PROFILE_FINALIZED_KEY: String = "profile_finalized"

## Hairstyles locked to the named protagonists: Riley's tousled
## bob and Tasha's copper waves are signature-only and can never
## be chosen for a custom profile. This mirrors the 3D rig's lock
## (ModularCharacterRig.LOCKED_CANON_HAIRSTYLES, enforced in its
## apply_profile()); canon audit gap G7: the rig enforced it, the
## shipping 2D creator did not. The lock is on the style IDS
## below, not on free-text descriptions. (Merged from code prep
## rotation 1, 2026-11-23, per rotation 2's merge instructions.)
const LOCKED_CANON_HAIRSTYLES: Array = ["riley_tousled_bob", "tasha_copper_waves"]

## Story-flag key the built character is stored under.
const SAVE_FLAG_KEY: String = "character_setup"

var _step_index: int = 0
var _values: Dictionary = {}
## True once finish() has finalized the profile. The identity
## lock is live exactly while this is true.
var _finalized: bool = false
## Non-step keys restored by load_character() (for example the
## wardrobe list another system keeps on the character dict).
## Preserved verbatim and re-emitted by build_character() so a
## load -> save round trip never strips another system's data.
var _extras: Dictionary = {}


## The ordered step ids, exactly 11 of them.
func get_steps() -> Array:
	return STEP_IDS.duplicate()


## The identity options from the canon data, verbatim.
static func identity_options() -> Array:
	return IDENTITY_OPTIONS.duplicate()


## The steps locked after finalizing (identity + body preset).
static func locked_steps() -> Array:
	return LOCKED_AFTER_FINALIZE_STEPS.duplicate()


## The hairstyle ids locked to Riley and Tasha (see
## LOCKED_CANON_HAIRSTYLES). Creator UIs filter their hair list
## with this so the locked styles are never offered.
static func locked_hairstyles() -> Array:
	return LOCKED_CANON_HAIRSTYLES.duplicate()


## True when a hairstyle id is one of the locked signature styles.
static func is_hairstyle_locked(style_id: String) -> bool:
	return LOCKED_CANON_HAIRSTYLES.has(style_id)


## The step the flow is currently on.
func current_step() -> String:
	return str(STEP_IDS[_step_index])


## The current step's position in get_steps() (0-based).
func current_step_index() -> int:
	return _step_index


## True once the profile has been finalized and the identity
## lock is live.
func is_finalized() -> bool:
	return _finalized


## Store one step's value, with the refusal spelled out.
## Returns {"ok": bool, "step": step_id, "reason": String}:
## reason is "" on success and a plain-English explanation on
## refusal. Refusals never throw and never change a value.
## - unknown step id: refused.
## - a locked step (identity / body_silhouette) after the
##   profile is finalized: refused — the choice is locked for
##   this save.
## - identity: the value must be a String from IDENTITY_OPTIONS.
## - heterochromia: accepts a bool or a String (for example
##   per-eye colors written as text); stored as given.
## - hair_style: accepts a String, EXCEPT the two locked
##   signature style ids (LOCKED_CANON_HAIRSTYLES), which are
##   refused — this flow builds custom profiles only, and the
##   named protagonists' own profiles never pass through here.
## - every other step: accepts a free-form String.
func set_value_result(step_id: String, value: Variant) -> Dictionary:
	if not STEP_IDS.has(step_id):
		return {"ok": false, "step": step_id, "reason": "That is not a character setup step."}
	if _finalized and LOCKED_AFTER_FINALIZE_STEPS.has(step_id):
		if step_id == "identity":
			return {"ok": false, "step": step_id, "reason": "Your identity is locked for this save and can't be changed."}
		return {"ok": false, "step": step_id, "reason": "Your body preset is locked for this save and can't be changed."}
	if step_id == "identity":
		if typeof(value) != TYPE_STRING:
			return {"ok": false, "step": step_id, "reason": "Identity must be one of the listed options."}
		var identity_text: String = value
		if not IDENTITY_OPTIONS.has(identity_text):
			return {"ok": false, "step": step_id, "reason": "Identity must be one of the listed options."}
		_values[step_id] = identity_text
		return {"ok": true, "step": step_id, "reason": ""}
	if step_id == "heterochromia":
		if typeof(value) == TYPE_BOOL:
			var flag: bool = value
			_values[step_id] = flag
			return {"ok": true, "step": step_id, "reason": ""}
		if typeof(value) == TYPE_STRING:
			var hetero_text: String = value
			_values[step_id] = hetero_text
			return {"ok": true, "step": step_id, "reason": ""}
		return {"ok": false, "step": step_id, "reason": "Heterochromia must be on/off or a written description."}
	if step_id == "hair_style":
		if typeof(value) != TYPE_STRING:
			return {"ok": false, "step": step_id, "reason": "That step takes a written value."}
		var style_text: String = value
		if LOCKED_CANON_HAIRSTYLES.has(style_text):
			return {"ok": false, "step": step_id, "reason": "That hairstyle belongs to a named character and can't be chosen."}
		_values[step_id] = style_text
		return {"ok": true, "step": step_id, "reason": ""}
	if typeof(value) != TYPE_STRING:
		return {"ok": false, "step": step_id, "reason": "That step takes a written value."}
	var text: String = value
	_values[step_id] = text
	return {"ok": true, "step": step_id, "reason": ""}


## Store one step's value. Returns true when the value was
## accepted. Thin wrapper over set_value_result() (the existing
## bool API is unchanged); callers that need to know WHY a
## value was refused use set_value_result().
func set_value(step_id: String, value: Variant) -> bool:
	var result: Dictionary = set_value_result(step_id, value)
	return bool(result.get("ok", false))


## The value stored for one step, or null when unset.
func get_value(step_id: String) -> Variant:
	return _values.get(step_id, null)


## Move to the next step. Refuses to advance past the final
## confirm step.
func next_step() -> bool:
	if _step_index >= STEP_IDS.size() - 1:
		return false
	_step_index += 1
	return true


## Move back one step. Refuses to go before the first step.
func previous_step() -> bool:
	if _step_index <= 0:
		return false
	_step_index -= 1
	return true


## True when the setup can finish: identity is set (it can only
## be set to a canon option) and every step before confirm has
## a value. Finishing with identity unset is refused here, and
## build_character()/save_character() both go through this.
func is_complete() -> bool:
	if not _values.has("identity"):
		return false
	for step_value in STEP_IDS:
		var step_id: String = str(step_value)
		if step_id == "confirm":
			continue
		if not _values.has(step_id):
			return false
	return true


## Attempt to finish the setup. True only when is_complete().
## Finishing FINALIZES the profile: the identity lock goes
## live (identity + body preset can no longer change) and the
## built character is stamped "profile_finalized": true.
## Finishing an already-finalized profile is harmless and
## returns true while it stays complete.
func finish() -> bool:
	if not is_complete():
		return false
	_finalized = true
	return true


## All chosen values as one Dictionary, plus any preserved
## non-step keys (see _extras) and the "profile_finalized"
## stamp. Returns an empty Dictionary when the setup is not
## complete (in particular when identity is unset).
func build_character() -> Dictionary:
	if not is_complete():
		return {}
	var built: Dictionary = _values.duplicate(true)
	for key_value in _extras.keys():
		var key: String = str(key_value)
		if not built.has(key):
			built[key] = _extras[key_value]
	built[PROFILE_FINALIZED_KEY] = _finalized
	return built


## Restore this setup from a character Dictionary built by
## build_character() — for example one loaded back out of a
## save's story_flags. Step values go back into the flow;
## "profile_finalized" restores the lock; any other keys
## (wardrobe data and other additive fields other systems
## keep on the character) are preserved as extras and
## re-emitted by build_character(). Returns true when the
## restored character is complete.
##
## FINALIZE-ON-LOAD RULE for old saves: a dict WITHOUT
## "profile_finalized" predates the identity lock. Such a
## character was necessarily created and confirmed before it
## could be saved at all, so a complete one loads as
## finalized and the flag is stamped true the next time
## build_character()/save_character() writes it. An
## incomplete dict without the key (never a real saved
## profile) loads unfinalized.
func load_character(data: Dictionary) -> bool:
	_values.clear()
	_extras.clear()
	_finalized = false
	_step_index = 0
	for key_value in data.keys():
		var key: String = str(key_value)
		if key == PROFILE_FINALIZED_KEY:
			continue
		if STEP_IDS.has(key):
			_values[key] = data[key_value]
		else:
			_extras[key] = data[key_value]
	if data.has(PROFILE_FINALIZED_KEY):
		var flag_value: Variant = data[PROFILE_FINALIZED_KEY]
		_finalized = bool(flag_value)
	elif is_complete():
		_finalized = true
	return is_complete()


## Store the built character in a save state Dictionary and
## persist it through the save manager's existing API.
## The character lands as a nested Dictionary at
## state["story_flags"]["character_setup"] — build_state()
## deep-copies story_flags and save_game() JSON-serializes the
## whole payload, so the nested dict survives the round trip.
## Returns false (and writes nothing) when not complete.
func save_character(state: Dictionary) -> bool:
	if not is_complete():
		return false
	var flags_value: Variant = state.get("story_flags", {})
	var flags: Dictionary = {}
	if flags_value is Dictionary:
		var existing_flags: Dictionary = flags_value
		flags = existing_flags.duplicate(true)
	flags[SAVE_FLAG_KEY] = build_character()
	state["story_flags"] = flags
	return PUWSaveManager.save_game(state)
