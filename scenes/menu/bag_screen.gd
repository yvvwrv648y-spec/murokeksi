class_name PUWBagScreen
extends Control
## Bag screen (MENU_AUDIT_AND_REBUILD_SPEC §3.3). Left: pocket tab
## rail with icons. Center: item rows (icon, name, xcount) at
## 64 px, full-row tappable, with the BW2 selection treatment —
## accent-tinted row fill plus a bobbing triangle cursor in the
## gutter; focus and hover are one selection state and every move
## plays ui_cursor. Right: detail panel (large icon, description,
## effect line). Bottom: context action bar (Use / Give / Toss /
## Close), all buttons >= 56 px, and under it the message strip
## every resolution reports to (show_message). Item names and
## descriptions come from the real items data
## (items_full_compact.json); quantities are the LIVE holdings
## the host hands over through bind_state()
## (PUWLiveBag.holdings_for_screen over the save state's bag —
## binding build 6, code prep code_prep_live_bag; build 3 shipped
## this screen with demo holdings because the placeholder
## overworld scene held no inventory state). An empty pocket
## shows a dim "No items." row, never a blank panel.
##
## Bound Use routes by PUWItemTarget.use_mode (code prep
## code_prep_item_target): field items (Repel family, Escape
## Rope) resolve in place through PUWLiveBag; targeted items
## (medicine, stones, candy, EV berries) ask the host for the
## party picker via bag_target_requested and the host reports
## the pick's resolution back through apply_target_result;
## party-wide items (Sacred Ash) resolve in place; anything
## else is refused in place with its reason on the message
## strip. Bound Give likewise asks for the picker. Every
## in-place resolution and every apply_target_result reports
## through bag_action_resolved exactly once and shows its
## message; a cancelled picker emits nothing and changes
## nothing.

signal close_requested
signal action_chosen(action_id: String, item_slug: String)
## Emitted when a state-bound Use / Toss resolves inside the
## bag (PUWLiveBag): the host shows the message and, for an
## Escape Rope result, performs the warp to result["target"].
signal bag_action_resolved(action_id: String, item_slug: String, result: Dictionary)
## Emitted when a bound Use or Give needs a target Pokémon:
## the host pushes the party picker (PUWPartyPickerScreen),
## resolves the pick through PUWItemTarget, and reports back
## through apply_target_result. A cancelled picker simply
## pops back; nothing was consumed.
signal bag_target_requested(action_id: String, item_slug: String)

