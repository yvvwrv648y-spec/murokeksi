class_name PalletHomeClues
extends RefCounted
## Section 8.1: Conditional world content for Riley's and Tasha's homes.

static func get_tasha_fridge_note(selected_protagonist: String) -> Dictionary:
	if selected_protagonist == "tasha":
		return {"present": false, "lines": []}
	var bottom_line: String = "Going to become the Champion." if selected_protagonist == "riley" else "Go find my boywife."
	return {
		"present": true,
		"scratched_out": ["See Professor Oak", "Head to Vermilion"],
		"active_line": bottom_line
	}

static func get_riley_drawing_book(selected_protagonist: String) -> Dictionary:
	if selected_protagonist == "riley":
		return {"present": false, "text": ""}
	if selected_protagonist == "tasha":
		return {
			"present": true,
			"text": "Didn't wake Wifestress! I'm off to become the Champion and marry my Wifestress!"
		}
	return {
		"present": true,
		"text": "The scribbled notes say, 'Going to become the champion then marry my Wifestress!'"
	}
