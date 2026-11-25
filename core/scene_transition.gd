class_name PUWSceneTransition
extends Node
## Scene switching for Pokemon Ultimate World.
## Plain words: this file only decides which scene to go to next,
## and then asks Godot to change to that scene. It holds no game
## state and it never starts a battle by itself.
##
## Scene names used here are short names like "overworld" and
## "battle". The full file paths live in SCENES below. The real
## scene files in the project are res://scenes/overworld.tscn,
## res://scenes/battle.tscn, res://scenes/party.tscn,
## res://scenes/bag.tscn and res://scenes/mart.tscn. There is no
## res://scenes/main.tscn file in the reference project yet, even
## though project.godot names it as the main scene, so the
## "battle_lost" path to "main" will only work once that file
## exists. Nothing here creates a scene file.
##
## MERGE NOTE: the RC1 project already has a file with this same
## class name, res://core/scene_transition.gd, but it is only a
## stub (transition_to with no real scene change, and nothing in
## the project calls it). This file REPLACES that stub: do not keep
## both files in the project, because two scripts cannot share one
## class_name and Godot will only see one of them. The stub's
## small API (transition_to, transition_completed,
## is_transitioning) is kept below so anything that used the old
## file still works.

## Fired when transition_to() finishes changing scene.
signal transition_completed(target_map_id: String)
## True while a transition_to() call is in progress.
var is_transitioning: bool = false

## Short scene name -> full scene file path.
const SCENES: Dictionary = {
	"overworld": "res://scenes/overworld.tscn",
	"battle": "res://scenes/battle.tscn",
	"party": "res://scenes/party.tscn",
	"bag": "res://scenes/bag.tscn",
	"mart": "res://scenes/mart.tscn",
	"main": "res://scenes/main.tscn",
}

## Work out the target scene path for a trigger, without changing
## anything. Returns "" when the trigger does nothing from the
## current scene. current_scene is a short name like "overworld",
## but a full path like "res://scenes/overworld.tscn" is also
## accepted. context is only used by "close_menu": it may hold
## "return_to" with the short name of the scene to go back to
## (default "overworld").
static func resolve_target(current_scene: String, trigger: String, context: Dictionary = {}) -> String:
	var current: String = _normalize_scene_name(current_scene)
	var trig: String = trigger.strip_edges().to_lower()
	match trig:
		"wild_encounter":
			if current == "overworld":
				return str(SCENES["battle"])
			return ""
		"trainer_battle":
			if current == "overworld":
				return str(SCENES["battle"])
			return ""
		"open_party":
			# The party can be opened from any scene.
			if current == "":
				return ""
			return str(SCENES["party"])
		"open_bag":
			if current == "battle" or current == "overworld":
				return str(SCENES["bag"])
			return ""
		"open_mart":
			if current == "overworld":
				return str(SCENES["mart"])
			return ""
		"close_menu":
			if current == "party" or current == "bag" or current == "mart":
				var return_to: String = str(context.get("return_to", "overworld"))
				return _path_for_name(return_to)
			return ""
		"battle_won":
			if current == "battle":
				return str(SCENES["overworld"])
			return ""
		"battle_fled":
			if current == "battle":
				return str(SCENES["overworld"])
			return ""
		"battle_lost":
			if current == "battle":
				return str(SCENES["main"])
			return ""
		_:
			return ""

## Change to the given scene file path. Does nothing when the path
## is empty or when this node is not inside a scene tree yet.
func go_to(scene_path: String) -> void:
	if scene_path == "":
		print("PUWSceneTransition: no scene to go to.")
		return
	if get_tree() == null:
		print("PUWSceneTransition: not in a scene tree, cannot go to " + scene_path + ".")
		return
	print("PUWSceneTransition: going to " + scene_path + ".")
	get_tree().change_scene_to_file(scene_path)

## The old RC1 stub's way to change scene, kept so old callers
## still work. target_map_id is a short scene name ("overworld",
## "battle", "party", "bag", "mart", "main") or a full scene path.
## It changes scene, clears is_transitioning, and fires
## transition_completed with the name it was given.
func transition_to(target_map_id: String) -> void:
	is_transitioning = true
	var target: String = _path_for_name(target_map_id)
	if target == "":
		target = target_map_id.strip_edges()
	go_to(target)
	is_transitioning = false
	transition_completed.emit(target_map_id)

## Work out the target for a trigger from the current scene, go
## there when there is one, and return the target path (or "").
func go_to_trigger(trigger: String, context: Dictionary = {}) -> String:
	var current: String = _current_scene_name()
	var target: String = resolve_target(current, trigger, context)
	if target == "":
		print("PUWSceneTransition: trigger '" + trigger + "' does nothing from '" + current + "'.")
		return ""
	go_to(target)
	return target

## The short name of the scene this node is currently in, or ""
## when there is no current scene.
func _current_scene_name() -> String:
	if get_tree() == null:
		return ""
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return ""
	var path: String = current_scene.scene_file_path
	if path != "":
		return _normalize_scene_name(path)
	return current_scene.name.to_lower()

## Turn a short name ("overworld") or a full path
## ("res://scenes/overworld.tscn") into a short name.
static func _normalize_scene_name(scene: String) -> String:
	var cleaned: String = scene.strip_edges().to_lower()
	if cleaned == "":
		return ""
	if cleaned.ends_with(".tscn"):
		cleaned = cleaned.get_file().trim_suffix(".tscn")
	# A plain file name such as "overworld" passes through as-is.
	return cleaned

## Full path for a short scene name, or for a path passed in
## directly. Returns "" when the name is not a known scene.
static func _path_for_name(scene_name: String) -> String:
	var cleaned: String = scene_name.strip_edges().to_lower()
	if cleaned == "":
		return ""
	if cleaned.ends_with(".tscn"):
		return scene_name.strip_edges()
	if SCENES.has(cleaned):
		return str(SCENES[cleaned])
	return ""
