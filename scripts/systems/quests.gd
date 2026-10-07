class_name Quests
extends Node
## Host only. Side quests from Tony, Granny Mabel and Zippy. Talking to the giver starts one;
## any crew member walking through each stop on its route moves it along.


func _ready() -> void:
	for quest: String in Catalog.QUESTS:
		GameState.register_interact("quest_" + quest, _start.bind(quest))
	GameState.tick.connect(_on_tick)


func _active() -> Dictionary:
	return GameState.state["quests"]


func _start(_peer: int, quest: String) -> void:
	var def: Dictionary = Catalog.QUESTS[quest]
	_active()[quest] = {"stage": 0, "time": def["time_limit"]}
	GameState.mark_dirty()
	GameState.notify_all("%s: \"%s\"" % [def["giver"], def["brief"]], UiTheme.INFO)
	GameState.fx("jingle", ["notify"], 0)


func _physics_process(_delta: float) -> void:
	var active: Dictionary = _active()
	for quest: String in active.keys():
		var stage: int = active[quest]["stage"]
		var stop: Vector3 = Layout.quest_route(quest)[stage]
		for player: Player in GameState.world.players():
			var flat := Vector2(player.global_position.x - stop.x, player.global_position.z - stop.z)
			if not player.downed and flat.length() <= Catalog.QUEST_STOP_RADIUS:
				_advance(quest)
				break


func _advance(quest: String) -> void:
	var progress: Dictionary = _active()[quest]
	var stage: int = progress["stage"] + 1
	var route: Array[Vector3] = Layout.quest_route(quest)
	if stage >= route.size():
		_finish(quest, true)
		return
	progress["stage"] = stage
	GameState.mark_dirty()
	GameState.notify_all("%s: stop %d of %d done" % [Catalog.QUESTS[quest]["title"], stage, route.size()], UiTheme.INFO)
	GameState.fx("jingle", ["notify"], 0)


func _finish(quest: String, success: bool) -> void:
	var def: Dictionary = Catalog.QUESTS[quest]
	_active().erase(quest)
	var cooldowns: Dictionary = GameState.state["cooldowns"]
	cooldowns["quest_" + quest] = def["cooldown"]
	if success:
		var reward: int = def["reward"]
		GameState.state["cash"] = GameState.cash() + reward
		GameState.announce("QUEST COMPLETE", "%s: %s" % [def["title"], UiTheme.money(reward)], UiTheme.MONEY)
		GameState.fx("jingle", ["win"], 0)
	else:
		GameState.announce("QUEST FAILED", "%s: out of time" % def["title"], UiTheme.BAD)
		GameState.fx("jingle", ["lose"], 0)
	GameState.mark_dirty()


func _on_tick() -> void:
	var active: Dictionary = _active()
	for quest: String in active.keys():
		var progress: Dictionary = active[quest]
		var time: int = progress["time"]
		if time == 0:
			continue
		progress["time"] = time - 1
		GameState.mark_dirty()
		if time - 1 == 0:
			_finish(quest, false)
