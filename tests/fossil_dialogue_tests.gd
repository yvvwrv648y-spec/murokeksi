extends SceneTree
## Fossil-revival dialogue data tests (code prep, 2026-11-23).
## Run: godot --headless --script res://tests/fossil_dialogue_tests.gd
##
## Validates data/fossil_service_dialogue.json against the REAL
## staged data it must serve:
## - every registered service point (fossil_service_points.json)
##   resolves to a complete set of flow lines (its own set or the
##   default set);
## - every line carries an honest status: "extracted" lines name
##   a held source, "placeholder" lines say so in their source;
## - the extracted Cinnabar set matches the held pokefirered
##   wording (spot-checked phrases, incl. the STR_VAR tokens
##   renamed to {SPECIES}/{FOSSIL} per the file's note);
## - refusal lines exist for every refusal reason string
##   PUWFossilRevivalService returns;
## - NO line anywhere is unlabeled.

var _passed: int = 0
var _failed: int = 0

const FLOW_KEYS: Array = [
	"greeting_ask", "declined_no_fossil", "identify", "handed_over",
	"wait", "back_to_life", "received", "come_again", "combination_identify",
]

const REFUSAL_KEYS: Array = [
	"not_a_fossil", "fossil_not_held", "incomplete_fossil_pair",
	"invalid_combination", "combination_wrong_point",
	"unknown_service_point", "species_build_failed",
]


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("PASS: ", name, (" - " + detail) if detail != "" else "")
	else:
		_failed += 1
		print("FAIL: ", name, (" - " + detail) if detail != "" else "")


func _load_json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _init() -> void:
	var dialogue: Dictionary = _load_json("res://data/fossil_service_dialogue.json")
	_check("dialogue file loads as a Dictionary", not dialogue.is_empty())
	var points_data: Dictionary = _load_json("res://data/fossil_service_points.json")
	_check("service points file loads", not points_data.is_empty())

	_test_point_coverage(dialogue, points_data)
	_test_labeling(dialogue)
	_test_extracted_cinnabar(dialogue)
	_test_refusal_coverage(dialogue)

	print("RESULT: ", _passed, " passed, ", _failed, " failed")
	quit(1 if _failed > 0 else 0)


func _lines_for_point(dialogue: Dictionary, point_id: String) -> Dictionary:
	var points: Dictionary = dialogue.get("points", {})
	if points.has(point_id):
		return points[point_id].get("lines", {})
	return dialogue.get("default_lines", {}).get("lines", {})


func _test_point_coverage(dialogue: Dictionary, points_data: Dictionary) -> void:
	var registered: Array = points_data.get("points", [])
	_check("7 service points registered", registered.size() == 7, str(registered.size()))
	for point: Variant in registered:
		var point_id: String = str(point.get("id", ""))
		var lines: Dictionary = _lines_for_point(dialogue, point_id)
		# combination_identify is only required at the Galar point;
		# every point needs the other 8 flow lines.
		for key: String in FLOW_KEYS:
			if key == "combination_identify" and point_id != "galar_route6_restoration":
				continue
			_check("point %s has line %s" % [point_id, key], lines.has(key))


func _all_line_sets(dialogue: Dictionary) -> Array:
	var sets: Array = []
	sets.append(dialogue.get("default_lines", {}).get("lines", {}))
	sets.append(dialogue.get("refusal_lines", {}).get("lines", {}))
	var points: Dictionary = dialogue.get("points", {})
	for point_id: String in points:
		sets.append(points[point_id].get("lines", {}))
	return sets


func _test_labeling(dialogue: Dictionary) -> void:
	var total: int = 0
	var extracted: int = 0
	for lines: Variant in _all_line_sets(dialogue):
		for key: String in lines:
			total += 1
			var line: Dictionary = lines[key]
			var status: String = str(line.get("status", ""))
			var source: String = str(line.get("source", ""))
			var text: String = str(line.get("text", ""))
			_check("line %s is labeled" % key, status == "extracted" or status == "placeholder", status)
			_check("line %s has text" % key, text != "")
			if status == "extracted":
				extracted += 1
				_check("extracted line %s names a source" % key, source != "" and not source.begins_with("PLACEHOLDER"))
			if status == "placeholder":
				_check("placeholder line %s says so" % key, source.begins_with("PLACEHOLDER"))
	_check("at least one extracted line exists", extracted > 0, str(extracted))
	# Exact composition: 9 default flow lines + 8 extracted Cinnabar
	# lines + 7 refusal lines = 24. An exact count, so a future edit
	# that adds or drops a line has to say so here on purpose.
	_check("dialogue line total exact", total == 24, str(total))


func _test_extracted_cinnabar(dialogue: Dictionary) -> void:
	var lines: Dictionary = _lines_for_point(dialogue, "kanto_cinnabar_lab")
	_check("cinnabar greeting is extracted", str(lines.get("greeting_ask", {}).get("status", "")) == "extracted")
	_check("cinnabar greeting wording", str(lines.get("greeting_ask", {}).get("text", "")).contains("Have you a fossil for me?"))
	_check("cinnabar identify names the machine", str(lines.get("identify", {}).get("text", "")).contains("My Resurrection Machine will make"))
	_check("cinnabar identify carries both tokens", str(lines.get("identify", {}).get("text", "")).contains("{FOSSIL}") and str(lines.get("identify", {}).get("text", "")).contains("{SPECIES}"))
	_check("cinnabar back-to-life wording", str(lines.get("back_to_life", {}).get("text", "")).contains("Your fossil is back to life!"))
	_check("cinnabar declined wording", str(lines.get("declined_no_fossil", {}).get("text", "")).contains("Is too bad!"))
	for key: String in FLOW_KEYS:
		if key == "combination_identify":
			continue
		_check("cinnabar line %s extracted" % key, str(lines.get(key, {}).get("status", "")) == "extracted")


func _test_refusal_coverage(dialogue: Dictionary) -> void:
	var refusal_lines: Dictionary = dialogue.get("refusal_lines", {}).get("lines", {})
	for key: String in REFUSAL_KEYS:
		_check("refusal line exists: %s" % key, refusal_lines.has(key))
		if refusal_lines.has(key):
			_check("refusal line %s is placeholder-labeled" % key, str(refusal_lines[key].get("status", "")) == "placeholder")
