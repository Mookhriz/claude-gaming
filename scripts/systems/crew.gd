class_name Crew
extends Node
## Host only. Players joining and leaving, masks, weapons, looks, shooting, bags, downs, revives and getting busted.


func _ready() -> void:
	GameState.register_action("join_crew", _join_crew)
	GameState.register_action("set_mask", _set_mask)
	GameState.register_action("set_weapon", _set_weapon)
	GameState.register_action("set_look", _set_look)
	GameState.register_action("shoot", _shoot)
	GameState.register_action("throw_bag", _throw_bag)
	GameState.register_action("pick_bag", _pick_bag)
	GameState.register_action("revive", _revive)
	GameState.tick.connect(_on_tick)
	Net.peer_left.connect(_on_peer_left)


func _player(peer: int) -> Player:
	var player: Player = GameState.world.player(peer)
	assert(player != null, "Peer %d sent a request before joining the crew" % peer)
	return player


func _join_crew(peer: int, player_name: String, look: Dictionary) -> void:
	assert(GameState.world.player(peer) == null, "Peer %d joined the crew twice" % peer)
	var clean_name: String = player_name.strip_edges().left(16)
	if clean_name == "":
		clean_name = "Robber"
	GameState.world.spawn_player(peer, clean_name, GameState.wearable_look(look))
	GameState.notify_all("%s joined the crew" % clean_name, UiTheme.INFO)


func _on_peer_left(peer: int) -> void:
	var player: Player = GameState.world.player(peer)
	if player == null:
		return
	_drop_bag(player)
	GameState.notify_all("%s left the crew" % player.display_name, UiTheme.MUTED)
	player.queue_free()
	_check_all_down()


func _set_mask(peer: int, on: bool) -> void:
	var player: Player = _player(peer)
	if player.downed:
		return
	player.masked = on
	GameState.fx("sound", ["mask", player.global_position], 0)


func _set_weapon(peer: int, id: String) -> void:
	assert(Catalog.WEAPONS.has(id), "Unknown weapon '%s'" % id)
	if not GameState.owns(id):
		GameState.notify(peer, "The crew doesn't own a %s yet" % Catalog.WEAPONS[id]["name"], UiTheme.BAD)
		return
	_player(peer).weapon = id


func _set_look(peer: int, look: Dictionary) -> void:
	_player(peer).look = GameState.wearable_look(look)


## The shooter's machine already decided what each pellet hit; the host applies it.
func _shoot(peer: int, weapon: String, origin: Vector3, ends: Array, targets: Array) -> void:
	assert(Catalog.WEAPONS.has(weapon), "Unknown weapon '%s'" % weapon)
	assert(ends.size() == targets.size(), "Shot from %d has %d ends but %d targets" % [peer, ends.size(), targets.size()])
	var player: Player = _player(peer)
	if player.downed or not player.masked:
		return
	var damage: int = Catalog.WEAPONS[weapon]["damage"]
	for target: String in targets:
		if target == "":
			continue
		var npc: Npc = GameState.world.npc(target)
		if npc != null:
			npc.take_damage(damage)
	GameState.fx("shot", [origin, ends], peer)
	GameState.world.heist.on_gunfire(origin)
	GameState.world.crowd.panic(origin)


func _throw_bag(peer: int, direction: Vector3) -> void:
	var player: Player = _player(peer)
	if player.carrying == "" or player.downed:
		return
	var aim: Vector3 = direction.normalized()
	var chest: Vector3 = player.global_position + Vector3(0, 1.4, 0)
	var reach: Vector3 = Vector3(aim.x, 0, aim.z).normalized() * 0.7
	# Stop short of a wall in front, or the bag spawns inside it and pops out the far side.
	var box := BoxShape3D.new()
	box.size = LootBag.SIZE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, chest)
	query.motion = reach
	query.collision_mask = Build.WORLD_LAYER
	var start: Vector3 = chest + reach * player.get_world_3d().direct_space_state.cast_motion(query)[0]
	var bag: LootBag = GameState.world.spawn_bag(player.carrying, start, aim * Catalog.THROW_SPEED + Vector3(0, 2.5, 0))
	bag.level = player.carrying_level
	player.carrying = ""
	GameState.fx("sound", ["throw", start], 0)


func _pick_bag(peer: int, bag_name: String) -> void:
	var player: Player = _player(peer)
	var bag: LootBag = GameState.world.bag(bag_name)
	if bag == null or player.downed or player.carrying != "":
		return
	if player.global_position.distance_to(bag.global_position) > Catalog.INTERACT_RANGE + 1.5 or not bag.in_reach_of(player):
		return
	player.carrying = bag.kind
	player.carrying_level = bag.level
	bag.queue_free()
	GameState.fx("sound", ["bag", player.global_position], 0)


func _revive(peer: int, target_peer: int) -> void:
	var reviver: Player = _player(peer)
	var target: Player = GameState.world.player(target_peer)
	if target == null or not target.downed or reviver.downed:
		return
	if reviver.global_position.distance_to(target.global_position) > Catalog.INTERACT_RANGE + 1.5:
		return
	target.downed = false
	target.bleed = 0
	target.health = Catalog.REVIVE_HEALTH
	GameState.notify_all("%s revived %s" % [reviver.display_name, target.display_name], UiTheme.GOOD)
	GameState.fx("sound", ["revive", target.global_position], 0)


## Host: an NPC's bullet hit a player.
func damage_player(player: Player, amount: int) -> void:
	if player.downed:
		return
	player.health = maxi(0, player.health - amount)
	if player.health > 0:
		return
	player.downed = true
	player.bleed = Catalog.BLEED_OUT_TIME
	player.masked = false
	_drop_bag(player)
	GameState.notify_all("%s is down! Hold E on them to revive" % player.display_name, UiTheme.BAD)
	_check_all_down()


func _drop_bag(player: Player) -> void:
	if player.carrying == "":
		return
	var bag: LootBag = GameState.world.spawn_bag(player.carrying, player.global_position + Vector3(0, 1.0, 0), Vector3.ZERO)
	bag.level = player.carrying_level
	player.carrying = ""


func _check_all_down() -> void:
	var players: Array[Player] = GameState.world.players()
	if players.is_empty():
		return
	for player: Player in players:
		if not player.downed:
			return
	bust("The whole crew went down")


func _on_tick() -> void:
	var max_health: int = int(GameState.upgrade_value("armor"))
	for player: Player in GameState.world.players():
		if player.max_health != max_health:
			if not player.downed:
				player.health += max_health - player.max_health
			player.max_health = max_health
		if player.downed:
			player.bleed -= 1
			if player.bleed <= 0:
				bust("%s bled out" % player.display_name)
				return


## Everyone back to the safehouse; bail takes a cut of the crew's cash and the heat is gone.
func bust(reason: String) -> void:
	var bail: int = int(GameState.cash() * Catalog.BAIL_RATE)
	GameState.state["cash"] = GameState.cash() - bail
	GameState.mark_dirty()
	for bag: LootBag in GameState.world.bags():
		bag.queue_free()
	for player: Player in GameState.world.players():
		player.respawn()
	GameState.world.police.clear_wanted()
	GameState.announce("BUSTED", "%s. Bail cost %s." % [reason, UiTheme.money(bail)], UiTheme.BAD)
	GameState.fx("jingle", ["busted"], 0)
