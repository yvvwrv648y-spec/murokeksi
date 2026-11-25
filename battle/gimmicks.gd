class_name PUWGimmicks
extends RefCounted
## Battle gimmicks for Pokemon Ultimate World (Godot 4).
## Plain words: Mega Evolution, Z-Moves, Dynamax, Gigantamax,
## Terastal, Primal Reversion, and Ultra Burst.
##
## Where the lists came from (made by a script, not typed by hand):
## - Mega stones, Mega formes, Z-Crystals, Z-Moves, Max Moves, G-Max
##   formes and G-Max moves come from files/pokemon-full/data/gimmicks.json.
## - Mega forme types, abilities, and base stats come from
##   files/pokemon-full/data/pokedex.json (the Showdown Pokedex data).
## - The Mega stone -> species links come from the "requiredItem" field
##   of each Mega forme in that same Pokedex data. Two stones,
##   Meowsticite and Tatsugirinite, have no Mega forme in the data
##   (the gimmicks file notes they are nonstandard), so they map to
##   Meowstic and Tatsugiri and Mega Evolving with them fails safe.
## - Rayquaza has no Mega Stone in the data. In the real games it Mega
##   Evolves by knowing Dragon Ascent, not by holding a stone, so
##   can_mega_evolve() checks the mon's moves for "Dragon Ascent"
##   when the species is Rayquaza, and mega_evolve() uses the
##   Rayquaza-Mega forme straight from MEGA_FORME_DATA.
## - The type -> Z-Move links and the species Z-Crystal links were
##   checked against the GameFAQs Z-Move list.
##
## Z-Power table (VERIFIED): the power of a type Z-Move comes from the
## power of the base move, using the standard table from Bulbapedia
## (quoted in the Pokemania Blog post "Z-Move Base Power") and checked
## against the GameFAQs list (Thunderbolt 90 -> 175, Hydro Pump 110 -> 185,
## Close Combat 120 -> 190, Bolt Strike 130 -> 195, Boomburst 140 -> 200,
## Blast Burn 150 -> 200). Seven moves break the table and have their
## own fixed Z-Power, also from Bulbapedia: Mega Drain 120,
## Weather Ball 160, Hex 160, Gear Grind 180, V-create 220,
## Flying Press 170, Core Enforcer 140. Those are in Z_POWER_EXCEPTIONS.
##
## Terastal STAB rule (Gen 9): a Terastallized Pokemon gets 2.0x STAB
## on moves of its Tera type, and keeps 1.5x STAB on moves that match
## its original types. PUWBattleEngine.calculate_damage() applies this
## using the "tera_type" and "original_types" keys set here.
##
## Every function here fails safe: if the Pokemon, item, or battle
## state does not allow the gimmick, the Pokemon is returned unchanged
## and a plain-English line is added to the logs array.

## Mega Stone item name -> species that holds it.
const MEGA_STONES: Dictionary = {
	"Abomasite": "Abomasnow",
	"Absolite": "Absol",
	"Absolite Z": "Absol",
	"Aerodactylite": "Aerodactyl",
	"Aggronite": "Aggron",
	"Alakazite": "Alakazam",
	"Altarianite": "Altaria",
	"Ampharosite": "Ampharos",
	"Audinite": "Audino",
	"Banettite": "Banette",
	"Barbaracite": "Barbaracle",
	"Baxcalibrite": "Baxcalibur",
	"Beedrillite": "Beedrill",
	"Blastoisinite": "Blastoise",
	"Blazikenite": "Blaziken",
	"Cameruptite": "Camerupt",
	"Chandelurite": "Chandelure",
	"Charizardite X": "Charizard",
	"Charizardite Y": "Charizard",
	"Chesnaughtite": "Chesnaught",
	"Chimechite": "Chimecho",
	"Clefablite": "Clefable",
	"Crabominite": "Crabominable",
	"Crucibellite": "Crucibelle",
	"Darkranite": "Darkrai",
	"Delphoxite": "Delphox",
	"Diancite": "Diancie",
	"Dragalgite": "Dragalge",
	"Dragoninite": "Dragonite",
	"Drampanite": "Drampa",
	"Eelektrossite": "Eelektross",
	"Emboarite": "Emboar",
	"Excadrite": "Excadrill",
	"Falinksite": "Falinks",
	"Feraligite": "Feraligatr",
	"Floettite": "Floette",
	"Froslassite": "Froslass",
	"Galladite": "Gallade",
	"Garchompite": "Garchomp",
	"Garchompite Z": "Garchomp",
	"Gardevoirite": "Gardevoir",
	"Gengarite": "Gengar",
	"Glalitite": "Glalie",
	"Glimmoranite": "Glimmora",
	"Golisopite": "Golisopod",
	"Golurkite": "Golurk",
	"Greninjite": "Greninja",
	"Gyaradosite": "Gyarados",
	"Hawluchanite": "Hawlucha",
	"Heatranite": "Heatran",
	"Heracronite": "Heracross",
	"Houndoominite": "Houndoom",
	"Kangaskhanite": "Kangaskhan",
	"Latiasite": "Latias",
	"Latiosite": "Latios",
	"Lopunnite": "Lopunny",
	"Lucarionite": "Lucario",
	"Lucarionite Z": "Lucario",
	"Magearnite": "Magearna",
	"Malamarite": "Malamar",
	"Manectite": "Manectric",
	"Mawilite": "Mawile",
	"Medichamite": "Medicham",
	"Meganiumite": "Meganium",
	"Meowsticite": "Meowstic",
	"Metagrossite": "Metagross",
	"Mewtwonite X": "Mewtwo",
	"Mewtwonite Y": "Mewtwo",
	"Pidgeotite": "Pidgeot",
	"Pinsirite": "Pinsir",
	"Pyroarite": "Pyroar",
	"Raichunite X": "Raichu",
	"Raichunite Y": "Raichu",
	"Sablenite": "Sableye",
	"Salamencite": "Salamence",
	"Sceptilite": "Sceptile",
	"Scizorite": "Scizor",
	"Scolipite": "Scolipede",
	"Scovillainite": "Scovillain",
	"Scraftinite": "Scrafty",
	"Sharpedonite": "Sharpedo",
	"Skarmorite": "Skarmory",
	"Slowbronite": "Slowbro",
	"Staraptite": "Staraptor",
	"Starminite": "Starmie",
	"Steelixite": "Steelix",
	"Swampertite": "Swampert",
	"Tatsugirinite": "Tatsugiri",
	"Tyranitarite": "Tyranitar",
	"Venusaurite": "Venusaur",
	"Victreebelite": "Victreebel",
	"Zeraorite": "Zeraora",
	"Zygardite": "Zygarde"
}

