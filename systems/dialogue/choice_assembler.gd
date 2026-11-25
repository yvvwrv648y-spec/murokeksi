class_name PUWChoiceAssembler
extends RefCounted
## PUWChoiceAssembler — applies the Kanto choice-split delta
## (data/kanto_choice_splits.json, schema puw.kanto_choice_splits/1)
## on top of the dialogue prep's Kanto text bridge.
##
## The bridge plays the 28 YesNoChoice roots linearly. This
## assembler turns a split entry's label segments into the
## runner-ready line list PUWDialogueRunner consumes: plain Strings
## for linear lines, and for each choice point one Dictionary
##   {"text": prompt, "speaker": "",
##    "choices": [{"label": "Yes", "target_index": int},
##                {"label": "No", "target_index": int}]}
##
## Layout inside a choice block (the dialogue prep's own fixture
## convention): prompt, NO branch lines, branch_end marker, YES
## branch lines, shared tail lines. The marker is a runner entry
##   {"text": "", "speaker": "", "choices": [],
##    "branch_end": true, "goto_index": int}
## whose goto is the branch's rejoin point: the first tail line
## when the block has a tail, else the index just past the block
## (so a no-tail NO path continues with whatever follows the
## block, or finishes when the block is last). PUWDialogueRunner
## resolves the marker the moment playback lands on it, so the
## NO path plays exactly its own lines, then the shared tail,
## and never falls through into the YES section — at all 30
## Kanto choice points, on both paths.
##
## Targets: Yes -> first YES line, else first tail line, else the
## branch_end marker (choosing Yes on an empty Yes branch with no
## tail ends the branch at once — v1's -1 fallback advanced into
## the NO section, a latent flaw with no Kanto case); No -> first
## NO line, else first tail line, else the branch_end marker.
## Label resolution replicates PUWSpawner._bridge_lines exactly
## (map group first, global index fallback, empty text skipped).
##
## assemble() returns [] for any (map, ref) with no split, so the
## caller falls back to the linear bridge path unchanged.
## The split data (data/kanto_choice_splits.json) is unchanged by
## this prep: the terminator is a layout/assembler change only.

const BANK_PATH: String = "res://data/dialogue_database.json"
const SPLITS_PATH: String = "res://data/kanto_choice_splits.json"

var _groups: Dictionary = {}
var _global: Dictionary = {}
var _splits: Dictionary = {}
var _loaded: bool = false


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var bank_v: Variant = _load_json(BANK_PATH)
	if bank_v is Dictionary:
		var bank: Dictionary = bank_v
		var groups_v: Variant = bank.get("groups", {})
		if groups_v is Dictionary:
			_groups = groups_v
	_global = _global_index(_groups)
	var splits_v: Variant = _load_json(SPLITS_PATH)
	if splits_v is Dictionary:
		var delta: Dictionary = splits_v
		var s_v: Variant = delta.get("splits", {})
		if s_v is Dictionary:
			_splits = s_v


static func _load_json(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text)


## Same construction as PUWSpawner._global_index: first non-empty
## string wins across all groups.
static func _global_index(groups: Dictionary) -> Dictionary:
	var idx: Dictionary = {}
	for map_name_v in groups:
		var g_v: Variant = groups[map_name_v]
		if not (g_v is Dictionary):
			continue
		var g: Dictionary = g_v
		var e_v: Variant = g.get("entries", {})
		if not (e_v is Dictionary):
			continue
		var entries: Dictionary = e_v
		for label_v in entries:
			var label: String = label_v
			if idx.has(label):
				continue
			var v: Variant = entries[label]
			if v is String:
				var t: String = v
				if t != "":
					idx[label] = t
	return idx


func _resolve(map_name: String, label: String) -> String:
	var group_entries: Dictionary = {}
	var g_v: Variant = _groups.get(map_name, {})
	if g_v is Dictionary:
		var g: Dictionary = g_v
		var e_v: Variant = g.get("entries", {})
		if e_v is Dictionary:
			group_entries = e_v
	var text: String = ""
	var own_v: Variant = group_entries.get(label, "")
	if own_v is String:
		text = own_v
	if text == "":
		var glob_v: Variant = _global.get(label, "")
		if glob_v is String:
			text = glob_v
	return text


func _resolve_all(map_name: String, labels: Array) -> Array:
	var out: Array = []
	for label_v in labels:
		var t: String = _resolve(map_name, String(label_v))
		if t != "":
			out.append(t)
	return out


func _split_entry(map_name: String, ref: String) -> Dictionary:
	var per_map_v: Variant = _splits.get(map_name, {})
	if not (per_map_v is Dictionary):
		return {}
	var per_map: Dictionary = per_map_v
	var entry_v: Variant = per_map.get(ref, {})
	if entry_v is Dictionary:
		var entry: Dictionary = entry_v
		return entry
	return {}


func has_split(map_name: String, ref: String) -> bool:
	_ensure_loaded()
	return not _split_entry(map_name, ref).is_empty()


