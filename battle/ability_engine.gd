class_name AbilityEngine
extends Node
## Ability engine for Pokemon Ultimate World, battle engine v2.
## Keeps the 4 original RC1 static funcs exactly (on_switch_in,
## on_switch_out, is_immune_by_ability, modify_damage) with the same
## names, signatures and behaviour, then adds hooks.
##
## Honest counts for the 322 abilities in abilities.json (see
## ABILITY_INFO below): 320 implemented (a real code
## hook exists), 0 partial (main effect works, one smaller part

## needs engine help — named in each entry's note), 0 blocked


## (all 15 formerly blocked abilities are implemented by the
## unblock-hooks spec), 1 no-effect (Ball Fetch has no battle
## effect in Showdown), 1 TurnResolver-owned (Chlorophyll speed).


## Partial means: the heal or stat boost on being hit now fires
## for Flash Fire, Volt Absorb, Motor Drive, Lightning Rod, Water
## Absorb, Storm Drain, Sap Sipper and Well-Baked Body (the
## immunity dispatcher runs the batch arms first since the
## Group B redirect spec); Mold Breaker (only the
## immunity and damage negations in this file). Solar Power and Poison
## Heal left this list in the Group A weather spec: both are now
## implemented in full (see their ABILITY_INFO notes). Dry Skin also
## left this list: its old double heal/loss from the v2 arm is removed.


##
## No hook in this file, on purpose: Chlorophyll, Swift Swim,
## Sand Rush, Slush Rush (speed is owned by TurnResolver.
## effective_speed, do not duplicate it); Magic Guard (its hook
## blocks_indirect_damage lives in Batch2 and is called by
## StatusAndFieldEngine and the controller); Prankster, Unaware,
## Supreme Overlord
## (no hook anywhere in this file); Good as Gold (it blocks status
## MOVES, not status itself, so blocks_status returns false for it
## and no move is skipped in on_before_move).
##
## Weather and terrain words used here match
## StatusAndFieldEngine.create_field_state: weather "sun", "rain",
## "sand", "snow"; terrain "grassy". Stage keys match moves.json:
## atk, def, spa, spd, spe. Status codes match StatusAndFieldEngine:
## BRN, PAR, PSN, TOX, SLP, FRZ.
## Protean and Libero change type once per switch-in; the flag
## mon["protean_used"] is cleared by whatever code handles switching
## (this file never clears it on its own).

const SUPPORTED_ABILITIES := [
	"Adaptability", "Aerilate", "Aftermath", "Air Lock", "Analytic", "Anger Point",
	"Anger Shell", "Anticipation", "Arena Trap", "Armor Tail", "Aroma Veil", "As One (Glastrier)",
	"As One (Spectrier)", "Aura Break", "Aura Guard", "Bad Dreams", "Ball Fetch", "Battery",
	"Battle Armor", "Battle Bond", "Beads of Ruin", "Beast Boost", "Berserk", "Big Pecks",
	"Blaze", "Bulletproof", "Cheek Pouch", "Chilling Neigh", "Chlorophyll", "Clear Body",
	"Cloud Nine", "Color Change", "Comatose", "Commander", "Competitive", "Compound Eyes",
	"Contrary", "Corrosion", "Costar", "Cotton Down", "Cud Chew", "Curious Medicine",
	"Cursed Body", "Cute Charm", "Damp", "Dancer", "Dark Aura", "Dauntless Shield",
	"Dazzling", "Defeatist", "Defiant", "Delta Stream", "Desolate Land", "Disguise",
	"Download", "Dragon's Maw", "Dragonize", "Drizzle", "Drought", "Dry Skin",
	"Early Bird", "Earth Eater", "Eelevate", "Effect Spore", "Electric Surge", "Electromorphosis",
	"Embody Aspect (Cornerstone)", "Embody Aspect (Hearthflame)", "Embody Aspect (Teal)", "Embody Aspect (Wellspring)", "Emergency Exit", "Fairy Aura",
	"Filter", "Fire Mane", "Flame Body", "Flare Boost", "Flash Fire", "Flower Gift",
	"Flower Veil", "Fluffy", "Forecast", "Forewarn", "Friend Guard", "Frisk",
	"Full Metal Body", "Fur Coat", "Gale Wings", "Galvanize", "Gluttony", "Good as Gold",
	"Gooey", "Gorilla Tactics", "Grass Pelt", "Grassy Surge", "Grim Neigh", "Guard Dog",
	"Gulp Missile", "Guts", "Hadron Engine", "Harvest", "Healer", "Heatproof",
	"Heavy Metal", "Honey Gather", "Hospitality", "Huge Power", "Hunger Switch", "Hustle",
	"Hydration", "Hyper Cutter", "Ice Body", "Ice Face", "Ice Scales", "Illuminate",
	"Illusion", "Immunity", "Imposter", "Infiltrator", "Innards Out", "Inner Focus",
	"Insomnia", "Intimidate", "Intrepid Sword", "Iron Barbs", "Iron Fist", "Justified",
	"Keen Eye", "Klutz", "Leaf Guard", "Levitate", "Libero", "Light Metal",
	"Lightning Rod", "Limber", "Lingering Aroma", "Liquid Ooze", "Liquid Voice", "Long Reach",
	"Magic Bounce", "Magic Guard", "Magician", "Magma Armor", "Magnet Pull", "Marvel Scale",
	"Mega Launcher", "Mega Sol", "Merciless", "Mimicry", "Mind's Eye", "Minus",
	"Mirror Armor", "Misty Surge", "Mold Breaker", "Moody", "Motor Drive", "Mountaineer",
	"Moxie", "Multiscale", "Multitype", "Mummy", "Mycelium Might", "Natural Cure",
	"Neuroforce", "Neutralizing Gas", "No Ability", "No Guard", "Normalize", "Oblivious",
	"Opportunist", "Orichalcum Pulse", "Overcoat", "Overgrow", "Own Tempo", "Parental Bond",
	"Pastel Veil", "Perish Body", "Persistent", "Pickpocket", "Pickup", "Piercing Drill",
	"Pixilate", "Plus", "Poison Heal", "Poison Point", "Poison Puppeteer", "Poison Touch",
	"Power Construct", "Power Spot", "Power of Alchemy", "Prankster", "Pressure", "Primordial Sea",
	"Prism Armor", "Propeller Tail", "Protean", "Protosynthesis", "Psychic Surge", "Punk Rock",
	"Pure Power", "Purifying Salt", "Quark Drive", "Queenly Majesty", "Quick Draw", "Quick Feet",
	"RKS System", "Rain Dish", "Rattled", "Rebound", "Receiver", "Reckless",
	"Refrigerate", "Regenerator", "Ripen", "Rivalry", "Rock Head", "Rocky Payload",
	"Rough Skin", "Run Away", "Sand Force", "Sand Rush", "Sand Spit", "Sand Stream",
	"Sand Veil", "Sap Sipper", "Schooling", "Scrappy", "Screen Cleaner", "Seed Sower",
	"Serene Grace", "Shadow Shield", "Shadow Tag", "Sharpness", "Shed Skin", "Sheer Force",
	"Shell Armor", "Shield Dust", "Shields Down", "Simple", "Skill Link", "Slow Start",
	"Slush Rush", "Sniper", "Snow Cloak", "Snow Warning", "Solar Power", "Solid Rock",
	"Soul-Heart", "Soundproof", "Speed Boost", "Spicy Spray", "Stakeout", "Stall",
	"Stalwart", "Stamina", "Stance Change", "Static", "Steadfast", "Steam Engine",
	"Steelworker", "Steely Spirit", "Stench", "Sticky Hold", "Storm Drain", "Strong Jaw",
	"Sturdy", "Suction Cups", "Super Luck", "Supersweet Syrup", "Supreme Overlord", "Surge Surfer",
	"Swarm", "Sweet Veil", "Swift Swim", "Sword of Ruin", "Symbiosis", "Synchronize",
	"Tablets of Ruin", "Tangled Feet", "Tangling Hair", "Technician", "Telepathy", "Tera Shell",
	"Tera Shift", "Teraform Zero", "Teravolt", "Thermal Exchange", "Thick Fat", "Tinted Lens",
	"Torrent", "Tough Claws", "Toxic Boost", "Toxic Chain", "Toxic Debris", "Trace",
	"Transistor", "Triage", "Truant", "Turboblaze", "Unaware", "Unburden",
	"Unnerve", "Unseen Fist", "Vessel of Ruin", "Victory Star", "Vital Spirit", "Volt Absorb",
	"Wandering Spirit", "Water Absorb", "Water Bubble", "Water Compaction", "Water Veil", "Weak Armor",
	"Well-Baked Body", "White Smoke", "Wimp Out", "Wind Power", "Wind Rider", "Wonder Guard",
	"Wonder Skin", "Zen Mode", "Zero to Hero", "asone"
]

