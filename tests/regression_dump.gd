extends SceneTree
## Regression dump — identical script in test_project (patched) and
## test_project_orig (original code). Dumps a canonical serialization
## of every build the two code versions can be compared on:
##   MON|<slug>|<level>|<mode>|<json>     build_mon, all 1,025 dex
##                                        species, levels 5/50/100,
##                                        singles + vgc
##   TEAM|<label>|<seed>|<json>           build_trainer_team for real
##                                        Kanto class parties + the
##                                        four Elite Four parties,
##                                        player_max 50, seeds 7/99
## Usage: godot --headless --path <proj> --script res://tests/regression_dump.gd -- <output_path>
## The comparison (work/compare_dumps.py) requires: every MON line
## for a species that built with >= 1 move in the original dump is
## byte-identical in the patched dump; every TEAM line whose
## original team had no zero-move mon is byte-identical.

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("DUMP_ERROR: no output path argument")
		quit(1)
		return
	var out_path: String = args[0]
	var builder: PUWTeamBuilder = PUWTeamBuilder.new()
	var lines: Array = []

	var sets_text: String = FileAccess.get_file_as_string("res://data/competitive_sets.json")
	var sets_parsed: Variant = JSON.parse_string(sets_text)
	var species: Dictionary = (sets_parsed as Dictionary).get("species", {})
	var slugs: Array = species.keys()
	slugs.sort()
	for slug_v in slugs:
		var slug: String = str(slug_v)
		for level in [5, 50, 100]:
			for mode in ["singles", "vgc"]:
				var mon: Dictionary = builder.build_mon(slug, level, mode)
				lines.append("MON|" + slug + "|" + str(level) + "|" + mode + "|" + JSON.stringify(mon))

	var parties: Array = _sample_parties()
	for party_v in parties:
		var party: Dictionary = party_v
		for seed_val in [7, 99]:
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = seed_val
			var team: Array = builder.build_trainer_team(party["species"], 50, "singles", rng)
			lines.append("TEAM|" + str(party["label"]) + "|" + str(seed_val) + "|" + JSON.stringify(team))

	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		print("DUMP_ERROR: cannot open " + out_path)
		quit(1)
		return
	for line_v in lines:
		f.store_line(str(line_v))
	f.close()
	print("DUMP_WROTE " + str(lines.size()) + " lines to " + out_path)
	quit(0)


## Real base parties: party 1 of a spread of Kanto trainer classes
## (data/trainers.json, from pret/pokered parties.asm) plus the four
## Elite Four parties (data/elite_four.json).
func _sample_parties() -> Array:
	var out: Array = []
	var t_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/trainers.json"))
	var classes: Dictionary = (t_parsed as Dictionary).get("classes", {})
	var wanted: Array = ["YOUNGSTER", "BUG_CATCHER", "LASS", "ROCKET", "CHANNELER", "SUPER_NERD", "HIKER", "BIKER", "SCIENTIST", "SWIMMER", "SAILOR", "POKEMANIAC", "JUGGLER", "TAMER", "GENTLEMAN", "FISHER", "BLACKBELT", "BEAUTY", "BURGLAR", "CUE_BALL"]
	for cls in wanted:
		var entry: Variant = classes.get(cls, {})
		if not (entry is Dictionary):
			continue
		var parties: Variant = (entry as Dictionary).get("parties", [])
		if not (parties is Array) or (parties as Array).is_empty():
			continue
		var first: Variant = (parties as Array)[0]
		if not (first is Array):
			continue
		var species_list: Array = []
		for mon_v in first:
			if mon_v is Dictionary:
				species_list.append(str((mon_v as Dictionary).get("species", "")))
		out.append({"label": "CLASS_" + cls, "species": species_list})
	var e_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/elite_four.json"))
	var members: Dictionary = (e_parsed as Dictionary).get("members", {})
	for member in ["LORELEI", "BRUNO", "AGATHA", "LANCE"]:
		var m_entry: Variant = members.get(member, {})
		if not (m_entry is Dictionary):
			continue
		var m_parties: Variant = (m_entry as Dictionary).get("parties", [])
		if not (m_parties is Array) or (m_parties as Array).is_empty():
			continue
		var first_rec: Variant = (m_parties as Array)[0]
		if not (first_rec is Dictionary):
			continue
		var plist: Variant = (first_rec as Dictionary).get("party", [])
		if not (plist is Array):
			continue
		var species_list2: Array = []
		for mon_v2 in plist:
			if mon_v2 is Dictionary:
				species_list2.append(str((mon_v2 as Dictionary).get("species", "")))
		out.append({"label": "E4_" + member, "species": species_list2})
	return out