## Every Mega forme name.
const MEGA_FORMES: Array = [
	"Abomasnow-Mega", "Absol-Mega", "Absol-Mega-Z", "Aerodactyl-Mega",
	"Aggron-Mega", "Alakazam-Mega", "Altaria-Mega", "Ampharos-Mega",
	"Audino-Mega", "Banette-Mega", "Barbaracle-Mega", "Baxcalibur-Mega",
	"Beedrill-Mega", "Blastoise-Mega", "Blaziken-Mega", "Camerupt-Mega",
	"Chandelure-Mega", "Charizard-Mega-X", "Charizard-Mega-Y", "Chesnaught-Mega",
	"Chimecho-Mega", "Clefable-Mega", "Crabominable-Mega", "Crucibelle-Mega",
	"Darkrai-Mega", "Delphox-Mega", "Diancie-Mega", "Dragalge-Mega",
	"Dragonite-Mega", "Drampa-Mega", "Eelektross-Mega", "Emboar-Mega",
	"Excadrill-Mega", "Falinks-Mega", "Feraligatr-Mega", "Floette-Mega",
	"Froslass-Mega", "Gallade-Mega", "Garchomp-Mega", "Garchomp-Mega-Z",
	"Gardevoir-Mega", "Gengar-Mega", "Glalie-Mega", "Glimmora-Mega",
	"Golisopod-Mega", "Golurk-Mega", "Greninja-Mega", "Gyarados-Mega",
	"Hawlucha-Mega", "Heatran-Mega", "Heracross-Mega", "Houndoom-Mega",
	"Kangaskhan-Mega", "Latias-Mega", "Latios-Mega", "Lopunny-Mega",
	"Lucario-Mega", "Lucario-Mega-Z", "Magearna-Mega", "Malamar-Mega",
	"Manectric-Mega", "Mawile-Mega", "Medicham-Mega", "Meganium-Mega",
	"Metagross-Mega", "Mewtwo-Mega-X", "Mewtwo-Mega-Y", "Pidgeot-Mega",
	"Pinsir-Mega", "Pyroar-Mega", "Raichu-Mega-X", "Raichu-Mega-Y",
	"Rayquaza-Mega", "Sableye-Mega", "Salamence-Mega", "Sceptile-Mega",
	"Scizor-Mega", "Scolipede-Mega", "Scovillain-Mega", "Scrafty-Mega",
	"Sharpedo-Mega", "Skarmory-Mega", "Slowbro-Mega", "Staraptor-Mega",
	"Starmie-Mega", "Steelix-Mega", "Swampert-Mega", "Tyranitar-Mega",
	"Venusaur-Mega", "Victreebel-Mega", "Zeraora-Mega", "Zygarde-Mega"
]