const POCKETS: Array = ["Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Key Items"]
const ITEM_ICONS: Dictionary = {
	"ability-capsule": "res://art/icons/it_ability_capsule.png",
	"ability-patch": "res://art/icons/it_ability_patch.png",
	"ability-shield": "res://art/icons/it_ability_shield.png",
	"ability-urge": "res://art/icons/it_ability_urge.png",
	"abomasite": "res://art/icons/it_abomasite.png",
	"absolite": "res://art/icons/it_absolite.png",
	"absolite-z": "res://art/icons/it_absolite_z.png",
	"absorb-bulb": "res://art/icons/it_absorb_bulb.png",
	"acro-bike": "res://art/icons/it_acro_bike.png",
	"adamant-crystal": "res://art/icons/it_adamant_crystal.png",
	"adamant-mint": "res://art/icons/it_adamant_mint.png",
	"adamant-orb": "res://art/icons/it_adamant_orb.png",
	"adrenaline-orb": "res://art/icons/it_adrenaline_orb.png",
	"aerodactylite": "res://art/icons/it_aerodactylite.png",
	"aggronite": "res://art/icons/it_aggronite.png",
	"aguav-berry": "res://art/icons/it_aguav_berry.png",
	"air-balloon": "res://art/icons/it_air_balloon.png",
	"air-mail": "res://art/icons/it_air_mail.png",
	"alakazite": "res://art/icons/it_alakazite.png",
	"aloraichium-z--bag": "res://art/icons/it_aloraichium_z__bag.png",
	"aloraichium-z--held": "res://art/icons/it_aloraichium_z__held.png",
	"altarianite": "res://art/icons/it_altarianite.png",
	"ampharosite": "res://art/icons/it_ampharosite.png",
	"amulet-coin": "res://art/icons/it_amulet_coin.png",
	"antidote": "res://art/icons/it_antidote.png",
	"apicot-berry": "res://art/icons/it_apicot_berry.png",
	"apricorn-box": "res://art/icons/it_apricorn_box.png",
	"armor-fossil": "res://art/icons/it_armor_fossil.png",
	"aspear-berry": "res://art/icons/it_aspear_berry.png",
	"assault-vest": "res://art/icons/it_assault_vest.png",
	"audinite": "res://art/icons/it_audinite.png",
	"auroraticket": "res://art/icons/it_auroraticket.png",
	"auspicious-armor": "res://art/icons/it_auspicious_armor.png",
	"awakening": "res://art/icons/it_awakening.png",
	"azure-flute": "res://art/icons/it_azure_flute.png",
	"babiri-berry": "res://art/icons/it_babiri_berry.png",
	"balm-mushroom": "res://art/icons/it_balm_mushroom.png",
	"banettite": "res://art/icons/it_banettite.png",
	"barbaracite": "res://art/icons/it_barbaracite.png",
	"basement-key": "res://art/icons/it_basement_key.png",
	"basement-key--goldenrod": "res://art/icons/it_basement_key__goldenrod.png",
	"basement-key--new-mauville": "res://art/icons/it_basement_key__new_mauville.png",
	"baxcalibrite": "res://art/icons/it_baxcalibrite.png",
	"bead-mail": "res://art/icons/it_bead_mail.png",
	"beast-ball": "res://art/icons/it_beast_ball.png",
	"beedrillite": "res://art/icons/it_beedrillite.png",
	"belue-berry": "res://art/icons/it_belue_berry.png",
	"berry-juice": "res://art/icons/it_berry_juice.png",
	"berry-pots": "res://art/icons/it_berry_pots.png",
	"berry-pouch": "res://art/icons/it_berry_pouch.png",
	"berry-sweet": "res://art/icons/it_berry_sweet.png",
	"bicycle": "res://art/icons/it_bicycle.png",
	"big-bamboo-shoot": "res://art/icons/it_big_bamboo_shoot.png",
	"big-malasada": "res://art/icons/it_big_malasada.png",
	"big-mushroom": "res://art/icons/it_big_mushroom.png",
	"big-nugget": "res://art/icons/it_big_nugget.png",
	"big-pearl": "res://art/icons/it_big_pearl.png",
	"big-root": "res://art/icons/it_big_root.png",
	"bike-voucher": "res://art/icons/it_bike_voucher.png",
	"binding-band": "res://art/icons/it_binding_band.png",
	"bitter-herba-mystica": "res://art/icons/it_bitter_herba_mystica.png",
	"black-apricorn": "res://art/icons/it_black_apricorn.png",
	"black-augurite": "res://art/icons/it_black_augurite.png",
	"black-belt": "res://art/icons/it_black_belt.png",
	"black-flute": "res://art/icons/it_black_flute.png",
	"black-glasses": "res://art/icons/it_black_glasses.png",
	"black-mane-hair": "res://art/icons/it_black_mane_hair.png",
	"black-sludge": "res://art/icons/it_black_sludge.png",
	"blank-plate": "res://art/icons/it_blank_plate.png",
	"blastoisinite": "res://art/icons/it_blastoisinite.png",
	"blazikenite": "res://art/icons/it_blazikenite.png",
	"bloom-mail": "res://art/icons/it_bloom_mail.png",
	"blue-apricorn": "res://art/icons/it_blue_apricorn.png",
	"blue-card": "res://art/icons/it_blue_card.png",
	"blue-flute": "res://art/icons/it_blue_flute.png",
	"blue-orb": "res://art/icons/it_blue_orb.png",
	"blue-petal": "res://art/icons/it_blue_petal.png",
	"blue-scarf": "res://art/icons/it_blue_scarf.png",
	"blue-shard": "res://art/icons/it_blue_shard.png",
	"bluk-berry": "res://art/icons/it_bluk_berry.png",
	"blunder-policy": "res://art/icons/it_blunder_policy.png",
	"bold-mint": "res://art/icons/it_bold_mint.png",
	"booster-energy": "res://art/icons/it_booster_energy.png",
	"bottle-cap": "res://art/icons/it_bottle_cap.png",
	"brave-mint": "res://art/icons/it_brave_mint.png",
	"brick-mail": "res://art/icons/it_brick_mail.png",
	"bridge-mail-d": "res://art/icons/it_bridge_mail_d.png",
	"bridge-mail-m": "res://art/icons/it_bridge_mail_m.png",
	"bridge-mail-s": "res://art/icons/it_bridge_mail_s.png",
	"bridge-mail-t": "res://art/icons/it_bridge_mail_t.png",
	"bridge-mail-v": "res://art/icons/it_bridge_mail_v.png",
	"bright-powder": "res://art/icons/it_bright_powder.png",
	"bubble-mail": "res://art/icons/it_bubble_mail.png",
	"bug-gem": "res://art/icons/it_bug_gem.png",
	"bug-memory": "res://art/icons/it_bug_memory.png",
	"buginium-z--bag": "res://art/icons/it_buginium_z__bag.png",
	"buginium-z--held": "res://art/icons/it_buginium_z__held.png",
	"burn-drive": "res://art/icons/it_burn_drive.png",
	"burn-heal": "res://art/icons/it_burn_heal.png",
	"calcium": "res://art/icons/it_calcium.png",
	"calm-mint": "res://art/icons/it_calm_mint.png",
	"cameruptite": "res://art/icons/it_cameruptite.png",
	"carbos": "res://art/icons/it_carbos.png",
	"card-key": "res://art/icons/it_card_key.png",
	"card-key--letsgo": "res://art/icons/it_card_key__letsgo.png",
	"careful-mint": "res://art/icons/it_careful_mint.png",
	"casteliacone": "res://art/icons/it_casteliacone.png",
	"catching-charm": "res://art/icons/it_catching_charm.png",
	"cell-battery": "res://art/icons/it_cell_battery.png",
	"chandelurite": "res://art/icons/it_chandelurite.png",
	"charcoal": "res://art/icons/it_charcoal.png",
	"charizardite-x": "res://art/icons/it_charizardite_x.png",
	"charizardite-y": "res://art/icons/it_charizardite_y.png",
	"charti-berry": "res://art/icons/it_charti_berry.png",
	"cheri-berry": "res://art/icons/it_cheri_berry.png",
	"cherish-ball": "res://art/icons/it_cherish_ball.png",
	"chesnaughtite": "res://art/icons/it_chesnaughtite.png",
	"chesto-berry": "res://art/icons/it_chesto_berry.png",
	"chilan-berry": "res://art/icons/it_chilan_berry.png",
	"chill-drive": "res://art/icons/it_chill_drive.png",
	"chimechite": "res://art/icons/it_chimechite.png",
	"chipped-pot": "res://art/icons/it_chipped_pot.png",
	"choice-band": "res://art/icons/it_choice_band.png",
	"choice-scarf": "res://art/icons/it_choice_scarf.png",
	"choice-specs": "res://art/icons/it_choice_specs.png",
	"chople-berry": "res://art/icons/it_chople_berry.png",
	"claw-fossil": "res://art/icons/it_claw_fossil.png",
	"cleanse-tag": "res://art/icons/it_cleanse_tag.png",
	"clear-amulet": "res://art/icons/it_clear_amulet.png",
	"clear-bell": "res://art/icons/it_clear_bell.png",
	"clefablite": "res://art/icons/it_clefablite.png",
	"clever-mochi": "res://art/icons/it_clever_mochi.png",
	"clever-wing": "res://art/icons/it_clever_wing.png",
	"clover-sweet": "res://art/icons/it_clover_sweet.png",
	"coba-berry": "res://art/icons/it_coba_berry.png",
	"coin-case": "res://art/icons/it_coin_case.png",
	"colbur-berry": "res://art/icons/it_colbur_berry.png",
	"comet-shard": "res://art/icons/it_comet_shard.png",
	"contest-pass": "res://art/icons/it_contest_pass.png",
	"cornerstone-mask": "res://art/icons/it_cornerstone_mask.png",
	"cornn-berry": "res://art/icons/it_cornn_berry.png",
	"coupon-1": "res://art/icons/it_coupon_1.png",
	"coupon-2": "res://art/icons/it_coupon_2.png",
	"coupon-3": "res://art/icons/it_coupon_3.png",
	"cover-fossil": "res://art/icons/it_cover_fossil.png",
	"covert-cloak": "res://art/icons/it_covert_cloak.png",
	"crabominite": "res://art/icons/it_crabominite.png",
	"cracked-pot": "res://art/icons/it_cracked_pot.png",
	"custap-berry": "res://art/icons/it_custap_berry.png",
	"damp-mulch": "res://art/icons/it_damp_mulch.png",
	"damp-rock": "res://art/icons/it_damp_rock.png",
	"dark-gem": "res://art/icons/it_dark_gem.png",
	"dark-memory": "res://art/icons/it_dark_memory.png",
	"dark-stone": "res://art/icons/it_dark_stone.png",
	"darkinium-z--bag": "res://art/icons/it_darkinium_z__bag.png",
	"darkinium-z--held": "res://art/icons/it_darkinium_z__held.png",
	"darkranite": "res://art/icons/it_darkranite.png",
	"dawn-stone": "res://art/icons/it_dawn_stone.png",
	"decidium-z--bag": "res://art/icons/it_decidium_z__bag.png",
	"decidium-z--held": "res://art/icons/it_decidium_z__held.png",
	"deep-sea-scale": "res://art/icons/it_deep_sea_scale.png",
	"deep-sea-tooth": "res://art/icons/it_deep_sea_tooth.png",
	"delphoxite": "res://art/icons/it_delphoxite.png",
	"destiny-knot": "res://art/icons/it_destiny_knot.png",
	"devon-goods": "res://art/icons/it_devon_goods.png",
	"devon-scope": "res://art/icons/it_devon_scope.png",
	"diancite": "res://art/icons/it_diancite.png",
	"dire-hit": "res://art/icons/it_dire_hit.png",
	"dire-hit-2": "res://art/icons/it_dire_hit_2.png",
	"dire-hit-3": "res://art/icons/it_dire_hit_3.png",
	"dive-ball": "res://art/icons/it_dive_ball.png",
	"dna-splicers": "res://art/icons/it_dna_splicers.png",
	"dna-splicers--merge": "res://art/icons/it_dna_splicers__merge.png",
	"dna-splicers--split": "res://art/icons/it_dna_splicers__split.png",
	"dome-fossil": "res://art/icons/it_dome_fossil.png",
	"douse-drive": "res://art/icons/it_douse_drive.png",
	"dowsing-machine": "res://art/icons/it_dowsing_machine.png",
	"draco-plate": "res://art/icons/it_draco_plate.png",
	"dragalgite": "res://art/icons/it_dragalgite.png",
	"dragon-fang": "res://art/icons/it_dragon_fang.png",
	"dragon-gem": "res://art/icons/it_dragon_gem.png",
	"dragon-memory": "res://art/icons/it_dragon_memory.png",
	"dragon-scale": "res://art/icons/it_dragon_scale.png",
	"dragon-skull": "res://art/icons/it_dragon_skull.png",
	"dragoninite": "res://art/icons/it_dragoninite.png",
	"dragonium-z--bag": "res://art/icons/it_dragonium_z__bag.png",
	"dragonium-z--held": "res://art/icons/it_dragonium_z__held.png",
	"drampanite": "res://art/icons/it_drampanite.png",
	"dread-plate": "res://art/icons/it_dread_plate.png",
	"dream-ball": "res://art/icons/it_dream_ball.png",
	"dream-mail": "res://art/icons/it_dream_mail.png",
	"dubious-disc": "res://art/icons/it_dubious_disc.png",
	"durin-berry": "res://art/icons/it_durin_berry.png",
	"dusk-ball": "res://art/icons/it_dusk_ball.png",
	"dusk-stone": "res://art/icons/it_dusk_stone.png",
	"earth-plate": "res://art/icons/it_earth_plate.png",
	"eelektrossite": "res://art/icons/it_eelektrossite.png",
	"eevium-z--bag": "res://art/icons/it_eevium_z__bag.png",
	"eevium-z--held": "res://art/icons/it_eevium_z__held.png",
	"eject-button": "res://art/icons/it_eject_button.png",
	"eject-pack": "res://art/icons/it_eject_pack.png",
	"electirizer": "res://art/icons/it_electirizer.png",
	"electric-gem": "res://art/icons/it_electric_gem.png",
	"electric-memory": "res://art/icons/it_electric_memory.png",
	"electric-seed": "res://art/icons/it_electric_seed.png",
	"electrium-z--bag": "res://art/icons/it_electrium_z__bag.png",
	"electrium-z--held": "res://art/icons/it_electrium_z__held.png",
	"elixir": "res://art/icons/it_elixir.png",
	"emboarite": "res://art/icons/it_emboarite.png",
	"energy-powder": "res://art/icons/it_energy_powder.png",
	"energy-root": "res://art/icons/it_energy_root.png",
	"enigma-berry": "res://art/icons/it_enigma_berry.png",
	"enigma-stone": "res://art/icons/it_enigma_stone.png",
	"eon-ticket": "res://art/icons/it_eon_ticket.png",
	"escape-rope": "res://art/icons/it_escape_rope.png",
	"ether": "res://art/icons/it_ether.png",
	"everstone": "res://art/icons/it_everstone.png",
	"eviolite": "res://art/icons/it_eviolite.png",
	"excadrite": "res://art/icons/it_excadrite.png",
	"exp-candy-l": "res://art/icons/it_exp_candy_l.png",
	"exp-candy-m": "res://art/icons/it_exp_candy_m.png",
	"exp-candy-s": "res://art/icons/it_exp_candy_s.png",
	"exp-candy-xl": "res://art/icons/it_exp_candy_xl.png",
	"exp-candy-xs": "res://art/icons/it_exp_candy_xs.png",
	"exp-charm": "res://art/icons/it_exp_charm.png",
	"exp-share": "res://art/icons/it_exp_share.png",
	"expert-belt": "res://art/icons/it_expert_belt.png",
	"explorer-kit": "res://art/icons/it_explorer_kit.png",
	"fab-mail": "res://art/icons/it_fab_mail.png",
	"fairium-z--bag": "res://art/icons/it_fairium_z__bag.png",
	"fairium-z--held": "res://art/icons/it_fairium_z__held.png",
	"fairy-feather": "res://art/icons/it_fairy_feather.png",
	"fairy-gem": "res://art/icons/it_fairy_gem.png",
	"fairy-memory": "res://art/icons/it_fairy_memory.png",
	"falinksite": "res://art/icons/it_falinksite.png",
	"fame-checker": "res://art/icons/it_fame_checker.png",
	"fashion-case": "res://art/icons/it_fashion_case.png",
	"fast-ball": "res://art/icons/it_fast_ball.png",
	"favored-mail": "res://art/icons/it_favored_mail.png",
	"feraligite": "res://art/icons/it_feraligite.png",
	"fighting-gem": "res://art/icons/it_fighting_gem.png",
	"fighting-memory": "res://art/icons/it_fighting_memory.png",
	"fightinium-z--bag": "res://art/icons/it_fightinium_z__bag.png",
	"fightinium-z--held": "res://art/icons/it_fightinium_z__held.png",
	"figy-berry": "res://art/icons/it_figy_berry.png",
	"fire-gem": "res://art/icons/it_fire_gem.png",
	"fire-memory": "res://art/icons/it_fire_memory.png",
	"fire-stone": "res://art/icons/it_fire_stone.png",
	"firium-z--bag": "res://art/icons/it_firium_z__bag.png",
	"firium-z--held": "res://art/icons/it_firium_z__held.png",
	"fist-plate": "res://art/icons/it_fist_plate.png",
	"flame-mail": "res://art/icons/it_flame_mail.png",
	"flame-orb": "res://art/icons/it_flame_orb.png",
	"flame-plate": "res://art/icons/it_flame_plate.png",
	"float-stone": "res://art/icons/it_float_stone.png",
	"floettite": "res://art/icons/it_floettite.png",
	"flower-sweet": "res://art/icons/it_flower_sweet.png",
	"fluffy-tail": "res://art/icons/it_fluffy_tail.png",
	"flying-gem": "res://art/icons/it_flying_gem.png",
	"flying-memory": "res://art/icons/it_flying_memory.png",
	"flyinium-z--bag": "res://art/icons/it_flyinium_z__bag.png",
	"flyinium-z--held": "res://art/icons/it_flyinium_z__held.png",
	"focus-band": "res://art/icons/it_focus_band.png",
	"focus-sash": "res://art/icons/it_focus_sash.png",
	"fossilized-bird": "res://art/icons/it_fossilized_bird.png",
	"fossilized-dino": "res://art/icons/it_fossilized_dino.png",
	"fossilized-drake": "res://art/icons/it_fossilized_drake.png",
	"fossilized-fish": "res://art/icons/it_fossilized_fish.png",
	"fresh-start-mochi": "res://art/icons/it_fresh_start_mochi.png",
	"fresh-water": "res://art/icons/it_fresh_water.png",
	"friend-ball": "res://art/icons/it_friend_ball.png",
	"froslassite": "res://art/icons/it_froslassite.png",
	"full-heal": "res://art/icons/it_full_heal.png",
	"full-incense": "res://art/icons/it_full_incense.png",
	"full-restore": "res://art/icons/it_full_restore.png",
	"galactic-key": "res://art/icons/it_galactic_key.png",
	"galarica-cuff": "res://art/icons/it_galarica_cuff.png",
	"galarica-wreath": "res://art/icons/it_galarica_wreath.png",
	"galladite": "res://art/icons/it_galladite.png",
	"ganlon-berry": "res://art/icons/it_ganlon_berry.png",
	"garchompite": "res://art/icons/it_garchompite.png",
	"garchompite-z": "res://art/icons/it_garchompite_z.png",
	"gardevoirite": "res://art/icons/it_gardevoirite.png",
	"gb-sounds": "res://art/icons/it_gb_sounds.png",
	"gengarite": "res://art/icons/it_gengarite.png",
	"genius-mochi": "res://art/icons/it_genius_mochi.png",
	"genius-wing": "res://art/icons/it_genius_wing.png",
	"gentle-mint": "res://art/icons/it_gentle_mint.png",
	"ghost-gem": "res://art/icons/it_ghost_gem.png",
	"ghost-memory": "res://art/icons/it_ghost_memory.png",
	"ghostium-z--bag": "res://art/icons/it_ghostium_z__bag.png",
	"ghostium-z--held": "res://art/icons/it_ghostium_z__held.png",
	"gimmighoul-coin": "res://art/icons/it_gimmighoul_coin.png",
	"glalitite": "res://art/icons/it_glalitite.png",
	"glimmoranite": "res://art/icons/it_glimmoranite.png",
	"glitter-mail": "res://art/icons/it_glitter_mail.png",
	"go-goggles": "res://art/icons/it_go_goggles.png",
	"gold-bottle-cap": "res://art/icons/it_gold_bottle_cap.png",
	"gold-teeth": "res://art/icons/it_gold_teeth.png",
	"golisopite": "res://art/icons/it_golisopite.png",
	"golurkite": "res://art/icons/it_golurkite.png",
	"good-rod": "res://art/icons/it_good_rod.png",
	"gooey-mulch": "res://art/icons/it_gooey_mulch.png",
	"gracidea": "res://art/icons/it_gracidea.png",
	"gram-1": "res://art/icons/it_gram_1.png",
	"grass-gem": "res://art/icons/it_grass_gem.png",
	"grass-mail": "res://art/icons/it_grass_mail.png",
	"grass-memory": "res://art/icons/it_grass_memory.png",
	"grassium-z--bag": "res://art/icons/it_grassium_z__bag.png",
	"grassium-z--held": "res://art/icons/it_grassium_z__held.png",
	"grassy-seed": "res://art/icons/it_grassy_seed.png",
	"great-ball": "res://art/icons/it_great_ball.png",
	"green-apricorn": "res://art/icons/it_green_apricorn.png",
	"green-petal": "res://art/icons/it_green_petal.png",
	"green-scarf": "res://art/icons/it_green_scarf.png",
	"green-shard": "res://art/icons/it_green_shard.png",
	"greet-mail": "res://art/icons/it_greet_mail.png",
	"greninjite": "res://art/icons/it_greninjite.png",
	"grepa-berry": "res://art/icons/it_grepa_berry.png",
	"grip-claw": "res://art/icons/it_grip_claw.png",
	"griseous-core": "res://art/icons/it_griseous_core.png",
	"griseous-orb": "res://art/icons/it_griseous_orb.png",
	"ground-gem": "res://art/icons/it_ground_gem.png",
	"ground-memory": "res://art/icons/it_ground_memory.png",
	"groundium-z--bag": "res://art/icons/it_groundium_z__bag.png",
	"groundium-z--held": "res://art/icons/it_groundium_z__held.png",
	"growth-mulch": "res://art/icons/it_growth_mulch.png",
	"grubby-hanky": "res://art/icons/it_grubby_hanky.png",
	"guard-spec": "res://art/icons/it_guard_spec.png",
	"gyaradosite": "res://art/icons/it_gyaradosite.png",
	"haban-berry": "res://art/icons/it_haban_berry.png",
	"harbor-mail": "res://art/icons/it_harbor_mail.png",
	"hard-stone": "res://art/icons/it_hard_stone.png",
	"hasty-mint": "res://art/icons/it_hasty_mint.png",
	"hawluchanite": "res://art/icons/it_hawluchanite.png",
	"heal-ball": "res://art/icons/it_heal_ball.png",
	"heal-powder": "res://art/icons/it_heal_powder.png",
	"health-mochi": "res://art/icons/it_health_mochi.png",
	"health-wing": "res://art/icons/it_health_wing.png",
	"heart-mail": "res://art/icons/it_heart_mail.png",
	"heart-scale": "res://art/icons/it_heart_scale.png",
	"hearthflame-mask": "res://art/icons/it_hearthflame_mask.png",
	"heat-rock": "res://art/icons/it_heat_rock.png",
	"heatranite": "res://art/icons/it_heatranite.png",
	"heavy-ball": "res://art/icons/it_heavy_ball.png",
	"heavy-duty-boots": "res://art/icons/it_heavy_duty_boots.png",
	"helix-fossil": "res://art/icons/it_helix_fossil.png",
	"heracronite": "res://art/icons/it_heracronite.png",
	"hondew-berry": "res://art/icons/it_hondew_berry.png",
	"honey": "res://art/icons/it_honey.png",
	"hopo-berry": "res://art/icons/it_hopo_berry.png",
	"houndoominite": "res://art/icons/it_houndoominite.png",
	"hp-up": "res://art/icons/it_hp_up.png",
	"hyper-potion": "res://art/icons/it_hyper_potion.png",
	"iapapa-berry": "res://art/icons/it_iapapa_berry.png",
	"ice-gem": "res://art/icons/it_ice_gem.png",
	"ice-heal": "res://art/icons/it_ice_heal.png",
	"ice-memory": "res://art/icons/it_ice_memory.png",
	"ice-stone": "res://art/icons/it_ice_stone.png",
	"iceroot-carrot": "res://art/icons/it_iceroot_carrot.png",
	"icicle-plate": "res://art/icons/it_icicle_plate.png",
	"icium-z--bag": "res://art/icons/it_icium_z__bag.png",
	"icium-z--held": "res://art/icons/it_icium_z__held.png",
	"icy-rock": "res://art/icons/it_icy_rock.png",
	"impish-mint": "res://art/icons/it_impish_mint.png",
	"incinium-z--bag": "res://art/icons/it_incinium_z__bag.png",
	"incinium-z--held": "res://art/icons/it_incinium_z__held.png",
	"inquiry-mail": "res://art/icons/it_inquiry_mail.png",
	"insect-plate": "res://art/icons/it_insect_plate.png",
	"intriguing-stone": "res://art/icons/it_intriguing_stone.png",
	"iron": "res://art/icons/it_iron.png",
	"iron-ball": "res://art/icons/it_iron_ball.png",
	"iron-plate": "res://art/icons/it_iron_plate.png",
	"item-drop": "res://art/icons/it_item_drop.png",
	"item-urge": "res://art/icons/it_item_urge.png",
	"jaboca-berry": "res://art/icons/it_jaboca_berry.png",
	"jade-orb": "res://art/icons/it_jade_orb.png",
	"jaw-fossil": "res://art/icons/it_jaw_fossil.png",
	"jolly-mint": "res://art/icons/it_jolly_mint.png",
	"journal": "res://art/icons/it_journal.png",
	"kangaskhanite": "res://art/icons/it_kangaskhanite.png",
	"kasib-berry": "res://art/icons/it_kasib_berry.png",
	"kebia-berry": "res://art/icons/it_kebia_berry.png",
	"kee-berry": "res://art/icons/it_kee_berry.png",
	"kelpsy-berry": "res://art/icons/it_kelpsy_berry.png",
	"kings-rock": "res://art/icons/it_kings_rock.png",
	"kofus-wallet": "res://art/icons/it_kofus_wallet.png",
	"kommonium-z--bag": "res://art/icons/it_kommonium_z__bag.png",
	"kommonium-z--held": "res://art/icons/it_kommonium_z__held.png",
	"lagging-tail": "res://art/icons/it_lagging_tail.png",
	"lagreat-ball": "res://art/icons/it_lagreat_ball.png",
	"laheavy-ball": "res://art/icons/it_laheavy_ball.png",
	"lansat-berry": "res://art/icons/it_lansat_berry.png",
	"lapoke-ball": "res://art/icons/it_lapoke_ball.png",
	"latiasite": "res://art/icons/it_latiasite.png",
	"latiosite": "res://art/icons/it_latiosite.png",
	"laultra-ball": "res://art/icons/it_laultra_ball.png",
	"lava-cookie": "res://art/icons/it_lava_cookie.png",
	"lax-incense": "res://art/icons/it_lax_incense.png",
	"lax-mint": "res://art/icons/it_lax_mint.png",
	"leaders-crest": "res://art/icons/it_leaders_crest.png",
	"leaf-stone": "res://art/icons/it_leaf_stone.png",
	"leek": "res://art/icons/it_leek.png",
	"leftovers": "res://art/icons/it_leftovers.png",
	"legend-plate": "res://art/icons/it_legend_plate.png",
	"lemonade": "res://art/icons/it_lemonade.png",
	"leppa-berry": "res://art/icons/it_leppa_berry.png",
	"letter": "res://art/icons/it_letter.png",
	"level-ball": "res://art/icons/it_level_ball.png",
	"liberty-pass": "res://art/icons/it_liberty_pass.png",
	"liechi-berry": "res://art/icons/it_liechi_berry.png",
	"life-orb": "res://art/icons/it_life_orb.png",
	"lift-key": "res://art/icons/it_lift_key.png",
	"light-ball": "res://art/icons/it_light_ball.png",
	"light-clay": "res://art/icons/it_light_clay.png",
	"light-stone": "res://art/icons/it_light_stone.png",
	"like-mail": "res://art/icons/it_like_mail.png",
	"linking-cord": "res://art/icons/it_linking_cord.png",
	"loaded-dice": "res://art/icons/it_loaded_dice.png",
	"lock-capsule": "res://art/icons/it_lock_capsule.png",
	"lonely-mint": "res://art/icons/it_lonely_mint.png",
	"loot-sack": "res://art/icons/it_loot_sack.png",
	"lopunnite": "res://art/icons/it_lopunnite.png",
	"lost-item": "res://art/icons/it_lost_item.png",
	"love-ball": "res://art/icons/it_love_ball.png",
	"love-sweet": "res://art/icons/it_love_sweet.png",
	"lucarionite": "res://art/icons/it_lucarionite.png",
	"lucarionite-z": "res://art/icons/it_lucarionite_z.png",
	"luck-incense": "res://art/icons/it_luck_incense.png",
	"lucky-egg": "res://art/icons/it_lucky_egg.png",
	"lucky-punch": "res://art/icons/it_lucky_punch.png",
	"lum-berry": "res://art/icons/it_lum_berry.png",
	"luminous-moss": "res://art/icons/it_luminous_moss.png",
	"lumiose-galette": "res://art/icons/it_lumiose_galette.png",
	"lunalium-z--bag": "res://art/icons/it_lunalium_z__bag.png",
	"lunalium-z--held": "res://art/icons/it_lunalium_z__held.png",
	"lunar-wing": "res://art/icons/it_lunar_wing.png",
	"lure-ball": "res://art/icons/it_lure_ball.png",
	"lustrous-globe": "res://art/icons/it_lustrous_globe.png",
	"lustrous-orb": "res://art/icons/it_lustrous_orb.png",
	"luxury-ball": "res://art/icons/it_luxury_ball.png",
	"lycanium-z--bag": "res://art/icons/it_lycanium_z__bag.png",
	"lycanium-z--held": "res://art/icons/it_lycanium_z__held.png",
	"mach-bike": "res://art/icons/it_mach_bike.png",
	"machine-part": "res://art/icons/it_machine_part.png",
	"macho-brace": "res://art/icons/it_macho_brace.png",
	"magearnite": "res://art/icons/it_magearnite.png",
	"magma-emblem": "res://art/icons/it_magma_emblem.png",
	"magma-stone": "res://art/icons/it_magma_stone.png",
	"magmarizer": "res://art/icons/it_magmarizer.png",
	"magnet": "res://art/icons/it_magnet.png",
	"mago-berry": "res://art/icons/it_mago_berry.png",
	"magost-berry": "res://art/icons/it_magost_berry.png",
	"malamarite": "res://art/icons/it_malamarite.png",
	"malicious-armor": "res://art/icons/it_malicious_armor.png",
	"manectite": "res://art/icons/it_manectite.png",
	"maranga-berry": "res://art/icons/it_maranga_berry.png",
	"marshadium-z--bag": "res://art/icons/it_marshadium_z__bag.png",
	"marshadium-z--held": "res://art/icons/it_marshadium_z__held.png",
	"master-ball": "res://art/icons/it_master_ball.png",
	"masterpiece-teacup": "res://art/icons/it_masterpiece_teacup.png",
	"mawilite": "res://art/icons/it_mawilite.png",
	"max-elixir": "res://art/icons/it_max_elixir.png",
	"max-ether": "res://art/icons/it_max_ether.png",
	"max-honey": "res://art/icons/it_max_honey.png",
	"max-mushrooms": "res://art/icons/it_max_mushrooms.png",
	"max-potion": "res://art/icons/it_max_potion.png",
	"max-repel": "res://art/icons/it_max_repel.png",
	"max-revive": "res://art/icons/it_max_revive.png",
	"meadow-plate": "res://art/icons/it_meadow_plate.png",
	"mech-mail": "res://art/icons/it_mech_mail.png",
	"medal-box": "res://art/icons/it_medal_box.png",
	"medichamite": "res://art/icons/it_medichamite.png",
	"mega-ring": "res://art/icons/it_mega_ring.png",
	"meganiumite": "res://art/icons/it_meganiumite.png",
	"meltan-candy": "res://art/icons/it_meltan_candy.png",
	"member-card": "res://art/icons/it_member_card.png",
	"mental-herb": "res://art/icons/it_mental_herb.png",
	"meowsticite": "res://art/icons/it_meowsticite.png",
	"metagrossite": "res://art/icons/it_metagrossite.png",
	"metal-alloy": "res://art/icons/it_metal_alloy.png",
	"metal-coat": "res://art/icons/it_metal_coat.png",
	"metal-powder": "res://art/icons/it_metal_powder.png",
	"meteorite": "res://art/icons/it_meteorite.png",
	"meteorite--2": "res://art/icons/it_meteorite__2.png",
	"meteorite--3": "res://art/icons/it_meteorite__3.png",
	"meteorite--4": "res://art/icons/it_meteorite__4.png",
	"metronome": "res://art/icons/it_metronome.png",
	"mewnium-z--bag": "res://art/icons/it_mewnium_z__bag.png",
	"mewnium-z--held": "res://art/icons/it_mewnium_z__held.png",
	"mewtwonite-x": "res://art/icons/it_mewtwonite_x.png",
	"mewtwonite-y": "res://art/icons/it_mewtwonite_y.png",
	"micle-berry": "res://art/icons/it_micle_berry.png",
	"mild-mint": "res://art/icons/it_mild_mint.png",
	"mimikium-z--bag": "res://art/icons/it_mimikium_z__bag.png",
	"mimikium-z--held": "res://art/icons/it_mimikium_z__held.png",
	"mind-plate": "res://art/icons/it_mind_plate.png",
	"miracle-seed": "res://art/icons/it_miracle_seed.png",
	"mirror-herb": "res://art/icons/it_mirror_herb.png",
	"misty-seed": "res://art/icons/it_misty_seed.png",
	"modest-mint": "res://art/icons/it_modest_mint.png",
	"moomoo-milk": "res://art/icons/it_moomoo_milk.png",
	"moon-ball": "res://art/icons/it_moon_ball.png",
	"moon-stone": "res://art/icons/it_moon_stone.png",
	"mosaic-mail": "res://art/icons/it_mosaic_mail.png",
	"muscle-band": "res://art/icons/it_muscle_band.png",
	"muscle-mochi": "res://art/icons/it_muscle_mochi.png",
	"muscle-wing": "res://art/icons/it_muscle_wing.png",
	"mystery-egg": "res://art/icons/it_mystery_egg.png",
	"mystic-water": "res://art/icons/it_mystic_water.png",
	"mysticticket": "res://art/icons/it_mysticticket.png",
	"n-lunarizer--merge": "res://art/icons/it_n_lunarizer__merge.png",
	"n-lunarizer--split": "res://art/icons/it_n_lunarizer__split.png",
	"n-solarizer--merge": "res://art/icons/it_n_solarizer__merge.png",
	"n-solarizer--split": "res://art/icons/it_n_solarizer__split.png",
	"naive-mint": "res://art/icons/it_naive_mint.png",
	"nanab-berry": "res://art/icons/it_nanab_berry.png",
	"naughty-mint": "res://art/icons/it_naughty_mint.png",
	"nest-ball": "res://art/icons/it_nest_ball.png",
	"net-ball": "res://art/icons/it_net_ball.png",
	"never-melt-ice": "res://art/icons/it_never_melt_ice.png",
	"nomel-berry": "res://art/icons/it_nomel_berry.png",
	"normal-gem": "res://art/icons/it_normal_gem.png",
	"normalium-z--bag": "res://art/icons/it_normalium_z__bag.png",
	"normalium-z--held": "res://art/icons/it_normalium_z__held.png",
	"nugget": "res://art/icons/it_nugget.png",
	"oaks-letter": "res://art/icons/it_oaks_letter.png",
	"oaks-parcel": "res://art/icons/it_oaks_parcel.png",
	"occa-berry": "res://art/icons/it_occa_berry.png",
	"odd-incense": "res://art/icons/it_odd_incense.png",
	"odd-keystone": "res://art/icons/it_odd_keystone.png",
	"old-amber": "res://art/icons/it_old_amber.png",
	"old-charm": "res://art/icons/it_old_charm.png",
	"old-gateau": "res://art/icons/it_old_gateau.png",
	"old-rod": "res://art/icons/it_old_rod.png",
	"old-sea-map": "res://art/icons/it_old_sea_map.png",
	"oran-berry": "res://art/icons/it_oran_berry.png",
	"orange-mail": "res://art/icons/it_orange_mail.png",
	"orange-petal": "res://art/icons/it_orange_petal.png",
	"oval-charm": "res://art/icons/it_oval_charm.png",
	"oval-stone": "res://art/icons/it_oval_stone.png",
	"pal-pad": "res://art/icons/it_pal_pad.png",
	"pamtre-berry": "res://art/icons/it_pamtre_berry.png",
	"paralyze-heal": "res://art/icons/it_paralyze_heal.png",
	"parcel": "res://art/icons/it_parcel.png",
	"parcel--letsgo": "res://art/icons/it_parcel__letsgo.png",
	"park-ball": "res://art/icons/it_park_ball.png",
	"pass": "res://art/icons/it_pass.png",
	"pass-orb": "res://art/icons/it_pass_orb.png",
	"passho-berry": "res://art/icons/it_passho_berry.png",
	"payapa-berry": "res://art/icons/it_payapa_berry.png",
	"pearl": "res://art/icons/it_pearl.png",
	"pearl-string": "res://art/icons/it_pearl_string.png",
	"peat-block": "res://art/icons/it_peat_block.png",
	"pecha-berry": "res://art/icons/it_pecha_berry.png",
	"permit": "res://art/icons/it_permit.png",
	"persim-berry": "res://art/icons/it_persim_berry.png",
	"petaya-berry": "res://art/icons/it_petaya_berry.png",
	"pewter-crunchies": "res://art/icons/it_pewter_crunchies.png",
	"pidgeotite": "res://art/icons/it_pidgeotite.png",
	"pikanium-z--bag": "res://art/icons/it_pikanium_z__bag.png",
	"pikanium-z--held": "res://art/icons/it_pikanium_z__held.png",
	"pinap-berry": "res://art/icons/it_pinap_berry.png",
	"pink-apricorn": "res://art/icons/it_pink_apricorn.png",
	"pink-nectar": "res://art/icons/it_pink_nectar.png",
	"pink-petal": "res://art/icons/it_pink_petal.png",
	"pink-scarf": "res://art/icons/it_pink_scarf.png",
	"pinsirite": "res://art/icons/it_pinsirite.png",
	"pixie-plate": "res://art/icons/it_pixie_plate.png",
	"plasma-card": "res://art/icons/it_plasma_card.png",
	"plume-fossil": "res://art/icons/it_plume_fossil.png",
	"poffin-case": "res://art/icons/it_poffin_case.png",
	"point-card": "res://art/icons/it_point_card.png",
	"poison-barb": "res://art/icons/it_poison_barb.png",
	"poison-gem": "res://art/icons/it_poison_gem.png",
	"poison-memory": "res://art/icons/it_poison_memory.png",
	"poisonium-z--bag": "res://art/icons/it_poisonium_z__bag.png",
	"poisonium-z--held": "res://art/icons/it_poisonium_z__held.png",
	"poke-ball": "res://art/icons/it_poke_ball.png",
	"poke-doll": "res://art/icons/it_poke_doll.png",
	"poke-flute": "res://art/icons/it_poke_flute.png",
	"poke-radar": "res://art/icons/it_poke_radar.png",
	"poke-toy": "res://art/icons/it_poke_toy.png",
	"pokeblock-case": "res://art/icons/it_pokeblock_case.png",
	"pokemon-box": "res://art/icons/it_pokemon_box.png",
	"pokemon-box-link": "res://art/icons/it_pokemon_box_link.png",
	"pomeg-berry": "res://art/icons/it_pomeg_berry.png",
	"potion": "res://art/icons/it_potion.png",
	"powder-jar": "res://art/icons/it_powder_jar.png",
	"power-anklet": "res://art/icons/it_power_anklet.png",
	"power-band": "res://art/icons/it_power_band.png",
	"power-belt": "res://art/icons/it_power_belt.png",
	"power-bracer": "res://art/icons/it_power_bracer.png",
	"power-herb": "res://art/icons/it_power_herb.png",
	"power-lens": "res://art/icons/it_power_lens.png",
	"power-weight": "res://art/icons/it_power_weight.png",
	"pp-max": "res://art/icons/it_pp_max.png",
	"pp-up": "res://art/icons/it_pp_up.png",
	"premier-ball": "res://art/icons/it_premier_ball.png",
	"pretty-wing": "res://art/icons/it_pretty_wing.png",
	"prettyfeather": "res://art/icons/it_prettyfeather.png",
	"primarium-z--bag": "res://art/icons/it_primarium_z__bag.png",
	"primarium-z--held": "res://art/icons/it_primarium_z__held.png",
	"prism-scale": "res://art/icons/it_prism_scale.png",
	"prison-bottle": "res://art/icons/it_prison_bottle.png",
	"prop-case": "res://art/icons/it_prop_case.png",
	"protective-pads": "res://art/icons/it_protective_pads.png",
	"protector": "res://art/icons/it_protector.png",
	"protein": "res://art/icons/it_protein.png",
	"psychic-gem": "res://art/icons/it_psychic_gem.png",
	"psychic-memory": "res://art/icons/it_psychic_memory.png",
	"psychic-seed": "res://art/icons/it_psychic_seed.png",
	"psychium-z--bag": "res://art/icons/it_psychium_z__bag.png",
	"psychium-z--held": "res://art/icons/it_psychium_z__held.png",
	"punching-glove": "res://art/icons/it_punching_glove.png",
	"pure-incense": "res://art/icons/it_pure_incense.png",
	"purple-nectar": "res://art/icons/it_purple_nectar.png",
	"pyroarite": "res://art/icons/it_pyroarite.png",
	"qualot-berry": "res://art/icons/it_qualot_berry.png",
	"quick-ball": "res://art/icons/it_quick_ball.png",
	"quick-claw": "res://art/icons/it_quick_claw.png",
	"quick-powder": "res://art/icons/it_quick_powder.png",
	"quiet-mint": "res://art/icons/it_quiet_mint.png",
	"rabuta-berry": "res://art/icons/it_rabuta_berry.png",
	"rage-candy-bar": "res://art/icons/it_rage_candy_bar.png",
	"raichunite-x": "res://art/icons/it_raichunite_x.png",
	"raichunite-y": "res://art/icons/it_raichunite_y.png",
	"rainbow-pass": "res://art/icons/it_rainbow_pass.png",
	"rainbow-wing": "res://art/icons/it_rainbow_wing.png",
	"rare-bone": "res://art/icons/it_rare_bone.png",
	"rare-candy": "res://art/icons/it_rare_candy.png",
	"rash-mint": "res://art/icons/it_rash_mint.png",
	"rawst-berry": "res://art/icons/it_rawst_berry.png",
	"razor-claw": "res://art/icons/it_razor_claw.png",
	"razor-fang": "res://art/icons/it_razor_fang.png",
	"razz-berry": "res://art/icons/it_razz_berry.png",
	"reaper-cloth": "res://art/icons/it_reaper_cloth.png",
	"red-apricorn": "res://art/icons/it_red_apricorn.png",
	"red-card": "res://art/icons/it_red_card.png",
	"red-chain": "res://art/icons/it_red_chain.png",
	"red-flute": "res://art/icons/it_red_flute.png",
	"red-nectar": "res://art/icons/it_red_nectar.png",
	"red-orb": "res://art/icons/it_red_orb.png",
	"red-scale": "res://art/icons/it_red_scale.png",
	"red-scarf": "res://art/icons/it_red_scarf.png",
	"red-shard": "res://art/icons/it_red_shard.png",
	"reins-of-unity": "res://art/icons/it_reins_of_unity.png",
	"reins-of-unity--merge": "res://art/icons/it_reins_of_unity__merge.png",
	"reins-of-unity--split": "res://art/icons/it_reins_of_unity__split.png",
	"relaxed-mint": "res://art/icons/it_relaxed_mint.png",
	"relic-band": "res://art/icons/it_relic_band.png",
	"relic-copper": "res://art/icons/it_relic_copper.png",
	"relic-crown": "res://art/icons/it_relic_crown.png",
	"relic-gold": "res://art/icons/it_relic_gold.png",
	"relic-silver": "res://art/icons/it_relic_silver.png",
	"relic-statue": "res://art/icons/it_relic_statue.png",
	"relic-vase": "res://art/icons/it_relic_vase.png",
	"repeat-ball": "res://art/icons/it_repeat_ball.png",
	"repel": "res://art/icons/it_repel.png",
	"reply-mail": "res://art/icons/it_reply_mail.png",
	"reset-urge": "res://art/icons/it_reset_urge.png",
	"resist-mochi": "res://art/icons/it_resist_mochi.png",
	"resist-wing": "res://art/icons/it_resist_wing.png",
	"retro-mail": "res://art/icons/it_retro_mail.png",
	"reveal-glass": "res://art/icons/it_reveal_glass.png",
	"revival-herb": "res://art/icons/it_revival_herb.png",
	"revive": "res://art/icons/it_revive.png",
	"ribbon-sweet": "res://art/icons/it_ribbon_sweet.png",
	"rindo-berry": "res://art/icons/it_rindo_berry.png",
	"ring-target": "res://art/icons/it_ring_target.png",
	"rock-gem": "res://art/icons/it_rock_gem.png",
	"rock-incense": "res://art/icons/it_rock_incense.png",
	"rock-memory": "res://art/icons/it_rock_memory.png",
	"rockium-z--bag": "res://art/icons/it_rockium_z__bag.png",
	"rockium-z--held": "res://art/icons/it_rockium_z__held.png",
	"rocky-helmet": "res://art/icons/it_rocky_helmet.png",
	"room-service": "res://art/icons/it_room_service.png",
	"root-fossil": "res://art/icons/it_root_fossil.png",
	"rose-incense": "res://art/icons/it_rose_incense.png",
	"roseli-berry": "res://art/icons/it_roseli_berry.png",
	"rotom-catalog": "res://art/icons/it_rotom_catalog.png",
	"rotom-phone": "res://art/icons/it_rotom_phone.png",
	"rowap-berry": "res://art/icons/it_rowap_berry.png",
	"rsvp-mail": "res://art/icons/it_rsvp_mail.png",
	"rule-book": "res://art/icons/it_rule_book.png",
	"rusted-shield": "res://art/icons/it_rusted_shield.png",
	"rusted-sword": "res://art/icons/it_rusted_sword.png",
	"sablenite": "res://art/icons/it_sablenite.png",
	"sachet": "res://art/icons/it_sachet.png",
	"sacred-ash": "res://art/icons/it_sacred_ash.png",
	"safari-ball": "res://art/icons/it_safari_ball.png",
	"safety-goggles": "res://art/icons/it_safety_goggles.png",
	"sail-fossil": "res://art/icons/it_sail_fossil.png",
	"salac-berry": "res://art/icons/it_salac_berry.png",
	"salamencite": "res://art/icons/it_salamencite.png",
	"salty-herba-mystica": "res://art/icons/it_salty_herba_mystica.png",
	"sandwich": "res://art/icons/it_sandwich.png",
	"sassy-mint": "res://art/icons/it_sassy_mint.png",
	"scanner": "res://art/icons/it_scanner.png",
	"scarlet-book": "res://art/icons/it_scarlet_book.png",
	"sceptilite": "res://art/icons/it_sceptilite.png",
	"scizorite": "res://art/icons/it_scizorite.png",
	"scolipite": "res://art/icons/it_scolipite.png",
	"scope-lens": "res://art/icons/it_scope_lens.png",
	"scovillainite": "res://art/icons/it_scovillainite.png",
	"scraftinite": "res://art/icons/it_scraftinite.png",
	"scroll-of-darkness": "res://art/icons/it_scroll_of_darkness.png",
	"scroll-of-waters": "res://art/icons/it_scroll_of_waters.png",
	"sea-incense": "res://art/icons/it_sea_incense.png",
	"seal-bag": "res://art/icons/it_seal_bag.png",
	"seal-case": "res://art/icons/it_seal_case.png",
	"secret-key": "res://art/icons/it_secret_key.png",
	"secret-key--letsgo": "res://art/icons/it_secret_key__letsgo.png",
	"secret-potion": "res://art/icons/it_secret_potion.png",
	"serious-mint": "res://art/icons/it_serious_mint.png",
	"shaderoot-carrot": "res://art/icons/it_shaderoot_carrot.png",
	"shadow-mail": "res://art/icons/it_shadow_mail.png",
	"shalour-sable": "res://art/icons/it_shalour_sable.png",
	"sharp-beak": "res://art/icons/it_sharp_beak.png",
	"sharpedonite": "res://art/icons/it_sharpedonite.png",
	"shed-shell": "res://art/icons/it_shed_shell.png",
	"shell-bell": "res://art/icons/it_shell_bell.png",
	"shiny-charm": "res://art/icons/it_shiny_charm.png",
	"shiny-stone": "res://art/icons/it_shiny_stone.png",
	"shoal-salt": "res://art/icons/it_shoal_salt.png",
	"shoal-shell": "res://art/icons/it_shoal_shell.png",
	"shock-drive": "res://art/icons/it_shock_drive.png",
	"shuca-berry": "res://art/icons/it_shuca_berry.png",
	"silk-scarf": "res://art/icons/it_silk_scarf.png",
	"silph-scope": "res://art/icons/it_silph_scope.png",
	"silver-powder": "res://art/icons/it_silver_powder.png",
	"silver-wing": "res://art/icons/it_silver_wing.png",
	"sitrus-berry": "res://art/icons/it_sitrus_berry.png",
	"skarmorite": "res://art/icons/it_skarmorite.png",
	"skull-fossil": "res://art/icons/it_skull_fossil.png",
	"sky-plate": "res://art/icons/it_sky_plate.png",
	"slowbronite": "res://art/icons/it_slowbronite.png",
	"slowpoke-tail": "res://art/icons/it_slowpoke_tail.png",
	"smoke-ball": "res://art/icons/it_smoke_ball.png",
	"smooth-rock": "res://art/icons/it_smooth_rock.png",
	"snorlium-z--bag": "res://art/icons/it_snorlium_z__bag.png",
	"snorlium-z--held": "res://art/icons/it_snorlium_z__held.png",
	"snow-mail": "res://art/icons/it_snow_mail.png",
	"snowball": "res://art/icons/it_snowball.png",
	"soda-pop": "res://art/icons/it_soda_pop.png",
	"soft-sand": "res://art/icons/it_soft_sand.png",
	"solganium-z--bag": "res://art/icons/it_solganium_z__bag.png",
	"solganium-z--held": "res://art/icons/it_solganium_z__held.png",
	"soot-sack": "res://art/icons/it_soot_sack.png",
	"soothe-bell": "res://art/icons/it_soothe_bell.png",
	"soul-dew": "res://art/icons/it_soul_dew.png",
	"sour-herba-mystica": "res://art/icons/it_sour_herba_mystica.png",
	"space-mail": "res://art/icons/it_space_mail.png",
	"spell-tag": "res://art/icons/it_spell_tag.png",
	"spelon-berry": "res://art/icons/it_spelon_berry.png",
	"spicy-herba-mystica": "res://art/icons/it_spicy_herba_mystica.png",
	"splash-plate": "res://art/icons/it_splash_plate.png",
	"spooky-plate": "res://art/icons/it_spooky_plate.png",
	"sport-ball": "res://art/icons/it_sport_ball.png",
	"sprayduck": "res://art/icons/it_sprayduck.png",
	"sprinklotad": "res://art/icons/it_sprinklotad.png",
	"squirt-bottle": "res://art/icons/it_squirt_bottle.png",
	"ss-ticket": "res://art/icons/it_ss_ticket.png",
	"ss-ticket--hoenn": "res://art/icons/it_ss_ticket__hoenn.png",
	"ss-ticket--letsgo": "res://art/icons/it_ss_ticket__letsgo.png",
	"stable-mulch": "res://art/icons/it_stable_mulch.png",
	"star-piece": "res://art/icons/it_star_piece.png",
	"star-sweet": "res://art/icons/it_star_sweet.png",
	"staraptite": "res://art/icons/it_staraptite.png",
	"stardust": "res://art/icons/it_stardust.png",
	"starf-berry": "res://art/icons/it_starf_berry.png",
	"starminite": "res://art/icons/it_starminite.png",
	"steel-gem": "res://art/icons/it_steel_gem.png",
	"steel-mail": "res://art/icons/it_steel_mail.png",
	"steel-memory": "res://art/icons/it_steel_memory.png",
	"steelium-z--bag": "res://art/icons/it_steelium_z__bag.png",
	"steelium-z--held": "res://art/icons/it_steelium_z__held.png",
	"steelixite": "res://art/icons/it_steelixite.png",
	"stick": "res://art/icons/it_stick.png",
	"sticky-barb": "res://art/icons/it_sticky_barb.png",
	"stone-plate": "res://art/icons/it_stone_plate.png",
	"storage-key": "res://art/icons/it_storage_key.png",
	"storage-key--galactic-warehouse": "res://art/icons/it_storage_key__galactic_warehouse.png",
	"storage-key--sea-mauville": "res://art/icons/it_storage_key__sea_mauville.png",
	"strange-ball": "res://art/icons/it_strange_ball.png",
	"strawberry-sweet": "res://art/icons/it_strawberry_sweet.png",
	"suite-key": "res://art/icons/it_suite_key.png",
	"sun-stone": "res://art/icons/it_sun_stone.png",
	"super-potion": "res://art/icons/it_super_potion.png",
	"super-repel": "res://art/icons/it_super_repel.png",
	"super-rod": "res://art/icons/it_super_rod.png",
	"swampertite": "res://art/icons/it_swampertite.png",
	"sweet-apple": "res://art/icons/it_sweet_apple.png",
	"sweet-heart": "res://art/icons/it_sweet_heart.png",
	"sweet-herba-mystica": "res://art/icons/it_sweet_herba_mystica.png",
	"swift-mochi": "res://art/icons/it_swift_mochi.png",
	"swift-wing": "res://art/icons/it_swift_wing.png",
	"syrupy-apple": "res://art/icons/it_syrupy_apple.png",
	"tamato-berry": "res://art/icons/it_tamato_berry.png",
	"tanga-berry": "res://art/icons/it_tanga_berry.png",
	"tapunium-z--bag": "res://art/icons/it_tapunium_z__bag.png",
	"tapunium-z--held": "res://art/icons/it_tapunium_z__held.png",
	"tart-apple": "res://art/icons/it_tart_apple.png",
	"tatsugirinite": "res://art/icons/it_tatsugirinite.png",
	"tea": "res://art/icons/it_tea.png",
	"teachy-tv": "res://art/icons/it_teachy_tv.png",
	"teal-mask": "res://art/icons/it_teal_mask.png",
	"terrain-extender": "res://art/icons/it_terrain_extender.png",
	"thanks-mail": "res://art/icons/it_thanks_mail.png",
	"thick-club": "res://art/icons/it_thick_club.png",
	"throat-spray": "res://art/icons/it_throat_spray.png",
	"thunder-stone": "res://art/icons/it_thunder_stone.png",
	"tidal-bell": "res://art/icons/it_tidal_bell.png",
	"timer-ball": "res://art/icons/it_timer_ball.png",
	"timid-mint": "res://art/icons/it_timid_mint.png",
	"tiny-bamboo-shoot": "res://art/icons/it_tiny_bamboo_shoot.png",
	"tiny-mushroom": "res://art/icons/it_tiny_mushroom.png",
	"tm-case": "res://art/icons/it_tm_case.png",
	"toxic-orb": "res://art/icons/it_toxic_orb.png",
	"toxic-plate": "res://art/icons/it_toxic_plate.png",
	"tri-pass": "res://art/icons/it_tri_pass.png",
	"tropic-mail": "res://art/icons/it_tropic_mail.png",
	"tunnel-mail": "res://art/icons/it_tunnel_mail.png",
	"twisted-spoon": "res://art/icons/it_twisted_spoon.png",
	"tyranitarite": "res://art/icons/it_tyranitarite.png",
	"ultra-ball": "res://art/icons/it_ultra_ball.png",
	"ultranecrozium-z--bag": "res://art/icons/it_ultranecrozium_z__bag.png",
	"ultranecrozium-z--held": "res://art/icons/it_ultranecrozium_z__held.png",
	"unown-report": "res://art/icons/it_unown_report.png",
	"unremarkable-teacup": "res://art/icons/it_unremarkable_teacup.png",
	"up-grade": "res://art/icons/it_up_grade.png",
	"utility-umbrella": "res://art/icons/it_utility_umbrella.png",
	"venusaurite": "res://art/icons/it_venusaurite.png",
	"victreebelite": "res://art/icons/it_victreebelite.png",
	"violet-book": "res://art/icons/it_violet_book.png",
	"vs-recorder": "res://art/icons/it_vs_recorder.png",
	"vs-seeker": "res://art/icons/it_vs_seeker.png",
	"wacan-berry": "res://art/icons/it_wacan_berry.png",
	"wailmer-pail": "res://art/icons/it_wailmer_pail.png",
	"water-gem": "res://art/icons/it_water_gem.png",
	"water-memory": "res://art/icons/it_water_memory.png",
	"water-stone": "res://art/icons/it_water_stone.png",
	"waterium-z--bag": "res://art/icons/it_waterium_z__bag.png",
	"waterium-z--held": "res://art/icons/it_waterium_z__held.png",
	"watmel-berry": "res://art/icons/it_watmel_berry.png",
	"wave-incense": "res://art/icons/it_wave_incense.png",
	"wave-mail": "res://art/icons/it_wave_mail.png",
	"weakness-policy": "res://art/icons/it_weakness_policy.png",
	"wellspring-mask": "res://art/icons/it_wellspring_mask.png",
	"wepear-berry": "res://art/icons/it_wepear_berry.png",
	"whipped-dream": "res://art/icons/it_whipped_dream.png",
	"white-apricorn": "res://art/icons/it_white_apricorn.png",
	"white-flute": "res://art/icons/it_white_flute.png",
	"white-herb": "res://art/icons/it_white_herb.png",
	"white-mane-hair": "res://art/icons/it_white_mane_hair.png",
	"wide-lens": "res://art/icons/it_wide_lens.png",
	"wiki-berry": "res://art/icons/it_wiki_berry.png",
	"wise-glasses": "res://art/icons/it_wise_glasses.png",
	"wishing-piece": "res://art/icons/it_wishing_piece.png",
	"wood-mail": "res://art/icons/it_wood_mail.png",
	"works-key": "res://art/icons/it_works_key.png",
	"x-accuracy": "res://art/icons/it_x_accuracy.png",
	"x-accuracy-2": "res://art/icons/it_x_accuracy_2.png",
	"x-accuracy-3": "res://art/icons/it_x_accuracy_3.png",
	"x-accuracy-6": "res://art/icons/it_x_accuracy_6.png",
	"x-attack": "res://art/icons/it_x_attack.png",
	"x-attack-2": "res://art/icons/it_x_attack_2.png",
	"x-attack-3": "res://art/icons/it_x_attack_3.png",
	"x-attack-6": "res://art/icons/it_x_attack_6.png",
	"x-defense": "res://art/icons/it_x_defense.png",
	"x-defense-2": "res://art/icons/it_x_defense_2.png",
	"x-defense-3": "res://art/icons/it_x_defense_3.png",
	"x-defense-6": "res://art/icons/it_x_defense_6.png",
	"x-sp-atk": "res://art/icons/it_x_sp_atk.png",
	"x-sp-atk-2": "res://art/icons/it_x_sp_atk_2.png",
	"x-sp-atk-3": "res://art/icons/it_x_sp_atk_3.png",
	"x-sp-atk-6": "res://art/icons/it_x_sp_atk_6.png",
	"x-sp-def": "res://art/icons/it_x_sp_def.png",
	"x-sp-def-2": "res://art/icons/it_x_sp_def_2.png",
	"x-sp-def-3": "res://art/icons/it_x_sp_def_3.png",
	"x-sp-def-6": "res://art/icons/it_x_sp_def_6.png",
	"x-speed": "res://art/icons/it_x_speed.png",
	"x-speed-2": "res://art/icons/it_x_speed_2.png",
	"x-speed-3": "res://art/icons/it_x_speed_3.png",
	"x-speed-6": "res://art/icons/it_x_speed_6.png",
	"yache-berry": "res://art/icons/it_yache_berry.png",
	"yellow-apricorn": "res://art/icons/it_yellow_apricorn.png",
	"yellow-flute": "res://art/icons/it_yellow_flute.png",
	"yellow-nectar": "res://art/icons/it_yellow_nectar.png",
	"yellow-scarf": "res://art/icons/it_yellow_scarf.png",
	"yellow-shard": "res://art/icons/it_yellow_shard.png",
	"zap-plate": "res://art/icons/it_zap_plate.png",
	"zeraorite": "res://art/icons/it_zeraorite.png",
	"zinc": "res://art/icons/it_zinc.png",
	"zoom-lens": "res://art/icons/it_zoom_lens.png",
	"zygarde-cube": "res://art/icons/it_zygarde_cube.png",
	"zygardite": "res://art/icons/it_zygardite.png",
	"hm01": "res://art/icons/it_hm01.png",
	"hm02": "res://art/icons/it_hm02.png",
	"hm03": "res://art/icons/it_hm03.png",
	"hm04": "res://art/icons/it_hm04.png",
	"hm05": "res://art/icons/it_hm05.png",
	"hm06": "res://art/icons/it_hm06.png",
	"hm07": "res://art/icons/it_hm07.png",
	"hm08": "res://art/icons/it_hm08.png",
	"tm01": "res://art/icons/it_tm01.png",
	"tm02": "res://art/icons/it_tm02.png",
	"tm03": "res://art/icons/it_tm03.png",
	"tm04": "res://art/icons/it_tm04.png",
	"tm05": "res://art/icons/it_tm05.png",
	"tm06": "res://art/icons/it_tm06.png",
	"tm07": "res://art/icons/it_tm07.png",
	"tm08": "res://art/icons/it_tm08.png",
	"tm09": "res://art/icons/it_tm09.png",
	"tm10": "res://art/icons/it_tm10.png",
	"tm11": "res://art/icons/it_tm11.png",
	"tm12": "res://art/icons/it_tm12.png",
	"tm13": "res://art/icons/it_tm13.png",
	"tm14": "res://art/icons/it_tm14.png",
	"tm15": "res://art/icons/it_tm15.png",
	"tm16": "res://art/icons/it_tm16.png",
	"tm17": "res://art/icons/it_tm17.png",
	"tm18": "res://art/icons/it_tm18.png",
	"tm19": "res://art/icons/it_tm19.png",
	"tm20": "res://art/icons/it_tm20.png",
	"tm21": "res://art/icons/it_tm21.png",
	"tm22": "res://art/icons/it_tm22.png",
	"tm23": "res://art/icons/it_tm23.png",
	"tm24": "res://art/icons/it_tm24.png",
	"tm25": "res://art/icons/it_tm25.png",
	"tm26": "res://art/icons/it_tm26.png",
	"tm27": "res://art/icons/it_tm27.png",
	"tm28": "res://art/icons/it_tm28.png",
	"tm29": "res://art/icons/it_tm29.png",
	"tm30": "res://art/icons/it_tm30.png",
	"tm31": "res://art/icons/it_tm31.png",
	"tm32": "res://art/icons/it_tm32.png",
	"tm33": "res://art/icons/it_tm33.png",
	"tm34": "res://art/icons/it_tm34.png",
	"tm35": "res://art/icons/it_tm35.png",
	"tm36": "res://art/icons/it_tm36.png",
	"tm37": "res://art/icons/it_tm37.png",
	"tm38": "res://art/icons/it_tm38.png",
	"tm39": "res://art/icons/it_tm39.png",
	"tm40": "res://art/icons/it_tm40.png",
	"tm41": "res://art/icons/it_tm41.png",
	"tm42": "res://art/icons/it_tm42.png",
	"tm43": "res://art/icons/it_tm43.png",
	"tm44": "res://art/icons/it_tm44.png",
	"tm45": "res://art/icons/it_tm45.png",
	"tm46": "res://art/icons/it_tm46.png",
	"tm47": "res://art/icons/it_tm47.png",
	"tm48": "res://art/icons/it_tm48.png",
	"tm49": "res://art/icons/it_tm49.png",
	"tm50": "res://art/icons/it_tm50.png",
	"tm51": "res://art/icons/it_tm51.png",
	"tm52": "res://art/icons/it_tm52.png",
	"tm53": "res://art/icons/it_tm53.png",
	"tm54": "res://art/icons/it_tm54.png",
	"tm55": "res://art/icons/it_tm55.png",
	"tm56": "res://art/icons/it_tm56.png",
	"tm57": "res://art/icons/it_tm57.png",
	"tm58": "res://art/icons/it_tm58.png",
	"tm59": "res://art/icons/it_tm59.png",
	"tm60": "res://art/icons/it_tm60.png",
	"tm61": "res://art/icons/it_tm61.png",
	"tm62": "res://art/icons/it_tm62.png",
	"tm63": "res://art/icons/it_tm63.png",
	"tm64": "res://art/icons/it_tm64.png",
	"tm65": "res://art/icons/it_tm65.png",
	"tm66": "res://art/icons/it_tm66.png",
	"tm67": "res://art/icons/it_tm67.png",
	"tm68": "res://art/icons/it_tm68.png",
	"tm69": "res://art/icons/it_tm69.png",
	"tm70": "res://art/icons/it_tm70.png",
	"tm71": "res://art/icons/it_tm71.png",
	"tm72": "res://art/icons/it_tm72.png",
	"tm73": "res://art/icons/it_tm73.png",
	"tm74": "res://art/icons/it_tm74.png",
	"tm75": "res://art/icons/it_tm75.png",
	"tm76": "res://art/icons/it_tm76.png",
	"tm77": "res://art/icons/it_tm77.png",
	"tm78": "res://art/icons/it_tm78.png",
	"tm79": "res://art/icons/it_tm79.png",
	"tm80": "res://art/icons/it_tm80.png",
	"tm81": "res://art/icons/it_tm81.png",
	"tm82": "res://art/icons/it_tm82.png",
	"tm83": "res://art/icons/it_tm83.png",
	"tm84": "res://art/icons/it_tm84.png",
	"tm85": "res://art/icons/it_tm85.png",
	"tm86": "res://art/icons/it_tm86.png",
	"tm87": "res://art/icons/it_tm87.png",
	"tm88": "res://art/icons/it_tm88.png",
	"tm89": "res://art/icons/it_tm89.png",
	"tm90": "res://art/icons/it_tm90.png",
	"tm91": "res://art/icons/it_tm91.png",
	"tm92": "res://art/icons/it_tm92.png",
	"tm93": "res://art/icons/it_tm93.png",
	"tm94": "res://art/icons/it_tm94.png",
	"tm95": "res://art/icons/it_tm95.png",
	"tm96": "res://art/icons/it_tm96.png",
	"tm97": "res://art/icons/it_tm97.png",
	"tm98": "res://art/icons/it_tm98.png",
	"tm99": "res://art/icons/it_tm99.png",
	"tm100": "res://art/icons/it_tm100.png",
	"tm101": "res://art/icons/it_tm101.png",
	"tm102": "res://art/icons/it_tm102.png",
	"tm103": "res://art/icons/it_tm103.png",
	"tm104": "res://art/icons/it_tm104.png",
	"tm105": "res://art/icons/it_tm105.png",
	"tm106": "res://art/icons/it_tm106.png",
	"tm107": "res://art/icons/it_tm107.png",
	"tm108": "res://art/icons/it_tm108.png",
	"tm109": "res://art/icons/it_tm109.png",
	"tm110": "res://art/icons/it_tm110.png",
	"tm111": "res://art/icons/it_tm111.png",
	"tm112": "res://art/icons/it_tm112.png",
	"tm113": "res://art/icons/it_tm113.png",
	"tm114": "res://art/icons/it_tm114.png",
	"tm115": "res://art/icons/it_tm115.png",
	"tm116": "res://art/icons/it_tm116.png",
	"tm117": "res://art/icons/it_tm117.png",
	"tm118": "res://art/icons/it_tm118.png",
	"tm119": "res://art/icons/it_tm119.png",
	"tm120": "res://art/icons/it_tm120.png",
	"tm121": "res://art/icons/it_tm121.png",
	"tm122": "res://art/icons/it_tm122.png",
	"tm123": "res://art/icons/it_tm123.png",
	"tm124": "res://art/icons/it_tm124.png",
	"tm125": "res://art/icons/it_tm125.png",
	"tm126": "res://art/icons/it_tm126.png",
	"tm127": "res://art/icons/it_tm127.png",
	"tm128": "res://art/icons/it_tm128.png",
	"tm129": "res://art/icons/it_tm129.png",
	"tm130": "res://art/icons/it_tm130.png",
	"tm131": "res://art/icons/it_tm131.png",
	"tm132": "res://art/icons/it_tm132.png",
	"tm133": "res://art/icons/it_tm133.png",
	"tm134": "res://art/icons/it_tm134.png",
	"tm135": "res://art/icons/it_tm135.png",
	"tm136": "res://art/icons/it_tm136.png",
	"tm137": "res://art/icons/it_tm137.png",
	"tm138": "res://art/icons/it_tm138.png",
	"tm139": "res://art/icons/it_tm139.png",
	"tm140": "res://art/icons/it_tm140.png",
	"tm141": "res://art/icons/it_tm141.png",
	"tm142": "res://art/icons/it_tm142.png",
	"tm143": "res://art/icons/it_tm143.png",
	"tm144": "res://art/icons/it_tm144.png",
	"tm145": "res://art/icons/it_tm145.png",
	"tm146": "res://art/icons/it_tm146.png",
	"tm147": "res://art/icons/it_tm147.png",
	"tm148": "res://art/icons/it_tm148.png",
	"tm149": "res://art/icons/it_tm149.png",
	"tm150": "res://art/icons/it_tm150.png",
	"tm151": "res://art/icons/it_tm151.png",
	"tm152": "res://art/icons/it_tm152.png",
	"tm153": "res://art/icons/it_tm153.png",
	"tm154": "res://art/icons/it_tm154.png",
	"tm155": "res://art/icons/it_tm155.png",
	"tm156": "res://art/icons/it_tm156.png",
	"tm157": "res://art/icons/it_tm157.png",
	"tm158": "res://art/icons/it_tm158.png",
	"tm159": "res://art/icons/it_tm159.png",
	"tm160": "res://art/icons/it_tm160.png",
	"tm161": "res://art/icons/it_tm161.png",
	"tm162": "res://art/icons/it_tm162.png",
	"tm163": "res://art/icons/it_tm163.png",
	"tm164": "res://art/icons/it_tm164.png",
	"tm165": "res://art/icons/it_tm165.png",
	"tm166": "res://art/icons/it_tm166.png",
	"tm167": "res://art/icons/it_tm167.png",
	"tm168": "res://art/icons/it_tm168.png",
	"tm169": "res://art/icons/it_tm169.png",
	"tm170": "res://art/icons/it_tm170.png",
	"tm171": "res://art/icons/it_tm171.png",
	"tm172": "res://art/icons/it_tm172.png",
	"tm173": "res://art/icons/it_tm173.png",
	"tm174": "res://art/icons/it_tm174.png",
	"tm175": "res://art/icons/it_tm175.png",
	"tm176": "res://art/icons/it_tm176.png",
	"tm177": "res://art/icons/it_tm177.png",
	"tm178": "res://art/icons/it_tm178.png",
	"tm179": "res://art/icons/it_tm179.png",
	"tm180": "res://art/icons/it_tm180.png",
	"tm181": "res://art/icons/it_tm181.png",
	"tm182": "res://art/icons/it_tm182.png",
	"tm183": "res://art/icons/it_tm183.png",
	"tm184": "res://art/icons/it_tm184.png",
	"tm185": "res://art/icons/it_tm185.png",
	"tm186": "res://art/icons/it_tm186.png",
	"tm187": "res://art/icons/it_tm187.png",
	"tm188": "res://art/icons/it_tm188.png",
	"tm189": "res://art/icons/it_tm189.png",
	"tm190": "res://art/icons/it_tm190.png",
	"tm191": "res://art/icons/it_tm191.png",
	"tm192": "res://art/icons/it_tm192.png",
	"tm193": "res://art/icons/it_tm193.png",
	"tm194": "res://art/icons/it_tm194.png",
	"tm195": "res://art/icons/it_tm195.png",
	"tm196": "res://art/icons/it_tm196.png",
	"tm197": "res://art/icons/it_tm197.png",
	"tm198": "res://art/icons/it_tm198.png",
	"tm199": "res://art/icons/it_tm199.png",
	"tm200": "res://art/icons/it_tm200.png",
	"tm201": "res://art/icons/it_tm201.png",
	"tm202": "res://art/icons/it_tm202.png",
	"tm203": "res://art/icons/it_tm203.png",
	"tm204": "res://art/icons/it_tm204.png",
	"tm205": "res://art/icons/it_tm205.png",
	"tm206": "res://art/icons/it_tm206.png",
	"tm207": "res://art/icons/it_tm207.png",
	"tm208": "res://art/icons/it_tm208.png",
	"tm209": "res://art/icons/it_tm209.png",
	"tm210": "res://art/icons/it_tm210.png",
	"tm211": "res://art/icons/it_tm211.png",
	"tm212": "res://art/icons/it_tm212.png",
	"tm213": "res://art/icons/it_tm213.png",
	"tm214": "res://art/icons/it_tm214.png",
	"tm215": "res://art/icons/it_tm215.png",
	"tm216": "res://art/icons/it_tm216.png",
	"tm217": "res://art/icons/it_tm217.png",
	"tm218": "res://art/icons/it_tm218.png",
	"tm219": "res://art/icons/it_tm219.png",
	"tm220": "res://art/icons/it_tm220.png",
	"tm221": "res://art/icons/it_tm221.png",
	"tm222": "res://art/icons/it_tm222.png",
	"tm223": "res://art/icons/it_tm223.png",
	"tm224": "res://art/icons/it_tm224.png",
	"tm225": "res://art/icons/it_tm225.png",
	"tm226": "res://art/icons/it_tm226.png",
	"tm227": "res://art/icons/it_tm227.png",
	"tm228": "res://art/icons/it_tm228.png",
	"tm229": "res://art/icons/it_tm229.png",
}

