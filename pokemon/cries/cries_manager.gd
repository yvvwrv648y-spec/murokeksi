class_name PokemonCryPlayer
extends Node
## Plays species cries in battle and in the Pokedex.
## Audio wiring build: the pack DOES ship local cry files now -
## 703 of them under res://audio/cries/, keyed by
## res://data/frlg_audio_index.json (649 species by dex number
## plus 54 form entries). play_cry tries the local file first
## and only falls back to the original web-bank behaviour
## (download the cry into the user cache, then play from cache)
## for species the local index does not cover - the Gen 6-9
## range, per the index's own note.
## Resolution never looks at a mon's family: an MDX (Moemon)
## battler resolves through its counterpart species exactly
## like a PKDX battler. Cries are the sound contract for both
## families; no Moemon voice data exists to source.

const BANK_PATH: String = "res://audio/cries/cries_bank.json"
const INDEX_PATH: String = "res://data/frlg_audio_index.json"
const CACHE_DIR: String = "user://cries_cache"

## Audio bus layout prep (code_prep_audio_buses): the cry
## player rides the "Cries" bus from default_bus_layout.tres,
## so cries mix separately from music and effects.
const CRY_BUS: String = "Cries"

## Playback volume in decibels. 0.0 is normal volume.
## There is no checked per-species volume or pitch data, so
## every cry uses this one plain setting. Nothing is made up.
@export var volume_db: float = 0.0

## Local-only playback (audio bus layout prep). When true,
## play_cry resolves the bound local files and nothing else:
## no cache lookup, no download, no network — a species the
## local index does not cover simply returns false. The menu
## host sets this on the Pokédex's cry player (a dex lookup
## must never start a download); battle's own player keeps
## the default false, so the Gen 6-9 bank fallback there is
## unchanged.
var local_only: bool = false

var _bank_loaded: bool = false
var _cries: Dictionary = {}
var _name_to_id: Dictionary = {}
var _index_loaded: bool = false
var _local_by_dex: Dictionary = {}
var _local_by_form: Dictionary = {}
var _local_name_by_dex: Dictionary = {}
var _player: AudioStreamPlayer = null
var _request: HTTPRequest = null
var _downloading: Dictionary = {}
var _download_id: int = 0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "CryAudioPlayer"
	_player.bus = CRY_BUS
	add_child(_player)


func get_status() -> Dictionary:
	return {"module": "cries", "class": "PokemonCryPlayer", "operational": true}


## How many species are in the loaded bank. Loads the bank first.
func get_bank_count() -> int:
	_ensure_bank()
	return _cries.size()


