class_name PUWDialogueRunner
extends RefCounted
## PUWDialogueRunner — plays one resolved dialogue in order.
##
## Input is the line list a resolver produced for one placed NPC
## (PUWSpawner.dialogue_for / dialogue_for_script): an Array of
## bank entry texts (Strings), in source order. Entries may also
## be Dictionaries of the form
##   {"text": String, "speaker": String,
##    "choices": [{"label": String, "target_index": int}]}
## for the sourced choice points (the bridge flags them; e.g.
## Bill's Yes/No in BillsHouse). Plain bank strings normalize to
## {"text": s, "speaker": "", "choices": []}.
##
## The runner is presentation-free: PUWDialogueBox renders it,
## tests drive it directly.
##
## Branch terminators (v2, dialogue-terminator prep): an entry
## may also be a branch_end marker,
##   {"text": "", "speaker": "", "choices": [],
##    "branch_end": true, "goto_index": int}
## PUWChoiceAssembler emits exactly one marker per choice block,
## between the NO section and the YES section; goto_index is the
## branch's rejoin point — the first shared-tail line, or the
## block-end index when the block has no tail (playback then
## continues with whatever follows the block, or finishes when
## the block is last). The runner resolves markers the moment
## the play position lands on one (setup / advance / choose all
## settle before returning), so a marker is never the current
## line, never renders, and never appears in played sequences.
## Entries without the branch_end key normalize to exactly the
## v1 shape, and linear (non-choice) playback is unchanged.

var _lines: Array = []
var _index: int = 0
var choices_made: Array = []


func setup(lines: Array) -> void:
	_lines = []
	_index = 0
	choices_made = []
	for entry_v in lines:
		_lines.append(_normalize(entry_v))
	_settle()


static func _normalize(entry_v: Variant) -> Dictionary:
	if entry_v is Dictionary:
		var d: Dictionary = entry_v
		var choices: Array = []
		var raw_choices_v: Variant = d.get("choices", [])
		if raw_choices_v is Array:
			var raw_choices: Array = raw_choices_v
			for c_v in raw_choices:
				if c_v is Dictionary:
					var c: Dictionary = c_v
					choices.append({
						"label": String(c.get("label", "")),
						"target_index": int(c.get("target_index", -1)),
					})
		var out: Dictionary = {
			"text": String(d.get("text", "")),
			"speaker": String(d.get("speaker", "")),
			"choices": choices,
		}
		if bool(d.get("branch_end", false)):
			out["branch_end"] = true
			out["goto_index"] = int(d.get("goto_index", -1))
		return out
	return {"text": String(entry_v), "speaker": "", "choices": []}


## If the play position sits on a branch_end marker, apply it:
## jump to its goto_index when that names a line, else finish.
## Markers may chain (a goto may land on another marker); the
## guard finishes rather than loop on a malformed list.
func _settle() -> void:
	var guard: int = 0
	while not is_finished():
		var d: Dictionary = _lines[_index]
		if not bool(d.get("branch_end", false)):
			return
		var target: int = int(d.get("goto_index", -1))
		if target < 0 or target >= _lines.size() \
				or target == _index or guard > _lines.size():
			_index = _lines.size()
			return
		_index = target
		guard += 1


func line_count() -> int:
	return _lines.size()


func index() -> int:
	return _index


func is_finished() -> bool:
	return _index >= _lines.size()


## The current line as {text, speaker, choices}, or {} when the
## dialogue is finished / was never set up. Never a branch_end
## marker: every position change settles first.
func current() -> Dictionary:
	if is_finished():
		return {}
	var d: Dictionary = _lines[_index]
	return d.duplicate(true)


func current_text() -> String:
	var d: Dictionary = current()
	return String(d.get("text", ""))


func current_speaker() -> String:
	var d: Dictionary = current()
	return String(d.get("speaker", ""))


func current_choices() -> Array:
	var d: Dictionary = current()
	var c_v: Variant = d.get("choices", [])
	if c_v is Array:
		var c: Array = c_v
		return c
	return []


## Move to the next line, resolving any branch_end marker the
## move lands on. Returns true when a line is current after
## the move.
func advance() -> bool:
	if is_finished():
		return false
	_index += 1
	_settle()
	return not is_finished()


## Take choice i of the current line. Jumps to the choice's
## target_index when it names a valid line (resolving a marker
## landed on, e.g. an empty branch whose target is the block's
## branch_end marker), else advances. Returns false when there
## is no such choice, and false when the jump ends the dialogue
## (matching v1's advance-fallback result in that case).
func choose(i: int) -> bool:
	var choices: Array = current_choices()
	if i < 0 or i >= choices.size():
		return false
	var c: Dictionary = choices[i]
	choices_made.append({"line_index": _index, "choice_index": i,
			"label": String(c.get("label", ""))})
	var target: int = int(c.get("target_index", -1))
	if target >= 0 and target < _lines.size():
		_index = target
		_settle()
		return not is_finished()
	return advance()
