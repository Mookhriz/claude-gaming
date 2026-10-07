class_name Police
extends Node
## Host only. Wanted stars, the evade meter, cop spawns and Officer Greasy's bribe.
## Stars drop one at a time while no cop or alarmed guard can see anyone.

## Where the crew was last seen. Cops with nobody in sight head here, then search around it.
var heat: Vector3 = Vector3.ZERO


func _ready() -> void:
	GameState.register_interact("greasy", _bribe)
	GameState.tick.connect(_on_tick)


func add_stars(count: int, where: Vector3) -> void:
	var was: int = GameState.wanted()
	GameState.state["wanted"] = mini(Catalog.MAX_STARS, was + count)
	GameState.state["evade"] = 0
	heat = where
	var cooldowns: Dictionary = GameState.state["cooldowns"]
	if was == 0:
		cooldowns["police"] = Catalog.POLICE_RESPONSE_TIME
	GameState.mark_dirty()
	GameState.fx("jingle", ["star_up"], 0)


func report_sighting(where: Vector3) -> void:
	heat = where


## Wipes the wanted level and sends the cops home.
func clear_wanted() -> void:
	GameState.state["wanted"] = 0
	GameState.state["evade"] = 0
	var cooldowns: Dictionary = GameState.state["cooldowns"]
	cooldowns.erase("police")
	for cop: Npc in GameState.world.npcs("cop"):
		cop.queue_free()
	GameState.mark_dirty()
	GameState.world.heist.on_clear()


func _on_tick() -> void:
	var stars: int = GameState.wanted()
	if stars == 0:
		return
	var cooldowns: Dictionary = GameState.state["cooldowns"]
	# Nobody can lose cops that haven't arrived yet.
	if cooldowns.has("police"):
		return
	_spawn_missing_cops(Catalog.COPS_BY_STARS[stars])
	if _crew_seen():
		GameState.state["evade"] = 0
	else:
		var evade: int = GameState.state["evade"]
		GameState.state["evade"] = evade + 1
		if evade + 1 >= Catalog.EVADE_TIME:
			_drop_star()
	GameState.mark_dirty()


func _drop_star() -> void:
	var stars: int = GameState.wanted() - 1
	GameState.state["wanted"] = stars
	GameState.state["evade"] = 0
	if stars == 0:
		GameState.announce("YOU LOST THE COPS", "The heat is off", UiTheme.GOOD)
		GameState.fx("jingle", ["star_down"], 0)
		clear_wanted()
	else:
		GameState.fx("jingle", ["star_down"], 0)


func _crew_seen() -> bool:
	for npc: Npc in GameState.world.npcs(""):
		if npc.sees_crew:
			return true
	return false


## Cops respond from the spawn point nearest the heat, so they reach the scene soon after they're called.
func _spawn_missing_cops(wanted_cops: int) -> void:
	var missing: int = wanted_cops - GameState.world.npcs("cop").size()
	if missing <= 0:
		return
	var spawn: Vector3 = Layout.COP_SPAWNS[0]
	for point: Vector3 in Layout.COP_SPAWNS:
		if point.distance_to(heat) < spawn.distance_to(heat):
			spawn = point
	for i: int in range(missing):
		GameState.world.spawn_npc("cop", spawn + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), 0.0)


func _bribe(peer: int) -> void:
	var cost: int = GameState.wanted() * Catalog.BRIBE_PER_STAR
	GameState.state["cash"] = GameState.cash() - cost
	var player: Player = GameState.world.player(peer)
	GameState.announce("STARS WIPED", "%s paid Officer Greasy %s" % [player.display_name, UiTheme.money(cost)], UiTheme.GOOD)
	GameState.fx("jingle", ["cash"], 0)
	clear_wanted()
