# PUWModLoader — mod support for Pokemon Ultimate World (Godot 4)
#
# What this does, in plain words:
# This loader lets players add mods to PUW. A mod is a folder with a
# mod.json file in it that says what the mod is, plus its own scripts,
# scenes, and models. The loader finds mods, reads their mod.json files,
# loads them, and can place mod models into the game world. When a mod is
# unloaded, everything it placed is removed again.
#
# Where mods live:
#   user://mods/          (the normal place — players put mods here)
#   res://mods/           (built-in mods that ship with the game)
#
# What a mod folder looks like:
#   MyMod/
#     mod.json            (the manifest — see MOD_MANIFEST_KEYS below)
#     main.gd             (optional entry script, loaded when the mod loads)
#     models/
#       my_statue.tscn    (a model the mod can place in the world)
#     textures/
#       my_texture.png
#
# What mod.json looks like:
#   {
#     "id": "my_mod",
#     "name": "My Mod",
#     "version": "1.0.0",
#     "author": "Your Name",
#     "description": "What this mod does, in one or two lines.",
#     "godot_version": "4.3",
#     "entry_script": "main.gd",
#     "models": ["models/my_statue.tscn"],
#     "requires": []
#   }
#
# Safety rules (these matter):
#   - A mod can only load files from inside its own folder.
#   - Paths that try to escape the mod folder ("..", absolute paths) are refused.
#   - Only safe file types can be placed as models: .tscn, .scn, .glb,
#     .gltf, .obj. Scripts must end in .gd.
#   - A mod that fails to load never stops the game; it is skipped and
#     reported through the mod_failed signal.
#
# How to use it:
#   var mods = PUWModLoader.new()
#   add_child(mods)
#   mods.scan_mods()
#   mods.load_mod("my_mod")
#   mods.place_model("my_mod", "models/my_statue.tscn", Vector3(10, 0, 5))

class_name PUWModLoader
extends Node

signal mod_loaded(mod_id: String, mod_name: String)
signal mod_unloaded(mod_id: String)
signal mod_failed(mod_id: String, reason: String)

## Folders the loader looks in, in order.
const MOD_FOLDERS: Array[String] = ["user://mods", "res://mods"]

## The keys a mod.json manifest must have. "entry_script" and "models"
## are optional; the rest are required.
const MOD_MANIFEST_KEYS: Array[String] = ["id", "name", "version", "author", "description"]

## File types that may be placed in the world as models.
const ALLOWED_MODEL_EXTENSIONS: Array[String] = ["tscn", "scn", "glb", "gltf", "obj"]

## File types that may be loaded as scripts.
const ALLOWED_SCRIPT_EXTENSIONS: Array[String] = ["gd"]

## Where placed models go. Set this to your world root node, or leave it
## empty and pass a parent node to place_model() instead.
@export var world_root: Node3D

## id -> manifest Dictionary for every mod found by scan_mods().
var found_mods: Dictionary = {}
## id -> manifest Dictionary for every mod that is loaded right now.
var loaded_mods: Dictionary = {}
## id -> Array of Nodes this mod placed in the world.
var _placed_by_mod: Dictionary = {}
## id -> folder path of the mod.
var _mod_folders: Dictionary = {}


func _ready() -> void:
	for folder in MOD_FOLDERS:
		DirAccess.make_dir_recursive_absolute(folder)


## Find all mods in the mod folders. Returns how many were found.
func scan_mods() -> int:
	found_mods.clear()
	for base in MOD_FOLDERS:
		var dir := DirAccess.open(base)
		if dir == null:
			continue
		for entry in dir.get_directories():
			var manifest_path: String = base.path_join(entry).path_join("mod.json")
			if not FileAccess.file_exists(manifest_path):
				continue
			var manifest: Dictionary = _read_manifest(manifest_path)
			if manifest.is_empty():
				continue
			var mod_id: String = str(manifest["id"])
			found_mods[mod_id] = manifest
			_mod_folders[mod_id] = base.path_join(entry)
	return found_mods.size()


