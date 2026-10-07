class_name Save
extends RefCounted
## The host's crew save (cash, unlocks, upgrades) and each player's own profile (name and look).

const CREW_PATH: String = "user://crew_save.json"
const PROFILE_PATH: String = "user://profile.cfg"
const SAVED_KEYS: Array = ["cash", "unlocks", "upgrades"]


## Why the crew save can't be loaded, or "" when it's fine or doesn't exist yet.
static func crew_problem() -> String:
	if not FileAccess.file_exists(CREW_PATH):
		return ""
	var where: String = ProjectSettings.globalize_path(CREW_PATH)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(CREW_PATH)) != OK:
		return "The crew save is damaged: %s line %d: %s" % [where, json.get_error_line(), json.get_error_message()]
	if not json.data is Dictionary:
		return "The crew save is damaged: %s is not a JSON object" % where
	var data: Dictionary = json.data
	for key: String in SAVED_KEYS:
		if not data.has(key):
			return "The crew save is damaged: %s has no '%s'" % [where, key]
	if not data["cash"] is float:
		return "The crew save is damaged: 'cash' in %s is not a number" % where
	if not data["unlocks"] is Array:
		return "The crew save is damaged: 'unlocks' in %s is not a list" % where
	for id: Variant in data["unlocks"]:
		if not (id is String and (Catalog.WEAPONS.has(id) or Catalog.look_slot(id) != "")):
			return "The crew save is damaged: unknown unlock %s in %s" % [id, where]
	if not data["upgrades"] is Dictionary:
		return "The crew save is damaged: 'upgrades' in %s is not an object" % where
	var upgrades: Dictionary = data["upgrades"]
	for key: Variant in upgrades:
		if not (key is String and Catalog.UPGRADES.has(key)):
			return "The crew save is damaged: unknown upgrade %s in %s" % [key, where]
		var level: Variant = upgrades[key]
		if not (level is float and level >= 0 and level <= Catalog.max_upgrade_level(key)):
			return "The crew save is damaged: bad level for '%s' in %s" % [key, where]
	return ""


## The saved crew keys, or an empty Dictionary when there is no save yet. Check crew_problem() first.
static func load_state() -> Dictionary:
	assert(crew_problem() == "", crew_problem())
	if not FileAccess.file_exists(CREW_PATH):
		return {}
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CREW_PATH))
	# JSON numbers come back as floats; the state holds ints.
	var upgrades: Dictionary = {}
	for key: String in Catalog.UPGRADE_ORDER:
		upgrades[key] = 0
	var saved_upgrades: Dictionary = data["upgrades"]
	for key: String in saved_upgrades:
		upgrades[key] = int(saved_upgrades[key])
	return {
		"cash": int(data["cash"]),
		"unlocks": data["unlocks"],
		"upgrades": upgrades,
	}


static func persist(state: Dictionary) -> void:
	var data: Dictionary = {}
	for key: String in SAVED_KEYS:
		data[key] = state[key]
	var file := FileAccess.open(CREW_PATH, FileAccess.WRITE)
	assert(file != null, "Can't write the crew save %s: %s" % [CREW_PATH, error_string(FileAccess.get_open_error())])
	file.store_string(JSON.stringify(data, "\t"))


# --- Profile (this machine only) ----------------------------------------------

static func load_profile() -> Dictionary:
	var config := ConfigFile.new()
	if FileAccess.file_exists(PROFILE_PATH):
		var err: Error = config.load(PROFILE_PATH)
		assert(err == OK, "Can't read the profile %s: %s" % [PROFILE_PATH, error_string(err)])
	var profile: Dictionary = {
		"name": config.get_value("player", "name", "Robber"),
		"mask": config.get_value("look", "mask", "classic"),
		"outfit": config.get_value("look", "outfit", "street"),
		"hat": config.get_value("look", "hat", "none"),
	}
	Catalog.assert_look(look_of(profile))
	return profile


static func save_profile(profile: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", profile["name"])
	for slot: String in Catalog.LOOK_SLOTS:
		config.set_value("look", slot, profile[slot])
	var err: Error = config.save(PROFILE_PATH)
	assert(err == OK, "Can't write the profile %s: %s" % [PROFILE_PATH, error_string(err)])


static func look_of(profile: Dictionary) -> Dictionary:
	return {"mask": profile["mask"], "outfit": profile["outfit"], "hat": profile["hat"]}
