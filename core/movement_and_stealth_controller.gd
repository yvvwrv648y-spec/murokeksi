class_name PUWMovementAndStealthController
extends RefCounted
## Official Pokemon Movement Physics: Legends Crouch-Sneak, Walk, Auto-Run Shoes, Acro Bike, & Mach Bike.

const BASE_WALK_TPS := 4.0
const SPEEDS := {
	"sneak": 2.20,
	"walk": 4.00,
	"run": 8.00,
	"bike_acro": 10.67,
	"bike_mach": 16.00
}
const NOISE := {
	"sneak": 0.00,
	"walk": 0.45,
	"run": 0.85,
	"bike_acro": 1.00,
	"bike_mach": 1.00
}
const DETECTION_MULT := {
	"sneak": 0.35,
	"walk": 1.00,
	"run": 1.45,
	"bike_acro": 1.75,
	"bike_mach": 1.90
}

static func resolve_state(is_biking: bool, bike_gear: String, is_sneaking: bool, is_running: bool, auto_run: bool) -> Dictionary:
	var mode := "walk"
	if is_biking:
		mode = "bike_mach" if bike_gear == "mach" else "bike_acro"
	elif is_sneaking:
		mode = "sneak"
	elif is_running or auto_run:
		mode = "run"
	return {"mode": mode, "tiles_per_sec": SPEEDS[mode], "noise": NOISE[mode], "detection_mult": DETECTION_MULT[mode]}