## The rows on show, in PUWLiveBag's shape ({"slug", "qty",
## "pocket"}). Fed by bind_state()/refresh_holdings(); a host
## may also assign it directly. Starts empty: an unbound bag
## honestly shows "No items.", never demo stock.
var holdings: Array = []

## The bound save state (the very dict the game saves) and
## the field-use context ({"habitat": ..., "map_loader": ...})
## PUWLiveBag.use_in_overworld reads. Empty state = unbound:
## actions then only emit action_chosen, exactly as build 3
## shipped, so panel probes and demos behave as before.
var _state: Dictionary = {}
var _field_context: Dictionary = {}

var _item_data: Dictionary = {}
var _pocket_buttons: Array[Button] = []
var _rows_box: VBoxContainer = null
var _rows: Array[Button] = []
var _current_pocket: int = 1
var _selected_slug: String = ""
var _detail_icon: TextureRect = null
var _detail_name: Label = null
var _detail_text: Label = null
var _message_panel: PanelContainer = null
var _message_label: Label = null
var _bob_tween: Tween = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = PUWUiTheme.make_theme()
	_load_item_data()
	_build()
	select_pocket(_current_pocket)


func _load_item_data() -> void:
	var path: String = "res://data/items_full_compact.json"
	if not FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var items: Array = (parsed as Dictionary).get("items", [])
	for entry_value in items:
		var entry: Dictionary = entry_value
		_item_data[str(entry.get("slug", ""))] = entry


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var back_button := Button.new()
	back_button.custom_minimum_size = Vector2(56, 56)
	back_button.icon = PUWUiTheme.tex("res://art/ui/back_chevron.png")
	back_button.expand_icon = true
	back_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(back_button)
	header.add_child(PUWUiTheme.make_label("BAG", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true))

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	# Pocket rail.
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 8)
	main.add_child(rail)
	for i in POCKETS.size():
		var pocket_index: int = i
		var tab: Button = PUWUiTheme.make_button(str(POCKETS[i]), Vector2(168, 64))
		tab.pressed.connect(func() -> void: select_pocket(pocket_index))
		rail.add_child(tab)
		_pocket_buttons.append(tab)

	# Item list.
	var list_panel := PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	var scroll_margin := MarginContainer.new()
	scroll_margin.add_theme_constant_override("margin_right", 16)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_margin)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_rows_box)

	# Detail panel.
	var detail := PanelContainer.new()
	detail.custom_minimum_size = Vector2(300, 0)
	detail.add_theme_stylebox_override("panel", PUWUiTheme.dark_panel_style())
	main.add_child(detail)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 10)
	detail.add_child(detail_box)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(96, 96)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_box.add_child(_detail_icon)
	_detail_name = PUWUiTheme.make_label("", PUWUiTheme.TITLE_SIZE, PUWUiTheme.TEXT, true)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_name)
	_detail_text = PUWUiTheme.make_label("", PUWUiTheme.SECONDARY_SIZE, PUWUiTheme.TEXT_DIM)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(_detail_text)

	# Action bar.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)
	for action_value in ["Use", "Give", "Toss"]:
		var action_id: String = action_value
		var button: Button = PUWUiTheme.make_button(action_id, Vector2(150, 56))
		button.pressed.connect(func() -> void: activate_action(action_id.to_lower()))
		actions.add_child(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var close_button: Button = PUWUiTheme.make_button("Close", Vector2(150, 56))
	close_button.pressed.connect(func() -> void: close_requested.emit())
	actions.add_child(close_button)

	# Message strip: the surface every resolution writes to.
	_message_panel = PanelContainer.new()
	_message_panel.custom_minimum_size = Vector2(0, 56)
	_message_panel.add_theme_stylebox_override("panel", PUWUiTheme.bright_panel_style())
	_message_panel.visible = false
	root.add_child(_message_panel)
	_message_label = PUWUiTheme.make_label("", PUWUiTheme.TEXT_SIZE, PUWUiTheme.WINDOW_TEXT)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_panel.add_child(_message_label)


## Show a resolution message on the strip under the action
## bar. Empty text hides the strip again.
func show_message(text: String) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_panel.visible = text != ""


func message_text() -> String:
	return _message_label.text if _message_label != null else ""


## Bind the screen to a live save state. Call before or after
## the screen enters the tree; holdings refresh immediately
## and again whenever refresh_holdings() is called (the host
## calls it each time the stack pushes this panel, so grants
## and purchases made elsewhere show up). field_context is
## PUWLiveBag.use_in_overworld's context, handed over by the
## scene that owns the habitat and the map loader.
func bind_state(state: Dictionary, field_context: Dictionary = {}) -> void:
	_state = state
	_field_context = field_context
	refresh_holdings()


## Re-read holdings from the bound state and rebuild the
## rows. A selection whose stack ran out is cleared.
func refresh_holdings() -> void:
	if _state.is_empty():
		return
	holdings = PUWLiveBag.holdings_for_screen(_state)
	if not is_inside_tree() or _rows_box == null:
		return
	select_pocket(_current_pocket)
	if _selected_slug != "":
		var still_held: bool = false
		for holding_value in holdings:
			var holding: Dictionary = holding_value
			if str(holding.get("slug", "")) == _selected_slug:
				still_held = true
				break
		if not still_held:
			_selected_slug = ""
			_show_detail("")


## Select a held item by slug (switching to its pocket).
## Hosts and tests use this; the focus flow remains the
## player's selection path. False when the slug is not held.
func select_item(slug: String) -> bool:
	for holding_value in holdings:
		var holding: Dictionary = holding_value
		if str(holding.get("slug", "")) == slug:
			var pocket: int = int(holding.get("pocket", _current_pocket))
			if pocket != _current_pocket:
				select_pocket(pocket)
			_selected_slug = slug
			_show_detail(slug)
			return true
	return false


## The action bar's one entry point (the buttons call this).
## Unbound, or with nothing selected, it emits action_chosen
## exactly as build 3 shipped. Bound, Use routes by
## PUWItemTarget.use_mode: targeted items ask the host for
## the party picker (bag_target_requested, no resolution
## yet); field items, party-wide items and refusals resolve
## in place; Give asks for the picker; Toss resolves in
## place. Every in-place resolution shows its message and
## reports through bag_action_resolved exactly once.
func activate_action(action_id: String) -> void:
	PUWUiSound.play("ui_confirm")
	if _state.is_empty() or _selected_slug == "":
		action_chosen.emit(action_id, _selected_slug)
		return
	match action_id:
		"use":
			match PUWItemTarget.use_mode(_state, _selected_slug):
				"target":
					bag_target_requested.emit(action_id, _selected_slug)
				"party":
					_report(action_id, PUWItemTarget.use_party_wide(_state, _selected_slug))
				"field":
					_report(action_id, PUWLiveBag.use_in_overworld(_state, _selected_slug, _field_context))
				_:
					_report(action_id, PUWItemTarget.not_usable_result(_state, _selected_slug))
		"give":
			bag_target_requested.emit(action_id, _selected_slug)
		"toss":
			_report(action_id, PUWLiveBag.toss_from_state(_state, _selected_slug))
		_:
			action_chosen.emit(action_id, _selected_slug)


## The host's report-back for a picker pick it resolved
## through PUWItemTarget (use_on_mon / give_to_mon /
## take_from_mon): refresh, show the message, and report
## through the same bag_action_resolved channel as in-place
## resolutions, so the host has exactly one to listen to.
func apply_target_result(action_id: String, item_slug: String, result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		refresh_holdings()
	show_message(PUWItemTarget.message_for_result(action_id, item_slug, result))
	bag_action_resolved.emit(action_id, item_slug, result)


func _report(action_id: String, result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		refresh_holdings()
	show_message(PUWItemTarget.message_for_result(action_id, _selected_slug, result))
	bag_action_resolved.emit(action_id, _selected_slug, result)


func select_pocket(pocket: int) -> void:
	_current_pocket = pocket
	PUWUiSound.play("ui_cursor")
	for i in _pocket_buttons.size():
		var tab: Button = _pocket_buttons[i]
		if i == pocket:
			tab.add_theme_stylebox_override("normal", PUWUiTheme._flat(PUWUiTheme.PANEL_LIGHT, PUWUiTheme.ACCENT, 8, 2))
		else:
			tab.remove_theme_stylebox_override("normal")
	_rebuild_rows()


func _rebuild_rows() -> void:
	for row in _rows:
		_rows_box.remove_child(row)
		row.free()
	_rows.clear()
	for child in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.free()
	if _bob_tween != null:
		_bob_tween.kill()
		_bob_tween = null
	var pocket_items: Array = []
	for holding_value in holdings:
		var holding: Dictionary = holding_value
		if int(holding.get("pocket", -1)) == _current_pocket:
			pocket_items.append(holding)
	if pocket_items.is_empty():
		var empty: Label = PUWUiTheme.make_label("No items.", PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM)
		empty.custom_minimum_size = Vector2(0, 64)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows_box.add_child(empty)
		_selected_slug = ""
		_show_detail("")
		return
	for holding_value in pocket_items:
		var holding: Dictionary = holding_value
		var row: Button = _make_row(holding)
		_rows_box.add_child(row)
		_rows.append(row)
	if not _rows.is_empty():
		_rows[0].grab_focus()


func _make_row(holding: Dictionary) -> Button:
	var slug: String = str(holding.get("slug", ""))
	var data: Dictionary = _item_data.get(slug, {})
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 64)
	row.focus_mode = Control.FOCUS_ALL
	row.add_theme_stylebox_override("normal", PUWUiTheme.row_style(false))
	row.add_theme_stylebox_override("hover", PUWUiTheme.row_style(true))
	row.add_theme_stylebox_override("pressed", PUWUiTheme.row_style(true))
	row.add_theme_stylebox_override("focus", PUWUiTheme._flat(Color(0.23, 0.31, 0.47), Color(0, 0, 0, 0), 6, 0))
	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var cursor := TextureRect.new()
	cursor.name = "Cursor"
	cursor.texture = PUWUiTheme.tex(PUWUiTheme.CURSOR_PATH)
	cursor.custom_minimum_size = Vector2(24, 24)
	cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.visible = false
	box.add_child(cursor)
	var icon := TextureRect.new()
	icon.texture = PUWUiTheme.tex(str(ITEM_ICONS.get(slug, "")))
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var name_label: Label = PUWUiTheme.make_label(str(data.get("display_name", slug)), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var qty_label: Label = PUWUiTheme.make_label("×" + str(holding.get("qty", 0)), PUWUiTheme.TEXT_SIZE, PUWUiTheme.TEXT_DIM)
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(qty_label)
	row.focus_entered.connect(func() -> void:
		PUWUiSound.play("ui_cursor")
		_selected_slug = slug
		_show_detail(slug)
		cursor.visible = true
		if _bob_tween != null:
			_bob_tween.kill()
		_bob_tween = PUWMenuTransitions.cursor_bob(self, cursor)
	)
	row.focus_exited.connect(func() -> void:
		cursor.visible = false
	)
	row.pressed.connect(func() -> void:
		PUWUiSound.play("ui_confirm")
		_selected_slug = slug
		_show_detail(slug)
	)
	return row


func _show_detail(slug: String) -> void:
	if slug == "" or not _item_data.has(slug):
		_detail_icon.texture = null
		_detail_name.text = ""
		_detail_text.text = ""
		return
	var data: Dictionary = _item_data[slug]
	_detail_icon.texture = PUWUiTheme.tex(str(ITEM_ICONS.get(slug, "")))
	_detail_name.text = str(data.get("display_name", slug))
	_detail_text.text = str(data.get("effect_short", ""))


func get_initial_focus_control() -> Control:
	if not _rows.is_empty():
		return _rows[0]
	return _pocket_buttons[_current_pocket]
