class_name PUWSpriteLoader
extends Node
## Streams Pokemon sprites at runtime from URLs resolved out
## of the sprite index (res://data/shiny_sprites_index.json)
## and caches them under user://sprite_cache/, so each sprite
## is downloaded at most once. Playback of the game never waits
## on this: get_url_sprite fills the given AnimatedSprite2D
## when the picture is ready (from cache at once, or when the
## download lands), and quietly does nothing when the download
## or the decode fails.
##
## Since the 2026-11-23 battle sprite binding fix, resolution
## (WHICH url) lives in PUWPokemonSpriteBinding over
## ShinySpriteResolver -- animated Showdown GIF first, indexed
## still PNG as fallback. This loader only moves bytes: it
## streams the one URL it is handed, caches it, decodes it
## (GIF frames via PUWGifDecoder, stills via Image) and plays
## it. Animated GIFs therefore actually animate in battle.
## The index itself ships with the game; the pictures stay
## URL-indexed and are fetched one at a time, on demand --
## never bulk-downloaded into the pack.
##
## The legacy get_sprite(species, view_key, ...) entry point is
## kept for compatibility, but it now resolves through the
## same binding (species_slug-aware, forme-blindness fixed by
## the binding's callers passing forme through the mon-based
## API in the battle scene) instead of the old PokeAPI-stills-
## only index this loader used to build for itself.

const CACHE_DIR: String = "user://sprite_cache"

var _binding: PUWPokemonSpriteBinding = null
## target instance id -> cache_key of the newest request for
## that target, so a slow download for a previous forme can
## never overwrite the sprite of the forme that replaced it.
var _latest_by_target: Dictionary = {}


func _ensure_binding() -> void:
	if _binding == null:
		_binding = PUWPokemonSpriteBinding.new()


## The shared binding this loader's legacy entry point
## resolves through.
func binding() -> PUWPokemonSpriteBinding:
	_ensure_binding()
	return _binding


## Sanitized cache file path for one cache key + URL (the
## extension comes from the URL itself: .gif for animated
## sprites, .png for stills).
func cache_path_for_key(cache_key: String, url: String) -> String:
	var ext: String = ".png"
	var clean_url: String = url.split("?")[0].split("#")[0]
	var dot: int = clean_url.rfind(".")
	if dot >= 0:
		var candidate: String = clean_url.substr(dot).to_lower()
		if candidate in [".gif", ".png", ".jpg", ".jpeg", ".webp"]:
			ext = candidate
	return CACHE_DIR + "/" + _sanitize(cache_key) + ext


## Legacy cache path helper (species + PokeAPI view key),
## kept so older callers/tests see the same shape as before.
func cache_path_for(species: String, view_key: String) -> String:
	return CACHE_DIR + "/" + _sanitize(species) + "_" + _sanitize(view_key) + ".png"


static func _sanitize(text: String) -> String:
	var out: String = text.strip_edges().to_lower()
	var clean: String = ""
	for ch in out:
		if ("a" <= ch and ch <= "z") or ("0" <= ch and ch <= "9") or ch == "-" or ch == "_":
			clean += ch
		else:
			clean += "-"
	while clean.contains("--"):
		clean = clean.replace("--", "-")
	return clean.strip_edges().trim_prefix("-").trim_suffix("-")


## Ask for the sprite at one already-resolved URL. cache_key
## names the cache entry (the binding's cache_key: row + view
## + shiny). When the picture is ready it is set on target
## and played, and the optional on_ready callback is called
## with the target. An empty URL does nothing -- there is no
## sprite to show, and no placeholder is substituted.
func get_url_sprite(url: String, cache_key: String, target: AnimatedSprite2D, on_ready: Callable = Callable()) -> void:
	if url.is_empty() or target == null:
		return
	var key: String = cache_key if not cache_key.is_empty() else _sanitize(url.get_file().get_basename())
	_latest_by_target[target.get_instance_id()] = key
	# Local project files (integration build 2, 2026-11-23): the
	# EBDX 1831 battle strips resolve to res:// paths. They ship
	# with the game, so there is nothing to stream or cache —
	# load the file directly and slice it (see _apply_local).
	if url.begins_with("res://"):
		_apply_local(url, key, target, on_ready)
		return
	var cache_path: String = cache_path_for_key(key, url)
	if FileAccess.file_exists(cache_path):
		_apply(cache_path, key, target, on_ready)
		return
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var request := HTTPRequest.new()
	request.name = "SpriteRequest"
	add_child(request)
	request.request_completed.connect(_on_request_done.bind(cache_path, key, target, on_ready, request))
	var err: int = request.request(url)
	if err != OK:
		request.queue_free()


## Legacy entry point: resolve a species + PokeAPI-style view
## key ("front", "back", "shiny-front", "shiny-back") through
## the shared binding and stream the result. New code should
## resolve through PUWPokemonSpriteBinding itself (it is
## forme-aware) and call get_url_sprite.
func get_sprite(species: String, view_key: String, target: AnimatedSprite2D, on_ready: Callable = Callable()) -> void:
	_ensure_binding()
	var shiny: bool = view_key.begins_with("shiny")
	var is_back: bool = view_key.ends_with("back")
	var result: Dictionary = _binding.resolve_species(species, "", shiny, PUWPokemonSpriteBinding.CONTEXT_BATTLE, is_back)
	var url: String = str(result.get("url", ""))
	if url.is_empty():
		return
	get_url_sprite(url, str(result.get("cache_key", "")), target, on_ready)