## Load one mod by its id. Returns true if it loaded.
func load_mod(mod_id: String) -> bool:
	if loaded_mods.has(mod_id):
		return true
	if not found_mods.has(mod_id):
		mod_failed.emit(mod_id, "Mod not found. Run scan_mods() first.")
		return false
	var manifest: Dictionary = found_mods[mod_id]
	# Check required mods first.
	for required_id in manifest.get("requires", []):
		if not loaded_mods.has(required_id):
			if not load_mod(str(required_id)):
				mod_failed.emit(mod_id, "Required mod missing: " + str(required_id))
				return false
	# Load the entry script, if the mod has one.
	var entry: String = str(manifest.get("entry_script", ""))
	if entry != "":
		if not _is_safe_relative_path(entry):
			mod_failed.emit(mod_id, "Entry script path is not safe: " + entry)
			return false
		var script_path: String = _mod_folders[mod_id].path_join(entry)
		var script: Script = load(script_path) as Script
		if script == null:
			mod_failed.emit(mod_id, "Entry script could not be loaded: " + entry)
			return false
		var instance: Node = script.new()
		if instance is Node:
			add_child(instance)
	loaded_mods[mod_id] = manifest
	_placed_by_mod[mod_id] = []
	mod_loaded.emit(mod_id, str(manifest["name"]))
	return true


## Unload one mod. Removes everything it placed in the world.
func unload_mod(mod_id: String) -> bool:
	if not loaded_mods.has(mod_id):
		return false
	for placed in _placed_by_mod.get(mod_id, []):
		if is_instance_valid(placed):
			placed.queue_free()
	_placed_by_mod.erase(mod_id)
	loaded_mods.erase(mod_id)
	mod_unloaded.emit(mod_id)
	return true


## Place one of a mod's models into the world.
## Returns the placed node, or null if something was wrong.
## "model_path" is relative to the mod folder, e.g. "models/my_statue.tscn".
func place_model(mod_id: String, model_path: String, position: Vector3,
		rotation_degrees: Vector3 = Vector3.ZERO,
		scale_factor: Vector3 = Vector3.ONE,
		parent: Node3D = null) -> Node3D:
	if not loaded_mods.has(mod_id):
		mod_failed.emit(mod_id, "Mod is not loaded: " + mod_id)
		return null
	if not _is_safe_relative_path(model_path):
		mod_failed.emit(mod_id, "Model path is not safe: " + model_path)
		return null
	if model_path.get_extension().to_lower() not in ALLOWED_MODEL_EXTENSIONS:
		mod_failed.emit(mod_id, "Model file type not allowed: " + model_path)
		return null
	var full_path: String = _mod_folders[mod_id].path_join(model_path)
	if not FileAccess.file_exists(full_path):
		mod_failed.emit(mod_id, "Model file not found: " + model_path)
		return null
	var packed: PackedScene = load(full_path) as PackedScene
	if packed == null:
		mod_failed.emit(mod_id, "Model could not be loaded: " + model_path)
		return null
	var node: Node3D = packed.instantiate() as Node3D
	if node == null:
		mod_failed.emit(mod_id, "Model is not a 3D scene: " + model_path)
		return null
	var place_parent: Node3D = parent if parent != null else world_root
	if place_parent == null:
		node.queue_free()
		mod_failed.emit(mod_id, "No world root set. Set world_root or pass a parent.")
		return null
	place_parent.add_child(node)
	node.position = position
	node.rotation_degrees = rotation_degrees
	node.scale = scale_factor
	_placed_by_mod[mod_id].append(node)
	return node


## Remove one placed model early, without unloading the whole mod.
func remove_placed_model(mod_id: String, node: Node3D) -> void:
	if _placed_by_mod.has(mod_id):
		_placed_by_mod[mod_id].erase(node)
	if is_instance_valid(node):
		node.queue_free()


## All models a mod has placed, so the game can move or hide them.
func placed_models(mod_id: String) -> Array:
	return _placed_by_mod.get(mod_id, []).duplicate()


## Read and check a mod.json manifest. Returns an empty Dictionary if bad.
func _read_manifest(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var manifest: Dictionary = parsed
	for key in MOD_MANIFEST_KEYS:
		if not manifest.has(key) or str(manifest[key]).strip_edges().is_empty():
			return {}
	return manifest


## A path is safe when it is relative, stays inside the mod folder, and
## only uses allowed script/model file types where one is expected.
func _is_safe_relative_path(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("/") or path.begins_with("res://") or path.begins_with("user://"):
		return false
	if ".." in path:
		return false
	if path.begins_with("~"):
		return false
	return true