## Mega forme name -> types, ability, and base stats (from the Pokedex
## data). The base stats are data for later stat work; Mega Evolving
## here changes forme, types, and ability only, not the battle stats.
const MEGA_FORME_DATA: Dictionary = {
	"Abomasnow-Mega": {"types": ["Grass", "Ice"], "ability": "Snow Warning", "base_stats": {"hp": 90, "atk": 132, "def": 105, "spa": 132, "spd": 105, "spe": 30}},
	"Absol-Mega": {"types": ["Dark"], "ability": "Magic Bounce", "base_stats": {"hp": 65, "atk": 150, "def": 60, "spa": 115, "spd": 60, "spe": 115}},
	"Absol-Mega-Z": {"types": ["Dark", "Ghost"], "ability": "Sharpness", "base_stats": {"hp": 65, "atk": 154, "def": 60, "spa": 75, "spd": 60, "spe": 151}},
	"Aerodactyl-Mega": {"types": ["Rock", "Flying"], "ability": "Tough Claws", "base_stats": {"hp": 80, "atk": 135, "def": 85, "spa": 70, "spd": 95, "spe": 150}},
	"Aggron-Mega": {"types": ["Steel"], "ability": "Filter", "base_stats": {"hp": 70, "atk": 140, "def": 230, "spa": 60, "spd": 80, "spe": 50}},
	"Alakazam-Mega": {"types": ["Psychic"], "ability": "Trace", "base_stats": {"hp": 55, "atk": 50, "def": 65, "spa": 175, "spd": 105, "spe": 150}},
	"Altaria-Mega": {"types": ["Dragon", "Fairy"], "ability": "Pixilate", "base_stats": {"hp": 75, "atk": 110, "def": 110, "spa": 110, "spd": 105, "spe": 80}},
	"Ampharos-Mega": {"types": ["Electric", "Dragon"], "ability": "Mold Breaker", "base_stats": {"hp": 90, "atk": 95, "def": 105, "spa": 165, "spd": 110, "spe": 45}},
	"Audino-Mega": {"types": ["Normal", "Fairy"], "ability": "Healer", "base_stats": {"hp": 103, "atk": 60, "def": 126, "spa": 80, "spd": 126, "spe": 50}},
	"Banette-Mega": {"types": ["Ghost"], "ability": "Prankster", "base_stats": {"hp": 64, "atk": 165, "def": 75, "spa": 93, "spd": 83, "spe": 75}},
	"Barbaracle-Mega": {"types": ["Rock", "Fighting"], "ability": "Tough Claws", "base_stats": {"hp": 72, "atk": 140, "def": 130, "spa": 64, "spd": 106, "spe": 88}},
	"Baxcalibur-Mega": {"types": ["Dragon", "Ice"], "ability": "Thermal Exchange", "base_stats": {"hp": 115, "atk": 175, "def": 117, "spa": 105, "spd": 101, "spe": 87}},
	"Beedrill-Mega": {"types": ["Bug", "Poison"], "ability": "Adaptability", "base_stats": {"hp": 65, "atk": 150, "def": 40, "spa": 15, "spd": 80, "spe": 145}},
	"Blastoise-Mega": {"types": ["Water"], "ability": "Mega Launcher", "base_stats": {"hp": 79, "atk": 103, "def": 120, "spa": 135, "spd": 115, "spe": 78}},
	"Blaziken-Mega": {"types": ["Fire", "Fighting"], "ability": "Speed Boost", "base_stats": {"hp": 80, "atk": 160, "def": 80, "spa": 130, "spd": 80, "spe": 100}},
	"Camerupt-Mega": {"types": ["Fire", "Ground"], "ability": "Sheer Force", "base_stats": {"hp": 70, "atk": 120, "def": 100, "spa": 145, "spd": 105, "spe": 20}},
	"Chandelure-Mega": {"types": ["Ghost", "Fire"], "ability": "Infiltrator", "base_stats": {"hp": 60, "atk": 75, "def": 110, "spa": 175, "spd": 110, "spe": 90}},
	"Charizard-Mega-X": {"types": ["Fire", "Dragon"], "ability": "Tough Claws", "base_stats": {"hp": 78, "atk": 130, "def": 111, "spa": 130, "spd": 85, "spe": 100}},
	"Charizard-Mega-Y": {"types": ["Fire", "Flying"], "ability": "Drought", "base_stats": {"hp": 78, "atk": 104, "def": 78, "spa": 159, "spd": 115, "spe": 100}},
	"Chesnaught-Mega": {"types": ["Grass", "Fighting"], "ability": "Bulletproof", "base_stats": {"hp": 88, "atk": 137, "def": 172, "spa": 74, "spd": 115, "spe": 44}},
	"Chimecho-Mega": {"types": ["Psychic", "Steel"], "ability": "Levitate", "base_stats": {"hp": 75, "atk": 50, "def": 110, "spa": 135, "spd": 120, "spe": 65}},
	"Clefable-Mega": {"types": ["Fairy", "Flying"], "ability": "Magic Bounce", "base_stats": {"hp": 95, "atk": 80, "def": 93, "spa": 135, "spd": 110, "spe": 70}},
	"Crabominable-Mega": {"types": ["Fighting", "Ice"], "ability": "Iron Fist", "base_stats": {"hp": 97, "atk": 157, "def": 122, "spa": 62, "spd": 107, "spe": 33}},
	"Crucibelle-Mega": {"types": ["Rock", "Poison"], "ability": "Magic Guard", "base_stats": {"hp": 106, "atk": 135, "def": 75, "spa": 91, "spd": 125, "spe": 108}},
	"Darkrai-Mega": {"types": ["Dark"], "ability": "Bad Dreams", "base_stats": {"hp": 70, "atk": 120, "def": 130, "spa": 165, "spd": 130, "spe": 85}},
	"Delphox-Mega": {"types": ["Fire", "Psychic"], "ability": "Levitate", "base_stats": {"hp": 75, "atk": 69, "def": 72, "spa": 159, "spd": 125, "spe": 134}},
	"Diancie-Mega": {"types": ["Rock", "Fairy"], "ability": "Magic Bounce", "base_stats": {"hp": 50, "atk": 160, "def": 110, "spa": 160, "spd": 110, "spe": 110}},
	"Dragalge-Mega": {"types": ["Poison", "Dragon"], "ability": "Regenerator", "base_stats": {"hp": 65, "atk": 85, "def": 105, "spa": 132, "spd": 163, "spe": 44}},
	"Dragonite-Mega": {"types": ["Dragon", "Flying"], "ability": "Multiscale", "base_stats": {"hp": 91, "atk": 124, "def": 115, "spa": 145, "spd": 125, "spe": 100}},
	"Drampa-Mega": {"types": ["Normal", "Dragon"], "ability": "Berserk", "base_stats": {"hp": 78, "atk": 85, "def": 110, "spa": 160, "spd": 116, "spe": 36}},
	"Eelektross-Mega": {"types": ["Electric"], "ability": "Eelevate", "base_stats": {"hp": 85, "atk": 145, "def": 80, "spa": 135, "spd": 90, "spe": 80}},
	"Emboar-Mega": {"types": ["Fire", "Fighting"], "ability": "Mold Breaker", "base_stats": {"hp": 110, "atk": 148, "def": 75, "spa": 110, "spd": 110, "spe": 75}},
	"Excadrill-Mega": {"types": ["Ground", "Steel"], "ability": "Piercing Drill", "base_stats": {"hp": 110, "atk": 165, "def": 100, "spa": 65, "spd": 65, "spe": 103}},
	"Falinks-Mega": {"types": ["Fighting"], "ability": "Defiant", "base_stats": {"hp": 65, "atk": 135, "def": 135, "spa": 70, "spd": 65, "spe": 100}},
	"Feraligatr-Mega": {"types": ["Water", "Dragon"], "ability": "Dragonize", "base_stats": {"hp": 85, "atk": 160, "def": 125, "spa": 89, "spd": 93, "spe": 78}},
	"Floette-Mega": {"types": ["Fairy"], "ability": "Fairy Aura", "base_stats": {"hp": 74, "atk": 85, "def": 87, "spa": 155, "spd": 148, "spe": 102}},
	"Froslass-Mega": {"types": ["Ice", "Ghost"], "ability": "Snow Warning", "base_stats": {"hp": 70, "atk": 80, "def": 70, "spa": 140, "spd": 100, "spe": 120}},
	"Gallade-Mega": {"types": ["Psychic", "Fighting"], "ability": "Inner Focus", "base_stats": {"hp": 68, "atk": 165, "def": 95, "spa": 65, "spd": 115, "spe": 110}},
	"Garchomp-Mega": {"types": ["Dragon", "Ground"], "ability": "Sand Force", "base_stats": {"hp": 108, "atk": 170, "def": 115, "spa": 120, "spd": 95, "spe": 92}},
	"Garchomp-Mega-Z": {"types": ["Dragon"], "ability": "Levitate", "base_stats": {"hp": 108, "atk": 130, "def": 85, "spa": 141, "spd": 85, "spe": 151}},
	"Gardevoir-Mega": {"types": ["Psychic", "Fairy"], "ability": "Pixilate", "base_stats": {"hp": 68, "atk": 85, "def": 65, "spa": 165, "spd": 135, "spe": 100}},
	"Gengar-Mega": {"types": ["Ghost", "Poison"], "ability": "Shadow Tag", "base_stats": {"hp": 60, "atk": 65, "def": 80, "spa": 170, "spd": 95, "spe": 130}},
	"Glalie-Mega": {"types": ["Ice"], "ability": "Refrigerate", "base_stats": {"hp": 80, "atk": 120, "def": 80, "spa": 120, "spd": 80, "spe": 100}},
	"Glimmora-Mega": {"types": ["Rock", "Poison"], "ability": "Adaptability", "base_stats": {"hp": 83, "atk": 90, "def": 105, "spa": 150, "spd": 96, "spe": 101}},
	"Golisopod-Mega": {"types": ["Bug", "Steel"], "ability": "Tough Claws", "base_stats": {"hp": 75, "atk": 150, "def": 175, "spa": 70, "spd": 120, "spe": 40}},
	"Golurk-Mega": {"types": ["Ground", "Ghost"], "ability": "Unseen Fist", "base_stats": {"hp": 89, "atk": 159, "def": 105, "spa": 70, "spd": 105, "spe": 55}},
	"Greninja-Mega": {"types": ["Water", "Dark"], "ability": "Protean", "base_stats": {"hp": 72, "atk": 125, "def": 77, "spa": 133, "spd": 81, "spe": 142}},
	"Gyarados-Mega": {"types": ["Water", "Dark"], "ability": "Mold Breaker", "base_stats": {"hp": 95, "atk": 155, "def": 109, "spa": 70, "spd": 130, "spe": 81}},
	"Hawlucha-Mega": {"types": ["Fighting", "Flying"], "ability": "No Guard", "base_stats": {"hp": 78, "atk": 137, "def": 100, "spa": 74, "spd": 93, "spe": 118}},
	"Heatran-Mega": {"types": ["Fire", "Steel"], "ability": "Flash Fire", "base_stats": {"hp": 91, "atk": 120, "def": 106, "spa": 175, "spd": 141, "spe": 67}},
	"Heracross-Mega": {"types": ["Bug", "Fighting"], "ability": "Skill Link", "base_stats": {"hp": 80, "atk": 185, "def": 115, "spa": 40, "spd": 105, "spe": 75}},
	"Houndoom-Mega": {"types": ["Dark", "Fire"], "ability": "Solar Power", "base_stats": {"hp": 75, "atk": 90, "def": 90, "spa": 140, "spd": 90, "spe": 115}},
	"Kangaskhan-Mega": {"types": ["Normal"], "ability": "Parental Bond", "base_stats": {"hp": 105, "atk": 125, "def": 100, "spa": 60, "spd": 100, "spe": 100}},
	"Latias-Mega": {"types": ["Dragon", "Psychic"], "ability": "Levitate", "base_stats": {"hp": 80, "atk": 100, "def": 120, "spa": 140, "spd": 150, "spe": 110}},
	"Latios-Mega": {"types": ["Dragon", "Psychic"], "ability": "Levitate", "base_stats": {"hp": 80, "atk": 130, "def": 100, "spa": 160, "spd": 120, "spe": 110}},
	"Lopunny-Mega": {"types": ["Normal", "Fighting"], "ability": "Scrappy", "base_stats": {"hp": 65, "atk": 136, "def": 94, "spa": 54, "spd": 96, "spe": 135}},
	"Lucario-Mega": {"types": ["Fighting", "Steel"], "ability": "Adaptability", "base_stats": {"hp": 70, "atk": 145, "def": 88, "spa": 140, "spd": 70, "spe": 112}},
	"Lucario-Mega-Z": {"types": ["Fighting", "Steel"], "ability": "Aura Guard", "base_stats": {"hp": 70, "atk": 100, "def": 70, "spa": 164, "spd": 70, "spe": 151}},
	"Magearna-Mega": {"types": ["Steel", "Fairy"], "ability": "Soul-Heart", "base_stats": {"hp": 80, "atk": 125, "def": 115, "spa": 170, "spd": 115, "spe": 95}},
	"Malamar-Mega": {"types": ["Dark", "Psychic"], "ability": "Contrary", "base_stats": {"hp": 86, "atk": 102, "def": 88, "spa": 98, "spd": 120, "spe": 88}},
	"Manectric-Mega": {"types": ["Electric"], "ability": "Intimidate", "base_stats": {"hp": 70, "atk": 75, "def": 80, "spa": 135, "spd": 80, "spe": 135}},
	"Mawile-Mega": {"types": ["Steel", "Fairy"], "ability": "Huge Power", "base_stats": {"hp": 50, "atk": 105, "def": 125, "spa": 55, "spd": 95, "spe": 50}},
	"Medicham-Mega": {"types": ["Fighting", "Psychic"], "ability": "Pure Power", "base_stats": {"hp": 60, "atk": 100, "def": 85, "spa": 80, "spd": 85, "spe": 100}},
	"Meganium-Mega": {"types": ["Grass", "Fairy"], "ability": "Mega Sol", "base_stats": {"hp": 80, "atk": 92, "def": 115, "spa": 143, "spd": 115, "spe": 80}},
	"Metagross-Mega": {"types": ["Steel", "Psychic"], "ability": "Tough Claws", "base_stats": {"hp": 80, "atk": 145, "def": 150, "spa": 105, "spd": 110, "spe": 110}},
	"Mewtwo-Mega-X": {"types": ["Psychic", "Fighting"], "ability": "Steadfast", "base_stats": {"hp": 106, "atk": 190, "def": 100, "spa": 154, "spd": 100, "spe": 130}},
	"Mewtwo-Mega-Y": {"types": ["Psychic"], "ability": "Insomnia", "base_stats": {"hp": 106, "atk": 150, "def": 70, "spa": 194, "spd": 120, "spe": 140}},
	"Pidgeot-Mega": {"types": ["Normal", "Flying"], "ability": "No Guard", "base_stats": {"hp": 83, "atk": 80, "def": 80, "spa": 135, "spd": 80, "spe": 121}},
	"Pinsir-Mega": {"types": ["Bug", "Flying"], "ability": "Aerilate", "base_stats": {"hp": 65, "atk": 155, "def": 120, "spa": 65, "spd": 90, "spe": 105}},
	"Pyroar-Mega": {"types": ["Fire", "Normal"], "ability": "Fire Mane", "base_stats": {"hp": 86, "atk": 88, "def": 92, "spa": 129, "spd": 86, "spe": 126}},
	"Raichu-Mega-X": {"types": ["Electric"], "ability": "Electric Surge", "base_stats": {"hp": 60, "atk": 135, "def": 95, "spa": 90, "spd": 95, "spe": 110}},
	"Raichu-Mega-Y": {"types": ["Electric"], "ability": "No Guard", "base_stats": {"hp": 60, "atk": 100, "def": 55, "spa": 160, "spd": 80, "spe": 130}},
	"Rayquaza-Mega": {"types": ["Dragon", "Flying"], "ability": "Delta Stream", "base_stats": {"hp": 105, "atk": 180, "def": 100, "spa": 180, "spd": 100, "spe": 115}},
	"Sableye-Mega": {"types": ["Dark", "Ghost"], "ability": "Magic Bounce", "base_stats": {"hp": 50, "atk": 85, "def": 125, "spa": 85, "spd": 115, "spe": 20}},
	"Salamence-Mega": {"types": ["Dragon", "Flying"], "ability": "Aerilate", "base_stats": {"hp": 95, "atk": 145, "def": 130, "spa": 120, "spd": 90, "spe": 120}},
	"Sceptile-Mega": {"types": ["Grass", "Dragon"], "ability": "Lightning Rod", "base_stats": {"hp": 70, "atk": 110, "def": 75, "spa": 145, "spd": 85, "spe": 145}},
	"Scizor-Mega": {"types": ["Bug", "Steel"], "ability": "Technician", "base_stats": {"hp": 70, "atk": 150, "def": 140, "spa": 65, "spd": 100, "spe": 75}},
	"Scolipede-Mega": {"types": ["Bug", "Poison"], "ability": "Shell Armor", "base_stats": {"hp": 60, "atk": 140, "def": 149, "spa": 75, "spd": 99, "spe": 62}},
	"Scovillain-Mega": {"types": ["Grass", "Fire"], "ability": "Spicy Spray", "base_stats": {"hp": 65, "atk": 138, "def": 85, "spa": 138, "spd": 85, "spe": 75}},
	"Scrafty-Mega": {"types": ["Dark", "Fighting"], "ability": "Intimidate", "base_stats": {"hp": 65, "atk": 130, "def": 135, "spa": 55, "spd": 135, "spe": 68}},
	"Sharpedo-Mega": {"types": ["Water", "Dark"], "ability": "Strong Jaw", "base_stats": {"hp": 70, "atk": 140, "def": 70, "spa": 110, "spd": 65, "spe": 105}},
	"Skarmory-Mega": {"types": ["Steel", "Flying"], "ability": "Stalwart", "base_stats": {"hp": 65, "atk": 140, "def": 110, "spa": 40, "spd": 100, "spe": 110}},
	"Slowbro-Mega": {"types": ["Water", "Psychic"], "ability": "Shell Armor", "base_stats": {"hp": 95, "atk": 75, "def": 180, "spa": 130, "spd": 80, "spe": 30}},
	"Staraptor-Mega": {"types": ["Fighting", "Flying"], "ability": "Contrary", "base_stats": {"hp": 85, "atk": 140, "def": 100, "spa": 60, "spd": 90, "spe": 110}},
	"Starmie-Mega": {"types": ["Water", "Psychic"], "ability": "Huge Power", "base_stats": {"hp": 60, "atk": 100, "def": 105, "spa": 130, "spd": 105, "spe": 120}},
	"Steelix-Mega": {"types": ["Steel", "Ground"], "ability": "Sand Force", "base_stats": {"hp": 75, "atk": 125, "def": 230, "spa": 55, "spd": 95, "spe": 30}},
	"Swampert-Mega": {"types": ["Water", "Ground"], "ability": "Swift Swim", "base_stats": {"hp": 100, "atk": 150, "def": 110, "spa": 95, "spd": 110, "spe": 70}},
	"Tyranitar-Mega": {"types": ["Rock", "Dark"], "ability": "Sand Stream", "base_stats": {"hp": 100, "atk": 164, "def": 150, "spa": 95, "spd": 120, "spe": 71}},
	"Venusaur-Mega": {"types": ["Grass", "Poison"], "ability": "Thick Fat", "base_stats": {"hp": 80, "atk": 100, "def": 123, "spa": 122, "spd": 120, "spe": 80}},
	"Victreebel-Mega": {"types": ["Grass", "Poison"], "ability": "Innards Out", "base_stats": {"hp": 80, "atk": 125, "def": 85, "spa": 135, "spd": 95, "spe": 70}},
	"Zeraora-Mega": {"types": ["Electric"], "ability": "Volt Absorb", "base_stats": {"hp": 88, "atk": 157, "def": 75, "spa": 147, "spd": 80, "spe": 153}},
	"Zygarde-Mega": {"types": ["Dragon", "Ground"], "ability": "Aura Break", "base_stats": {"hp": 216, "atk": 70, "def": 91, "spa": 216, "spd": 85, "spe": 100}}
}

