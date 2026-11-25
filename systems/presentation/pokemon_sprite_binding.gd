class_name PUWPokemonSpriteBinding
extends RefCounted
## Shared Pokemon display-sprite binding for Pokemon Ultimate
## World: the ONE resolution path for Pokemon pictures in
## battle and in cutscenes/story display.
##
## What this does, in plain words:
## Battle and cutscenes must never grow separate sprite paths
## (the 2026-11-23 battle/cutscene check found battle using a
## stills-only loader while the animated resolver sat unused,
## and cutscenes having no Pokemon display path at all). This
## binding is the single door: given a mon Dictionary (or a
## species/forme pair), it resolves the display sprite through
## ShinySpriteResolver -- the animated Showdown resolver over
## data/shiny_sprites_index.json -- and returns the URL plus an
## honest classification:
##
##   "animated"    -- a live-verified animated GIF exists for
##                    the requested view/shiny and is the URL.
##   "static-only" -- no verified animated sprite for that
##                    view, but the index carries a still
##                    picture (PokeAPI PNG; official artwork as
##                    a front-view last resort). The still is
##                    the URL.
##   "missing"     -- no sprite of any kind for that
##                    species/forme/view. The URL is "" and the
##                    caller must show NOTHING in place of the
##                    Pokemon -- never a flat placeholder block
##                    presented as the Pokemon.
##
## Forme-aware: a mon's "forme" field (set by Mega Evolution,
## Gigantamax, Primal Reversion, Ultra Burst and ability
## form-changes) wins over its species, so a form-change
## re-resolves to the forme's own art. Name resolution goes
## through the resolver's proven row-finding, preferring the
## mon's "species_slug" field where present -- the name
## formats the old battle loader missed (Iron-treads,
## Type: Null, Ho-Oh, Farfetch'd, tapu-koko, ...) all resolve.
##
## Contexts: "battle" and "cutscene" resolve IDENTICALLY --
## same resolver, same classification, same URL -- which the
## test suite proves sample by sample. The follower context
## keeps its own binding (PUWFollowerSpriteResolver over the
## same index), because a battle GIF is not follower
## animation; there is no third placeholder path.
##
## MDX (Moemon): unchanged by design. An MDX mon resolves
## exactly like its PKDX counterpart through this binding
## (counterpart art via the resolver), as documented for
## battle; MDX follower art stays missing per the follower
## binding's rule.
##
## HARD RULES: sprites are INDEXED BY URL and streamed/cached
## by the caller (PUWSpriteLoader); this binding downloads
## nothing and never constructs a URL -- every URL it returns
## comes out of ShinySpriteResolver over the index data.

const CONTEXT_BATTLE: String = "battle"
const CONTEXT_CUTSCENE: String = "cutscene"

const CLASS_ANIMATED: String = "animated"
const CLASS_STATIC: String = "static-only"
const CLASS_MISSING: String = "missing"

var _resolver: ShinySpriteResolver = null
var _rig_registry: PUWRigRegistry = null


func _init(resolver: ShinySpriteResolver = null) -> void:
	_resolver = resolver if resolver != null else ShinySpriteResolver.new()


## The shared engine-rigging registry (route 3): battle rigs
## for the species with no source-animated sprite.
func rig_registry() -> PUWRigRegistry:
	if _rig_registry == null:
		_rig_registry = PUWRigRegistry.new()
	return _rig_registry


## The underlying animated resolver (shared, read-only use).
func resolver() -> ShinySpriteResolver:
	return _resolver


## Resolve the display sprite for a battle/cutscene mon.
## "mon" is a battle-style Dictionary with any of:
## species, species_slug, forme, shiny, name, family.
## is_back asks for the back view (the player's own battler);
## the foe/cutscene default is the front view.
func resolve_for_mon(mon: Dictionary, context: String = CONTEXT_BATTLE, is_back: bool = false) -> Dictionary:
	var species: String = str(mon.get("species", mon.get("name", "")))
	var species_slug: String = str(mon.get("species_slug", ""))
	var forme: String = str(mon.get("forme", ""))
	var shiny: bool = bool(mon.get("shiny", false))
	var family: String = str(mon.get("family", "PKDX"))
	var resolved_name: String = _resolved_name(species, species_slug, forme)
	return _resolve_named(resolved_name, species, forme, shiny, context, is_back, family)


## Resolve a display sprite from plain parts -- the entry
## point story/campaign code uses when it has a species name
## (and optionally a forme) rather than a battle mon.
func resolve_species(species: String, forme: String = "", shiny: bool = false, context: String = CONTEXT_CUTSCENE, is_back: bool = false, species_slug: String = "") -> Dictionary:
	var resolved_name: String = _resolved_name(species, species_slug, forme)
	return _resolve_named(resolved_name, species, forme, shiny, context, is_back, "PKDX")


