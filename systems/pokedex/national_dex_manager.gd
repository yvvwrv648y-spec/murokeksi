class_name NationalDexManager
extends Node
## Dual PKDX (Pokémon) & MDX (Moemon) National Pokédex Manager (1,025 Gen I-IX + 3 Gen X = 1,028).

const DEX_PATH := "res://systems/pokedex/national_dex_1028.json"
var species_by_id: Dictionary = {}
var pkdx_caught: Dictionary = {}
var mdx_caught: Dictionary = {}

func _ready() -> void:
	if FileAccess.file_exists(DEX_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DEX_PATH))
		if parsed is Dictionary and parsed.has("entries"):
			for e in parsed["entries"]:
				species_by_id[int(e["national_dex_id"])] = e

func register_catch(dex_id: int, family: String = "PKDX") -> void:
	if family == "MDX":
		mdx_caught[dex_id] = true
	else:
		pkdx_caught[dex_id] = true