## Every Z-Crystal item name.
const Z_CRYSTALS: Array = [
	"Aloraichium Z", "Buginium Z", "Darkinium Z", "Decidium Z",
	"Dragonium Z", "Eevium Z", "Electrium Z", "Fairium Z",
	"Fightinium Z", "Firium Z", "Flyinium Z", "Ghostium Z",
	"Grassium Z", "Groundium Z", "Icium Z", "Incinium Z",
	"Kommonium Z", "Lunalium Z", "Lycanium Z", "Marshadium Z",
	"Mewnium Z", "Mimikium Z", "Normalium Z", "Pikanium Z",
	"Pikashunium Z", "Poisonium Z", "Primarium Z", "Psychium Z",
	"Rockium Z", "Snorlium Z", "Solganium Z", "Steelium Z",
	"Tapunium Z", "Ultranecrozium Z", "Waterium Z"
]

## Every Z-Move name.
const Z_MOVES: Array = [
	"10,000,000 Volt Thunderbolt", "Acid Downpour", "All-Out Pummeling", "Black Hole Eclipse",
	"Bloom Doom", "Breakneck Blitz", "Catastropika", "Clangorous Soulblaze",
	"Continental Crush", "Corkscrew Crash", "Devastating Drake", "Extreme Evoboost",
	"Genesis Supernova", "Gigavolt Havoc", "Guardian of Alola", "Hydro Vortex",
	"Inferno Overdrive", "Let's Snuggle Forever", "Light That Burns the Sky", "Malicious Moonsault",
	"Menacing Moonraze Maelstrom", "Never-Ending Nightmare", "Oceanic Operetta", "Pulverizing Pancake",
	"Savage Spin-Out", "Searing Sunraze Smash", "Shattered Psyche", "Sinister Arrow Raid",
	"Soul-Stealing 7-Star Strike", "Splintered Stormshards", "Stoked Sparksurfer", "Subzero Slammer",
	"Supersonic Skystrike", "Tectonic Rage", "Twinkle Tackle"
]

