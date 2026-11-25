extends SceneTree
## G7 hairstyle lock tests (canon audit gap G7, merged into
## PUWCharacterSetup by binding build 2, 2026-11-23, from code
## prep rotation 1 via rotation 2's merge instructions).
## The two signature styles (Riley's tousled bob, Tasha's copper
## waves) can never be chosen for a custom profile — before or
## after finalizing — while ordinary styles stay settable.
## Run: godot --headless --script res://tests/g7_hairstyle_lock_tests.gd

var _passed: int = 0
var _failed: int = 0


func _check(name: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", name)
	else:
		_failed += 1
		print("FAIL: ", name)


func _init() -> void:
	_check("G7 locked list holds exactly the two signature styles",
		PUWCharacterSetup.locked_hairstyles() == ["riley_tousled_bob", "tasha_copper_waves"])
	_check("G7 is_hairstyle_locked true for riley style", PUWCharacterSetup.is_hairstyle_locked("riley_tousled_bob"))
	_check("G7 is_hairstyle_locked true for tasha style", PUWCharacterSetup.is_hairstyle_locked("tasha_copper_waves"))
	_check("G7 is_hairstyle_locked false for a free style", not PUWCharacterSetup.is_hairstyle_locked("medium"))

	var setup: PUWCharacterSetup = PUWCharacterSetup.new()
	var riley: Dictionary = setup.set_value_result("hair_style", "riley_tousled_bob")
	_check("G7 riley style refused via result API", not bool(riley.get("ok", true)))
	_check("G7 refusal reason names the named-character lock",
		str(riley.get("reason", "")).contains("named character"))
	_check("G7 riley style refused via bool API", not setup.set_value("hair_style", "riley_tousled_bob"))
	_check("G7 tasha style refused via bool API", not setup.set_value("hair_style", "tasha_copper_waves"))
	_check("G7 refused styles store nothing", setup.get_value("hair_style") == null)
	_check("G7 free style accepted", setup.set_value("hair_style", "medium"))
	_check("G7 free style stored", str(setup.get_value("hair_style")) == "medium")

	# The lock is step-content-based: it still applies after
	# finalizing, alongside the identity lock.
	setup.set_value("identity", "Female")
	setup.set_value("pronouns", "she/her")
	setup.set_value("body_silhouette", "female")
	setup.set_value("face", "soft")
	setup.set_value("eyes", "blue")
	setup.set_value("heterochromia", false)
	setup.set_value("hair_color", "black")
	setup.set_value("clothing", "athletic")
	setup.set_value("signature_ball", "signature ball")
	setup.set_value("confirm", "confirmed")
	_check("G7 fixture finalizes", setup.finish() and setup.is_finalized())
	_check("G7 locked style still refused after finalize", not setup.set_value("hair_style", "tasha_copper_waves"))
	_check("G7 free style still settable after finalize", setup.set_value("hair_style", "long waves"))

	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
