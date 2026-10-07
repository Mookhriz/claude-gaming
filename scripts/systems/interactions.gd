class_name Interactions
extends RefCounted
## The rule for every interactable. The client draws the prompt from it; the host checks it again before acting.
## A rule is {"visible": bool, "allowed": bool, "text": String, "hold": float seconds}.


static func describe(id: String, player: Player) -> Dictionary:
	if player.downed:
		return _hidden()
	if id.begins_with("cash_pile_"):
		return _pile(id, player)
	if id.begins_with("atm_"):
		return _atm(id, player)
	if id.begins_with("quest_"):
		return _quest(id.trim_prefix("quest_"), player)
	match id:
		"armory", "workshop", "tailor":
			return _venue(id, player, "Browse " + Layout.INTERACTABLES[id]["label"])
		"slots":
			return _venue(id, player, "Play the slots")
		"roulette":
			return _venue(id, player, "Play roulette")
		"store":
			return _store(player)
		"staff_door":
			return _staff_door(player)
		"vault_door":
			return _vault_door(player)
		"greasy":
			return _greasy(player)
	assert(false, "No rule for interactable '%s'" % id)
	return _hidden()


static func _rule(text: String, allowed: bool, hold: float) -> Dictionary:
	return {"visible": true, "allowed": allowed, "text": text, "hold": hold}


static func _hidden() -> Dictionary:
	return {"visible": false, "allowed": false, "text": "", "hold": 0.0}


static func _bank() -> Dictionary:
	return GameState.state["bank"]


static func _cooldown(key: String) -> int:
	var cooldowns: Dictionary = GameState.state["cooldowns"]
	if cooldowns.has(key):
		return cooldowns[key]
	return 0


static func _venue(_id: String, player: Player, text: String) -> Dictionary:
	if player.masked:
		return _rule("Take your mask off first (F)", false, 0.0)
	return _rule(text, true, 0.0)


static func _store(player: Player) -> Dictionary:
	var left: int = _cooldown("store")
	if left > 0:
		return _rule("The register is empty (%ds)" % left, false, 0.0)
	if not player.masked:
		return _rule("Mask up to rob the store (F)", false, 0.0)
	return _rule("Rob Grab-N-Dash", true, Catalog.STORE_TIME)


static func _atm(id: String, player: Player) -> Dictionary:
	if GameState.upgrade_level("hacker_kit") == 0:
		return _rule("ATM: needs a Hacker Kit from Fixit Fred's", false, 0.0)
	var left: int = _cooldown(id)
	if left > 0:
		return _rule("ATM drained (%ds)" % left, false, 0.0)
	if not player.masked:
		return _rule("Mask up to skim the ATM (F)", false, 0.0)
	return _rule("Skim the ATM", true, Catalog.ATM_TIME)


static func _staff_door(player: Player) -> Dictionary:
	var bank: Dictionary = _bank()
	if bank["staff_door"]:
		return _hidden()
	if bank["closed"] > 0:
		return _rule("The bank is closed", false, 0.0)
	if not player.masked:
		return _rule("Staff only. Mask up to pick the lock (F)", false, 0.0)
	return _rule("Pick the lock", true, Catalog.LOCKPICK_TIME * GameState.upgrade_value("lockpick"))


static func _vault_door(player: Player) -> Dictionary:
	var bank: Dictionary = _bank()
	if bank["vault_open"]:
		return _hidden()
	if bank["closed"] > 0:
		return _rule("The bank is closed", false, 0.0)
	if not player.masked:
		return _rule("Mask up first (F)", false, 0.0)
	match bank["drill"]:
		"none":
			return _rule("Place the drill", true, Catalog.DRILL_PLACE_TIME)
		"running":
			return _rule("Drilling... %d%%" % int(float(bank["drill_progress"]) * 100.0), false, 0.0)
		"jammed":
			return _rule("Fix the jammed drill", true, Catalog.DRILL_FIX_TIME)
	assert(false, "Unknown drill state '%s'" % bank["drill"])
	return _hidden()


static func _pile(id: String, player: Player) -> Dictionary:
	var bank: Dictionary = _bank()
	var piles: Dictionary = bank["piles"]
	var kind: String = piles[id]
	if kind == "" or not bank["vault_open"]:
		return _hidden()
	if player.carrying != "":
		return _rule("Your hands are full (G to throw)", false, 0.0)
	if not player.masked:
		return _rule("Mask up first (F)", false, 0.0)
	return _rule("Bag the %s" % kind, true, Catalog.BAG_TIME)


static func _greasy(player: Player) -> Dictionary:
	if player.masked:
		return _rule("Greasy won't talk to a mask", false, 0.0)
	var stars: int = GameState.wanted()
	if stars == 0:
		return _rule("Officer Greasy: \"Nothing to wipe, pal.\"", false, 0.0)
	var cost: int = stars * Catalog.BRIBE_PER_STAR
	if GameState.cash() < cost:
		return _rule("Bribe Officer Greasy: %s (not enough cash)" % UiTheme.money(cost), false, 0.0)
	return _rule("Bribe Officer Greasy to wipe your stars: %s" % UiTheme.money(cost), true, 0.0)


static func _quest(quest: String, player: Player) -> Dictionary:
	assert(Catalog.QUESTS.has(quest), "Unknown quest '%s'" % quest)
	var def: Dictionary = Catalog.QUESTS[quest]
	var giver: String = def["giver"]
	if player.masked:
		return _rule("%s won't talk to a mask" % giver, false, 0.0)
	var quests: Dictionary = GameState.state["quests"]
	if quests.has(quest):
		return _rule("%s: \"Well? Get going!\"" % giver, false, 0.0)
	var left: int = _cooldown("quest_" + quest)
	if left > 0:
		return _rule("%s: \"Come back later.\" (%ds)" % [giver, left], false, 0.0)
	return _rule("Talk to %s: %s (%s)" % [giver, def["title"], UiTheme.money(def["reward"])], true, 0.0)