## Type Z-Crystal -> the Z-Move it makes. Checked against the
## GameFAQs Z-Move list (type-specific Z-Moves table).
const Z_MOVE_BY_CRYSTAL: Dictionary = {
	"Normalium Z": "Breakneck Blitz",
	"Firium Z": "Inferno Overdrive",
	"Waterium Z": "Hydro Vortex",
	"Electrium Z": "Gigavolt Havoc",
	"Grassium Z": "Bloom Doom",
	"Icium Z": "Subzero Slammer",
	"Fightinium Z": "All-Out Pummeling",
	"Poisonium Z": "Acid Downpour",
	"Groundium Z": "Tectonic Rage",
	"Flyinium Z": "Supersonic Skystrike",
	"Psychium Z": "Shattered Psyche",
	"Buginium Z": "Savage Spin-Out",
	"Rockium Z": "Continental Crush",
	"Ghostium Z": "Never-Ending Nightmare",
	"Dragonium Z": "Devastating Drake",
	"Darkinium Z": "Black Hole Eclipse",
	"Steelium Z": "Corkscrew Crash",
	"Fairium Z": "Twinkle Tackle",
}

## Type Z-Crystal -> its type, so callers can check that the base
## move matches the crystal before using the Z-Move.
const Z_CRYSTAL_TYPE: Dictionary = {
	"Normalium Z": "Normal",
	"Firium Z": "Fire",
	"Waterium Z": "Water",
	"Electrium Z": "Electric",
	"Grassium Z": "Grass",
	"Icium Z": "Ice",
	"Fightinium Z": "Fighting",
	"Poisonium Z": "Poison",
	"Groundium Z": "Ground",
	"Flyinium Z": "Flying",
	"Psychium Z": "Psychic",
	"Buginium Z": "Bug",
	"Rockium Z": "Rock",
	"Ghostium Z": "Ghost",
	"Dragonium Z": "Dragon",
	"Darkinium Z": "Dark",
	"Steelium Z": "Steel",
	"Fairium Z": "Fairy",
}

## Species Z-Crystal -> the one base move it needs and the Z-Move it
## makes. Checked against the GameFAQs Z-Move list (species Z-Moves
## table). A different base move gives no Z-Move ("").
const Z_SPECIES_MOVES: Dictionary = {
	"Pikanium Z": {"move": "Volt Tackle", "z_move": "Catastropika"},
	"Pikashunium Z": {"move": "Thunderbolt", "z_move": "10,000,000 Volt Thunderbolt"},
	"Aloraichium Z": {"move": "Thunderbolt", "z_move": "Stoked Sparksurfer"},
	"Decidium Z": {"move": "Spirit Shackle", "z_move": "Sinister Arrow Raid"},
	"Incinium Z": {"move": "Darkest Lariat", "z_move": "Malicious Moonsault"},
	"Primarium Z": {"move": "Sparkling Aria", "z_move": "Oceanic Operetta"},
	"Lycanium Z": {"move": "Stone Edge", "z_move": "Splintered Stormshards"},
	"Mimikium Z": {"move": "Play Rough", "z_move": "Let's Snuggle Forever"},
	"Snorlium Z": {"move": "Giga Impact", "z_move": "Pulverizing Pancake"},
	"Mewnium Z": {"move": "Psychic", "z_move": "Genesis Supernova"},
	"Marshadium Z": {"move": "Spectral Thief", "z_move": "Soul-Stealing 7-Star Strike"},
	"Kommonium Z": {"move": "Clanging Scales", "z_move": "Clangorous Soulblaze"},
	"Lunalium Z": {"move": "Moongeist Beam", "z_move": "Menacing Moonraze Maelstrom"},
	"Solganium Z": {"move": "Sunsteel Strike", "z_move": "Searing Sunraze Smash"},
	"Ultranecrozium Z": {"move": "Photon Geyser", "z_move": "Light That Burns the Sky"},
	"Eevium Z": {"move": "Last Resort", "z_move": "Extreme Evoboost"},
	"Tapunium Z": {"move": "Nature's Madness", "z_move": "Guardian of Alola"},
}

## Moves whose Z-Power does not follow the table (Bulbapedia, verified).
## Every other damaging move follows z_power() below.
const Z_POWER_EXCEPTIONS: Dictionary = {
	"Mega Drain": 120,
	"Weather Ball": 160,
	"Hex": 160,
	"Gear Grind": 180,
	"V-create": 220,
	"Flying Press": 170,
	"Core Enforcer": 140,
}

## Every Max Move name.
const MAX_MOVES: Array = [
	"Max Airstream", "Max Darkness", "Max Flare", "Max Flutterby",
	"Max Geyser", "Max Guard", "Max Hailstorm", "Max Knuckle",
	"Max Lightning", "Max Mindstorm", "Max Ooze", "Max Overgrowth",
	"Max Phantasm", "Max Quake", "Max Rockfall", "Max Starfall",
	"Max Steelspike", "Max Strike", "Max Wyrmwind"
]

## Move type -> the Max Move it becomes. Standard Gen 8 mapping.
## Status moves become Max Guard.
const MAX_MOVE_BY_TYPE: Dictionary = {
	"Normal": "Max Strike",
	"Fire": "Max Flare",
	"Water": "Max Geyser",
	"Electric": "Max Lightning",
	"Grass": "Max Overgrowth",
	"Ice": "Max Hailstorm",
	"Fighting": "Max Knuckle",
	"Poison": "Max Ooze",
	"Ground": "Max Quake",
	"Flying": "Max Airstream",
	"Psychic": "Max Mindstorm",
	"Bug": "Max Flutterby",
	"Rock": "Max Rockfall",
	"Ghost": "Max Phantasm",
	"Dragon": "Max Wyrmwind",
	"Dark": "Max Darkness",
	"Steel": "Max Steelspike",
	"Fairy": "Max Starfall",
}

