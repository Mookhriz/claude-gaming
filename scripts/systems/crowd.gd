class_name Crowd
extends Node
## Host only. Civilians wandering the sidewalks, panicking at gunfire, replaced over time when they die.

var _respawn_wait: int = 0


func _ready() -> void:
	for i: int in range(Catalog.CIVILIAN_COUNT):
		_spawn_civilian()
	GameState.tick.connect(_on_tick)


func _spawn_civilian() -> void:
	var point: Vector3 = Layout.walk_points().pick_random()
	GameState.world.spawn_npc("civilian", point, randf_range(-PI, PI))


func _on_tick() -> void:
	if GameState.world.npcs("civilian").size() >= Catalog.CIVILIAN_COUNT:
		_respawn_wait = Catalog.CIVILIAN_RESPAWN_TIME
		return
	_respawn_wait -= 1
	if _respawn_wait <= 0:
		_respawn_wait = Catalog.CIVILIAN_RESPAWN_TIME
		_spawn_civilian()


func panic(pos: Vector3) -> void:
	for civilian: Npc in GameState.world.npcs("civilian"):
		if civilian.global_position.distance_to(pos) <= Catalog.CIVILIAN_PANIC_RADIUS:
			civilian.panic(pos)