## Load the bank file once and keep it in memory.
## Also builds a name lookup, so "Pikachu" can find dex id 25.
func _ensure_bank() -> void:
	if _bank_loaded:
		return
	_bank_loaded = true
	if not FileAccess.file_exists(BANK_PATH):
		return
	var file: FileAccess = FileAccess.open(BANK_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var bank: Dictionary = parsed
	var cries_value: Variant = bank.get("cries", {})
	if not (cries_value is Dictionary):
		return
	_cries = cries_value
	for key_value: Variant in _cries.keys():
		var key: String = str(key_value)
		var entry_value: Variant = _cries.get(key, {})
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var species_name: String = str(entry.get("name", ""))
			if species_name != "":
				_name_to_id[_normalize_name(species_name)] = int(key)


## Load the bound local index once: dex number -> res file for
## the 649 species entries, and normalized form name -> res
## file for the 54 form entries (each form entry also carries
## its base dex number, recorded by the keying pass).
func _ensure_local_index() -> void:
	if _index_loaded:
		return
	_index_loaded = true
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not (parsed is Dictionary):
		return
	var index: Dictionary = parsed
	var cries_value: Variant = index.get("cries", {})
	if not (cries_value is Dictionary):
		return
	var cries: Dictionary = cries_value
	for key_value: Variant in cries.keys():
		var key: String = str(key_value)
		var entry_value: Variant = cries.get(key, {})
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var file: String = str(entry.get("file", ""))
		if file == "":
			continue
		if key.is_valid_int():
			_local_by_dex[int(key)] = file
			var species_name: String = str(entry.get("name", ""))
			if species_name != "":
				_local_name_by_dex[int(key)] = _normalize_name(species_name)
		else:
			# Form entry: keyed by its index name (for example
			# "kyurem-white"); the entry's own name field is
			# the same string.
			_local_by_form[_normalize_name(key)] = file
			var entry_name: String = str(entry.get("name", ""))
			if entry_name != "":
				_local_by_form[_normalize_name(entry_name)] = file


## How many local cry files the bound index carries.
func get_local_count() -> int:
	_ensure_local_index()
	return _local_by_dex.size() + _local_by_form.size()


## The local res:// path of a species cry, "" when the local
## index does not cover it. form_name, when given, is matched
## against the form entries first - directly ("kyurem-white")
## or as a species+forme composite ("kyurem" + "white").
## Species matching reuses the bank's id resolution, so a dex
## number, a number string, or a display name all work, for
## PKDX and MDX battlers alike (family is never consulted).
func local_cry_path_for(species: Variant, form_name: String = "") -> String:
	_ensure_local_index()
	var form_text: String = _normalize_name(form_name)
	if form_text != "":
		var direct_value: Variant = _local_by_form.get(form_text, "")
		if str(direct_value) != "":
			return "res://" + str(direct_value)
		# Composite candidates: the species as given ("kyurem"
		# + "white"), and the species' index name when the
		# caller passed a dex number (646 + "white").
		var composites: Array[String] = [_normalize_name(str(species)) + "-" + form_text]
		var dex_for_name: int = resolve_id(species)
		if dex_for_name > 0:
			var index_name: String = str(_local_name_by_dex.get(dex_for_name, ""))
			if index_name != "":
				composites.append(index_name + "-" + form_text)
		for composite in composites:
			var composite_value: Variant = _local_by_form.get(composite, "")
			if str(composite_value) != "":
				return "res://" + str(composite_value)
	var species_text: String = _normalize_name(str(species))
	var by_species_form: Variant = _local_by_form.get(species_text, "")
	if str(by_species_form) != "":
		return "res://" + str(by_species_form)
	var dex_id: int = resolve_id(species)
	if dex_id > 0:
		var by_dex_value: Variant = _local_by_dex.get(dex_id, "")
		if str(by_dex_value) != "":
			return "res://" + str(by_dex_value)
	return ""


## Play the cry for a battle party entry. Reads the same
## fields BattleScene always read (dex_id / species_id / dex,
## else species / name, plus forme / form when present) and
## never reads "family": an MDX battler's cry is its
## counterpart species' cry, by the same resolution.
func play_cry_for_mon(mon: Dictionary) -> bool:
	var dex_value: Variant = mon.get("dex_id", mon.get("species_id", mon.get("dex", 0)))
	var form_text: String = str(mon.get("forme", mon.get("form", "")))
	if dex_value is int and int(dex_value) > 0:
		return play_cry(int(dex_value), form_text)
	var species_text: String = str(mon.get("species_slug", mon.get("species", mon.get("name", ""))))
	if species_text != "":
		return play_cry(species_text, form_text)
	return false


## Make a species name easy to match: lower case, spaces and
## underscores become hyphens, dots and apostrophes are dropped.
## Example: "Mr. Mime" becomes "mr-mime".
func _normalize_name(raw_name: String) -> String:
	var result: String = raw_name.strip_edges().to_lower()
	result = result.replace("_", "-")
	result = result.replace(" ", "-")
	result = result.replace("'", "")
	result = result.replace(".", "")
	result = result.replace("♀", "-f")
	result = result.replace("♂", "-m")
	while result.contains("--"):
		result = result.replace("--", "-")
	return result.strip_edges()


## Turn a species value into a dex id.
## The value can be an int (25), a number string ("25"),
## or a name ("Pikachu", "mr-mime", "Mr. Mime").
## Returns 0 when the species is not in the bank.
func resolve_id(species: Variant) -> int:
	_ensure_bank()
	if species is int:
		var id_from_int: int = int(species)
		if _cries.has(str(id_from_int)):
			return id_from_int
		return 0
	if species is float:
		var id_from_float: int = int(species)
		if _cries.has(str(id_from_float)):
			return id_from_float
		return 0
	var text: String = str(species).strip_edges()
	if text == "":
		return 0
	if text.is_valid_int():
		var id_from_text: int = text.to_int()
		if _cries.has(str(id_from_text)):
			return id_from_text
		return 0
	var normalized: String = _normalize_name(text)
	var id_value: Variant = _name_to_id.get(normalized, 0)
	return int(id_value)


## The web link for a species cry. Uses the "latest" link.
## Returns "" when the species is unknown.
func cry_url_for(species: Variant) -> String:
	var dex_id: int = resolve_id(species)
	if dex_id <= 0:
		return ""
	var entry_value: Variant = _cries.get(str(dex_id), {})
	if not (entry_value is Dictionary):
		return ""
	var entry: Dictionary = entry_value
	return str(entry.get("latest", ""))


## Where a downloaded cry is saved on this device.
func cache_path_for(id_value: Variant) -> String:
	var dex_id: int = resolve_id(id_value)
	if dex_id <= 0:
		# Still give a plain path for a raw number, so callers
		# can check the cache before the bank is checked.
		var text: String = str(id_value).strip_edges()
		if text.is_valid_int():
			dex_id = text.to_int()
	if dex_id <= 0:
		return ""
	return CACHE_DIR + "/" + str(dex_id) + ".ogg"


## True when this species cry is already in the local cache.
func is_cached(species: Variant) -> bool:
	var path: String = cache_path_for(species)
	if path == "":
		return false
	return FileAccess.file_exists(path)


## Play a species cry. The bound local file plays first when
## the local index covers the species (or the named form);
## otherwise the original bank behaviour runs: play from the
## download cache, or start the download (the cry plays when
## the download lands). Returns false only when the species
## is unknown to both the local index and the bank. A failed
## download just gives up quietly. With local_only set, the
## bank behaviour never runs: an uncovered species returns
## false right after the local attempt.
func play_cry(species: Variant, form_name: String = "") -> bool:
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "CryAudioPlayer"
		_player.bus = CRY_BUS
		add_child(_player)
	var local_path: String = local_cry_path_for(species, form_name)
	if local_path != "" and _play_local(local_path):
		return true
	if local_only:
		return false
	var dex_id: int = resolve_id(species)
	if dex_id <= 0:
		return false
	if is_cached(dex_id):
		return _play_from_cache(dex_id)
	if bool(_downloading.get(str(dex_id), false)):
		# This cry is already on its way. Do not start it twice.
		return true
	return _start_download(dex_id)


## Load a bound local .ogg (a res:// path from the local
## index) and play it. False when the resource cannot load,
## so the caller can fall back to the bank behaviour.
func _play_local(res_path: String) -> bool:
	var stream: AudioStream = ResourceLoader.load(res_path) as AudioStream
	if stream == null:
		return false
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()
	return true


## Load a cached .ogg file and play it.
func _play_from_cache(dex_id: int) -> bool:
	var path: String = cache_path_for(dex_id)
	var stream: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(path)
	if stream == null:
		return false
	_player.stream = stream
	_player.volume_db = volume_db
	_player.play()
	return true


## Start downloading one cry into the cache folder.
func _start_download(dex_id: int) -> bool:
	var url: String = cry_url_for(dex_id)
	if url == "":
		return false
	var err: Error = DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return false
	if _request == null:
		_request = HTTPRequest.new()
		_request.name = "CryDownloadRequest"
		add_child(_request)
		_request.request_completed.connect(_on_download_completed)
	if _request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		# The one request node is busy with another cry.
		# Give up quietly for now; the caller can ask again.
		return true
	_downloading[str(dex_id)] = true
	_download_id = dex_id
	# Save the download straight into the cache file.
	_request.download_file = cache_path_for(dex_id)
	var request_err: Error = _request.request(url)
	if request_err != OK:
		_downloading.erase(str(dex_id))
		_download_id = 0
		return true
	return true


## Called when a cry download ends. Plays the cry if it landed.
func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var dex_id: int = _download_id
	_download_id = 0
	if dex_id > 0:
		_downloading.erase(str(dex_id))
	if dex_id <= 0:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Give up quietly. Remove a partial file if one was left.
		var path: String = cache_path_for(dex_id)
		if path != "" and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	if is_cached(dex_id):
		_play_from_cache(dex_id)
