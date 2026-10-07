class_name Heist
extends Node
## Host only. First National: guards, the staff door, the drill, the vault, loot, deliveries,
## and the bank closing once the crew is clear, then reopening one security level tougher.


func _ready() -> void:
	GameState.register_interact("staff_door", _pick_staff_door)
	GameState.register_interact("vault_door", _work_vault_door)
	for id: String in Layout.ids_with_prefix("cash_pile_"):
		GameState.register_interact(id, _bag_pile.bind(id))
	GameState.tick.connect(_on_tick)
	_open_bank()


func _bank() -> Dictionary:
	return GameState.state["bank"]


func _level() -> int:
	return _bank()["level"]


## Resets the bank at its current level: doors shut, vault stocked, guards at their posts.
## Anyone still behind the staff door gets walked out first, or they'd be locked in.
func _open_bank() -> void:
	var bank: Dictionary = _bank()
	var level: int = bank["level"]
	bank["alarm"] = false
	bank["staff_door"] = false
	bank["drill"] = "none"
	bank["drill_progress"] = 0.0
	bank["vault_open"] = false
	bank["closed"] = 0
	var piles: Dictionary = bank["piles"]
	var ids: Array[String] = Layout.ids_with_prefix("cash_pile_")
	var cash_piles: int = Catalog.BANK_CASH_PILES[level]
	var gold_piles: int = Catalog.BANK_GOLD_PILES[level]
	assert(cash_piles + gold_piles <= ids.size(), "Level %d wants %d piles but the vault has %d spots" % [level, cash_piles + gold_piles, ids.size()])
	for i: int in range(ids.size()):
		if i < cash_piles:
			piles[ids[i]] = "cash"
		elif i < cash_piles + gold_piles:
			piles[ids[i]] = "gold"
		else:
			piles[ids[i]] = ""
	for player: Player in GameState.world.players():
		if Layout.behind_staff_door(player.global_position):
			player.respawn()
			GameState.notify(player.peer_id, "Security walked you out of the bank", UiTheme.WARN)
	_despawn_guards()
	var guards: int = Catalog.BANK_GUARDS[level]
	assert(guards <= Layout.GUARD_POSTS.size(), "Level %d wants %d guards but there are %d posts" % [level, guards, Layout.GUARD_POSTS.size()])
	for i: int in range(guards):
		var post: Array = Layout.GUARD_POSTS[i]
		GameState.world.spawn_npc("guard", post[0], deg_to_rad(post[1]))
	GameState.mark_dirty()


func _despawn_guards() -> void:
	for guard: Npc in GameState.world.npcs("guard"):
		guard.queue_free()


## Sounds the alarm. The police head for where, so it should be where the trouble is.
func raise_alarm(reason: String, where: Vector3) -> void:
	var bank: Dictionary = _bank()
	if bank["alarm"] or bank["closed"] > 0:
		return
	bank["alarm"] = true
	GameState.mark_dirty()
	GameState.announce("ALARM", reason, UiTheme.BAD)
	GameState.fx("jingle", ["alarm"], 0)
	GameState.world.police.add_stars(Catalog.BANK_ALARM_STARS, where)


func on_gunfire(pos: Vector3) -> void:
	if Layout.in_bank(pos):
		raise_alarm("Gunshots inside the bank!", pos)


func _pick_staff_door(_peer: int) -> void:
	_bank()["staff_door"] = true
	GameState.mark_dirty()
	GameState.fx("sound", ["door", Layout.interactable_pos("staff_door")], 0)


func _work_vault_door(peer: int) -> void:
	var bank: Dictionary = _bank()
	match bank["drill"]:
		"none":
			bank["drill"] = "running"
			GameState.mark_dirty()
			GameState.fx("sound", ["drill", Layout.DRILL_POS], 0)
			raise_alarm("The drill tripped the alarm!", Layout.DRILL_POS)
		"jammed":
			bank["drill"] = "running"
			GameState.mark_dirty()
			GameState.notify(peer, "Drill fixed", UiTheme.GOOD)
			GameState.fx("sound", ["drill", Layout.DRILL_POS], 0)


func _bag_pile(peer: int, id: String) -> void:
	var player: Player = GameState.world.player(peer)
	var piles: Dictionary = _bank()["piles"]
	player.carrying = piles[id]
	player.carrying_level = _level()
	piles[id] = ""
	GameState.mark_dirty()
	GameState.fx("sound", ["bag", player.global_position], 0)


func _on_tick() -> void:
	var bank: Dictionary = _bank()
	var closed: int = bank["closed"]
	if closed > 0:
		bank["closed"] = closed - 1
		GameState.mark_dirty()
		if closed == 1:
			bank["level"] = mini(_level() + 1, Catalog.BANK_MAX_LEVEL)
			_open_bank()
			GameState.announce("FIRST NATIONAL REOPENED", "Security level %d. More guards, more loot." % _level(), UiTheme.WARN)
		return
	if bank["drill"] != "running":
		return
	if randf() < Catalog.DRILL_JAM_CHANCE[_level()]:
		bank["drill"] = "jammed"
		GameState.notify_all("The drill jammed! Hold E on the vault door to fix it", UiTheme.WARN)
		GameState.fx("sound", ["jam", Layout.DRILL_POS], 0)
	else:
		var progress: float = bank["drill_progress"]
		progress += GameState.upgrade_value("drill") / float(Catalog.DRILL_TIME[_level()])
		bank["drill_progress"] = minf(progress, 1.0)
		if progress >= 1.0:
			bank["drill"] = "done"
			bank["vault_open"] = true
			GameState.announce("VAULT OPEN", "Bag the loot and get it to the van or the safehouse", UiTheme.MONEY)
			GameState.fx("sound", ["door", Layout.DRILL_POS], 0)
	GameState.mark_dirty()


## Loot that reaches the van zone or the safehouse stash counts for the crew.
func _physics_process(_delta: float) -> void:
	for player: Player in GameState.world.players():
		if player.carrying != "" and not player.downed and Layout.in_delivery_zone(player.global_position):
			_deliver(player.carrying, player.carrying_level, player.display_name)
			player.carrying = ""
	for bag: LootBag in GameState.world.bags():
		if Layout.in_delivery_zone(bag.global_position):
			_deliver(bag.kind, bag.level, "A thrown bag")
			bag.queue_free()


## Loot is worth what it was worth in the vault it came from, not what the bank holds today.
func _deliver(kind: String, level: int, by: String) -> void:
	var value: int = Catalog.BAG_VALUE[kind][level]
	GameState.state["cash"] = GameState.cash() + value
	GameState.mark_dirty()
	GameState.notify_all("%s delivered %s of %s" % [by, UiTheme.money(value), kind], UiTheme.MONEY)
	GameState.fx("jingle", ["deliver"], 0)


## Called by the police once the wanted level is gone. After an alarm, the bank closes for a while.
func on_clear() -> void:
	var bank: Dictionary = _bank()
	if not bank["alarm"]:
		return
	bank["alarm"] = false
	bank["closed"] = Catalog.BANK_CLOSED_TIME
	_despawn_guards()
	GameState.mark_dirty()
	GameState.announce("FIRST NATIONAL CLOSED", "Reopening in %d seconds with tighter security" % Catalog.BANK_CLOSED_TIME, UiTheme.INFO)