## Max Move power that does not follow the tables below. Key is
## the move name, value is the Max Move power. 50 rows come from
## this project's moves.json ("maxMove" field, Showdown data).
## 8 rows come from Bulbapedia's Max Move per-move table:
## Low Kick 100, Night Shade 100, Super Fang 100, Mirror Coat 100,
## Beat Up 100, Spit Up 100, Reversal 100, Present 100.
const MAX_POWER_EXCEPTIONS: Dictionary = {
	"Bonemerang": 130, "Bone Rush": 130, "Bullet Seed": 130,
	"Comet Punch": 100, "Counter": 75, "Crush Grip": 140,
	"Double Hit": 120, "Double Iron Bash": 140, "Double Kick": 80,
	"Dragon Darts": 130, "Dual Chop": 130, "Dual Wingbeat": 130,
	"Electro Ball": 130, "Endeavor": 130, "Fissure": 130,
	"Flail": 130, "Frustration": 130, "Fury Swipes": 100,
	"Gear Grind": 130, "Grass Knot": 130, "Guillotine": 130,
	"Gyro Ball": 130, "Heat Crash": 130, "Heavy Slam": 130,
	"Horn Drill": 130, "Icicle Spear": 130, "Magnitude": 140,
	"Multi-Attack": 95, "Natural Gift": 130, "Pin Missile": 130,
	"Power Trip": 130, "Punishment": 130, "Return": 130,
	"Rising Voltage": 140, "Rock Blast": 130, "Scale Shot": 130,
	"Seismic Toss": 75, "Sheer Cold": 130, "Spike Cannon": 120,
	"Stored Power": 130, "Surging Strikes": 130,
	"Tachyon Cutter": 140, "Tail Slap": 130, "Terrain Pulse": 130,
	"Triple Axel": 140, "Triple Kick": 80, "Trump Card": 130,
	"Twineedle": 100, "Weather Ball": 130, "Wring Out": 140,
	"Low Kick": 100, "Night Shade": 100, "Super Fang": 100,
	"Mirror Coat": 100, "Beat Up": 100, "Spit Up": 100,
	"Reversal": 100, "Present": 100,
}

## Max Move power for most moves, from the base move's power.
## Fighting and Poison use a lower table because Max Knuckle and
## Max Ooze raise Attack and Special Attack. Checked against the
## Bulbapedia Max Move per-move table (see the spot checks in
## the patch notes above).
static func max_power_for_move(move_name: String, base_power: int, move_type: String, category: String) -> int:
	if str(category).to_lower() == "status":
		return 0
	if MAX_POWER_EXCEPTIONS.has(move_name):
		return int(MAX_POWER_EXCEPTIONS[move_name])
	if base_power <= 0:
		# No fixed power and no table row. Fallback, said plainly:
		# 100 until that move's real row is added above.
		return 100
	var mtype: String = move_type.capitalize()
	if mtype == "Fighting" or mtype == "Poison":
		if base_power <= 40:
			return 70
		if base_power <= 50:
			return 75
		if base_power <= 60:
			return 80
		if base_power <= 70:
			return 85
		if base_power <= 100:
			return 90
		return 95
	if base_power <= 40:
		return 90
	if base_power <= 50:
		return 100
	if base_power <= 60:
		return 110
	if base_power <= 70:
		return 120
	if base_power <= 100:
		return 130
	if base_power <= 140:
		return 140
	return 150

## Full Max Move for one base move: its name, power, type and
## category. Status moves become Max Guard. Struggle stays
## Struggle and is never converted.
static func get_max_move(move_name: String, base_power: int, move_type: String, category: String) -> Dictionary:
	if move_name == "Struggle":
		return {"name": "Struggle", "power": base_power, "type": move_type, "cat": category}
	if str(category).to_lower() == "status":
		return {"name": "Max Guard", "power": 0, "type": "Normal", "cat": "Status"}
	var max_name: String = str(MAX_MOVE_BY_TYPE.get(move_type.capitalize(), "Max Strike"))
	return {"name": max_name, "power": max_power_for_move(move_name, base_power, move_type, category), "type": move_type, "cat": category}

## Every Gigantamax forme name.
const GMAX_FORMES: Array = [
	"Alcremie-Gmax", "Appletun-Gmax", "Blastoise-Gmax", "Butterfree-Gmax",
	"Centiskorch-Gmax", "Charizard-Gmax", "Cinderace-Gmax", "Coalossal-Gmax",
	"Copperajah-Gmax", "Corviknight-Gmax", "Drednaw-Gmax", "Duraludon-Gmax",
	"Eevee-Gmax", "Flapple-Gmax", "Garbodor-Gmax", "Gengar-Gmax",
	"Grimmsnarl-Gmax", "Hatterene-Gmax", "Inteleon-Gmax", "Kingler-Gmax",
	"Lapras-Gmax", "Machamp-Gmax", "Melmetal-Gmax", "Meowth-Gmax",
	"Orbeetle-Gmax", "Pikachu-Gmax", "Rillaboom-Gmax", "Sandaconda-Gmax",
	"Snorlax-Gmax", "Toxtricity-Gmax", "Urshifu-Gmax", "Venusaur-Gmax"
]

## Species that can Gigantamax.
const GMAX_SPECIES: Array = [
	"Alcremie", "Appletun", "Blastoise", "Butterfree",
	"Centiskorch", "Charizard", "Cinderace", "Coalossal",
	"Copperajah", "Corviknight", "Drednaw", "Duraludon",
	"Eevee", "Flapple", "Garbodor", "Gengar",
	"Grimmsnarl", "Hatterene", "Inteleon", "Kingler",
	"Lapras", "Machamp", "Melmetal", "Meowth",
	"Orbeetle", "Pikachu", "Rillaboom", "Sandaconda",
	"Snorlax", "Toxtricity", "Urshifu", "Venusaur"
]

## Every G-Max Move name.
const GMAX_MOVES: Array = [
	"G-Max Befuddle", "G-Max Cannonade", "G-Max Centiferno", "G-Max Chi Strike",
	"G-Max Cuddle", "G-Max Depletion", "G-Max Drum Solo", "G-Max Finale",
	"G-Max Fireball", "G-Max Foam Burst", "G-Max Gold Rush", "G-Max Gravitas",
	"G-Max Hydrosnipe", "G-Max Malodor", "G-Max Meltdown", "G-Max One Blow",
	"G-Max Rapid Flow", "G-Max Replenish", "G-Max Resonance", "G-Max Sandblast",
	"G-Max Smite", "G-Max Snooze", "G-Max Steelsurge", "G-Max Stonesurge",
	"G-Max Stun Shock", "G-Max Sweetness", "G-Max Tartness", "G-Max Terror",
	"G-Max Vine Lash", "G-Max Volcalith", "G-Max Volt Crash", "G-Max Wildfire",
	"G-Max Wind Rage"
]

## Species -> its G-Max Move. Standard Gen 8 pairing. Urshifu has two
## forms: Single Strike uses G-Max One Blow, Rapid Strike uses
## G-Max Rapid Flow (see gigantamax()).
const GMAX_MOVE_BY_SPECIES: Dictionary = {
	"Alcremie": "G-Max Finale",
	"Appletun": "G-Max Sweetness",
	"Blastoise": "G-Max Cannonade",
	"Butterfree": "G-Max Befuddle",
	"Centiskorch": "G-Max Centiferno",
	"Charizard": "G-Max Wildfire",
	"Cinderace": "G-Max Fireball",
	"Coalossal": "G-Max Volcalith",
	"Copperajah": "G-Max Steelsurge",
	"Corviknight": "G-Max Wind Rage",
	"Drednaw": "G-Max Stonesurge",
	"Duraludon": "G-Max Depletion",
	"Eevee": "G-Max Cuddle",
	"Flapple": "G-Max Tartness",
	"Garbodor": "G-Max Malodor",
	"Gengar": "G-Max Terror",
	"Grimmsnarl": "G-Max Snooze",
	"Hatterene": "G-Max Smite",
	"Inteleon": "G-Max Hydrosnipe",
	"Kingler": "G-Max Foam Burst",
	"Lapras": "G-Max Resonance",
	"Machamp": "G-Max Chi Strike",
	"Melmetal": "G-Max Meltdown",
	"Meowth": "G-Max Gold Rush",
	"Orbeetle": "G-Max Gravitas",
	"Pikachu": "G-Max Volt Crash",
	"Rillaboom": "G-Max Drum Solo",
	"Sandaconda": "G-Max Sandblast",
	"Snorlax": "G-Max Replenish",
	"Toxtricity": "G-Max Stun Shock",
	"Urshifu": "G-Max One Blow",
	"Venusaur": "G-Max Vine Lash",
}