## Pick the name that should be looked up, in order:
## 1. the forme itself when it names a row (Mega/Gmax/Primal/
##    Ultra and ability formes are stored as full names like
##    "Charizard-Mega-X", "Darmanitan-Zen", "mimikyu-busted");
## 2. species + forme combined, for partial forme values
##    ("Rapid-Strike", "Zen", "Gmax");
## 3. the mon's species_slug where present (the field the old
##    loader ignored);
## 4. the species/name text as given.
## Row existence is checked through the resolver's own
## row-finding, so the first candidate that names a real index
## row wins and no candidate is ever guessed into a URL.
func _resolved_name(species: String, species_slug: String, forme: String) -> String:
	var forme_clean: String = forme.strip_edges()
	if not forme_clean.is_empty():
		if not _resolver.row_info(forme_clean).is_empty():
			return forme_clean
		var base_for_forme: String = species_slug if not species_slug.strip_edges().is_empty() else species
		if not base_for_forme.strip_edges().is_empty():
			var combined: String = base_for_forme.strip_edges() + "-" + forme_clean
			if not _resolver.row_info(combined).is_empty():
				return combined
			# Partial forme with no row of its own: fall through
			# to the species candidates below rather than
			# returning a name that resolves nowhere.
	if not species_slug.strip_edges().is_empty():
		if not _resolver.row_info(species_slug).is_empty():
			return species_slug
	if not species.strip_edges().is_empty():
		return species
	return species_slug


func _resolve_named(resolved_name: String, species: String, forme: String, shiny: bool, context: String, is_back: bool, family: String) -> Dictionary:
	var view: String = "back" if is_back else "front"
	var result: Dictionary = {
		"context": context,
		"classification": CLASS_MISSING,
		"url": "",
		"animated_url": "",
		"static_url": "",
		"animated": false,
		"species": species,
		"forme": forme,
		"resolved_name": resolved_name,
		"showdown_id": "",
		"sprite_slug": "",
		"is_form": false,
		"shiny": shiny,
		"view": view,
		"family": family,
		"cache_key": "",
		"reason": "",
		"provenance": "none",
		"animation_status": "neon-gap",
		"rig": {},
	}
	if resolved_name.strip_edges().is_empty():
		result["reason"] = "no_species_name"
		return result
	var info: Dictionary = _resolver.row_info(resolved_name)
	if info.is_empty():
		result["reason"] = "species_not_in_index"
		return result
	result["showdown_id"] = str(info.get("showdown_id", ""))
	result["sprite_slug"] = str(info.get("sprite_slug", ""))
	result["is_form"] = bool(info.get("is_form", false))
	result["cache_key"] = _cache_key(str(info.get("showdown_id", "")), view, shiny)
	var animated_url: String = ""
	if shiny:
		animated_url = _resolver.get_shiny_sprite_url(resolved_name, is_back)
	else:
		animated_url = _resolver.get_normal_sprite_url(resolved_name, is_back)
	result["animated_url"] = animated_url
	if not animated_url.is_empty():
		result["classification"] = CLASS_ANIMATED
		result["url"] = animated_url
		result["animated"] = true
		result["provenance"] = "source-animated"
		result["animation_status"] = "source-animated"
		return result
	var static_url: String = _resolver.get_still_sprite_url(resolved_name, shiny, is_back)
	if static_url.is_empty() and not is_back:
		# Official artwork is a front picture only; it is never
		# presented as a back view.
		static_url = _resolver.get_official_artwork_url(resolved_name)
	result["static_url"] = static_url
	if not static_url.is_empty():
		result["classification"] = CLASS_STATIC
		result["url"] = static_url
		result["reason"] = "no_verified_animated_" + view
		# Engine rigging (route 3): where a battle rig exists
		# for this species, the still is presented with the
		# rig's idle motion (PUWRigStage). The classification
		# stays honestly "static-only" for the ART; the motion
		# provenance is labeled "engine-rigged" and the rig
		# definition travels with the result.
		var rig: Dictionary = rig_registry().battle_rig(str(info.get("showdown_id", "")))
		if not rig.is_empty():
			result["provenance"] = "engine-rigged"
			result["animation_status"] = "engine-rigged"
			result["rig"] = rig
		else:
			result["provenance"] = "static-still"
			result["animation_status"] = "neon-gap"
		return result
	result["reason"] = "form_no_sprite_at_all" if bool(info.get("is_form", false)) else "no_sprite_for_view"
	return result


## Stable cache key for one resolved row + view + shiny flag.
## Forme changes change the row, so they change the key --
## the battle scene keys its shown-sprite state on this, which
## is what makes a form-change refresh the picture.
static func _cache_key(showdown_id: String, view: String, shiny: bool) -> String:
	var key: String = showdown_id.strip_edges().to_lower()
	if key.is_empty():
		return ""
	key += "_" + view
	if shiny:
		key += "_shiny"
	return key