## Metadata for all 322 abilities from abilities.json. "hook" is
## "implemented" when a real code hook exists in this file, "partial"
## when only part of the mechanic is coded, "listed_only" when this
## is metadata only. Generated by a script from abilities.json, not
## typed by hand. "desc" is the shortDesc from that file.
const ABILITY_INFO := {
	"adaptability": {"name": "Adaptability", "desc": "This Pokemon's same-type attack bonus (STAB) is 2 instead of 1.5.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"aerilate": {"name": "Aerilate", "desc": "This Pokemon's Normal-type moves become Flying type and have 1.2× power.", "hook": "implemented", "note": "Normal moves become Flying type and deal 1.2x power."},
	"aftermath": {"name": "Aftermath", "desc": "If this Pokemon is KOed with a contact move, that move's user loses 1/4 its max HP.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"airlock": {"name": "Air Lock", "desc": "While this Pokemon is active, the effects of weather conditions are disabled.", "hook": "implemented", "note": "Sets field weather_suppressed on switch-in; caller must clear it when this mon leaves."},
	"analytic": {"name": "Analytic", "desc": "This Pokemon's attacks have 1.3× power if it is the last to move in a turn.", "hook": "implemented", "note": "1.3x power when field attacker_moved_last is set by TurnResolver."},
	"angerpoint": {"name": "Anger Point", "desc": "If this Pokemon (not its substitute) takes a critical hit, its Attack is raised 12 stages.", "hook": "implemented", "note": "Crit hit (move crit flag) raises Attack by 12 stages, clamped to +6."},
	"angershell": {"name": "Anger Shell", "desc": "At 1/2 or less of this Pokemon's max HP: +1 Atk, Sp. Atk, Spe, and -1 Def, Sp. Def.", "hook": "implemented", "note": "Dropping from above 1/2 to 1/2 or less max HP: +1 Atk/SpA/Spe, -1 Def/SpD."},
	"anticipation": {"name": "Anticipation", "desc": "On switch-in, this Pokemon shudders if any foe has a supereffective or OHKO move.", "hook": "implemented", "note": "Shudders on switch-in if a foe move is super-effective or OHKO, using the full type chart."},
	"arenatrap": {"name": "Arena Trap", "desc": "Prevents opposing Pokemon from choosing to switch out unless they are airborne.", "hook": "implemented", "note": "Traps grounded foes; Flying, Ghost, Levitate, Air Balloon and Shed Shell escape."},
	"armortail": {"name": "Armor Tail", "desc": "This Pokemon and its allies are protected from opposing priority moves.", "hook": "implemented", "note": "Blocks foe priority moves in before_move (singles), and in doubles the whole side is protected through side_priority_block in the damage pass."},
	"aromaveil": {"name": "Aroma Veil", "desc": "Protects user/allies from Attract, Disable, Encore, Heal Block, Taunt, and Torment.", "hook": "implemented", "note": "Blocks Attract, Disable, Encore, Heal Block, Taunt and Torment moves in before_move."},
	"asoneglastrier": {"name": "As One (Glastrier)", "desc": "Combination of the Unnerve and Chilling Neigh Abilities.", "hook": "implemented", "note": "Unnerve log on switch-in; +1 Attack on a move KO (Chilling Neigh half). Berries are blocked by the item engine while the holder is active."},
	"asonespectrier": {"name": "As One (Spectrier)", "desc": "Combination of the Unnerve and Grim Neigh Abilities.", "hook": "implemented", "note": "Unnerve log on switch-in; +1 Sp. Atk on a move KO (Grim Neigh half). Berries are blocked by the item engine while the holder is active."},
	"asone": {"name": "asone", "desc": "See 'As One (Glastrier)' and 'As One (Spectrier)'.", "hook": "implemented", "note": "Variant picked from the ability string or the species (Calyrex-Shadow is Spectrier, anything else is Glastrier). The KO boost only fires on a move KO (by_move). The Unnerve half blocks Berries through the item engine."},
	"aurabreak": {"name": "Aura Break", "desc": "While this Pokemon is active, the Dark Aura and Fairy Aura power modifier is 0.75×.", "hook": "implemented", "note": "Dark/Fairy Aura power becomes 0.75x instead of 4/3x when an aura is active."},
	"auraguard": {"name": "Aura Guard", "desc": "This Pokemon receives 1/2 damage from contact moves.", "hook": "implemented", "note": "Contact moves deal 1/2 damage."},
	"baddreams": {"name": "Bad Dreams", "desc": "Causes sleeping foes to lose 1/8 of their max HP at the end of each turn.", "hook": "implemented", "note": "Sleeping foe loses 1/8 max HP at end of turn via field foe, else sets bad_dreams_active for the caller."},
	"ballfetch": {"name": "Ball Fetch", "desc": "No competitive use.", "hook": "no_effect", "note": "No battle effect in Showdown; no hook exists or is needed."},
	"battery": {"name": "Battery", "desc": "This Pokemon's allies have the power of their special attacks multiplied by 1.3.", "hook": "implemented", "note": "Ally Special moves deal 1.3x power; no effect in singles."},
	"battlearmor": {"name": "Battle Armor", "desc": "This Pokemon cannot be struck by a critical hit.", "hook": "implemented", "note": "The hit can never be a crit: the damage calculator blocks the crit roll when the defender has Battle Armor (unless the move ignores abilities). The damage_mult arm that cancels the 1.5x bonus is kept as a backstop for direct modify_damage calls."},

	"battlebond": {"name": "Battle Bond", "desc": "After KOing a Pokemon: raises Attack, Sp. Atk, Speed by 1 stage. Once per battle.", "hook": "implemented", "note": "Greninja +1 Atk/SpA/Spe on a move KO, once per battle."},
	"beadsofruin": {"name": "Beads of Ruin", "desc": "Active Pokemon without this Ability have their Special Defense multiplied by 0.75.", "hook": "implemented", "note": "Holder's Special moves deal 4/3x damage (foe SpD is 0.75x)."},
	"beastboost": {"name": "Beast Boost", "desc": "This Pokemon's highest stat is raised by 1 if it attacks and KOes another Pokemon.", "hook": "implemented", "note": "+1 to the KOer's highest stat (ties: Atk, Def, SpA, SpD, Spe) on a move KO."},
	"berserk": {"name": "Berserk", "desc": "This Pokemon's Sp. Atk is raised by 1 when it reaches 1/2 or less of its max HP.", "hook": "implemented", "note": "+1 Sp. Atk when dropping from above 1/2 to 1/2 or less max HP."},
	"bigpecks": {"name": "Big Pecks", "desc": "Prevents other Pokemon from lowering this Pokemon's Defense stat stage.", "hook": "implemented", "note": "Blocks foe-inflicted Defense stage drops."},
	"blaze": {"name": "Blaze", "desc": "At 1/3 or less of its max HP, this Pokemon's offensive stat is 1.5× with Fire attacks.", "hook": "implemented", "note": "1.5x power on Fire moves at 1/3 or less max HP."},
	"bulletproof": {"name": "Bulletproof", "desc": "This Pokemon is immune to bullet moves.", "hook": "implemented", "note": "Blocks bullet-flagged moves in before_move (is_immune cannot see move flags)."},
	"cheekpouch": {"name": "Cheek Pouch", "desc": "If this Pokemon eats a Berry, it restores 1/3 of its max HP after the Berry's effect.", "hook": "implemented", "note": "Eating a Berry restores 1/3 max HP after the Berry effect."},
	"chillingneigh": {"name": "Chilling Neigh", "desc": "This Pokemon's Attack is raised by 1 stage if it attacks and KOes another Pokemon.", "hook": "implemented", "note": "+1 Attack on a move KO."},
	"chlorophyll": {"name": "Chlorophyll", "desc": "If Sun is active, this Pokemon's Speed is doubled.", "hook": "turnresolver", "note": "Speed doubling in sun is owned by TurnResolver.effective_speed per brief; no hook here."},
	"clearbody": {"name": "Clear Body", "desc": "Prevents other Pokemon from lowering this Pokemon's stat stages.", "hook": "implemented", "note": "Blocks all foe-inflicted stat stage drops."},
	"cloudnine": {"name": "Cloud Nine", "desc": "While this Pokemon is active, the effects of weather conditions are disabled.", "hook": "implemented", "note": "Sets field weather_suppressed on switch-in; caller must clear it when this mon leaves."},
	"colorchange": {"name": "Color Change", "desc": "This Pokemon's type changes to the type of a move it's hit by, unless it has the type.", "hook": "implemented", "note": "Type changes to the type of a damaging move that hits it."},
	"comatose": {"name": "Comatose", "desc": "This Pokemon cannot be statused, and is considered to be asleep.", "hook": "implemented", "note": "Blocks every non-volatile status; treated as asleep (Bad Dreams checks for it)."},
	"commander": {"name": "Commander", "desc": "If ally is Dondozo: this Pokemon cannot act or be hit, +2 to all Dondozo's stats.", "hook": "implemented", "note": "Tatsugiri + ally Dondozo: Tatsugiri enters the mouth (commanding), Dondozo gains +2 to all five stats (commanded), Tatsugiri cannot act or be hit until Dondozo faints. While the pair is together, neither can be switched out: voluntary switches are refused in the doubles action step, and forced switches (Roar, Whirlwind, Dragon Tail, Circle Throw, Red Card) are refused in _handle_forced_switch."},
	"competitive": {"name": "Competitive", "desc": "This Pokemon's Sp. Atk is raised by 2 for each of its stats that is lowered by a foe.", "hook": "implemented", "note": "+2 Sp. Atk when a stat is lowered by a foe (caller calls on_stat_boosted for foe drops only)."},
	"compoundeyes": {"name": "Compound Eyes", "desc": "This Pokemon's moves have their accuracy multiplied by 1.3.", "hook": "implemented", "note": "Moves have 1.3x accuracy."},
	"contrary": {"name": "Contrary", "desc": "If this Pokemon has a stat stage raised it is lowered instead, and vice versa.", "hook": "implemented", "note": "Stat changes are inverted in on_stat_boosted (applied after the change, -2x amount)."},
	"corrosion": {"name": "Corrosion", "desc": "This Pokemon can poison or badly poison a Pokemon regardless of its typing.", "hook": "implemented", "note": "try_set_status skips the PSN/TOX vs Steel/Poison immunity when the source has Corrosion; Steel and Poison types can no longer be poisoned at all otherwise."},
	"costar": {"name": "Costar", "desc": "On switch-in, this Pokemon copies all of its ally's stat stage changes.", "hook": "implemented", "note": "Copies the ally's stat stages (atk/def/spa/spd/spe) on switch-in from mon[\"ally\"], set by the controller in doubles. The crit volatiles Showdown also copies (Focus Energy and the like) are not copied: this engine has no such volatiles."},
	"cottondown": {"name": "Cotton Down", "desc": "If this Pokemon is hit, it lowers the Speed of all other Pokemon on the field 1 stage.", "hook": "implemented", "note": "Lowers the Speed of other active Pokemon by 1 when hit; singles version lowers the attacker."},
	"cudchew": {"name": "Cud Chew", "desc": "If this Pokemon eats a Berry, it will eat that Berry again at the end of the next turn.", "hook": "implemented", "note": "Eaten Berry is eaten again at the end of the next turn, re-applying its healing."},
	"curiousmedicine": {"name": "Curious Medicine", "desc": "On switch-in, this Pokemon's allies have their stat stages reset to 0.", "hook": "implemented", "note": "Resets the ally's stat stages to 0 on switch-in from mon[\"ally\"], set by the controller in doubles."},
	"cursedbody": {"name": "Cursed Body", "desc": "If this Pokemon is hit by an attack, there is a 30% chance that move gets disabled.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"cutecharm": {"name": "Cute Charm", "desc": "30% chance of infatuating Pokemon of the opposite gender if they make contact.", "hook": "implemented", "note": "30% chance to infatuate an opposite-gender attacker on contact."},
	"damp": {"name": "Damp", "desc": "Prevents Explosion/Mind Blown/Misty Explosion/Self-Destruct/Aftermath while active.", "hook": "implemented", "note": "Blocks Explosion, Mind Blown, Misty Explosion and Self-Destruct in before_move."},
	"dancer": {"name": "Dancer", "desc": "After another Pokemon uses a dance move, this Pokemon uses the same move.", "hook": "implemented", "note": "Copies a dance move once after it does something, slowest Dancer first, no PP cost, no chains (controller _dancer_copy, Showdown runMove). No copy when the original move affects nothing; a confused dancer hurting itself and a semi-invulnerable dancer are not modeled."},
	"darkaura": {"name": "Dark Aura", "desc": "While this Pokemon is active, a Dark move used by any Pokemon has 1.33× power.", "hook": "implemented", "note": "Dark moves from any active mon deal 4/3x power (0.75x with Aura Break)."},
	"dauntlessshield": {"name": "Dauntless Shield", "desc": "On switch-in, this Pokemon's Defense is raised by 1 stage. Once per battle.", "hook": "implemented", "note": "+1 Defense on switch-in, once per battle."},
	"dazzling": {"name": "Dazzling", "desc": "This Pokemon and its allies are protected from opposing priority moves.", "hook": "implemented", "note": "Blocks foe priority moves in before_move (singles), and in doubles the whole side is protected through side_priority_block in the damage pass."},
	"defeatist": {"name": "Defeatist", "desc": "While this Pokemon has 1/2 or less of its max HP, its Attack and Sp. Atk are halved.", "hook": "implemented", "note": "Power halved at 1/2 or less max HP."},
	"defiant": {"name": "Defiant", "desc": "This Pokemon's Attack is raised by 2 for each of its stats that is lowered by a foe.", "hook": "implemented", "note": "+2 Attack when a stat is lowered by a foe (caller calls on_stat_boosted for foe drops only)."},
	"deltastream": {"name": "Delta Stream", "desc": "On switch-in, strong winds begin until this Ability is not active in battle.", "hook": "implemented", "note": "Sets strongwinds weather (indefinite until the setter leaves)."},
	"desolateland": {"name": "Desolate Land", "desc": "On switch-in, extremely harsh sunlight begins until this Ability is not active in battle.", "hook": "implemented", "note": "Sets intensesun weather and blocks damaging Water moves in before_move."},
	"disguise": {"name": "Disguise", "desc": "(Mimikyu only) The first hit it takes is blocked, and it takes 1/8 HP damage instead.", "hook": "implemented", "note": "First hit on Mimikyu deals 0 damage, costs 1/8 max HP, changes forme to Mimikyu-Busted."},
	"download": {"name": "Download", "desc": "On switch-in, Attack or Sp. Atk is raised 1 stage based on the foes' weaker Defense.", "hook": "implemented", "note": "+1 Sp. Atk if foe Def >= foe SpD, else +1 Attack, on switch-in."},
	"dragonsmaw": {"name": "Dragon's Maw", "desc": "This Pokemon's offensive stat is multiplied by 1.5 while using a Dragon-type attack.", "hook": "implemented", "note": "1.5x power on Dragon moves."},
	"dragonize": {"name": "Dragonize", "desc": "This Pokemon's Normal-type moves become Dragon type and have 1.2× power.", "hook": "implemented", "note": "Normal moves become Dragon type and deal 1.2x power."},
	"drizzle": {"name": "Drizzle", "desc": "On switch-in, this Pokemon summons Rain.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"drought": {"name": "Drought", "desc": "On switch-in, this Pokemon summons Sun.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"dryskin": {"name": "Dry Skin", "desc": "This Pokemon is healed 1/4 by Water, 1/8 by Rain; is hurt 1.25× by Fire, 1/8 by Sun.", "hook": "implemented", "note": "COMPLETED: Water immunity + 1/4 heal on Water hit, 1.25x Fire damage, 1/8 rain heal / sun hurt (end_of_turn in Batch1). The old double heal/loss from the v2 arm is removed."},
	"earlybird": {"name": "Early Bird", "desc": "This Pokemon's sleep counter drops by 2 instead of 1.", "hook": "implemented", "note": "sleep_tick (Batch1) returns 2 for Early Bird; the sleep branch in StatusAndFieldEngine decrements first, then checks, and try_set_status sets sleep_turns 2-4."},
	"eartheater": {"name": "Earth Eater", "desc": "This Pokemon heals 1/4 of its max HP when hit by Ground moves; Ground immunity.", "hook": "implemented", "note": "Ground immunity + 1/4 max HP heal on a Ground hit."},
	"eelevate": {"name": "Eelevate", "desc": "This Pokemon is immune to Ground; +1 to highest stat if it KOes another Pokemon.", "hook": "implemented", "note": "Ground immunity +1 to highest stat on a move KO (Beast Boost half)."},
	"effectspore": {"name": "Effect Spore", "desc": "30% chance of poison/paralysis/sleep on others making contact with this Pokemon.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"electricsurge": {"name": "Electric Surge", "desc": "On switch-in, this Pokemon summons Electric Terrain.", "hook": "implemented", "note": "Sets Electric Terrain on switch-in; terrain_on_switch_in returns electric."},
	"electromorphosis": {"name": "Electromorphosis", "desc": "This Pokemon gains the Charge effect when it takes a hit from an attack.", "hook": "implemented", "note": "Gains Charge (mon charged flag) when hit by an attack."},
	"embodyaspectcornerstone": {"name": "Embody Aspect (Cornerstone)", "desc": "On switch-in, this Pokemon's Defense is raised by 1 stage.", "hook": "implemented", "note": "+1 Defense on switch-in for Terastallized Ogerpon-Cornerstone-Tera, once."},
	"embodyaspecthearthflame": {"name": "Embody Aspect (Hearthflame)", "desc": "On switch-in, this Pokemon's Attack is raised by 1 stage.", "hook": "implemented", "note": "+1 Attack on switch-in for Terastallized Ogerpon-Hearthflame-Tera, once."},
	"embodyaspectteal": {"name": "Embody Aspect (Teal)", "desc": "On switch-in, this Pokemon's Speed is raised by 1 stage.", "hook": "implemented", "note": "+1 Speed on switch-in for Terastallized Ogerpon-Teal-Tera, once."},
	"embodyaspectwellspring": {"name": "Embody Aspect (Wellspring)", "desc": "On switch-in, this Pokemon's Special Defense is raised by 1 stage.", "hook": "implemented", "note": "+1 Sp. Def on switch-in for Terastallized Ogerpon-Wellspring-Tera, once."},
	"emergencyexit": {"name": "Emergency Exit", "desc": "This Pokemon switches out when it reaches 1/2 or less of its maximum HP.", "hook": "implemented", "note": "Sets force_switch when dropping from above 1/2 to 1/2 or less max HP; the caller switches it out on the shared path with Wimp Out."},
	"fairyaura": {"name": "Fairy Aura", "desc": "While this Pokemon is active, a Fairy move used by any Pokemon has 1.33× power.", "hook": "implemented", "note": "Fairy moves from any active mon deal 4/3x power (0.75x with Aura Break)."},
	"filter": {"name": "Filter", "desc": "This Pokemon receives 3/4 damage from supereffective attacks.", "hook": "implemented", "note": "Super-effective hits deal 3/4 damage."},
	"firemane": {"name": "Fire Mane", "desc": "This Pokemon's offensive stat is multiplied by 1.5 while using a Fire-type attack.", "hook": "implemented", "note": "1.5x power on Fire moves."},
	"flamebody": {"name": "Flame Body", "desc": "30% chance a Pokemon making contact with this Pokemon will be burned.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"flareboost": {"name": "Flare Boost", "desc": "While this Pokemon is burned, its special attacks have 1.5× power.", "hook": "implemented", "note": "1.5x power on Special moves while burned."},
	"flashfire": {"name": "Flash Fire", "desc": "This Pokemon's Fire attacks do 1.5× damage if hit by one Fire move; Fire immunity.", "hook": "implemented", "note": "COMPLETED: Fire immunity + charge on Fire hit, then 1.5x power on Fire moves; charge clears on switch-out."},
	"flowergift": {"name": "Flower Gift", "desc": "If user is Cherrim and Sun is active, it and allies' Attack and Sp. Def are 1.5×.", "hook": "implemented", "note": "Cherrim Sunshine forme in sun (form_change); Atk 1.5x physical and SpD 1.5x special folded into damage_mult, ally half via ally_ability."},
	"flowerveil": {"name": "Flower Veil", "desc": "This side's Grass types can't have stats lowered or status inflicted by other Pokemon.", "hook": "implemented", "note": "Blocks stat drops on Grass-type holder (blocks_stat_change) and status on Grass-type holder (blocks_status); ally half needs side info."},
	"fluffy": {"name": "Fluffy", "desc": "This Pokemon takes 1/2 damage from contact moves, 2× damage from Fire moves.", "hook": "implemented", "note": "Contact damage halved, Fire damage doubled in damage_mult."},
	"forecast": {"name": "Forecast", "desc": "Castform's type changes to the current weather condition's type, except Sandstorm.", "hook": "implemented", "note": "Castform forme follows weather in form_change (Sun/Rain/Snow/base), Utility Umbrella blocks Sun/Rain change."},
	"forewarn": {"name": "Forewarn", "desc": "On switch-in, this Pokemon is alerted to the foes' move with the highest power.", "hook": "implemented", "note": "Switch-in log names the foe's highest-power move when power data is present, else a generic alert."},
	"friendguard": {"name": "Friend Guard", "desc": "This Pokemon's allies receive 3/4 damage from other Pokemon's attacks.", "hook": "implemented", "note": "Allies take 3/4 damage in ally_damage_mult."},
	"frisk": {"name": "Frisk", "desc": "On switch-in, this Pokemon identifies the held items of all opposing Pokemon.", "hook": "implemented", "note": "Switch-in log names the foe's held item."},
	"fullmetalbody": {"name": "Full Metal Body", "desc": "Prevents other Pokemon from lowering this Pokemon's stat stages.", "hook": "implemented", "note": "Blocks all stat drops in blocks_stat_change."},
	"furcoat": {"name": "Fur Coat", "desc": "This Pokemon's Defense is doubled.", "hook": "implemented", "note": "Physical damage halved in damage_mult (Def doubled)."},
	"galewings": {"name": "Gale Wings", "desc": "If this Pokemon is at full HP, its Flying-type moves have their priority increased by 1.", "hook": "implemented", "note": "Flying moves +1 priority at full HP in priority_bonus."},
	"galvanize": {"name": "Galvanize", "desc": "This Pokemon's Normal-type moves become Electric type and have 1.2× power.", "hook": "implemented", "note": "Normal moves become Electric in move_type and get 1.2x power in power_mult."},
	"gluttony": {"name": "Gluttony", "desc": "This Pokemon eats Berries at 1/2 max HP or less instead of their usual 1/4 max HP.", "hook": "implemented", "note": "Sets mon[gluttony] on switch-in so the item engine uses the 1/2 HP Berry threshold."},
	"goodasgold": {"name": "Good as Gold", "desc": "This Pokemon is immune to Status moves.", "hook": "implemented", "note": "Status moves aimed at the holder are skipped in before_move."},
	"gooey": {"name": "Gooey", "desc": "Pokemon making contact with this Pokemon have their Speed lowered by 1 stage.", "hook": "implemented", "note": "Contact attacker loses 1 Speed stage in on_damage_taken."},
	"gorillatactics": {"name": "Gorilla Tactics", "desc": "This Pokemon's Attack is 1.5×, but it can only select the first move it executes.", "hook": "implemented", "note": "Physical damage 1.5x in damage_mult; first-move lock enforced in before_move (other moves skipped)."},
	"grasspelt": {"name": "Grass Pelt", "desc": "If Grassy Terrain is active, this Pokemon's Defense is multiplied by 1.5.", "hook": "implemented", "note": "Physical damage divided by 1.5 in Grassy Terrain in damage_mult (Def 1.5x)."},
	"grassysurge": {"name": "Grassy Surge", "desc": "On switch-in, this Pokemon summons Grassy Terrain.", "hook": "implemented", "note": "Sets Grassy Terrain on switch-in (on_switch_in and terrain_on_switch_in)."},
	"grimneigh": {"name": "Grim Neigh", "desc": "This Pokemon's Sp. Atk is raised by 1 stage if it attacks and KOes another Pokemon.", "hook": "implemented", "note": "Sp. Atk +1 in on_faint when the foe KOs a Pokemon with its move."},
	"guarddog": {"name": "Guard Dog", "desc": "Immune to Intimidate. Intimidated: +1 Attack. Cannot be forced to switch out.", "hook": "implemented", "note": "Blocks Attack drops in blocks_stat_change; drag-out immunity now works via blocks_drag_out (Batch2). The +1 Attack on Intimidate is still missing - it needs Intimidate-side handling."},
	"gulpmissile": {"name": "Gulp Missile", "desc": "When hit after Surf/Dive, attacker takes 1/4 max HP and -1 Defense or paralysis.", "hook": "implemented", "note": "Surf changes Cramorant to Gulping/Gorging forme in before_move; when hit in those formes the attacker takes 1/4 max HP plus -1 Def or paralysis in on_damage_taken."},
	"guts": {"name": "Guts", "desc": "If this Pokemon is statused, its Attack is 1.5×; ignores burn halving physical damage.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"hadronengine": {"name": "Hadron Engine", "desc": "On switch-in, summons Electric Terrain. During Electric Terrain, Sp. Atk is 1.3333×.", "hook": "implemented", "note": "Sets Electric Terrain on switch-in; special damage 1.3333x in Electric Terrain in damage_mult."},
	"harvest": {"name": "Harvest", "desc": "If last item used is a Berry, 50% chance to restore it each end of turn. 100% in Sun.", "hook": "implemented", "note": "Restores the last Berry used at end of turn, always in Sun else 50% chance, in end_of_turn."},
	"healer": {"name": "Healer", "desc": "30% chance this Pokemon's ally has its status cured at the end of each turn.", "hook": "implemented", "note": "30% chance to cure the active ally's status at end of turn (mon[ally])."},
	"heatproof": {"name": "Heatproof", "desc": "Fire damage against this Pokemon is dealt with 1/2 offensive stat; 1/2 burn damage.", "hook": "implemented", "note": "Fire damage halved in damage_mult (halved offensive stat); burn-damage half has no hook."},
	"heavymetal": {"name": "Heavy Metal", "desc": "This Pokemon's weight is doubled.", "hook": "implemented", "note": "Weight doubled in weight_mult."},
	"honeygather": {"name": "Honey Gather", "desc": "No competitive use.", "hook": "implemented", "note": "No competitive use; Showdown defines no hooks for it."},
	"hospitality": {"name": "Hospitality", "desc": "On switch-in, this Pokemon restores 1/4 of its ally's maximum HP, rounded down.", "hook": "implemented", "note": "Heals the active ally 1/4 max HP on switch-in (mon[ally])."},
	"hugepower": {"name": "Huge Power", "desc": "This Pokemon's Attack is doubled.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"hungerswitch": {"name": "Hunger Switch", "desc": "If Morpeko, it changes between Full Belly and Hangry Mode at the end of each turn.", "hook": "implemented", "note": "Morpeko flips between Full Belly and Hangry forme at end of turn in end_of_turn."},
	"hustle": {"name": "Hustle", "desc": "This Pokemon's Attack is 1.5× and accuracy of its physical attacks is 0.8×.", "hook": "implemented", "note": "Physical damage 1.5x in damage_mult; physical accuracy 0.8x in accuracy_mult."},
	"hydration": {"name": "Hydration", "desc": "This Pokemon has its status cured at the end of each turn if Rain is active.", "hook": "implemented", "note": "Cures status at end of turn in Rain in end_of_turn (not with Utility Umbrella)."},
	"hypercutter": {"name": "Hyper Cutter", "desc": "Prevents other Pokemon from lowering this Pokemon's Attack stat stage.", "hook": "implemented", "note": "Blocks Attack drops in blocks_stat_change."},
	"icebody": {"name": "Ice Body", "desc": "If Snow is active, this Pokemon heals 1/16 of its max HP each turn.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"iceface": {"name": "Ice Face", "desc": "If Eiscue, the first physical hit it takes deals 0 damage. Effect is restored in Snow.", "hook": "implemented", "note": "First physical hit deals 0 damage in damage_mult and sets ice_face_broken plus Noice forme; Snow restores Ice Face in form_change."},
	"icescales": {"name": "Ice Scales", "desc": "This Pokemon receives 1/2 damage from special attacks.", "hook": "implemented", "note": "Special damage halved in damage_mult."},
	"illuminate": {"name": "Illuminate", "desc": "This Pokemon's accuracy can't be lowered by others; ignores their evasiveness stat.", "hook": "implemented", "note": "Blocks accuracy drops in blocks_stat_change; evasion-ignore cannot be expressed without stage data."},
	"illusion": {"name": "Illusion", "desc": "This Pokemon appears as the last Pokemon in the party until it takes direct damage.", "hook": "implemented", "note": "Sets illusion_active on switch-in and clears it when the holder takes direct damage in on_damage_taken; disguise target needs party data."},
	"immunity": {"name": "Immunity", "desc": "This Pokemon cannot be poisoned. Gaining this Ability while poisoned cures it.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"imposter": {"name": "Imposter", "desc": "On switch-in, this Pokemon Transforms into the opposing Pokemon that is facing it.", "hook": "implemented", "note": "Copies the foe's types and ability on switch-in and sets transformed."},
	"infiltrator": {"name": "Infiltrator", "desc": "Moves ignore substitutes and foe's Reflect/Light Screen/Safeguard/Mist/Aurora Veil.", "hook": "implemented", "note": "Marks moves as infiltrating in before_move so they ignore substitutes and screens."},
	"innardsout": {"name": "Innards Out", "desc": "If this Pokemon is KOed with a move, that move's user loses an equal amount of HP.", "hook": "implemented", "note": "Attacker loses HP equal to the KO damage in on_damage_taken when the holder faints."},
	"innerfocus": {"name": "Inner Focus", "desc": "This Pokemon cannot be made to flinch. Immune to Intimidate.", "hook": "implemented", "note": "Flinch blocked via blocks_flinch (MoveEffects checks it); Intimidate Attack drop blocked via blocks_stat_change (dispatcher now passes the source)."},
	"insomnia": {"name": "Insomnia", "desc": "This Pokemon cannot fall asleep. Gaining this Ability while asleep cures it.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"intimidate": {"name": "Intimidate", "desc": "On switch-in, this Pokemon lowers the Attack of opponents by 1 stage.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"intrepidsword": {"name": "Intrepid Sword", "desc": "On switch-in, this Pokemon's Attack is raised by 1 stage. Once per battle.", "hook": "implemented", "note": "Attack +1 once per battle on switch-in."},
	"ironbarbs": {"name": "Iron Barbs", "desc": "Pokemon making contact with this Pokemon lose 1/8 of their max HP.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"ironfist": {"name": "Iron Fist", "desc": "This Pokemon's punch-based attacks have 1.2× power. Sucker Punch is not boosted.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"justified": {"name": "Justified", "desc": "This Pokemon's Attack is raised by 1 stage after it is damaged by a Dark-type move.", "hook": "implemented", "note": "Attack +1 when hit by a Dark move in on_damage_taken."},
	"keeneye": {"name": "Keen Eye", "desc": "This Pokemon's accuracy can't be lowered by others; ignores their evasiveness stat.", "hook": "implemented", "note": "Blocks accuracy drops in blocks_stat_change; evasion-ignore cannot be expressed without stage data."},
	"klutz": {"name": "Klutz", "desc": "This Pokemon's held item has no effect, except Macho Brace. Fling cannot be used.", "hook": "implemented", "note": "Sets ignore_item on switch-in so the held item has no effect."},
	"leafguard": {"name": "Leaf Guard", "desc": "If Sun is active, this Pokemon cannot be statused and Rest will fail for it.", "hook": "implemented", "note": "Blocks every status in Sun via blocks_status (field now passed); Yawn blocking and Rest failing in Sun are not built - no Yawn volatile and no working Rest move exist in this engine."},
	"levitate": {"name": "Levitate", "desc": "This Pokemon is immune to Ground; Gravity/Ingrain/Smack Down/Iron Ball nullify it.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"libero": {"name": "Libero", "desc": "This Pokemon's type changes to the type of the move it is using. Once per switch-in.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"lightmetal": {"name": "Light Metal", "desc": "This Pokemon's weight is halved.", "hook": "implemented", "note": "Weight halved in weight_mult."},
	"lightningrod": {"name": "Lightning Rod", "desc": "This Pokemon draws Electric moves to itself to raise Sp. Atk by 1; Electric immunity.", "hook": "implemented", "note": "Electric immunity plus Sp. Atk +1 on the hit, both in is_immune; single-target Electric moves aimed at its foe-side partner are redirected to it in doubles (DoublesTargeting._apply_redirect). Propeller Tail and Stalwart moves ignore the redirect, and Mold Breaker, Teravolt and Turboblaze ignore it too. Follow Me and Rage Powder are not built: those moves are not in the runtime move list."},

	"limber": {"name": "Limber", "desc": "This Pokemon cannot be paralyzed. Gaining this Ability while paralyzed cures it.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"lingeringaroma": {"name": "Lingering Aroma", "desc": "Making contact with this Pokemon has the attacker's Ability become Lingering Aroma.", "hook": "implemented", "note": "Contact attacker gains Lingering Aroma in on_damage_taken, except protected abilities."},
	"liquidooze": {"name": "Liquid Ooze", "desc": "This Pokemon damages those draining HP from it for as much as they would heal.", "hook": "implemented", "note": "Drain heals are turned into damage in MoveEffects.apply_after_hit (can KO). Leech Seed and Strength Sap are covered too, in the controller: a seeded Liquid Ooze mon hurts the seeder at the end of the turn, and Strength Sap against a Liquid Ooze target hurts the user instead of healing."},
	"liquidvoice": {"name": "Liquid Voice", "desc": "This Pokemon's sound-based moves become Water type.", "hook": "implemented", "note": "Sound moves become Water type in move_type."},
	"longreach": {"name": "Long Reach", "desc": "This Pokemon's attacks do not make contact with the target.", "hook": "implemented", "note": "Removes contact from moves in before_move."},
	"magicbounce": {"name": "Magic Bounce", "desc": "This Pokemon blocks certain Status moves and bounces them back to the user.", "hook": "implemented", "note": "Reflectable Status moves aimed at the holder are skipped and marked bounced in before_move; controller must re-target them."},
	"magicguard": {"name": "Magic Guard", "desc": "This Pokemon can only be damaged by direct attacks.", "hook": "implemented", "note": "blocks_indirect_damage (Batch2) guards end-of-turn damage, entry hazards, Rough Skin/Iron Barbs, Aftermath and Life Orb; move recoil and confusion self-hit are Move effects and are NOT blocked."},
	"magician": {"name": "Magician", "desc": "If this Pokemon has no item, it steals the item off a Pokemon it hits with an attack.", "hook": "implemented", "note": "Steals the defender's item when the holder has none and hits with a damaging move in on_damage_taken."},
	"magmaarmor": {"name": "Magma Armor", "desc": "This Pokemon cannot be frozen. Gaining this Ability while frozen cures it.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"magnetpull": {"name": "Magnet Pull", "desc": "Prevents opposing Steel-type Pokemon from choosing to switch out.", "hook": "implemented", "note": "Traps Steel-type foes that are not Ghost type and not holding Shed Shell in traps_foe."},
	"marvelscale": {"name": "Marvel Scale", "desc": "If this Pokemon has a non-volatile status condition, its Defense is multiplied by 1.5.", "hook": "implemented", "note": "Physical damage divided by 1.5 while statused in damage_mult (Def 1.5x)."},
	"megalauncher": {"name": "Mega Launcher", "desc": "This Pokemon's pulse moves have 1.5× power. Heal Pulse heals 3/4 target's max HP.", "hook": "implemented", "note": "Pulse moves get 1.5x power in power_mult."},
	"megasol": {"name": "Mega Sol", "desc": "This Pokemon's moves are used as if the effects of Sun were active.", "hook": "implemented", "note": "Uses the Sun damage table in damage_mult: Fire 1.5x, Water 0.5x."},
	"merciless": {"name": "Merciless", "desc": "This Pokemon's attacks are critical hits if the target is poisoned.", "hook": "implemented", "note": "crit_stage returns 5 against a PSN/TOX target (dispatcher now passes the defender); the calculator clamps to 4, which is a guaranteed crit."},
	"mimicry": {"name": "Mimicry", "desc": "This Pokemon's types change to match the Terrain. Type reverts when Terrain ends.", "hook": "implemented", "note": "Type follows the active Terrain on switch-in; no-terrain revert needs base species types."},
	"mindseye": {"name": "Mind's Eye", "desc": "Fighting, Normal moves hit Ghost. Accuracy can't be lowered, ignores evasiveness.", "hook": "implemented", "note": "Blocks accuracy drops in blocks_stat_change; Normal/Fighting hit Ghost via the default non-immune return in is_immune."},
	"minus": {"name": "Minus", "desc": "If an active ally has this Ability or the Plus Ability, this Pokemon's Sp. Atk is 1.5×.", "hook": "implemented", "note": "Special damage 1.5x when the ally has Minus or Plus (mon[ally_ability]) in damage_mult."},
	"mirrorarmor": {"name": "Mirror Armor", "desc": "If this Pokemon's stat stages would be lowered, the attacker's are lowered instead.", "hook": "implemented", "note": "try_mirror_armor (dispatcher + Batch2) bounces foe-caused drops onto the source (per stat, -6 floor; the dispatcher checks the source's own blocks_stat_change, so a Clear Body source fizzles the drop); wired into _apply_stages, MoveEffects._apply_boosts and the Intimidate arm."},
	"mistysurge": {"name": "Misty Surge", "desc": "On switch-in, this Pokemon summons Misty Terrain.", "hook": "implemented", "note": "Sets Misty Terrain on switch-in (on_switch_in and terrain_on_switch_in)."},
	"moldbreaker": {"name": "Mold Breaker", "desc": "This Pokemon's moves and their effects ignore the Abilities of other Pokemon.", "hook": "implemented", "note": "Negates defender ability immunities in is_immune, skips defender ability cuts in damage_mult, sets ignore_ability in before_move, announces on switch-in."},
	"moody": {"name": "Moody", "desc": "Boosts a random stat (except accuracy/evasion) +2 and another stat -1 every turn.", "hook": "implemented", "note": "Random stat +2 and a different random stat -1 at end of turn in end_of_turn."},
	"motordrive": {"name": "Motor Drive", "desc": "This Pokemon's Speed is raised 1 stage if hit by an Electric move; Electric immunity.", "hook": "implemented", "note": "Electric immunity plus Speed +1 on the hit, both in is_immune."},
	"mountaineer": {"name": "Mountaineer", "desc": "On switch-in, this Pokemon avoids all Rock-type attacks and Stealth Rock.", "hook": "implemented", "note": "Rock immunity only on the switch-in turn, gated on defender[just_switched_in]; Stealth Rock block has no hook."},
	"moxie": {"name": "Moxie", "desc": "This Pokemon's Attack is raised by 1 stage if it attacks and KOes another Pokemon.", "hook": "implemented", "note": "Attack +1 in on_faint when the foe KOs a Pokemon with its move."},
	"multiscale": {"name": "Multiscale", "desc": "If this Pokemon is at full HP, damage taken from attacks is halved.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"multitype": {"name": "Multitype", "desc": "If this Pokemon is an Arceus, its type changes to match its held Plate.", "hook": "implemented", "note": "Arceus type follows its held Plate on switch-in."},
	"mummy": {"name": "Mummy", "desc": "Pokemon making contact with this Pokemon have their Ability changed to Mummy.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"myceliummight": {"name": "Mycelium Might", "desc": "This Pokemon's Status moves go last in their priority bracket and ignore Abilities.", "hook": "implemented", "note": "Status moves ignore abilities via before_move; the -0.1 fractional priority cannot be an int priority_bonus."},
	"naturalcure": {"name": "Natural Cure", "desc": "This Pokemon has its non-volatile status condition cured when it switches out.", "hook": "implemented", "note": "Switch-out clears the status (on_switch_out)."},
	"neuroforce": {"name": "Neuroforce", "desc": "This Pokemon's attacks that are super effective against the target do 1.25× damage.", "hook": "implemented", "note": "Supereffective hits deal 1.25x damage (damage_mult)."},
	"neutralizinggas": {"name": "Neutralizing Gas", "desc": "While this Pokemon is active, Abilities have no effect.", "hook": "implemented", "note": "Switch-in sets field abilities_suppressed and the engine guard stops other abilities while it is on. The caller clears the flag on switch-out and faint."},
	"noability": {"name": "No Ability", "desc": "Does nothing.", "hook": "implemented", "note": "Does nothing; no hook needed."},
	"noguard": {"name": "No Guard", "desc": "Every move used by or against this Pokemon will always hit.", "hook": "implemented", "note": "Moves by or against the holder always hit (accuracy_mult 100x)."},
	"normalize": {"name": "Normalize", "desc": "This Pokemon's moves are changed to be Normal type and have 1.2× power.", "hook": "implemented", "note": "Moves become Normal type with 1.2x power (move_type + power_mult)."},
	"oblivious": {"name": "Oblivious", "desc": "This Pokemon cannot be infatuated or taunted. Immune to Intimidate.", "hook": "implemented", "note": "Blocks Attract, Captivate and Taunt and clears their volatiles; an Attack drop from Intimidate is blocked too (the Intimidate arm marks its own call, Batch3 reads the mark)."},

	"opportunist": {"name": "Opportunist", "desc": "When an opposing Pokemon has a stat stage raised, this Pokemon copies the effect.", "hook": "implemented", "note": "Copies a foe's positive stage gain (on_stat_boosted). Verified: the caller sets field boost_target_name and passes the holder, so it works end to end."},
	"orichalcumpulse": {"name": "Orichalcum Pulse", "desc": "On switch-in, summons Sun. During Sun, Attack is 1.3333×.", "hook": "implemented", "note": "Switch-in summons sun; physical moves deal 4/3x damage in sun (on_switch_in + power_mult)."},
	"overcoat": {"name": "Overcoat", "desc": "This Pokemon is immune to powder moves, Sandstorm damage, and Effect Spore.", "hook": "implemented", "note": "Blocks powder moves (before_move) and takes no sandstorm damage (weather check in the status engine). Hail needs no check: snow deals no damage in Gen 9. Effect Spore blocking is still open, see the Group A spec known gaps."},

	"overgrow": {"name": "Overgrow", "desc": "At 1/3 or less of its max HP, this Pokemon's offensive stat is 1.5× with Grass attacks.", "hook": "implemented", "note": "Grass moves deal 1.5x power at 1/3 HP or less (power_mult)."},
	"owntempo": {"name": "Own Tempo", "desc": "This Pokemon cannot be confused. Immune to Intimidate.", "hook": "implemented", "note": "Blocks confusion moves and clears confusion; an Attack drop from Intimidate is blocked too (the Intimidate arm marks its own call, Batch3 reads the mark)."},

	"parentalbond": {"name": "Parental Bond", "desc": "This Pokemon's damaging moves hit twice. The second hit has its damage quartered.", "hook": "implemented", "note": "Damaging moves hit twice (before_move sets multihit 2), and the second hit deals 1/4 damage in the controller hit loop (singles and doubles). Secondaries run once per move use."},

	"pastelveil": {"name": "Pastel Veil", "desc": "This Pokemon and its allies cannot be poisoned. On switch-in, cures poisoned allies.", "hook": "implemented", "note": "Blocks poison status and cures the holder's poison on switch-in and end of turn (blocks_status + on_switch_in + end_of_turn)."},
	"perishbody": {"name": "Perish Body", "desc": "Making contact with this Pokemon starts the Perish Song effect for it and the attacker.", "hook": "implemented", "note": "Contact hits start Perish Song on both mons (on_damage_taken)."},
	"persistent": {"name": "Persistent", "desc": "When used, Gravity/Heal Block/Safeguard/Tailwind/Room effects last 2 more turns.", "hook": "implemented", "note": "field_duration (Batch3) adds +2 turns to Tailwind, Trick Room, Gravity, Safeguard, Wonder Room, Magic Room and Heal Block; only the durations are built - the underlying effects of Gravity, Safeguard, the Rooms and Heal Block do not exist yet."},
	"pickpocket": {"name": "Pickpocket", "desc": "If this Pokemon has no item and is hit by a contact move, it steals the attacker's item.", "hook": "implemented", "note": "Steals the attacker's item on a contact hit when the holder has none (on_damage_taken)."},
	"pickup": {"name": "Pickup", "desc": "If this Pokemon has no item, it finds one used by an adjacent Pokemon this turn.", "hook": "implemented", "note": "Takes the first item used this turn when the holder has none (end_of_turn + on_item_use recording)."},
	"piercingdrill": {"name": "Piercing Drill", "desc": "This Pokemon's contact moves ignore a target's protection and deal 1/4 the usual damage.", "hook": "implemented", "note": "Contact moves bypass Protect (before_move marks them ignores_protect and the controller's Protect check honours it); there is no damage change - the old 1/4 damage arm was a misreading and is removed."},

	"pixilate": {"name": "Pixilate", "desc": "This Pokemon's Normal-type moves become Fairy type and have 1.2× power.", "hook": "implemented", "note": "Normal moves become Fairy type with 1.2x power (move_type + power_mult)."},
	"plus": {"name": "Plus", "desc": "If an active ally has this Ability or the Minus Ability, this Pokemon's Sp. Atk is 1.5×.", "hook": "implemented", "note": "Special damage 1.5x when the ally has Plus or Minus (mon[\"ally_ability\"], same damage_mult arm as Minus); the controller sets it in doubles, and it is empty in singles so it never fires there."},
	"poisonheal": {"name": "Poison Heal", "desc": "This Pokemon is healed by 1/8 of its max HP each turn when poisoned; no HP loss.", "hook": "implemented", "note": "Heals 1/8 max HP per turn while poisoned (end_of_turn in Batch3) and takes no poison damage (the status engine skips PSN and TOX damage for the holder). The old double heal from the v2 arm is removed."},

	"poisonpoint": {"name": "Poison Point", "desc": "30% chance a Pokemon making contact with this Pokemon will be poisoned.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"poisonpuppeteer": {"name": "Poison Puppeteer", "desc": "Pecharunt: If this Pokemon poisons a target, the target also becomes confused.", "hook": "implemented", "note": "on_after_set_status confuses a PSN/TOX target for 2-5 turns (Pecharunt only, Own Tempo immune); confusion system added to the controller (33% self-hit, 40 power)."},
	"poisontouch": {"name": "Poison Touch", "desc": "This Pokemon's contact moves have a 30% chance of poisoning.", "hook": "implemented", "note": "Contact moves have a 30% chance to poison (on_damage_taken, attacker-side)."},
	"powerconstruct": {"name": "Power Construct", "desc": "If Zygarde 10%/50%, changes to Complete if at 1/2 max HP or less at end of turn.", "hook": "implemented", "note": "Zygarde at 1/2 HP or less becomes Zygarde-Complete (form_change)."},
	"powerofalchemy": {"name": "Power of Alchemy", "desc": "This Pokemon copies the Ability of an ally that faints.", "hook": "implemented", "note": "Copies a fainted ally's ability, except the no-receiver list (on_faint)."},
	"powerspot": {"name": "Power Spot", "desc": "This Pokemon's allies have the power of their moves multiplied by 1.3.", "hook": "implemented", "note": "Allies' moves deal 1.3x damage (ally_damage_mult)."},
	"prankster": {"name": "Prankster", "desc": "This Pokemon's Status moves have priority raised by 1, but Dark types are immune.", "hook": "implemented", "note": "Status moves get +1 priority; Dark types are immune to them (priority_bonus + before_move)."},
	"pressure": {"name": "Pressure", "desc": "If this Pokemon is the target of a foe's move, that move loses one additional PP.", "hook": "implemented", "note": "Announces on switch-in, and a foe target with Pressure costs the move 1 extra PP (2 PP in total, 1 extra even with two Pressure targets, never below 0 PP). Allies with Pressure cost nothing."},

	"primordialsea": {"name": "Primordial Sea", "desc": "On switch-in, heavy rain begins until this Ability is not active in battle.", "hook": "implemented", "note": "Switch-in starts heavy rain (rain + primordialsea flag); damaging Fire moves are blocked (before_move)."},
	"prismarmor": {"name": "Prism Armor", "desc": "This Pokemon receives 3/4 damage from supereffective attacks.", "hook": "implemented", "note": "Supereffective hits deal 0.75x damage (damage_mult)."},
	"propellertail": {"name": "Propeller Tail", "desc": "This Pokemon's moves cannot be redirected to a different target by any effect.", "hook": "implemented", "note": "Move is marked ignores_redirection in before_move, and the doubles targeting code honours the mark: Lightning Rod and Storm Drain never draw the move away from its chosen target. Follow Me and Rage Powder redirects are not built, because those moves are not in the runtime move list."},

	"protean": {"name": "Protean", "desc": "This Pokemon's type changes to the type of the move it is using. Once per switch-in.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"protosynthesis": {"name": "Protosynthesis", "desc": "Sun active or Booster Energy used: highest stat is 1.3×, or 1.5× if Speed.", "hook": "implemented", "note": "In sun or with Booster Energy, the highest stat is 1.3x (1.5x Speed) with stage-aware best-stat pick (on_switch_in + end_of_turn + power_mult + damage_mult + speed_mult)."},
	"psychicsurge": {"name": "Psychic Surge", "desc": "On switch-in, this Pokemon summons Psychic Terrain.", "hook": "implemented", "note": "Switch-in summons Psychic Terrain (on_switch_in + terrain_on_switch_in)."},
	"punkrock": {"name": "Punk Rock", "desc": "This Pokemon receives 1/2 damage from sound moves. Its own have 1.3× power.", "hook": "implemented", "note": "Sound moves deal 1.3x power and sound moves taken deal 0.5x damage (power_mult + damage_mult)."},
	"purepower": {"name": "Pure Power", "desc": "This Pokemon's Attack is doubled.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"purifyingsalt": {"name": "Purifying Salt", "desc": "Ghost damage to this Pokemon dealt with a halved offensive stat; can't be statused.", "hook": "implemented", "note": "Cannot be statused; Ghost moves taken use a halved offensive stat (blocks_status + before_move + damage_mult)."},
	"quarkdrive": {"name": "Quark Drive", "desc": "Electric Terrain active or Booster Energy used: highest stat is 1.3×, or 1.5× if Speed.", "hook": "implemented", "note": "In Electric Terrain or with Booster Energy, the highest stat is 1.3x (1.5x Speed) with stage-aware best-stat pick (on_switch_in + end_of_turn + power_mult + damage_mult + speed_mult)."},
	"queenlymajesty": {"name": "Queenly Majesty", "desc": "This Pokemon and its allies are protected from opposing priority moves.", "hook": "implemented", "note": "Foe priority moves targeting the holder are blocked (before_move); in doubles the whole side is protected through side_priority_block in the damage pass."},
	"quickdraw": {"name": "Quick Draw", "desc": "This Pokemon has a 30% chance to move first in its priority bracket with attacking moves.", "hook": "implemented", "note": "30% chance of +0.1 priority on attacking moves, via frac_priority (Batch3) and the float TurnResolver; the controller rolls once per turn."},
	"quickfeet": {"name": "Quick Feet", "desc": "If this Pokemon is statused, its Speed is 1.5×; ignores Speed drop from paralysis.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"raindish": {"name": "Rain Dish", "desc": "If Rain is active, this Pokemon heals 1/16 of its max HP each turn.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"rattled": {"name": "Rattled", "desc": "Speed is raised 1 stage if hit by a Bug-, Dark-, or Ghost-type attack, or Intimidated.", "hook": "implemented", "note": "Bug/Dark/Ghost hits raise Speed 1 stage; Intimidate drops raise Speed when the caller sets field stat_source (on_damage_taken + on_stat_boosted)."},
	"rebound": {"name": "Rebound", "desc": "On switch-in, blocks certain status moves and bounces them back to the user.", "hook": "implemented", "note": "Reflectable status moves are stopped on the switch-in turn (before_move) and bounced back at the user, in singles and in doubles."},
	"receiver": {"name": "Receiver", "desc": "This Pokemon copies the Ability of an ally that faints.", "hook": "implemented", "note": "Copies a fainted ally's ability, except the no-receiver list (on_faint)."},
	"reckless": {"name": "Reckless", "desc": "This Pokemon's attacks with recoil or crash damage have 1.2× power; not Struggle.", "hook": "implemented", "note": "Recoil and crash-damage moves have 1.2x power (power_mult)."},
	"refrigerate": {"name": "Refrigerate", "desc": "This Pokemon's Normal-type moves become Ice type and have 1.2× power.", "hook": "implemented", "note": "Normal moves become Ice type with 1.2x power (move_type + power_mult)."},
	"regenerator": {"name": "Regenerator", "desc": "This Pokemon restores 1/3 of its maximum HP, rounded down, when it switches out.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"ripen": {"name": "Ripen", "desc": "When this Pokemon eats certain Berries, the effects are doubled.", "hook": "implemented", "note": "Eating a Berry doubles its effect: Sitrus and pinch Berries heal twice as much, Oran heals 20 HP, Berry Juice heals 40 HP, stat Berries raise 2 stages (Starf Berry raises 4), Leppa Berry restores 20 PP, Enigma Berry heals half of max HP, and weaken Berries quarter damage. Lansat Berry is not built: the engine has no Focus Energy volatile."},

	"rivalry": {"name": "Rivalry", "desc": "This Pokemon's attacks do 1.25× on same gender targets; 0.75× on opposite gender.", "hook": "implemented", "note": "1.25x power vs same gender, 0.75x vs opposite gender (power_mult)."},
	"rkssystem": {"name": "RKS System", "desc": "If this Pokemon is a Silvally, its type changes to match its held Memory.", "hook": "implemented", "note": "A Silvally's type changes to match its held Memory on switch-in (on_switch_in)."},
	"rockhead": {"name": "Rock Head", "desc": "This Pokemon does not take recoil damage besides Struggle/Life Orb/crash damage.", "hook": "implemented", "note": "Move recoil skipped in MoveEffects.apply_after_hit; Struggle recoil (controller) and Life Orb recoil (ItemEngine) are separate paths and are not skipped."},
	"rockypayload": {"name": "Rocky Payload", "desc": "This Pokemon's offensive stat is multiplied by 1.5 while using a Rock-type attack.", "hook": "implemented", "note": "Rock moves deal 1.5x power (power_mult)."},
	"roughskin": {"name": "Rough Skin", "desc": "Pokemon making contact with this Pokemon lose 1/8 of their max HP.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"runaway": {"name": "Run Away", "desc": "No competitive use.", "hook": "implemented", "note": "No competitive use; no hook needed."},
	"sandforce": {"name": "Sand Force", "desc": "This Pokemon's Ground/Rock/Steel attacks do 1.3× in Sandstorm; immunity to it.", "hook": "implemented", "note": "Ground, Rock and Steel moves deal 1.3x power in sand (power_mult) and the holder takes no sandstorm damage (weather check in the status engine)."},

	"sandrush": {"name": "Sand Rush", "desc": "If Sandstorm is active, this Pokemon's Speed is doubled; immunity to Sandstorm.", "hook": "implemented", "note": "Speed is doubled in sand (TurnResolver) and the holder takes no sandstorm damage (weather check in the status engine)."},

	"sandspit": {"name": "Sand Spit", "desc": "When this Pokemon is hit by an attack, the effect of Sandstorm begins.", "hook": "implemented", "note": "Being hit sets the sandspit_triggered flag so the caller starts a sandstorm (on_damage_taken)."},
	"sandstream": {"name": "Sand Stream", "desc": "On switch-in, this Pokemon summons Sandstorm.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"sandveil": {"name": "Sand Veil", "desc": "If Sandstorm is active, this Pokemon's evasiveness is 1.25×; immunity to Sandstorm.", "hook": "implemented", "note": "Moves used against the holder are 0.8x accurate in sand (accuracy_mult) and the holder takes no sandstorm damage (weather check in the status engine)."},

	"sapsipper": {"name": "Sap Sipper", "desc": "This Pokemon's Attack is raised 1 stage if hit by a Grass move; Grass immunity.", "hook": "implemented", "note": "Grass immunity plus +1 Attack stage on a Grass hit (is_immune, v2 partial completed)."},
	"schooling": {"name": "Schooling", "desc": "If user is Wishiwashi, changes to School Form if it has > 1/4 max HP, else Solo Form.", "hook": "implemented", "note": "Wishiwashi changes between Solo and School Forme at the 1/4 HP line (form_change)."},
	"scrappy": {"name": "Scrappy", "desc": "Fighting, Normal moves hit Ghost. Immune to Intimidate.", "hook": "implemented", "note": "Normal and Fighting moves hit Ghosts; an Attack drop from Intimidate is blocked too (the Intimidate arm marks its own call, Batch3 reads the mark)."},

	"screencleaner": {"name": "Screen Cleaner", "desc": "On switch-in, the effects of Aurora Veil, Light Screen, and Reflect end for both sides.", "hook": "implemented", "note": "Switch-in sets field screens_cleared; the caller then removes Reflect, Light Screen and Aurora Veil from both sides."},
	"seedsower": {"name": "Seed Sower", "desc": "When this Pokemon is hit by an attack, the effect of Grassy Terrain begins.", "hook": "implemented", "note": "Being hit sets the seedsower_triggered flag so the caller starts Grassy Terrain (on_damage_taken)."},
	"serenegrace": {"name": "Serene Grace", "desc": "This Pokemon's moves have their secondary effect chance doubled.", "hook": "implemented", "note": "Secondary effect chances are doubled (before_move)."},
	"shadowshield": {"name": "Shadow Shield", "desc": "If this Pokemon is at full HP, damage taken from attacks is halved.", "hook": "implemented", "note": "Damage taken at full HP is halved (damage_mult)."},
	"shadowtag": {"name": "Shadow Tag", "desc": "Prevents foes from choosing to switch unless they also have this Ability.", "hook": "implemented", "note": "Foes cannot switch out unless Ghost, holding Shed Shell, or also Shadow Tag (traps_foe)."},
	"sharpness": {"name": "Sharpness", "desc": "This Pokemon's slicing moves have their power multiplied by 1.5.", "hook": "implemented", "note": "Slicing moves have 1.5x power (power_mult)."},
	"shedskin": {"name": "Shed Skin", "desc": "This Pokemon has a 33% chance to have its status cured at the end of each turn.", "hook": "implemented", "note": "33% chance to cure the status each end of turn (end_of_turn)."},
	"sheerforce": {"name": "Sheer Force", "desc": "This Pokemon's attacks with secondary effects have 1.3× power; nullifies the effects.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"shellarmor": {"name": "Shell Armor", "desc": "This Pokemon cannot be struck by a critical hit.", "hook": "implemented", "note": "The hit can never be a crit: the damage calculator blocks the crit roll when the defender has Shell Armor (unless the move ignores abilities). The damage_mult arm that cancels the 1.5x bonus is kept as a backstop for direct modify_damage calls."},

	"shielddust": {"name": "Shield Dust", "desc": "This Pokemon is not affected by the secondary effect of another Pokemon's attack.", "hook": "implemented", "note": "Marks the move so the caller skips its secondaries (before_move)."},
	"shieldsdown": {"name": "Shields Down", "desc": "If Minior, switch-in/end of turn it changes to Core at 1/2 max HP or less, else Meteor.", "hook": "implemented", "note": "Minior changes between Meteor and base forme at the 1/2 HP line and cannot be statused in Meteor forme (form_change + blocks_status)."},
	"simple": {"name": "Simple", "desc": "When one of this Pokemon's stat stages is raised or lowered, the amount is doubled.", "hook": "implemented", "note": "Stat stage changes are doubled (on_stat_boosted)."},
	"skilllink": {"name": "Skill Link", "desc": "This Pokemon's multi-hit attacks always hit the maximum number of times.", "hook": "implemented", "note": "Multi-hit moves always hit the maximum number of times (before_move)."},
	"slowstart": {"name": "Slow Start", "desc": "On switch-in, this Pokemon's Attack and Speed are halved for 5 turns.", "hook": "implemented", "note": "Attack and Speed are halved for 5 turns after switch-in (on_switch_in + damage_mult + speed_mult + end_of_turn + on_switch_out)."},
	"slushrush": {"name": "Slush Rush", "desc": "If Snow is active, this Pokemon's Speed is doubled.", "hook": "implemented", "note": "Speed x2 in snow; owned by TurnResolver.effective_speed, no hook needed here."},
	"sniper": {"name": "Sniper", "desc": "If this Pokemon strikes with a critical hit, the damage is multiplied by 1.5.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"snowcloak": {"name": "Snow Cloak", "desc": "If Snow is active, this Pokemon's evasiveness is 1.25×.", "hook": "implemented", "note": "Moves used against the holder are 0.8x accurate in snow (accuracy_mult). Hail needs no check: snow deals no damage in Gen 9."},

	"snowwarning": {"name": "Snow Warning", "desc": "On switch-in, this Pokemon summons Snow.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"solarpower": {"name": "Solar Power", "desc": "If Sun is active, this Pokemon's Sp. Atk is 1.5×; loses 1/8 max HP per turn.", "hook": "implemented", "note": "Special moves deal 1.5x power in sun (power_mult) and the holder loses 1/8 max HP at the end of the turn in sun (end_of_turn in Batch4); Utility Umbrella blocks both, including in harsh sunlight. The old double HP loss from the v2 arm is removed."},

	"solidrock": {"name": "Solid Rock", "desc": "This Pokemon receives 3/4 damage from supereffective attacks.", "hook": "implemented", "note": "Takes 0.75x damage from supereffective hits."},
	"soulheart": {"name": "Soul-Heart", "desc": "This Pokemon's Special Attack is raised by 1 stage when another Pokemon faints.", "hook": "implemented", "note": "Sp. Atk +1 when another Pokemon faints."},
	"soundproof": {"name": "Soundproof", "desc": "This Pokemon is immune to sound-based moves, unless it used the move.", "hook": "implemented", "note": "Sound moves aimed at holder are skipped in before_move (is_immune cannot see the sound flag)."},
	"speedboost": {"name": "Speed Boost", "desc": "This Pokemon's Speed is raised 1 stage at the end of each full turn on the field.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"spicyspray": {"name": "Spicy Spray", "desc": "If this Pokemon is hit by an attack, the attacker becomes burned.", "hook": "implemented", "note": "Attacker is burned when it damages the holder."},
	"stakeout": {"name": "Stakeout", "desc": "This Pokemon's offensive stat is doubled against a target that switched in this turn.", "hook": "implemented", "note": "Power 2x against a foe that switched in this turn; the caller sets defender switched_in_this_turn on switch-in and clears it at end of turn."},
	"stall": {"name": "Stall", "desc": "This Pokemon moves last among Pokemon using the same or greater priority moves.", "hook": "implemented", "note": "Moves last in its own priority bracket: the turn resolver puts a mon with moves_last (or the Stall ability) after every other mon with the same priority, whatever the Speeds are. Priority numbers are not changed."},

	"stalwart": {"name": "Stalwart", "desc": "This Pokemon's moves cannot be redirected to a different target by any effect.", "hook": "implemented", "note": "Move is marked ignores_redirection in before_move, and the doubles targeting code honours the mark: Lightning Rod and Storm Drain never draw the move away from its chosen target. Follow Me and Rage Powder redirects are not built, because those moves are not in the runtime move list."},

	"stamina": {"name": "Stamina", "desc": "This Pokemon's Defense is raised by 1 stage after it is damaged by a move.", "hook": "implemented", "note": "Defense +1 after taking damage from a move."},
	"stancechange": {"name": "Stance Change", "desc": "If Aegislash, changes Forme to Blade before attacks and Shield before King's Shield.", "hook": "implemented", "note": "Aegislash changes to Blade Forme before an attacking move and Shield Forme before King's Shield."},
	"static": {"name": "Static", "desc": "30% chance a Pokemon making contact with this Pokemon will be paralyzed.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"steadfast": {"name": "Steadfast", "desc": "If this Pokemon flinches, its Speed is raised by 1 stage.", "hook": "implemented", "note": "Speed +1 when the holder flinches; the caller calls on_flinch from the flinch branch of each move function."},
	"steamengine": {"name": "Steam Engine", "desc": "This Pokemon's Speed is raised by 6 stages after it is damaged by Fire/Water moves.", "hook": "implemented", "note": "Speed +6 after taking damage from a Fire or Water move."},
	"steelworker": {"name": "Steelworker", "desc": "This Pokemon's offensive stat is multiplied by 1.5 while using a Steel-type attack.", "hook": "implemented", "note": "Verified: Steel move deals 148 damage with Steelworker vs 99 without (seed 99, Iron Head), the same as Showdown's 1.5x Attack boost gives."},
	"steelyspirit": {"name": "Steely Spirit", "desc": "This Pokemon and its allies' Steel-type moves have their power multiplied by 1.5.", "hook": "implemented", "note": "Steel moves 1.5x for holder (power_mult) and for a different ally (ally_damage_mult)."},
	"stench": {"name": "Stench", "desc": "This Pokemon's attacks without a chance to flinch gain a 10% chance to flinch.", "hook": "implemented", "note": "Damaging moves with no flinch chance gain a 10 percent flinch chance; moves that already have a secondary effect roll the flinch chance on its own (roll_secondary)."},

	"stickyhold": {"name": "Sticky Hold", "desc": "This Pokemon cannot lose its held item due to another Pokemon's Ability or attack.", "hook": "implemented", "note": "blocks_take_item (Batch4) guards Knock Off (1.5x power + take), Trick/Switcheroo swaps, Magician and Pickpocket; a Sticky Barb is still takeable."},
	"stormdrain": {"name": "Storm Drain", "desc": "This Pokemon draws Water moves to itself to raise Sp. Atk by 1; Water immunity.", "hook": "implemented", "note": "Water immunity plus Sp. Atk +1 on a Water hit, done in is_immune, and single-target Water moves aimed at its foe-side partner are redirected to it in doubles (DoublesTargeting._apply_redirect). Propeller Tail and Stalwart moves ignore the redirect, and Mold Breaker, Teravolt and Turboblaze ignore it too. Follow Me and Rage Powder are not built: those moves are not in the runtime move list."},

	"strongjaw": {"name": "Strong Jaw", "desc": "This Pokemon's bite-based attacks have 1.5× power. Bug Bite is not boosted.", "hook": "implemented", "note": "Bite-flag moves 1.5x; Bug Bite has no bite flag in moves.json so it is not boosted, as Showdown wants."},
	"sturdy": {"name": "Sturdy", "desc": "If this Pokemon is at full HP, it survives one hit with at least 1 HP. Immune to OHKO.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"suctioncups": {"name": "Suction Cups", "desc": "This Pokemon cannot be forced to switch out by another Pokemon's attack or item.", "hook": "implemented", "note": "blocks_drag_out (Batch4) stops Roar/Whirlwind/Dragon Tail/Circle Throw; the drag-out moves are not in the RC1 move list yet, so the handler only runs once the v5 loader brings them in."},
	"superluck": {"name": "Super Luck", "desc": "This Pokemon's critical hit ratio is raised by 1 stage.", "hook": "implemented", "note": "Critical hit ratio +1 stage."},
	"supersweetsyrup": {"name": "Supersweet Syrup", "desc": "On switch-in, this Pokemon lowers the evasiveness of opponents 1 stage. Once per battle.", "hook": "implemented", "note": "On switch-in, once per battle, lowers the foe's evasiveness 1 stage; moves used against that foe are 4/3x accurate (Batch4 accuracy_mult reads evasion_stage)."},

	"supremeoverlord": {"name": "Supreme Overlord", "desc": "This Pokemon's moves have 10% more power for each fainted ally, up to 5 allies.", "hook": "implemented", "note": "Power 1 + 0.1x per fainted ally, up to 5; the caller keeps mon fallen_allies fresh at battle start, after every faint and after a Revive."},
	"surgesurfer": {"name": "Surge Surfer", "desc": "If Electric Terrain is active, this Pokemon's Speed is doubled.", "hook": "implemented", "note": "Speed x2 in Electric Terrain; owned by TurnResolver.effective_speed, no hook needed here."},
	"swarm": {"name": "Swarm", "desc": "At 1/3 or less of its max HP, this Pokemon's offensive stat is 1.5× with Bug attacks.", "hook": "implemented", "note": "Verified: Bug move deals 310 damage with Swarm at 33/100 HP vs 207 without and vs 207 at 34/100 HP (seed 777, Bug Buzz), the same as Showdown's 1.5x Sp. Atk boost gives."},
	"sweetveil": {"name": "Sweet Veil", "desc": "This Pokemon and its allies cannot fall asleep; those already asleep do not wake up.", "hook": "implemented", "note": "Holder cannot fall asleep, and in doubles its ally cannot fall asleep either (blocks_status reads the ally's ability from mon[\"ally\"]). Blocking Yawn is not built: this engine has no Yawn volatile."},

	"swiftswim": {"name": "Swift Swim", "desc": "If Rain is active, this Pokemon's Speed is doubled.", "hook": "implemented", "note": "Speed x2 in rain; owned by TurnResolver.effective_speed, no hook needed here."},
	"swordofruin": {"name": "Sword of Ruin", "desc": "Active Pokemon without this Ability have their Defense multiplied by 0.75.", "hook": "implemented", "note": "Field flag ruin_sword set on switch-in; foes without it take 1/0.75x physical damage (same size as their Defense x0.75); the flag clears when the holder switches out or faints, including a faint to end-of-turn damage, because the faint path re-syncs the field flags."},

	"symbiosis": {"name": "Symbiosis", "desc": "If an ally uses its item, this Pokemon gives its item to that ally immediately.", "hook": "implemented", "note": "When an ally uses its held item (a Berry eaten at end of turn), the holder gives its held item to that ally at once (on_item_use with the ally parameter). The trainer's bag-item action does not trigger it: that is not the ally using its held item."},
	"synchronize": {"name": "Synchronize", "desc": "If another Pokemon burns/poisons/paralyzes this Pokemon, it also gets that status.", "hook": "implemented", "note": "on_after_set_status passes BRN/PAR/PSN/TOX back to the source (SLP/FRZ do not pass back); the dispatcher does the pass-back through try_set_status."},
	"tabletsofruin": {"name": "Tablets of Ruin", "desc": "Active Pokemon without this Ability have their Attack multiplied by 0.75.", "hook": "implemented", "note": "Field flag ruin_tablets set on switch-in; foes without it deal 0.75x physical damage (same size as their Attack x0.75); the flag clears when the holder switches out or faints, including a faint to end-of-turn damage, because the faint path re-syncs the field flags."},

	"tangledfeet": {"name": "Tangled Feet", "desc": "This Pokemon's evasiveness is doubled as long as it is confused.", "hook": "implemented", "note": "Moves aimed at a confused holder are 0.5x accurate. Verified: the arm reads mon confused, which the engine sets when Poison Puppeteer confuses a foe and clears when confusion ends. Confusion moves do not set it yet."},
	"tanglinghair": {"name": "Tangling Hair", "desc": "Pokemon making contact with this Pokemon have their Speed lowered by 1 stage.", "hook": "implemented", "note": "Attacker Speed -1 on a contact hit."},
	"technician": {"name": "Technician", "desc": "This Pokemon's moves of 60 power or less have 1.5× power, including Struggle.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"telepathy": {"name": "Telepathy", "desc": "This Pokemon does not take damage from attacks made by its allies.", "hook": "implemented", "note": "Takes no damage from an ally's non-Status attacks in doubles (controller check in _execute_move_doubles); Mold Breaker, Teravolt and Turboblaze ignore it."},
	"terashell": {"name": "Tera Shell", "desc": "Terapagos: If full HP, attacks taken have 0.5× effectiveness unless naturally immune.", "hook": "implemented", "note": "Full-HP Terapagos takes every non-immune hit at 0.5x effectiveness (0.5 / effectiveness in damage_mult)."},
	"terashift": {"name": "Tera Shift", "desc": "If this Pokemon is a Terapagos, it transforms into its Terastal Form on entry.", "hook": "implemented", "note": "Terapagos changes to Terastal Form on switch-in (on_switch_in and form_change)."},
	"teraformzero": {"name": "Teraform Zero", "desc": "Terapagos: Terastallizing ends the effects of weather and terrain. Once per battle.", "hook": "implemented", "note": "Terastallizing ends weather and terrain once per battle, at the moment of Terastallization."},

	"teravolt": {"name": "Teravolt", "desc": "This Pokemon's moves and their effects ignore the Abilities of other Pokemon.", "hook": "implemented", "note": "Moves are marked ignore_ability in before_move, and the damage and immunity code honours the flag: ability immunities are skipped, defender ability damage cuts are skipped, and foe stat blocks and stat answers are skipped."},

	"thermalexchange": {"name": "Thermal Exchange", "desc": "This Pokemon's Attack is raised by 1 when damaged by Fire moves; can't be burned.", "hook": "implemented", "note": "Attack +1 on a Fire hit; cannot be burned; an existing burn is cured at end of turn."},
	"thickfat": {"name": "Thick Fat", "desc": "Fire-/Ice-type moves against this Pokemon deal damage with a halved offensive stat.", "hook": "implemented", "note": "Verified: Fire and Ice moves against the holder deal 53 damage vs 105 without (seed 777, spa 100), the same as Showdown's halved offensive stat gives; the holder's own Fire move is not halved."},
	"tintedlens": {"name": "Tinted Lens", "desc": "This Pokemon's attacks that are not very effective on a target deal double damage.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"torrent": {"name": "Torrent", "desc": "At 1/3 or less of its max HP, this Pokemon's offensive stat is 1.5× with Water attacks.", "hook": "implemented", "note": "Verified: Water move deals 310 damage with Torrent at 33/100 HP vs 207 without and vs 207 at 34/100 HP (seed 777, Surf), the same as Showdown's 1.5x Sp. Atk boost gives."},
	"toughclaws": {"name": "Tough Claws", "desc": "This Pokemon's contact moves have their power multiplied by 1.3.", "hook": "implemented", "note": "Verified: contact move deals 88 damage with Tough Claws vs 68 without (seed 42, Iron Head with the contact flag), the same as Showdown's 1.3x base power boost gives."},
	"toxicboost": {"name": "Toxic Boost", "desc": "While this Pokemon is poisoned, its physical attacks have 1.5× power.", "hook": "implemented", "note": "Verified: physical move deals 123 damage with Toxic Boost while poisoned (PSN or TOX) vs 82 healthy (seed 99, Earthquake), the same as Showdown's 1.5x base power boost gives; special moves get no boost."},
	"toxicchain": {"name": "Toxic Chain", "desc": "This Pokemon's attacks have a 30% chance of badly poisoning.", "hook": "implemented", "note": "Holder's damaging hits badly poison the target 30% of the time; Shield Dust and Covert Cloak block it."},
	"toxicdebris": {"name": "Toxic Debris", "desc": "If this Pokemon is hit by a physical attack, Toxic Spikes are set on the opposing side.", "hook": "implemented", "note": "A physical hit sets one layer of Toxic Spikes (max 2) on the attacker's side, in the side hazards of the shared field."},
	"trace": {"name": "Trace", "desc": "On switch-in, or when it can, this Pokemon copies a random adjacent foe's Ability.", "hook": "implemented", "note": "On switch-in copies the foe's Ability unless it is on Showdown's no-copy list."},
	"transistor": {"name": "Transistor", "desc": "This Pokemon's offensive stat is multiplied by 1.3 while using an Electric-type attack.", "hook": "implemented", "note": "Verified: Electric move deals 304 damage with Transistor vs 234 without (seed 5, Thunderbolt), the same as Showdown's 1.3x Sp. Atk boost gives."},
	"triage": {"name": "Triage", "desc": "This Pokemon's healing moves have their priority increased by 3.", "hook": "implemented", "note": "Healing moves get +3 priority."},
	"truant": {"name": "Truant", "desc": "This Pokemon skips every other turn instead of using a move.", "hook": "implemented", "note": "Skips every other turn (alternating, first move works)."},
	"turboblaze": {"name": "Turboblaze", "desc": "This Pokemon's moves and their effects ignore the Abilities of other Pokemon.", "hook": "implemented", "note": "Moves are marked ignore_ability in before_move, and the damage and immunity code honours the flag: ability immunities are skipped, defender ability damage cuts are skipped, and foe stat blocks and stat answers are skipped."},

	"unaware": {"name": "Unaware", "desc": "This Pokemon ignores other Pokemon's stat stages when taking or doing damage.", "hook": "implemented", "note": "Stat stages are now applied in the damage calculator, and Unaware ignores the foe's stages: the holder's attacks ignore the foe's Defense stages, and the holder's Defense ignores the foe's Attack stages (flags from before_move, plus a direct ability check so doubles works too)."},

	"unburden": {"name": "Unburden", "desc": "Speed is doubled on held item loss; boost is lost if it switches, gets new item/Ability.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"unnerve": {"name": "Unnerve", "desc": "While this Pokemon is active, it prevents opposing Pokemon from using their Berries.", "hook": "implemented", "note": "Sets field unnerve_active on switch-in; the item engine blocks foe Berries while a holder is active on the other side. The flag clears on switch-out and faint."},
	"unseenfist": {"name": "Unseen Fist", "desc": "This Pokemon's contact moves ignore the target's protection, except Max Guard.", "hook": "implemented", "note": "Contact moves are marked ignores_protect in before_move, and the controller's Protect check now honours the flag, so they hit through Protect."},

	"vesselofruin": {"name": "Vessel of Ruin", "desc": "Active Pokemon without this Ability have their Special Attack multiplied by 0.75.", "hook": "implemented", "note": "Field flag ruin_vessel set on switch-in; foes without it deal 0.75x special damage (same size as their Sp. Atk x0.75); the flag clears when the holder switches out or faints, including a faint to end-of-turn damage, because the faint path re-syncs the field flags."},

	"victorystar": {"name": "Victory Star", "desc": "This Pokemon and its allies' moves have their accuracy multiplied by 1.1.", "hook": "implemented", "note": "Holder's own moves are 1.1x accurate, and in doubles its ally's moves are 1.1x accurate too (accuracy_mult reads the ally's ability from attacker[\"ally_ability\"]). Two Victory Star holders on one side give 1.1 x 1.1 = 1.21x, the same as Showdown."},

	"vitalspirit": {"name": "Vital Spirit", "desc": "This Pokemon cannot fall asleep. Gaining this Ability while asleep cures it.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"voltabsorb": {"name": "Volt Absorb", "desc": "This Pokemon heals 1/4 of its max HP when hit by Electric moves; Electric immunity.", "hook": "implemented", "note": "Electric immunity plus heals 1/4 max HP on an Electric hit, done in is_immune. COMPLETES the v2 partial (heal was missing)."},
	"wanderingspirit": {"name": "Wandering Spirit", "desc": "Pokemon making contact with this Pokemon have their Ability swapped with this one.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"waterabsorb": {"name": "Water Absorb", "desc": "This Pokemon heals 1/4 of its max HP when hit by Water moves; Water immunity.", "hook": "implemented", "note": "Water immunity plus heals 1/4 max HP on a Water hit, done in is_immune. COMPLETES the v2 partial (heal was missing)."},
	"waterbubble": {"name": "Water Bubble", "desc": "This Pokemon's Water power is 2×; it can't be burned; Fire power against it is halved.", "hook": "implemented", "note": "Water moves deal 2x power (power_mult), Fire moves against the holder deal 0.5x damage (damage_mult), the holder cannot be burned (blocks_status) and a burn is cured at the end of the turn (end_of_turn in Batch4)."},

	"watercompaction": {"name": "Water Compaction", "desc": "This Pokemon's Defense is raised 2 stages after it is damaged by a Water-type move.", "hook": "implemented", "note": "Defense +2 after taking damage from a Water move."},
	"waterveil": {"name": "Water Veil", "desc": "This Pokemon cannot be burned. Gaining this Ability while burned cures it.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"weakarmor": {"name": "Weak Armor", "desc": "If a physical attack hits this Pokemon, Defense is lowered by 1, Speed is raised by 2.", "hook": "implemented", "note": "Physical hit lowers Defense 1 and raises Speed 2."},
	"wellbakedbody": {"name": "Well-Baked Body", "desc": "This Pokemon's Defense is raised 2 stages if hit by a Fire move; Fire immunity.", "hook": "implemented", "note": "Fire immunity plus Defense +2 on a Fire hit, done in is_immune."},
	"whitesmoke": {"name": "White Smoke", "desc": "Prevents other Pokemon from lowering this Pokemon's stat stages.", "hook": "implemented", "note": "Blocks any lowering of the holder's stat stages by a foe; the holder's own moves still lower its own stages, because self drops pass no source, so the block never runs for them."},

	"wimpout": {"name": "Wimp Out", "desc": "This Pokemon switches out when it reaches 1/2 or less of its maximum HP.", "hook": "implemented", "note": "Flags a switch (mon switch_flag) when damage drops the holder from above 1/2 to 1/2 or less of max HP; the caller switches it out on the shared path with Emergency Exit."},
	"windpower": {"name": "Wind Power", "desc": "This Pokemon gains the Charge effect when hit by a wind move or Tailwind begins.", "hook": "implemented", "note": "Gains Charge on a wind hit and when Tailwind starts on its side; the next Electric move is 2x."},

	"windrider": {"name": "Wind Rider", "desc": "Attack raised by 1 if hit by a wind move or Tailwind begins. Wind move immunity.", "hook": "implemented", "note": "Wind moves aimed at the holder are blocked and Attack rises 1; Attack also rises 1 when Tailwind starts on its side or when it switches in under an active Tailwind."},

	"wonderguard": {"name": "Wonder Guard", "desc": "This Pokemon can only be damaged by supereffective moves and indirect damage.", "hook": "implemented", "note": "v2 hook, kept verbatim"},
	"wonderskin": {"name": "Wonder Skin", "desc": "Status moves with accuracy checks are 50% accurate when used on this Pokemon.", "hook": "implemented", "note": "Status moves aimed at holder have their accuracy set to 50."},
	"zenmode": {"name": "Zen Mode", "desc": "If Darmanitan, at end of turn changes Mode to Standard if > 1/2 max HP, else Zen.", "hook": "implemented", "note": "Darmanitan changes forme at the 1/2 HP line at end of turn (Zen below, Standard above), Galarian form included."},
	"zerotohero": {"name": "Zero to Hero", "desc": "If this Pokemon is a Palafin in Zero Form, switching out has it change to Hero Form.", "hook": "implemented", "note": "Palafin in Zero Form changes to Hero Form on switching out, and announces Hero Form on switching in."},
}

static func _v2_on_switch_in(mon: Dictionary, foe: Dictionary, field: Dictionary) -> Array:
	var logs: Array = []
	var ab: String = mon.get("ability", "")
	match ab:
		"Intimidate":
			# Intimidate is a foe-caused drop, so it goes through the
			# same path as a move drop: Mirror Armor bounces it,
			# blocks_stat_change can stop it, on_stat_boosted fires
			# (Competitive / Defiant / Contrary / Rattled). Guard Dog
			# blocks the drop but its +1 Attack is still a known gap
			# - see its ABILITY_INFO note.
			if not try_mirror_armor(foe, "atk", -1, mon, logs):

				# Mark this one call as Intimidate-caused, so the
				# Oblivious / Own Tempo / Scrappy arm in Batch3 can
				# tell it from a move drop. Cleared right after.
				mon["intimidate_drop"] = true
				if blocks_stat_change(foe, "atk", -1, mon) or ItemEngine.blocks_foe_stat_drop(foe):
					# Clear Amulet blocks the drop beside the
					# ability blocks.
					logs.append("%s's Intimidate had no effect on %s!" % [mon.get("name", "Pokémon"), foe.get("name", "Foe")])
				else:
					var stages: Dictionary = foe.get("stages", {"atk": 0})
					stages["atk"] = max(-6, int(stages.get("atk", 0)) - 1)
					foe["stages"] = stages
					logs.append("%s's Intimidate cut %s's Attack!" % [mon.get("name", "Pokémon"), foe.get("name", "Foe")])
					field["boost_target_name"] = str(foe.get("name", "Pokemon"))
					# Rattled reads stat_source, so it is set just
					# before this one call and cleared right after.
					field["stat_source"] = "Intimidate"
					on_stat_boosted(foe, "atk", -1, field, logs)
					field.erase("stat_source")
					# Adrenaline Orb answers a real Intimidate
					# drop with +1 Speed; Eject Pack answers it
					# with a switch-out flag, like any other
					# foe-caused drop.
					ItemEngine.on_intimidate_drop(foe, logs)
					ItemEngine.on_stat_dropped(foe, logs)
				mon.erase("intimidate_drop")


		"Drought":
			field["weather"] = "sun"
			field["weather_turns"] = ItemEngine.weather_duration(mon, "sun", 5)
			logs.append("%s's Drought intensified the sun's rays!" % mon.get("name", "Pokémon"))
		"Drizzle":
			field["weather"] = "rain"
			field["weather_turns"] = ItemEngine.weather_duration(mon, "rain", 5)
			logs.append("%s's Drizzle made it rain!" % mon.get("name", "Pokémon"))
		"Sand Stream":
			field["weather"] = "sand"
			field["weather_turns"] = ItemEngine.weather_duration(mon, "sand", 5)
			logs.append("%s's Sand Stream whipped up a sandstorm!" % mon.get("name", "Pokémon"))
		"Snow Warning":
			field["weather"] = "snow"
			field["weather_turns"] = ItemEngine.weather_duration(mon, "snow", 5)
			logs.append("%s's Snow Warning made it snow!" % mon.get("name", "Pokémon"))
	return logs

static func _v2_on_switch_out(mon: Dictionary) -> void:
	if mon.get("ability", "") == "Regenerator" and int(mon.get("hp", 0)) > 0:
		var heal := int(floor(float(mon.get("max_hp", 100)) / 3.0))
		mon["hp"] = min(int(mon.get("max_hp", 100)), int(mon.get("hp", 0)) + heal)
	# Confusion is a volatile: it ends on switch-out, like every
	# other volatile in Showdown.
	mon["confused"] = false
	mon["confusion_turns"] = 0

static func _v2_is_immune_by_ability(defender: Dictionary, move_type: String, attacker_ability: String = "", effectiveness: float = 1.0) -> bool:
	if attacker_ability == "Mold Breaker" or attacker_ability == "Teravolt" or attacker_ability == "Turboblaze":
		return false

	var ab: String = defender.get("ability", "")
	if ab == "Levitate" and move_type == "Ground":
		return true
	if ab == "Flash Fire" and move_type == "Fire":
		return true
	if ab in ["Volt Absorb", "Motor Drive", "Lightning Rod"] and move_type == "Electric":
		return true
	if ab in ["Water Absorb", "Storm Drain", "Dry Skin"] and move_type == "Water":
		return true
	if ab == "Sap Sipper" and move_type == "Grass":
		return true
	if ab == "Wonder Guard" and effectiveness < 2.0:
		# Wonder Guard is only hit by super-effective moves. Callers
		# must pass the real effectiveness; with the default 1.0 it
		# blocks, which is the safe side for this check.
		return true
	return false

static func _v2_modify_damage(attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int, is_stab: bool, is_crit: bool = false, effectiveness: float = 1.0) -> int:
	var mult := 1.0
	var a_ab: String = attacker.get("ability", "")
	var d_ab: String = defender.get("ability", "")
	if a_ab == "Adaptability" and is_stab:
		mult *= (2.0 / 1.5)
	if a_ab == "Technician" and int(move.get("power", 0)) <= 60:
		mult *= 1.5
	if a_ab in ["Huge Power", "Pure Power"] and move.get("cat", "") == "Physical":
		mult *= 2.0
	if a_ab == "Sheer Force" and (move.has("status_chance") or move.has("flinch_chance")):
		mult *= 1.3
	if a_ab == "Guts" and attacker.get("status", "") != "" and move.get("cat", "") == "Physical":
		mult *= 1.5
	if a_ab == "Tinted Lens" and effectiveness > 0.0 and effectiveness < 1.0:
		mult *= 2.0
	if a_ab == "Sniper" and is_crit:
		mult *= 1.5
	if a_ab == "Iron Fist" and _is_punching_move(move):
		mult *= 1.2
	if d_ab == "Multiscale" and a_ab != "Mold Breaker" and int(defender.get("hp", 0)) == int(defender.get("max_hp", 1)):
		mult *= 0.5
	var dmg := int(max(1, round(float(base_dmg) * mult)))
	if d_ab == "Sturdy" and a_ab != "Mold Breaker" and int(defender.get("hp", 0)) == int(defender.get("max_hp", 1)) and dmg >= int(defender.get("hp", 1)):
		dmg = int(defender.get("hp", 1)) - 1
	return dmg


## True when a move is a punching move. moves.json marks these with
## flags.punch (checked in the data: Fire Punch, Ice Punch,
## Thunder Punch, Mach Punch, Bullet Punch, Drain Punch and the rest
## all carry "punch": 1). RC1 move dicts may carry "punch": true.
static func _is_punching_move(move: Dictionary) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if bool(flags.get("punch", false)):
		return true
	return bool(move.get("punch", false))


## Raise one stat stage by an amount, clamped between -6 and +6.
static func _raise_stage(mon: Dictionary, key: String, amount: int, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var stages: Dictionary = mon.get("stages", {"atk": 0, "def": 0, "spa": 0, "spd": 0, "spe": 0})
	stages[key] = clampi(int(stages.get(key, 0)) + amount, -6, 6)
	mon["stages"] = stages


## True when the move makes contact. moves.json marks this with
## flags.contact; RC1 move dicts may carry "contact": true.
static func _is_contact(move: Dictionary) -> bool:
	var flags: Dictionary = move.get("flags", {})
	if bool(flags.get("contact", false)):
		return true
	return bool(move.get("contact", false))


## Lose HP equal to a fraction of max HP, at least 1, never below 0.
static func _lose_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp := int(mon.get("max_hp", 100))
	var loss := maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before := int(mon.get("hp", 0))
	mon["hp"] = maxi(0, before - loss)
	return mini(loss, before)


## Heal HP by a fraction of max HP, never above max HP.
static func _heal_fraction_hp(mon: Dictionary, numerator: int, denominator: int) -> int:
	var max_hp := int(mon.get("max_hp", 100))
	var gain := maxi(1, int(floor(float(max_hp) * float(numerator) / float(denominator))))
	var before := int(mon.get("hp", 0))
	mon["hp"] = mini(max_hp, before + gain)
	return int(mon.get("hp", 0)) - before


## End of turn ability effects. Poison Heal heals 1/8 max HP when
## poisoned instead of taking poison damage (see the header note:
## StatusAndFieldEngine must also skip poison damage for these
## holders). Speed Boost raises Speed by 1 stage. Rain Dish heals
## 1/16 in rain. Dry Skin heals 1/8 in rain and loses 1/8 in sun.
## Solar Power loses 1/8 in sun. Ice Body heals 1/16 in snow.
static func _v2_on_end_of_turn(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if int(mon.get("hp", 0)) <= 0:
		return
	var ab: String = mon.get("ability", "")
	var weather: String = str(field.get("weather", "none"))
	match ab:
		"Speed Boost":

			_raise_stage(mon, "spe", 1, logs)
			logs.append("%s's Speed Boost raised its Speed!" % mon.get("name", "Pokémon"))
		"Rain Dish":
			if weather == "rain":
				var healed2 := _heal_fraction_hp(mon, 1, 16)
				if healed2 > 0:
					logs.append("%s restored HP with Rain Dish (+%d HP)!" % [mon.get("name", "Pokémon"), healed2])
		"Ice Body":

			if weather == "snow":
				var healed4 := _heal_fraction_hp(mon, 1, 16)
				if healed4 > 0:
					logs.append("%s restored HP with Ice Body (+%d HP)!" % [mon.get("name", "Pokémon"), healed4])


## Effects when the defender is hit. Rough Skin and Iron Barbs cost
## the attacker 1/8 max HP on contact. Static (30% PAR), Flame
## Body (30% BRN) and Poison Point (30% PSN) can status the attacker
## on contact. Effect Spore is a 30% chance on contact, split
## evenly between sleep, poison and paralysis (10% each). Cursed
## Body has a 30% chance to disable the move used. Mummy changes
## the attacker's ability to Mummy on contact. Wandering Spirit
## swaps the two abilities on contact. Aftermath costs the attacker
## 1/4 max HP when it knocks the user out with a contact move.
static func _v2_on_damage_taken(defender: Dictionary, attacker: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if damage <= 0:
		return
	var d_ab: String = defender.get("ability", "")
	var contact := _is_contact(move)
	if contact and int(attacker.get("hp", 0)) > 0:
		if (d_ab == "Rough Skin" or d_ab == "Iron Barbs") and not blocks_indirect_damage(attacker):
			var lost := _lose_fraction_hp(attacker, 1, 8)
			if lost > 0:
				logs.append("%s was hurt by %s (-%d HP)!" % [attacker.get("name", "Pokémon"), d_ab, lost])
		if str(attacker.get("status", "")) == "":
			if d_ab == "Static" and randf() < 0.30:
				# Field is {} here: the _v2 hook has no field, so
				# Leaf Guard's Sun check cannot fire from a contact
				# ability. Synchronize / Poison Puppeteer DO fire
				# through try_set_status.
				if try_set_status(attacker, "PAR", defender, {}, logs, true):
					logs.append("%s was paralyzed by Static!" % attacker.get("name", "Pokémon"))
			elif d_ab == "Flame Body" and randf() < 0.30:
				if try_set_status(attacker, "BRN", defender, {}, logs, true):
					logs.append("%s was burned by Flame Body!" % attacker.get("name", "Pokémon"))
			elif d_ab == "Poison Point" and randf() < 0.30:
				if try_set_status(attacker, "PSN", defender, {}, logs, true):
					logs.append("%s was poisoned by Poison Point!" % attacker.get("name", "Pokémon"))
			elif d_ab == "Effect Spore" and str(attacker.get("ability", "")) != "Overcoat" and randf() < 0.30:
				var pick := randi_range(1, 3)
				if pick == 1:
					if try_set_status(attacker, "SLP", defender, {}, logs, true):
						logs.append("%s fell asleep from Effect Spore!" % attacker.get("name", "Pokémon"))
				elif pick == 2:
					if try_set_status(attacker, "PSN", defender, {}, logs, true):
						logs.append("%s was poisoned by Effect Spore!" % attacker.get("name", "Pokémon"))
				else:
					if try_set_status(attacker, "PAR", defender, {}, logs, true):
						logs.append("%s was paralyzed by Effect Spore!" % attacker.get("name", "Pokémon"))
		if d_ab == "Cursed Body" and randf() < 0.30:
			attacker["disabled_move"] = str(move.get("name", ""))
			logs.append("%s's Cursed Body disabled %s!" % [defender.get("name", "Pokémon"), str(move.get("name", "move"))])
		if d_ab == "Mummy" and str(attacker.get("ability", "")) != "Mummy":
			attacker["ability"] = "Mummy"
			logs.append("%s's Mummy changed %s's ability to Mummy!" % [defender.get("name", "Pokémon"), attacker.get("name", "Pokémon")])
		if d_ab == "Wandering Spirit":
			var mine: String = defender.get("ability", "")
			var theirs: String = attacker.get("ability", "")
			if mine != theirs:
				defender["ability"] = theirs
				attacker["ability"] = mine
				logs.append("%s's Wandering Spirit swapped abilities with %s!" % [defender.get("name", "Pokémon"), attacker.get("name", "Pokémon")])
	if d_ab == "Aftermath" and contact and int(defender.get("hp", 0)) <= 0 and int(attacker.get("hp", 0)) > 0 and not blocks_indirect_damage(attacker):
		var lost2 := _lose_fraction_hp(attacker, 1, 4)
		if lost2 > 0:
			logs.append("%s was hurt by Aftermath (-%d HP)!" % [attacker.get("name", "Pokémon"), lost2])


## Speed multipliers for abilities NOT owned by TurnResolver.
## Unburden doubles Speed after the held item is lost (the caller
## sets mon["item_lost"] = true when the item goes; the boost is
## lost on switch or on getting a new item, which the caller owns).
## Quick Feet gives 1.5x Speed while statused. Anything else is
## 1.0. Chlorophyll, Swift Swim, Sand Rush and Slush Rush stay in
## TurnResolver.effective_speed and are not done here.
static func _v2_get_speed_multiplier(mon: Dictionary, field: Dictionary) -> float:
	var ab: String = mon.get("ability", "")
	if ab == "Unburden" and bool(mon.get("item_lost", false)) and str(mon.get("item", "")) == "":
		return 2.0
	if ab == "Quick Feet" and str(mon.get("status", "")) != "":
		return 1.5
	return 1.0


## True when an ability blocks a status outright. Immunity blocks
## PSN and TOX, Water Veil blocks BRN, Limber blocks PAR, Insomnia
## and Vital Spirit block SLP, Magma Armor blocks FRZ. Good as Gold
## is NOT here: it blocks status MOVES, not the status itself, so
## this returns false for it and the move check belongs to the
## caller, not to this func.
static func _v2_blocks_status(mon: Dictionary, status: String) -> bool:
	var ab: String = mon.get("ability", "")
	var st := status.to_upper()
	match ab:
		"Immunity":
			return st == "PSN" or st == "TOX"
		"Water Veil":
			return st == "BRN"
		"Limber":
			return st == "PAR"
		"Insomnia", "Vital Spirit":
			return st == "SLP"
		"Magma Armor":
			return st == "FRZ"
	return false


## Run before a move is used. Protean and Libero change the
## attacker's type to the move's type, once per switch-in (tracked
## with mon["protean_used"]). The move dict itself is returned
## unchanged. No ability here stops a move, so this never returns
## {"skip": true}; that key is named only so callers know the shape
## a skipping ability would use.
static func _v2_on_before_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary, logs: Array) -> Dictionary:
	var ab: String = attacker.get("ability", "")
	if ab == "Protean" or ab == "Libero":
		if not bool(attacker.get("protean_used", false)):
			var move_type := str(move.get("type", ""))
			if move_type != "":
				attacker["types"] = [move_type]
				attacker["protean_used"] = true
				logs.append("%s's %s changed its type to %s!" % [attacker.get("name", "Pokémon"), ab, move_type])
	return move


## ---- v3 dispatchers: v2 core + batch 1-4 hooks ----
## Batch files live beside this file (ability_batch_1..4.gd).
## Poison Heal lives in batch 3 only (batch 2's duplicate arm removed).
## Mold Breaker, Teravolt and Turboblaze bypass ALL ability
## immunities: is_immune_by_ability returns false before any
## batch hook runs when the move ignores abilities (the move
## flag) or the attacker has one of the three abilities.
## Neutralizing Gas guard: while field["abilities_suppressed"] is
## true, no other ability has any effect (Showdown: suppressed
## abilities simply do not fire). The guard lives at the top of
## every effect dispatcher below, so each hook needs no change of
## its own. Gas's own arm still runs: its switch-in happens while
## the flag is still false.
static func _suppressed(field: Dictionary, mons: Array = []) -> bool:
	if not bool(field.get("abilities_suppressed", false)):
		return false
	# Showdown abilities.ts flags.cantsuppress: these abilities
	# cannot be suppressed by Neutralizing Gas, so their effects
	# still fire while the flag is up. The list is read straight
	# from abilities.ts (As One counts once here: the engine stores
	# it as "As One", not as the two Glastrier/Spectrier variants).
	# Form-change abilities (Zen Mode, Schooling, Stance Change and
	# the rest) are not in this guard at all: form_change is never
	# guarded, so they already fire under Gas.
	for m in mons:
		var ab: String = str(m.get("ability", "")).to_lower().replace(" ", "").replace("-", "").replace("'", "")
		if ab in ["asone", "battlebond", "comatose", "disguise", "gulpmissile", "iceface", "multitype", "powerconstruct", "rkssystem", "schooling", "shieldsdown", "stancechange", "terashift", "zenmode", "zerotohero"]:
			return false
	return true


## The shared field dict carried on a mon (the controller stamps
## mon["field"] on every combatant at the start of the turn and on
## the attacker and defender of every move). Returns {} when the
## mon carries none, so the guard reads "not suppressed" instead
## of crashing.
static func _mon_field(mon: Dictionary) -> Dictionary:
	var f: Dictionary = {}
	if mon.has("field") and mon["field"] is Dictionary:
		f = mon["field"]
	return f



static func on_switch_in(mon: Dictionary, foe: Dictionary, field: Dictionary) -> Array:
	if _suppressed(field, [mon]):
		return []
	var logs: Array = _v2_on_switch_in(mon, foe, field)
	logs.append_array(AbilityBatch1.on_switch_in(mon, foe, field))
	logs.append_array(AbilityBatch2.on_switch_in(mon, foe, field))
	logs.append_array(AbilityBatch3.on_switch_in(mon, foe, field))
	logs.append_array(AbilityBatch4.on_switch_in(mon, foe, field))
	return logs

## Teraform Zero, at the moment of Terastallization. Called by
## the controller right after a real Terastallization (see
## _apply_gimmick in battle_controller.gd). Only batch 4 owns
## this ability.
static func on_terastallize(mon: Dictionary, field: Dictionary) -> Array:
	return AbilityBatch4.on_terastallize(mon, field)

## Tailwind-start effects (Wind Power Charge, Wind Rider
## Attack). Called by the controller when Tailwind begins on a
## side, once per living mon on that side. Only batch 4 owns
## these abilities.
static func on_tailwind_start(mon: Dictionary, field: Dictionary) -> Array:
	return AbilityBatch4.on_tailwind_start(mon, field)

## Switch-in under an active Tailwind (Wind Rider Attack only;
## Wind Power has no switch-in effect in Showdown). Called by
## the controller at each switch-in site when the side's
## Tailwind is up. Only batch 4 owns this ability.
static func on_tailwind_switch_in(mon: Dictionary, field: Dictionary) -> Array:
	return AbilityBatch4.on_tailwind_switch_in(mon, field)


static func on_switch_out(mon: Dictionary, field: Dictionary = {}) -> void:
	if _suppressed(field, [mon]):
		# Confusion is volatile, not an ability, so it still ends
		# when the mon leaves, even under Gas.
		mon["confused"] = false
		mon["confusion_turns"] = 0
		return
	_v2_on_switch_out(mon)
	AbilityBatch1.on_switch_out(mon)
	AbilityBatch2.on_switch_out(mon)
	AbilityBatch3.on_switch_out(mon)
	AbilityBatch4.on_switch_out(mon)

## True when this move ignores the defender's ability. Showdown
## Mold Breaker, Teravolt and Turboblaze set move.ignoreAbility
## in onModifyMove; the batch before_move arms copy that into
## move["ignore_ability"] (Mold Breaker also sets
## attacker["ignore_ability"]). The attacker ability name is
## checked too, so direct calls that never ran before_move
## (Struggle, and tests that call the hooks by hand) still work.
## This is the one place that knows the rule: is_immune_by_ability,
## modify_damage, blocks_stat_change and _apply_stages all read it.
static func move_ignores_ability(attacker: Dictionary, move: Dictionary) -> bool:
	if bool(move.get("ignore_ability", false)):
		return true
	if bool(attacker.get("ignore_ability", false)):
		return true
	var ab: String = str(attacker.get("ability", ""))
	return ab == "Mold Breaker" or ab == "Teravolt" or ab == "Turboblaze"


## Batch arms run first, the old v2 check last. The v2 check
## used to run first and return true at once, so the batch arms
## were never reached for Volt Absorb, Water Absorb, Lightning
## Rod, Motor Drive, Storm Drain, Sap Sipper and Well-Baked
## Body, and their heals and stat boosts never fired. Every v2
## case is either also a batch arm (Flash Fire, Dry Skin, Sap
## Sipper) or still reached as the fallback (Levitate, Wonder
## Guard). Mold Breaker, Teravolt and Turboblaze ignore all
## ability immunities (all three are breakable in Showdown).
static func is_immune_by_ability(defender: Dictionary, move_type: String, attacker_ability: String = "", effectiveness: float = 1.0, move: Dictionary = {}) -> bool:
	if _suppressed(_mon_field(defender), [defender]):
		return false
	if attacker_ability == "Mold Breaker" or attacker_ability == "Teravolt" or attacker_ability == "Turboblaze" or bool(move.get("ignore_ability", false)):
		return false
	# Gravity grounds a Levitate Pokemon: while Gravity is up
	# (the defender's field state says so), Levitate gives no
	# immunity to Ground moves. Levitate only ever immunizes
	# Ground, so returning false here is the whole rule.
	if move_type.to_lower() == "ground" and str(defender.get("ability", "")) == "Levitate":
		if int(_mon_field(defender).get("gravity", 0)) > 0:
			return false

	if AbilityBatch1.is_immune(defender, move_type, attacker_ability, effectiveness):
		return true
	if AbilityBatch2.is_immune(defender, move_type, attacker_ability, effectiveness):
		return true
	if AbilityBatch3.is_immune(defender, move_type, attacker_ability, effectiveness):
		return true
	if AbilityBatch4.is_immune(defender, move_type, attacker_ability, effectiveness):
		return true
	if _v2_is_immune_by_ability(defender, move_type, attacker_ability, effectiveness):
		return true
	return false


static func modify_damage(attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int, is_stab: bool, is_crit: bool = false, effectiveness: float = 1.0) -> int:
	if _suppressed(_mon_field(attacker), [attacker, defender]):
		return base_dmg
	# When the move ignores abilities, the defender's ability is
	# not read anywhere below: the damage code gets a defender
	# copy with no ability, and the Sturdy re-cap reads the same
	# copy. The attacker's ability is kept, so attacker-side arms
	# still fire. No copy is made otherwise, so Disguise and Ice
	# Face mutations still land on the real defender.
	var def_for_damage: Dictionary = defender
	if move_ignores_ability(attacker, move):
		def_for_damage = defender.duplicate()
		def_for_damage["ability"] = ""
	var dmg: int = _v2_modify_damage(attacker, def_for_damage, move, base_dmg, is_stab, is_crit, effectiveness)
	if dmg <= 0:
		return dmg
	var mult: float = 1.0
	mult *= AbilityBatch1.damage_mult(attacker, def_for_damage, move, is_stab, is_crit, effectiveness)
	mult *= AbilityBatch2.damage_mult(attacker, def_for_damage, move, is_stab, is_crit, effectiveness)
	mult *= AbilityBatch3.damage_mult(attacker, def_for_damage, move, is_stab, is_crit, effectiveness)
	mult *= AbilityBatch4.damage_mult(attacker, def_for_damage, move, is_stab, is_crit, effectiveness)
	dmg = int(max(1, round(float(dmg) * mult)))
	# Re-apply the Sturdy cap after batch multipliers.
	var d_ab: String = str(def_for_damage.get("ability", ""))
	var a_ab: String = str(attacker.get("ability", ""))
	if d_ab == "Sturdy" and a_ab != "Mold Breaker" and int(defender.get("hp", 0)) == int(defender.get("max_hp", 1)) and dmg >= int(defender.get("hp", 1)):
		dmg = int(defender.get("hp", 1)) - 1
	return dmg


static func on_end_of_turn(mon: Dictionary, field: Dictionary, logs: Array) -> void:
	if _suppressed(field, [mon]):
		return
	var hp_before: int = int(mon.get("hp", 0))
	var logs_before: int = logs.size()
	_v2_on_end_of_turn(mon, field, logs)
	AbilityBatch1.end_of_turn(mon, field, logs)
	AbilityBatch2.end_of_turn(mon, field, logs)
	AbilityBatch3.end_of_turn(mon, field, logs)
	AbilityBatch4.end_of_turn(mon, field, logs)
	# Heal Block blocks end-of-turn ability healing (Rain Dish,
	# Ice Body, Dry Skin in rain, Poison Heal and the like),
	# from either source: the Heal Block move's counter or
	# Psychic Noise's own 2-turn counter (both keys checked
	# inline here, the same rule as the other heal gates). The
	# heal arms live in the batch files, so the block is applied
	# here at the shared entry point: any HP the hooks gained is
	# taken back and their "restored HP" lines are dropped.
	# Damage and other effects from the same hooks still stand.
	# Cud Chew is left alone: it re-eats a Berry, and Heal Block
	# does not gate Berry eating in this engine.
	if int(mon.get("hp", 0)) > hp_before and str(mon.get("ability", "")) != "Cud Chew" and (int(mon.get("heal_block_turns", 0)) > 0 or int(mon.get("noise_heal_block_turns", 0)) > 0):
		mon["hp"] = hp_before
		var kept_logs: Array = []
		for li in range(logs.size()):
			if li >= logs_before and str(logs[li]).contains("restored HP with"):
				continue
			kept_logs.append(logs[li])
		logs.clear()
		logs.append_array(kept_logs)
		logs.append("%s is prevented from healing by Heal Block!" % mon.get("name", "Pokémon"))

static func on_damage_taken(defender: Dictionary, attacker: Dictionary, move: Dictionary, damage: int, logs: Array) -> void:
	if _suppressed(_mon_field(defender), [defender, attacker]):
		return
	_v2_on_damage_taken(defender, attacker, move, damage, logs)
	AbilityBatch1.on_damage_taken(defender, attacker, move, damage, logs)
	AbilityBatch2.on_damage_taken(defender, attacker, move, damage, logs)
	AbilityBatch3.on_damage_taken(defender, attacker, move, damage, logs)
	AbilityBatch4.on_damage_taken(defender, attacker, move, damage, logs)

static func get_speed_multiplier(mon: Dictionary, field: Dictionary) -> float:
	if _suppressed(field, [mon]):
		return 1.0
	var mult: float = _v2_get_speed_multiplier(mon, field)
	mult *= AbilityBatch2.speed_mult(mon, field)
	mult *= AbilityBatch3.speed_mult(mon, field)
	return mult

static func blocks_status(mon: Dictionary, status: String, field: Dictionary = {}, source: Dictionary = {}) -> bool:
	if _suppressed(field, [mon]):
		return false
	if _v2_blocks_status(mon, status):
		return true
	if AbilityBatch1.blocks_status(mon, status, field, source):
		return true
	if AbilityBatch2.blocks_status(mon, status, field, source):
		return true
	if AbilityBatch3.blocks_status(mon, status, field, source):
		return true
	if AbilityBatch4.blocks_status(mon, status, field, source):
		return true
	return false

## Side priority block, for doubles. Dazzling, Queenly Majesty
## and Armor Tail protect the holder's WHOLE side: a foe's
## priority move fails against any Pokemon on that side. The
## controller's doubles damage pass calls this once per foe
## target, because damaging moves never get a per-target
## on_before_move call there (in singles they do, and the
## batches' own checks cover it). The move's final priority
## counts, ability boosts included (a Prankster status move
## at +1 is blocked; a plain move is not). A move that
## ignores abilities is never blocked. side_mons is every
## active mon on the target's side.
static func side_priority_block(attacker: Dictionary, move: Dictionary, side_mons: Array, field: Dictionary, logs: Array) -> bool:
	if _suppressed(field, side_mons):
		return false
	if move_ignores_ability(attacker, move):
		return false
	var prio: int = int(move.get("priority", 0)) + priority_bonus(attacker, move)
	if prio <= 0:
		return false
	if str(move.get("target", "normal")).to_lower() == "foeside":
		return false
	for mon in side_mons:
		if int(mon.get("hp", 0)) <= 0:
			continue
		var ab: String = str(mon.get("ability", ""))
		if ab == "Dazzling" or ab == "Queenly Majesty" or ab == "Armor Tail":
			logs.append("%s's %s blocked the priority move!" % [str(mon.get("name", "Pokémon")), ab])
			return true
	return false

static func on_before_move(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary, logs: Array) -> Dictionary:
	if _suppressed(field, [attacker, defender]):
		return move
	var result: Dictionary = _v2_on_before_move(attacker, defender, move, field, logs)
	for batch_result in [
		AbilityBatch1.before_move(attacker, defender, move, field, logs),
		AbilityBatch2.before_move(attacker, defender, move, field, logs),
		AbilityBatch3.before_move(attacker, defender, move, field, logs),
		AbilityBatch4.before_move(attacker, defender, move, field, logs),
	]:
		for key in batch_result:
			if key == "skip" and bool(batch_result[key]):
				result["skip"] = true
			elif key != "skip":
				result[key] = batch_result[key]
	return result


static func power_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	if _suppressed(field, [attacker, defender]):
		return 1.0
	var mult: float = 1.0
	mult *= AbilityBatch1.power_mult(attacker, defender, move, field)
	mult *= AbilityBatch2.power_mult(attacker, defender, move, field)
	mult *= AbilityBatch3.power_mult(attacker, defender, move, field)
	mult *= AbilityBatch4.power_mult(attacker, defender, move, field)
	return mult

static func accuracy_mult(attacker: Dictionary, defender: Dictionary, move: Dictionary, field: Dictionary) -> float:
	if _suppressed(field, [attacker, defender]):
		return 1.0
	var mult: float = 1.0
	mult *= AbilityBatch1.accuracy_mult(attacker, defender, move, field)
	mult *= AbilityBatch2.accuracy_mult(attacker, defender, move, field)
	mult *= AbilityBatch3.accuracy_mult(attacker, defender, move, field)
	mult *= AbilityBatch4.accuracy_mult(attacker, defender, move, field)
	return mult

static func crit_stage(attacker: Dictionary, move: Dictionary, defender: Dictionary = {}) -> int:
	if _suppressed(_mon_field(attacker), [attacker, defender]):
		return 0
	var total: int = 0
	total += AbilityBatch2.crit_stage(attacker, move, defender)
	total += AbilityBatch4.crit_stage(attacker, move, defender)
	return total

static func priority_bonus(attacker: Dictionary, move: Dictionary) -> int:
	if _suppressed(_mon_field(attacker), [attacker]):
		return 0
	var total: int = 0
	total += AbilityBatch2.priority_bonus(attacker, move)
	total += AbilityBatch3.priority_bonus(attacker, move)
	total += AbilityBatch4.priority_bonus(attacker, move)
	return total

static func move_type(attacker: Dictionary, move: Dictionary, field: Dictionary) -> String:
	if _suppressed(field, [attacker]):
		return ""
	var r1: String = AbilityBatch1.move_type(attacker, move, field)
	if r1 != "":
		return r1
	var r2: String = AbilityBatch2.move_type(attacker, move, field)
	if r2 != "":
		return r2
	var r3: String = AbilityBatch3.move_type(attacker, move, field)
	if r3 != "":
		return r3
	return ""

static func blocks_stat_change(mon: Dictionary, stat_key: String, amount: int, source: Dictionary = {}, move: Dictionary = {}) -> bool:
	if _suppressed(_mon_field(mon), [mon]):
		return false
	if not source.is_empty() and not move.is_empty() and move_ignores_ability(source, move):
		return false
	if AbilityBatch1.blocks_stat_change(mon, stat_key, amount, source):
		return true
	if AbilityBatch2.blocks_stat_change(mon, stat_key, amount, source):
		return true
	if AbilityBatch3.blocks_stat_change(mon, stat_key, amount, source):
		return true
	if AbilityBatch4.blocks_stat_change(mon, stat_key, amount, source):
		return true
	return false



## Fractional priority. Quick Draw adds +0.1 (30% chance, attacking
## moves only). Mycelium Might (-0.1) and Stall (+0.1) are NOT built;
## they are out of scope for this spec, so Batch2 and Batch4 return 0.0.
static func frac_priority(attacker: Dictionary, move: Dictionary) -> float:
	if _suppressed(_mon_field(attacker), [attacker]):
		return 0.0
	var bonus: float = 0.0
	bonus += AbilityBatch2.frac_priority(attacker, move)
	bonus += AbilityBatch3.frac_priority(attacker, move)
	bonus += AbilityBatch4.frac_priority(attacker, move)
	return bonus

## True when an ability blocks indirect (non-move) damage on this mon.
## Showdown Magic Guard onDamage: effect.effectType !== "Move" is
## blocked. Move recoil, confusion self-hit and Struggle recoil are
## Move effects and are NOT blocked; Life Orb recoil, Rough Skin,
## Iron Barbs and Aftermath damage ARE blocked.
static func blocks_indirect_damage(mon: Dictionary) -> bool:
	if _suppressed(_mon_field(mon), [mon]):
		return false
	return AbilityBatch2.blocks_indirect_damage(mon)

## True when the holder takes no damage from the current weather at
## the end of the turn. Showdown abilities.ts onImmunity: sandstorm
## is blocked by Overcoat, Sand Force, Sand Rush and Sand Veil;
## hail is blocked by Overcoat and Snow Cloak. Ground, Rock and
## Steel types are already safe in sand and Ice types already safe
## in hail in the games, but this helper only answers for abilities:
## the caller still checks types. Snow deals no damage in Gen 9
## (hail was replaced by snow, and the damage was removed), so the
## snow arm below is never reached today; it is here so a future
## hail weather cannot hurt these holders. Magic Guard is NOT
## checked here: the caller already skips all end-of-turn damage
## for Magic Guard holders, so checking it again would double-count.
## "weather" is the field weather word: "sand", "snow", "hail".
static func is_immune_to_weather_damage(mon: Dictionary, weather: String) -> bool:
	var ab: String = str(mon.get("ability", ""))
	var w: String = weather.to_lower()
	if w == "sand" or w == "sandstorm":
		return ab == "Overcoat" or ab == "Sand Force" or ab == "Sand Rush" or ab == "Sand Veil"
	if w == "snow" or w == "hail" or w == "snowscape":
		return ab == "Overcoat" or ab == "Snow Cloak"
	return false


## True when the mon's ability lets it poison a Steel or Poison type.
## Showdown Corrosion is implemented in sim/pokemon.ts setStatus:
## the type immunity to PSN/TOX is skipped when the source has
## Corrosion. Only the PSN/TOX immunity is covered here.
static func bypasses_poison_type_immunity(mon: Dictionary) -> bool:
	if _suppressed(_mon_field(mon), [mon]):
		return false
	return AbilityBatch1.bypasses_poison_type_immunity(mon)

## How many sleep turns one failed attempt costs this mon. Normal sleep
## costs 1; Early Bird costs 2 (Showdown conditions.ts slp onBeforeMove
## decrements time an extra time when the mon has Early Bird).
static func sleep_tick(mon: Dictionary) -> int:
	if _suppressed(_mon_field(mon), [mon]):
		return 1
	return AbilityBatch1.sleep_tick(mon)

## Field-effect duration for a move used by this mon. Persistent adds
## +2 turns (Showdown moves.ts durationCallback: Tailwind 4 -> 6,
## Trick Room 5 -> 7, Gravity 5 -> 7, Safeguard 5 -> 7, Wonder Room
## 5 -> 7, Magic Room 5 -> 7, Heal Block 5 -> 7).
static func field_duration(mon: Dictionary, effect_id: String, base_turns: int) -> int:
	if _suppressed(_mon_field(mon), [mon]):
		return base_turns
	return AbilityBatch3.field_duration(mon, effect_id, base_turns)

## True when an ability stops this mon's item being taken. Showdown
## Sticky Hold onTakeItem: blocked when the mon has HP, its item is
## not Sticky Barb, and either the source is a different mon or the
## move is Knock Off (Knock Off calls takeItem with no source).
static func blocks_take_item(mon: Dictionary, source: Dictionary, move: Dictionary) -> bool:
	if _suppressed(_mon_field(mon), [mon]):
		return false
	return AbilityBatch4.blocks_take_item(mon, source, move)

## True when an ability stops this mon being dragged out by a forced
## switch. Showdown Suction Cups onDragOut returns null; Guard Dog
## has the same immunity in Showdown (and the Intimidate Attack
## answer, which is still missing - see its ABILITY_INFO note).
static func blocks_drag_out(mon: Dictionary, source: Dictionary = {}) -> bool:
	if _suppressed(_mon_field(mon), [mon]):
		return false
	if AbilityBatch2.blocks_drag_out(mon, source):
		return true
	if AbilityBatch4.blocks_drag_out(mon, source):
		return true
	return false

## Mirror Armor bounce. Called by a stat-change caller BEFORE applying
## a foe-caused drop: if it returns true the drop was bounced onto the
## source and the caller must not apply it to the holder. Showdown
## Mirror Armor onTryBoost: only negative stages bounce, per stat,
## respecting the holder's -6 floor; the source's own blocks_stat_change
## is respected, so a Clear Body source keeps its stages. That check
## lives HERE in the dispatcher, not inside Batch2: a batch file can
## only see its own batch's blocks_stat_change, and Clear Body lives
## in Batch1 and White Smoke in Batch4. When the source blocks it the
## drop fizzles entirely (it was already taken off the holder), so
## return true without delegating to Batch2.
static func try_mirror_armor(mon: Dictionary, stat_key: String, amount: int, source: Dictionary, logs: Array) -> bool:
	if _suppressed(_mon_field(mon), [mon]):
		return false
	if amount >= 0:
		return false
	if str(mon.get("ability", "")) != "Mirror Armor":
		return false
	if source.is_empty():
		return false
	if blocks_stat_change(source, stat_key.to_lower(), amount, mon):
		logs.append("%s's Mirror Armor bounced the %s drop, but it had no effect!" % [str(mon.get("name", "Pokémon")), stat_key.to_lower()])
		return true
	return AbilityBatch2.try_mirror_armor(mon, stat_key, amount, source, logs)

## True when an ability stops this mon flinching. Showdown Inner Focus
## onTryAddVolatile flinch returns null.
static func blocks_flinch(mon: Dictionary) -> bool:
	if _suppressed(_mon_field(mon), [mon]):
		return false
	return AbilityBatch2.blocks_flinch(mon)

## Fires after a status was set on target by source. Poison Puppeteer
## confuses the target; Synchronize passes BRN/PAR/PSN/TOX back to the
## source. The hook cannot tell a move-caused status from an
## ability-caused one (the engine has no effect id), but in practice
## only Pecharunt has Poison Puppeteer and its only poison sources are
## moves. Batch on_damage_taken status setters do not go through
## try_set_status, so this hook does not fire for those.
static func on_after_set_status(target: Dictionary, source: Dictionary, status: String, field: Dictionary, logs: Array) -> void:
	if _suppressed(field, [target, source]):
		return
	AbilityBatch3.on_after_set_status(target, source, status, field, logs)
	var pass_back: String = AbilityBatch4.synchronize_pass_back(target, source, status)
	if pass_back != "":
		logs.append("Synchronize passed %s back!" % pass_back)
		if not source.is_empty():
			try_set_status(source, pass_back, target, field, logs)

## The one choke point for every status set, in Showdown setStatus
## order. Returns true when the status was set. Callers must use this
## instead of writing mon["status"] directly, so blocks_status,
## Corrosion, sleep_turns, toxic_counter and on_after_set_status all
## fire. The quiet flag skips the generic log line (the _v2 contact
## abilities keep their own specific lines). NOTE: this changes one
## behaviour on purpose - a Steel or Poison type can no longer be
## poisoned at all, because the PSN/TOX type immunity that Corrosion
## bypasses has to live here to be bypassable. Before this patch
## nothing in the engine checked that immunity, so Steel/Poison types
## could be poisoned by any move.
static func try_set_status(target: Dictionary, status: String, source: Dictionary, field: Dictionary, logs: Array, quiet: bool = false) -> bool:
	var st: String = status.to_upper()
	if str(target.get("status", "")) != "":
		return false
	if float(target.get("hp", 0)) <= 0.0:
		return false
	if blocks_status(target, st, field, source):
		return false
	# Safeguard: while it is up on the target's side, a foe
	# cannot give the target a status condition. The controller
	# stamps every active mon with its side ("player"/"enemy")
	# each turn; when the target's side is known and its
	# Safeguard counter is running, and the source is a
	# different mon whose side is not the target's side, the
	# status is blocked. Unstamped mons (direct calls, tests)
	# are not affected, and a mon can still status itself.
	if not source.is_empty() and source != target:
		var target_side: String = str(target.get("side", ""))
		var source_side: String = str(source.get("side", ""))
		if target_side != "" and source_side != target_side:
			var safeguard_key: String = "player_safeguard" if target_side == "player" else "enemy_safeguard"
			if int(field.get(safeguard_key, 0)) > 0:
				if not quiet:
					logs.append("%s is protected by Safeguard!" % str(target.get("name", target.get("species", "Pokemon"))))
				return false
	if (st == "PSN" or st == "TOX") and not source.is_empty() and not bypasses_poison_type_immunity(source):
		var type_list: Array = target.get("types", [])
		for t in type_list:
			# Type strings are lowercase in test mons ("steel") and
			# capitalised in the data files ("Steel"), so compare
			# without case.
			var tname: String = str(t).to_lower()
			if tname == "steel" or tname == "poison":
				return false
	# The remaining type immunities, completed beside the
	# PSN/TOX block above (code_prep_items_hooks: the Flame
	# Orb's end-of-turn burn routes through this choke point,
	# and a Fire type must not burn): Fire types cannot be
	# burned, Ice types cannot be frozen, Electric types
	# cannot be paralyzed.
	if not source.is_empty() and (st == "BRN" or st == "FRZ" or st == "PAR"):
		var immune_type: String = "fire" if st == "BRN" else ("ice" if st == "FRZ" else "electric")
		var type_list2: Array = target.get("types", [])
		for t2 in type_list2:
			if str(t2).to_lower() == immune_type:
				return false
	if st == "SLP":
		target["sleep_turns"] = randi_range(2, 4)
	if st == "TOX":
		target["toxic_counter"] = 1
	target["status"] = st
	if not quiet:
		logs.append("%s got status %s!" % [str(target.get("name", target.get("species", "Pokemon"))), st])
	on_after_set_status(target, source, st, field, logs)
	# A held cure Berry (Cheri / Pecha / Rawst / Aspear / Chesto,
	# or a Miracle Berry) answers the moment the status lands —
	# this choke point is its timing window.
	ItemEngine.on_status_set(target, field, logs)
	return true

static func on_stat_boosted(mon: Dictionary, stat_key: String, amount: int, field: Dictionary, logs: Array) -> void:
	if _suppressed(field, [mon]):
		return
	AbilityBatch1.on_stat_boosted(mon, stat_key, amount, field, logs)
	AbilityBatch2.on_stat_boosted(mon, stat_key, amount, field, logs)
	AbilityBatch3.on_stat_boosted(mon, stat_key, amount, field, logs)

static func traps_foe(trapper: Dictionary, foe: Dictionary) -> bool:
	if _suppressed(_mon_field(trapper), [trapper, foe]):
		return false
	if AbilityBatch1.traps_foe(trapper, foe):
		return true
	if AbilityBatch2.traps_foe(trapper, foe):
		return true
	if AbilityBatch3.traps_foe(trapper, foe):
		return true
	return false

static func on_flinch(mon: Dictionary, logs: Array) -> void:
	# Steadfast: Speed +1 when the holder flinches. The controller
	# calls this from the flinch branch of each move function,
	# before it clears the flinch flag, after the move is done.
	if _suppressed(_mon_field(mon), [mon]):
		return
	AbilityBatch4.on_flinch(mon, logs)

static func on_faint(fainted: Dictionary, foe: Dictionary, field: Dictionary, logs: Array, by_move: bool = true) -> void:
	if _suppressed(field, [foe]):
		return
	# Batch3 (Power of Alchemy, Receiver) fires on any ally faint,
	# so it keeps 4 args. Batch1, Batch2 and Batch4 only boost on a
	# move KO (Showdown onSourceAfterFaint), so they get by_move.
	AbilityBatch1.on_faint(fainted, foe, field, logs, by_move)
	AbilityBatch2.on_faint(fainted, foe, field, logs, by_move)
	AbilityBatch3.on_faint(fainted, foe, field, logs)
	AbilityBatch4.on_faint(fainted, foe, field, logs, by_move)

static func ally_damage_mult(ally: Dictionary, attacker: Dictionary, defender: Dictionary, move: Dictionary, base_dmg: int) -> float:
	if _suppressed(_mon_field(ally), [ally]):
		return 1.0
	var mult: float = 1.0
	mult *= AbilityBatch1.ally_damage_mult(ally, attacker, defender, move, base_dmg)
	mult *= AbilityBatch2.ally_damage_mult(ally, attacker, defender, move, base_dmg)
	mult *= AbilityBatch3.ally_damage_mult(ally, attacker, defender, move, base_dmg)
	mult *= AbilityBatch4.ally_damage_mult(ally, attacker, defender, move, base_dmg)
	return mult

static func terrain_on_switch_in(mon: Dictionary) -> String:
	var r1: String = AbilityBatch1.terrain_on_switch_in(mon)
	if r1 != "":
		return r1
	var r2: String = AbilityBatch2.terrain_on_switch_in(mon)
	if r2 != "":
		return r2
	var r3: String = AbilityBatch3.terrain_on_switch_in(mon)
	if r3 != "":
		return r3
	return ""

static func form_change(mon: Dictionary, field: Dictionary) -> String:
	var r1: String = AbilityBatch1.form_change(mon, field)
	if r1 != "":
		return r1
	var r2: String = AbilityBatch2.form_change(mon, field)
	if r2 != "":
		return r2
	var r3: String = AbilityBatch3.form_change(mon, field)
	if r3 != "":
		return r3
	var r4: String = AbilityBatch4.form_change(mon, field)
	if r4 != "":
		return r4
	return ""

static func weight_mult(mon: Dictionary) -> float:
	if _suppressed(_mon_field(mon), [mon]):
		return 1.0
	var mult: float = 1.0
	mult *= AbilityBatch2.weight_mult(mon)
	return mult

## The ally parameter is the item user's active ally (the
## Symbiosis holder candidate). It is optional with a default, so
## old calls with four arguments still work. Batch 4 has the
## Symbiosis arm; batches 1-3 only accept the parameter so the
## dispatcher can pass it through.
static func on_item_use(mon: Dictionary, item_id: String, field: Dictionary, logs: Array, ally: Dictionary = {}) -> void:
	if _suppressed(field, [mon]):
		return
	AbilityBatch1.on_item_use(mon, item_id, field, logs, ally)
	AbilityBatch2.on_item_use(mon, item_id, field, logs, ally)
	AbilityBatch3.on_item_use(mon, item_id, field, logs, ally)
	AbilityBatch4.on_item_use(mon, item_id, field, logs, ally)