## The 18 normal types (Capitalized), for checking a Tera type.
const ALL_TYPES: Array = [
	"Normal", "Fire", "Water", "Electric",
	"Grass", "Ice", "Fighting", "Poison",
	"Ground", "Flying", "Psychic", "Bug",
	"Rock", "Ghost", "Dragon", "Dark",
	"Steel", "Fairy"
]

## Primal Orb item -> species it works on.
## From the gimmicks file: "Red Orb for Groudon, Blue Orb for Kyogre".
const PRIMAL_ORBS: Dictionary = {
	"Red Orb": "Groudon",
	"Blue Orb": "Kyogre",
}

## Species -> its Primal forme name.
const PRIMAL_FORMES: Dictionary = {
	"Groudon": "Groudon-Primal",
	"Kyogre": "Kyogre-Primal",
}

## Primal forme name -> types and ability (from the Pokedex data).
const PRIMAL_FORME_DATA: Dictionary = {
	"Groudon-Primal": {"types": ["Ground", "Fire"], "ability": "Desolate Land", "base_stats": {"hp": 100, "atk": 180, "def": 160, "spa": 150, "spd": 90, "spe": 90}},
	"Kyogre-Primal": {"types": ["Water"], "ability": "Primordial Sea", "base_stats": {"hp": 100, "atk": 150, "def": 90, "spa": 180, "spd": 160, "spe": 90}}
}

## Ultra Burst: the item, the species, and the forme it becomes.
const ULTRA_ITEM: String = "Ultranecrozium Z"
const ULTRA_SPECIES: Array = ["Necrozma", "Necrozma-Dusk-Mane", "Necrozma-Dawn-Wings"]
const ULTRA_FORME: String = "Necrozma-Ultra"

## Ultra Necrozma types and ability (from the Pokedex data).
const ULTRA_FORME_DATA: Dictionary = {
	"Necrozma-Ultra": {"types": ["Psychic", "Dragon"], "ability": "Neuroforce", "base_stats": {"hp": 97, "atk": 167, "def": 97, "spa": 167, "spd": 97, "spe": 129}}
}

static func _mon_name(mon: Dictionary) -> String:
	return str(mon.get("name", mon.get("species", "Pokémon")))

static func _vfx(stage: Node, gimmick_id: String) -> void:
	if stage != null and stage.has_method("trigger_omni_ring_vfx"):
		stage.trigger_omni_ring_vfx(gimmick_id)

static func _mega_forme_for_stone(stone: String) -> String:
	var species: String = str(MEGA_STONES.get(stone, ""))
	if species == "":
		return ""
	var suffix: String = ""
	if stone.ends_with(" X"):
		suffix = "-X"
	elif stone.ends_with(" Y"):
		suffix = "-Y"
	elif stone.ends_with(" Z"):
		suffix = "-Z"
	var forme: String = species + "-Mega" + suffix
	if forme in MEGA_FORMES:
		return forme
	if (species + "-Mega") in MEGA_FORMES:
		return species + "-Mega"
	return ""

static func can_mega_evolve(mon: Dictionary) -> bool:
	if bool(mon.get("mega_evolved", false)):
		return false
	if bool(mon.get("dynamax_active", false)) or bool(mon.get("tera_active", false)):
		return false
	if str(mon.get("species", "")) == "Rayquaza":
		return "Dragon Ascent" in mon.get("moves", [])
	var item: String = str(mon.get("item", ""))
	if not MEGA_STONES.has(item):
		return false
	if str(MEGA_STONES[item]) != str(mon.get("species", "")):
		return false
	return _mega_forme_for_stone(item) != ""

static func mega_evolve(mon: Dictionary, logs: Array, battle_state: Dictionary = {}, stage: Node = null) -> Dictionary:
	var mon_name: String = _mon_name(mon)
	if bool(battle_state.get("mega_used", false)):
		logs.append(mon_name + " can't Mega Evolve: Mega Evolution was already used this battle.")
		return mon
	if not can_mega_evolve(mon):
		if str(mon.get("species", "")) == "Rayquaza":
			logs.append(mon_name + " can't Mega Evolve: it needs to know Dragon Ascent.")
		else:
			logs.append(mon_name + " can't Mega Evolve: it needs its own Mega Stone.")
		return mon
	var stone: String = str(mon.get("item", ""))
	var forme: String = "Rayquaza-Mega" if str(mon.get("species", "")) == "Rayquaza" else _mega_forme_for_stone(stone)
	var data: Dictionary = MEGA_FORME_DATA.get(forme, {})
	mon["forme"] = forme
	mon["types"] = data.get("types", mon.get("types", []))
	mon["ability"] = str(data.get("ability", mon.get("ability", "")))
	mon["mega_evolved"] = true
	battle_state["mega_used"] = true
	_vfx(stage, "mega")
	logs.append(mon_name + " Mega Evolved into " + forme + "!")
	return mon

static func get_z_move(move_name: String, crystal: String) -> String:
	if Z_SPECIES_MOVES.has(crystal):
		var entry: Dictionary = Z_SPECIES_MOVES[crystal]
		if str(entry.get("move", "")) == move_name:
			return str(entry.get("z_move", ""))
		return ""
	return str(Z_MOVE_BY_CRYSTAL.get(crystal, ""))

static func z_crystal_type(crystal: String) -> String:
	return str(Z_CRYSTAL_TYPE.get(crystal, ""))

static func z_power(base_power: int) -> int:
	# Standard table, VERIFIED (see the header comment for sources).
	if base_power <= 55:
		return 100
	if base_power <= 65:
		return 120
	if base_power <= 75:
		return 140
	if base_power <= 85:
		return 160
	if base_power <= 95:
		return 175
	if base_power <= 100:
		return 180
	if base_power <= 110:
		return 185
	if base_power <= 120:
		return 190
	if base_power <= 130:
		return 195
	return 200

static func z_power_for_move(move_name: String, base_power: int) -> int:
	if Z_POWER_EXCEPTIONS.has(move_name):
		return int(Z_POWER_EXCEPTIONS[move_name])
	return z_power(base_power)

static func can_dynamax(mon: Dictionary) -> bool:
	if bool(mon.get("dynamax_active", false)):
		return false
	if bool(mon.get("mega_evolved", false)) or bool(mon.get("tera_active", false)):
		return false
	return true

static func _to_max_moves(moves: Array, logs: Array, mon_name: String) -> Array:
	var out: Array = []
	for m in moves:
		if m is Dictionary:
			var mtype: String = str(m.get("type", ""))
			var cat: String = str(m.get("cat", m.get("category", ""))).to_lower()
			if cat == "status":
				out.append("Max Guard")
			else:
				out.append(str(MAX_MOVE_BY_TYPE.get(mtype.capitalize(), "Max Strike")))
		else:
			# A plain move name has no type on it, so it cannot be
			# turned into a Max Move without the MoveDatabase.
			out.append(str(m))
			logs.append(mon_name + "'s move " + str(m) + " stayed as-is: its type is not known here.")
	return out