## Append one choice block to `lines` (mutated). Returns the block
## descriptor {prompt_index, yes_target, no_target, block_end,
## branch_end_index, branch_goto} with indices into `lines`.
func _append_choice_block(lines: Array, map_name: String,
		seg: Dictionary) -> Dictionary:
	var prompt_text: String = _resolve(map_name, String(seg.get("prompt", "")))
	var prompt_index: int = lines.size()
	lines.append(prompt_text)
	var no_texts: Array = _resolve_all(map_name, _seg_labels(seg, "no"))
	var yes_texts: Array = _resolve_all(map_name, _seg_labels(seg, "yes"))
	var tail_texts: Array = _resolve_all(map_name, _seg_labels(seg, "tail"))
	var no_start: int = lines.size()
	lines.append_array(no_texts)
	# Branch terminator: sits between the NO and YES sections.
	# Its goto is fixed once the whole block is laid out.
	var branch_end_index: int = lines.size()
	lines.append({})
	var yes_start: int = lines.size()
	lines.append_array(yes_texts)
	var tail_start: int = lines.size()
	lines.append_array(tail_texts)
	var branch_goto: int = tail_start
	if tail_texts.is_empty():
		branch_goto = lines.size()
	lines[branch_end_index] = {
		"text": "",
		"speaker": "",
		"choices": [],
		"branch_end": true,
		"goto_index": branch_goto,
	}
	var yes_target: int = branch_end_index
	if not yes_texts.is_empty():
		yes_target = yes_start
	elif not tail_texts.is_empty():
		yes_target = tail_start
	var no_target: int = branch_end_index
	if not no_texts.is_empty():
		no_target = no_start
	elif not tail_texts.is_empty():
		no_target = tail_start
	lines[prompt_index] = {
		"text": prompt_text,
		"speaker": "",
		"choices": [
			{"label": "Yes", "target_index": yes_target},
			{"label": "No", "target_index": no_target},
		],
	}
	return {
		"prompt_index": prompt_index,
		"yes_target": yes_target,
		"no_target": no_target,
		"block_end": lines.size(),
		"branch_end_index": branch_end_index,
		"branch_goto": branch_goto,
	}


static func _seg_labels(seg: Dictionary, key: String) -> Array:
	var v: Variant = seg.get(key, [])
	if v is Array:
		var a: Array = v
		return a
	return []


## Full runner-ready line list for a split entry, or [] when the
## (map, ref) has no split.
func assemble(map_name: String, ref: String) -> Array:
	_ensure_loaded()
	var entry: Dictionary = _split_entry(map_name, ref)
	if entry.is_empty():
		return []
	var lines: Array = []
	var segments: Array = _seg_labels(entry, "segments")
	for seg_v in segments:
		if not (seg_v is Dictionary):
			continue
		var seg: Dictionary = seg_v
		if String(seg.get("type", "")) == "linear":
			lines.append_array(
				_resolve_all(map_name, _seg_labels(seg, "labels")))
		elif String(seg.get("type", "")) == "choice":
			_append_choice_block(lines, map_name, seg)
	return lines


## Descriptors of the choice blocks inside assemble()'s output,
## in source order: {choice_ordinal, prompt_index, yes_target,
## no_target, block_end, branch_end_index, branch_goto}. Indices
## are into the assembled array.
func choice_blocks(map_name: String, ref: String) -> Array:
	_ensure_loaded()
	var entry: Dictionary = _split_entry(map_name, ref)
	var blocks: Array = []
	if entry.is_empty():
		return blocks
	var lines: Array = []
	var ordinal: int = 0
	var segments: Array = _seg_labels(entry, "segments")
	for seg_v in segments:
		if not (seg_v is Dictionary):
			continue
		var seg: Dictionary = seg_v
		if String(seg.get("type", "")) == "linear":
			lines.append_array(
				_resolve_all(map_name, _seg_labels(seg, "labels")))
		elif String(seg.get("type", "")) == "choice":
			var d: Dictionary = _append_choice_block(lines, map_name, seg)
			d["choice_ordinal"] = ordinal
			ordinal += 1
			blocks.append(d)
	return blocks


## Just one choice block as its own line list (prompt at index 0,
## block-relative targets) — what a host plays for one flow, and
## what the test suite drives. [] when out of range.
func assemble_block(map_name: String, ref: String,
		choice_ordinal: int) -> Array:
	_ensure_loaded()
	var entry: Dictionary = _split_entry(map_name, ref)
	if entry.is_empty():
		return []
	var ordinal: int = 0
	var segments: Array = _seg_labels(entry, "segments")
	for seg_v in segments:
		if not (seg_v is Dictionary):
			continue
		var seg: Dictionary = seg_v
		if String(seg.get("type", "")) != "choice":
			continue
		if ordinal == choice_ordinal:
			var lines: Array = []
			_append_choice_block(lines, map_name, seg)
			return lines
		ordinal += 1
	return []