func _on_request_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, cache_path: String, cache_key: String, target: AnimatedSprite2D, on_ready: Callable, request: HTTPRequest) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.is_empty():
		return
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(body)
	file.close()
	_apply(cache_path, cache_key, target, on_ready)


func _apply(cache_path: String, cache_key: String, target: AnimatedSprite2D, on_ready: Callable) -> void:
	if not is_instance_valid(target):
		return
	# A newer request for this target superseded this one
	# (e.g. the mon changed forme while downloading): the
	# stale picture must not land.
	if str(_latest_by_target.get(target.get_instance_id(), cache_key)) != cache_key:
		return
	var frames: SpriteFrames = null
	var frame_size: Vector2 = Vector2.ZERO
	if cache_path.ends_with(".gif"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(cache_path)
		var decoded: Dictionary = PUWGifDecoder.decode(bytes)
		if not bool(decoded.get("ok", false)):
			return
		frames = _sprite_frames_from_gif(decoded)
		frame_size = Vector2(float(decoded.get("width", 0)), float(decoded.get("height", 0)))
	else:
		var image := Image.new()
		if image.load(cache_path) != OK:
			return
		frames = SpriteFrames.new()
		frames.add_animation("default")
		frames.add_frame("default", ImageTexture.create_from_image(image))
		frame_size = image.get_size()
	if frames == null:
		return
	target.sprite_frames = frames
	# Fit the picture into the 96x96 frame the placeholder
	# blocks use, keeping its shape.
	var longest: float = maxf(frame_size.x, frame_size.y)
	if longest > 0.0:
		var scale_factor: float = 96.0 / longest
		target.scale = Vector2(scale_factor, scale_factor)
	target.play("default")
	if on_ready.is_valid():
		on_ready.call(target)


## Apply a LOCAL image file (res://) to the target. When the
## image is an EBDX-style horizontal strip — wider than tall
## with the width an exact multiple of the height — it is
## sliced into height-sized square frames and looped at the
## same 10 fps base rate as GIF playback (the EBDX engine
## keeps its rate as a constant; no per-sprite fps data
## exists). Any other local image is a single frame. The same
## stale-request guard and 96x96 fit as the streamed path
## apply. A file that fails to load does nothing — no
## placeholder is substituted.
##
## Binding build 5 (2026-11-24): a local .gif file (the held
## Showdown GIF pool bound into art/battle_gifs/) is decoded
## with the same PUWGifDecoder path the streamed cache uses —
## a local GIF is the same bytes the cache path already
## plays, so it plays identically.
func _apply_local(path: String, cache_key: String, target: AnimatedSprite2D, on_ready: Callable) -> void:
	if not is_instance_valid(target):
		return
	if str(_latest_by_target.get(target.get_instance_id(), cache_key)) != cache_key:
		return
	if path.to_lower().ends_with(".gif"):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return
		var decoded: Dictionary = PUWGifDecoder.decode(bytes)
		if not bool(decoded.get("ok", false)):
			return
		var gif_frames: SpriteFrames = _sprite_frames_from_gif(decoded)
		if gif_frames == null:
			return
		target.sprite_frames = gif_frames
		var gif_size: Vector2 = Vector2(float(decoded.get("width", 0)), float(decoded.get("height", 0)))
		var gif_longest: float = maxf(gif_size.x, gif_size.y)
		if gif_longest > 0.0:
			var gif_scale: float = 96.0 / gif_longest
			target.scale = Vector2(gif_scale, gif_scale)
		target.play("default")
		if on_ready.is_valid():
			on_ready.call(target)
		return
	var image := Image.new()
	if image.load(path) != OK:
		return
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", 10.0)
	frames.set_animation_loop("default", true)
	var width: int = image.get_width()
	var height: int = image.get_height()
	if height > 0 and width > height and width % height == 0:
		var frame_count: int = width / height
		for i in frame_count:
			var cell: Image = image.get_region(Rect2i(i * height, 0, height, height))
			frames.add_frame("default", ImageTexture.create_from_image(cell))
	else:
		frames.add_frame("default", ImageTexture.create_from_image(image))
	target.sprite_frames = frames
	var is_strip: bool = height > 0 and width > height and width % height == 0
	var longest: float = float(height) if is_strip else maxf(float(width), float(height))
	if longest > 0.0:
		var scale_factor: float = 96.0 / longest
		target.scale = Vector2(scale_factor, scale_factor)
	target.play("default")
	if on_ready.is_valid():
		on_ready.call(target)


## Build SpriteFrames from a decoded GIF. The animation runs
## at a 10 fps base rate and each frame's relative duration
## carries the GIF's own delay, so Showdown timing is kept.
func _sprite_frames_from_gif(decoded: Dictionary) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", 10.0)
	frames.set_animation_loop("default", true)
	var images: Array = decoded.get("frames", [])
	var delays: Array = decoded.get("delays", [])
	for i in images.size():
		var image: Image = images[i]
		var delay_s: float = float(delays[i]) if i < delays.size() else 0.1
		var duration: float = clampf(delay_s * 10.0, 0.2, 100.0)
		frames.add_frame("default", ImageTexture.create_from_image(image), duration)
	return frames