static func dynamax(mon: Dictionary, logs: Array, battle_state: Dictionary = {}, stage: Node = null) -> Dictionary:
	var mon_name: String = _mon_name(mon)
	if bool(battle_state.get("dynamax_used", false)):
		logs.append(mon_name + " can't Dynamax: Dynamax was already used this battle.")
		return mon
	if not can_dynamax(mon):
		logs.append(mon_name + " can't Dynamax right now.")
		return mon
	var max_hp: int = int(mon.get("max_hp", 100))
	mon["pre_dynamax_max_hp"] = max_hp
	var max_powers: Dictionary = {}
	for m in mon.get("moves", []):
		if m is Dictionary:
			var full: Dictionary = get_max_move(str(m.get("name", "")), int(m.get("power", 0)), str(m.get("type", "Normal")), str(m.get("cat", m.get("category", "Physical"))))
			max_powers[str(full.get("name", ""))] = int(full.get("power", 0))
	mon["max_move_powers"] = max_powers
	mon["pre_dynamax_hp"] = int(mon.get("hp", 0))
	mon["pre_dynamax_moves"] = (mon.get("moves", [])).duplicate()
	mon["pre_dynamax_forme"] = str(mon.get("forme", ""))
	mon["max_hp"] = max_hp * 2
	mon["hp"] = mini(max_hp * 2, int(mon.get("hp", 0)) * 2)
	mon["moves"] = _to_max_moves(mon.get("moves", []), logs, mon_name)
	mon["dynamax_active"] = true
	mon["dynamax_turns"] = 3
	battle_state["dynamax_used"] = true
	_vfx(stage, "dynamax")
	logs.append(mon_name + " Dynamaxed! Its HP doubled for 3 turns.")
	return mon

static func end_dynamax(mon: Dictionary, logs: Array) -> Dictionary:
	if not bool(mon.get("dynamax_active", false)):
		return mon
	var old_max: int = int(mon.get("pre_dynamax_max_hp", mon.get("max_hp", 100)))
	mon["max_hp"] = old_max
	var hp: int = int(mon.get("hp", 0))
	mon["hp"] = maxi(1, hp / 2) if hp > 0 else 0
	if mon.has("pre_dynamax_moves"):
		mon["moves"] = mon["pre_dynamax_moves"]
	if str(mon.get("pre_dynamax_forme", "")) == "":
		mon.erase("forme")
	else:
		mon["forme"] = str(mon.get("pre_dynamax_forme", ""))
	mon["dynamax_active"] = false
	mon["gigantamax_active"] = false
	mon["dynamax_turns"] = 0
	mon.erase("max_move_powers")
	logs.append(_mon_name(mon) + " returned to normal size.")
	return mon

static func can_gigantamax(mon: Dictionary) -> bool:
	if bool(mon.get("dynamax_active", false)):
		return false
	if bool(mon.get("mega_evolved", false)) or bool(mon.get("tera_active", false)):
		return false
	return str(mon.get("species", "")) in GMAX_SPECIES

static func gigantamax(mon: Dictionary, logs: Array, battle_state: Dictionary = {}, stage: Node = null) -> Dictionary:
	var mon_name: String = _mon_name(mon)
	if bool(battle_state.get("dynamax_used", false)):
		logs.append(mon_name + " can't Gigantamax: Dynamax was already used this battle.")
		return mon
	if not can_gigantamax(mon):
		logs.append(mon_name + " can't Gigantamax: only certain Pokemon can.")
		return mon
	var species: String = str(mon.get("species", ""))
	var gmax_move: String = str(GMAX_MOVE_BY_SPECIES.get(species, ""))
	if species == "Urshifu" and str(mon.get("forme", "")) == "Rapid-Strike":
		gmax_move = "G-Max Rapid Flow"
	var result: Dictionary = dynamax(mon, logs, battle_state, stage)
	if not bool(result.get("dynamax_active", false)):
		return result
	mon["forme"] = species + "-Gmax"
	mon["gigantamax_active"] = true
	var moves: Array = mon.get("moves", [])
	if gmax_move != "" and not moves.is_empty():
		# The G-Max Move takes the place of the first Max Move.
		moves[0] = gmax_move
		mon["moves"] = moves
	logs.append(mon_name + " Gigantamaxed into " + species + "-Gmax!")
	return mon

static func can_terastallize(mon: Dictionary) -> bool:
	if bool(mon.get("tera_active", false)):
		return false
	if bool(mon.get("mega_evolved", false)) or bool(mon.get("dynamax_active", false)):
		return false
	return true

static func terastallize(mon: Dictionary, tera_type: String, logs: Array, battle_state: Dictionary = {}, stage: Node = null) -> Dictionary:
	var mon_name: String = _mon_name(mon)
	if bool(battle_state.get("tera_used", false)):
		logs.append(mon_name + " can't Terastallize: Terastal was already used this battle.")
		return mon
	if not can_terastallize(mon):
		logs.append(mon_name + " can't Terastallize right now.")
		return mon
	if not (tera_type in ALL_TYPES):
		logs.append(mon_name + " can't Terastallize: " + tera_type + " is not a real type.")
		return mon
	mon["original_types"] = (mon.get("types", [])).duplicate()
	mon["types"] = [tera_type]
	mon["tera_type"] = tera_type
	mon["tera_active"] = true
	battle_state["tera_used"] = true
	_vfx(stage, "tera")
	logs.append(mon_name + " Terastallized into the " + tera_type + " type!")
	return mon

static func primal_revert(mon: Dictionary, logs: Array, battle_state: Dictionary = {}, stage: Node = null) -> Dictionary:
	var mon_name: String = _mon_name(mon)
	var item: String = str(mon.get("item", ""))
	if not PRIMAL_ORBS.has(item):
		logs.append(mon_name + " can't revert: it needs a Red Orb or a Blue Orb.")
		return mon
	var species: String = str(PRIMAL_ORBS[item])
	if str(mon.get("species", "")) != species:
		logs.append(mon_name + " can't revert: the " + item + " only works on " + species + ".")
		return mon
	if bool(mon.get("primal_active", false)):
		logs.append(mon_name + " is already in its Primal form.")
		return mon
	var forme: String = str(PRIMAL_FORMES[species])
	var data: Dictionary = PRIMAL_FORME_DATA.get(forme, {})
	mon["forme"] = forme
	mon["types"] = data.get("types", mon.get("types", []))
	mon["ability"] = str(data.get("ability", mon.get("ability", "")))
	mon["primal_active"] = true
	_vfx(stage, "primal")
	logs.append(mon_name + " reverted to its Primal form!")
	return mon

static func ultra_burst(mon: Dictionary, logs: Array, battle_state: Dictionary = {}, stage: Node = null) -> Dictionary:
	var mon_name: String = _mon_name(mon)
	if bool(battle_state.get("ultra_used", false)):
		logs.append(mon_name + " can't Ultra Burst: Ultra Burst was already used this battle.")
		return mon
	if str(mon.get("species", "")) not in ULTRA_SPECIES:
		logs.append(mon_name + " can't Ultra Burst: only Necrozma can.")
		return mon
	if str(mon.get("item", "")) != ULTRA_ITEM:
		logs.append(mon_name + " can't Ultra Burst: it needs Ultranecrozium Z.")
		return mon
	if bool(mon.get("ultra_active", false)):
		logs.append(mon_name + " is already Ultra Necrozma.")
		return mon
	var data: Dictionary = ULTRA_FORME_DATA.get(ULTRA_FORME, {})
	mon["forme"] = ULTRA_FORME
	mon["types"] = data.get("types", mon.get("types", []))
	mon["ability"] = str(data.get("ability", mon.get("ability", "")))
	mon["ultra_active"] = true
	battle_state["ultra_used"] = true
	_vfx(stage, "zmove")
	logs.append(mon_name + " became Ultra Necrozma!")
	return mon
