class_name World
extends Node3D
## Builds the whole town from Layout identically on every machine, spawns players, NPCs and bags,
## draws effects, and keeps the doors, drill, loot, alarm, signs and quest markers in step with the crew state.
## On the host it also runs the systems under Systems.

const NAV_CELL: float = 0.25

var hud: Hud = null

# Host only.
var crew: Crew = null
var heist: Heist = null
var police: Police = null
var jobs: Jobs = null
var quests: Quests = null
var shops: Shops = null
var casino: Casino = null
var crowd: Crowd = null

var _town: NavigationRegion3D = null
var _actors: Node3D = null
var _actor_spawner: MultiplayerSpawner = null
var _fx: Node3D = null
var _doors: Dictionary = {}
var _piles: Dictionary = {}
var _beacons: Dictionary = {}
var _drill: Node3D = null
var _drill_label: Label3D = null
var _alarm_light: OmniLight3D = null
var _closed_sign: Label3D = null
var _cat: Node3D = null
var _spawn_count: int = 0


## Replicates properties from the host to every machine. "always" props stream; "on_change" props send when they change.
static func replicate(node: Node, always: Array, on_change: Array, interval: float) -> void:
	var config := SceneReplicationConfig.new()
	for prop: String in always:
		var path := NodePath(".:" + prop)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for prop: String in on_change:
		var path := NodePath(".:" + prop)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = config
	sync.replication_interval = interval
	node.add_child(sync)


func _ready() -> void:
	GameState.world = self
	_build_environment()
	_town = NavigationRegion3D.new()
	_town.name = "Town"
	add_child(_town)
	Build.town(_town)
	Interactable.build_all(self)
	_build_state_visuals()
	_fx = Node3D.new()
	_fx.name = "Fx"
	add_child(_fx)
	_actors = Node3D.new()
	_actors.name = "Actors"
	add_child(_actors)
	_actor_spawner = MultiplayerSpawner.new()
	_actor_spawner.name = "ActorSpawner"
	_actor_spawner.spawn_function = _spawn_actor
	_actor_spawner.spawn_path = NodePath("../Actors")
	add_child(_actor_spawner)
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	GameState.state_changed.connect(_refresh_state_visuals)
	if multiplayer.is_server():
		_bake_navigation()
		_start_systems()
	# A joining client may get the world before the first state sync; state_changed draws it then.
	if not GameState.state.is_empty():
		_refresh_state_visuals()
	var profile: Dictionary = Save.load_profile()
	GameState.request("join_crew", [Net.local_name, Save.look_of(profile)])


func _exit_tree() -> void:
	if GameState.world == self:
		GameState.world = null


func _build_environment() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.35, 0.55, 0.85)
	sky.sky_horizon_color = Color(0.75, 0.8, 0.85)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _bake_navigation() -> void:
	var navmesh := NavigationMesh.new()
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = Build.WORLD_LAYER
	navmesh.cell_size = NAV_CELL
	navmesh.cell_height = NAV_CELL
	# Whole voxels, so the bake doesn't round them.
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 2.0
	navmesh.agent_max_climb = 0.25
	_town.navigation_mesh = navmesh
	_town.bake_navigation_mesh(false)


func _start_systems() -> void:
	var systems := Node.new()
	systems.name = "Systems"
	add_child(systems)
	crew = Crew.new()
	police = Police.new()
	heist = Heist.new()
	jobs = Jobs.new()
	quests = Quests.new()
	shops = Shops.new()
	casino = Casino.new()
	crowd = Crowd.new()
	for system: Node in [crew, police, heist, jobs, quests, shops, casino, crowd]:
		systems.add_child(system)


# --- Actors ---------------------------------------------------------------------

func _spawn_actor(data: Variant) -> Node:
	var args: Array = data
	var kind: String = args[0]
	match kind:
		"player":
			var new_player := Player.new()
			new_player.setup(args[1], args[2], args[3], args[4], args[5])
			return new_player
		"npc":
			var new_npc := Npc.new()
			new_npc.setup(args[1], args[2], args[3], args[4])
			return new_npc
		"bag":
			var new_bag := LootBag.new()
			new_bag.setup(args[1], args[2], args[3], args[4])
			return new_bag
	assert(false, "Unknown actor kind '%s'" % kind)
	return null


func spawn_player(peer: int, player_name: String, look: Dictionary) -> Player:
	var max_health: int = int(GameState.upgrade_value("armor"))
	return _actor_spawner.spawn(["player", peer, player_name, look, Layout.spawn_point(peer), max_health])


func spawn_npc(kind: String, pos: Vector3, yaw: float) -> Npc:
	_spawn_count += 1
	return _actor_spawner.spawn(["npc", kind, "%s_%d" % [kind, _spawn_count], pos, yaw])


func spawn_bag(kind: String, pos: Vector3, velocity: Vector3) -> LootBag:
	_spawn_count += 1
	return _actor_spawner.spawn(["bag", kind, "bag_%d" % _spawn_count, pos, velocity])


func players() -> Array[Player]:
	var out: Array[Player] = []
	for child: Node in _actors.get_children():
		if child is Player and not child.is_queued_for_deletion():
			out.append(child as Player)
	return out


func player(peer: int) -> Player:
	for each: Player in players():
		if each.peer_id == peer:
			return each
	return null


func local_player() -> Player:
	return player(multiplayer.get_unique_id())


## Every live NPC of a kind, or of every kind when kind is "".
func npcs(kind: String) -> Array[Npc]:
	var out: Array[Npc] = []
	for child: Node in _actors.get_children():
		if child is Npc and not child.is_queued_for_deletion() and (kind == "" or (child as Npc).kind == kind):
			out.append(child as Npc)
	return out


func npc(npc_name: String) -> Npc:
	var node: Node = _actors.get_node_or_null(NodePath(npc_name))
	if node is Npc and not node.is_queued_for_deletion():
		return node as Npc
	return null


func bags() -> Array[LootBag]:
	var out: Array[LootBag] = []
	for child: Node in _actors.get_children():
		if child is LootBag and not child.is_queued_for_deletion():
			out.append(child as LootBag)
	return out


func bag(bag_name: String) -> LootBag:
	var node: Node = _actors.get_node_or_null(NodePath(bag_name))
	if node is LootBag and not node.is_queued_for_deletion():
		return node as LootBag
	return null


# --- Effects --------------------------------------------------------------------

func play_fx(kind: String, args: Array) -> void:
	match kind:
		"shot":
			var origin: Vector3 = args[0]
			for end: Vector3 in args[1]:
				_tracer(origin, end)
			Sfx.play_at(_fx, "shot", origin)
		"sound":
			Sfx.play_at(_fx, args[0], args[1])
		"jingle":
			Sfx.play_ui(_fx, args[0])
		"poof":
			_poof(args[0])
		_:
			assert(false, "Unknown effect '%s'" % kind)


func _tracer(from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to)
	if length < 0.1:
		return
	var line := Build.box_mesh(Vector3(0.03, 0.03, length), Color(1.0, 0.9, 0.5))
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
	line.transform = Transform3D(Basis.looking_at(to - from, up), (from + to) / 2.0)
	_fx.add_child(line)
	get_tree().create_timer(0.06).timeout.connect(line.queue_free)


func _poof(pos: Vector3) -> void:
	var puff := SphereMesh.new()
	puff.radius = 0.6
	puff.height = 1.2
	var node := Build.mesh(puff, Color(0.7, 0.7, 0.7, 0.6))
	node.position = pos + Vector3(0, 0.8, 0)
	_fx.add_child(node)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(2, 2, 2), 0.4)
	tween.tween_callback(node.queue_free)


# --- Visuals that follow the crew state ---------------------------------------------

func _build_state_visuals() -> void:
	for id: String in Layout.DOORS:
		var def: Dictionary = Layout.DOORS[id]
		_doors[id] = Build.solid_box(self, def["center"], def["size"], def["color"])
	for id: String in Layout.ids_with_prefix("cash_pile_"):
		var pile := Node3D.new()
		pile.position = Layout.interactable_pos(id)
		add_child(pile)
		_piles[id] = pile
	_drill = Build.visual_box(self, Layout.DRILL_POS, Vector3(0.6, 0.6, 0.9), Color(0.85, 0.45, 0.1))
	_drill_label = Build.sign_label(self, "", Layout.DRILL_POS + Vector3(0.6, 0.9, 0), 0.0, 48, Color(1, 1, 1))
	_drill_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alarm_light = OmniLight3D.new()
	_alarm_light.light_color = Color(1, 0.1, 0.1)
	_alarm_light.omni_range = 30.0
	_alarm_light.position = Layout.ALARM_LIGHT_POS
	add_child(_alarm_light)
	_closed_sign = Build.sign_label(self, "", Layout.CLOSED_SIGN_POS, 180.0, 72, UiTheme.BAD)
	for quest: String in Catalog.QUESTS:
		var beacon := CylinderMesh.new()
		beacon.top_radius = 0.8
		beacon.bottom_radius = 0.8
		beacon.height = 40.0
		var node := Build.mesh(beacon, Color(1.0, 0.85, 0.2, 0.35))
		add_child(node)
		_beacons[quest] = node
	_cat = Node3D.new()
	var body := Build.box_mesh(Vector3(0.25, 0.25, 0.5), Color(0.95, 0.55, 0.15))
	body.position.y = 0.2
	_cat.add_child(body)
	var head := Build.box_mesh(Vector3(0.22, 0.22, 0.2), Color(0.95, 0.55, 0.15))
	head.position = Vector3(0, 0.38, -0.3)
	_cat.add_child(head)
	_cat.position = Layout.quest_route("cat")[0]
	add_child(_cat)


func _refresh_state_visuals() -> void:
	var bank: Dictionary = GameState.state["bank"]
	_set_door("staff_door", not bank["staff_door"])
	_set_door("vault_door", not bank["vault_open"])
	var drill: String = bank["drill"]
	_drill.visible = drill != "none" and not bank["vault_open"]
	_drill_label.visible = _drill.visible
	_drill_label.text = "JAMMED" if drill == "jammed" else "%d%%" % int(float(bank["drill_progress"]) * 100.0)
	_drill_label.modulate = UiTheme.BAD if drill == "jammed" else Color(1, 1, 1)
	var piles: Dictionary = bank["piles"]
	for id: String in _piles:
		_draw_pile(_piles[id], piles[id])
	_alarm_light.visible = bank["alarm"]
	var closed: int = bank["closed"]
	_closed_sign.visible = closed > 0
	_closed_sign.text = "CLOSED - reopens in " + UiTheme.clock(closed)
	var active: Dictionary = GameState.state["quests"]
	for quest: String in _beacons:
		var beacon: MeshInstance3D = _beacons[quest]
		beacon.visible = active.has(quest)
		if beacon.visible:
			var stage: int = active[quest]["stage"]
			beacon.position = Layout.quest_route(quest)[stage] + Vector3(0, 20, 0)
	_cat.visible = active.has("cat") and active["cat"]["stage"] == 0


func _set_door(id: String, closed: bool) -> void:
	var door: StaticBody3D = _doors[id]
	door.visible = closed
	var shape: CollisionShape3D = door.get_child(0)
	shape.set_deferred("disabled", not closed)


func _draw_pile(pile: Node3D, kind: String) -> void:
	var shown: String = pile.get_meta("kind", "")
	if shown == kind:
		return
	pile.set_meta("kind", kind)
	for child: Node in pile.get_children():
		child.free()
	if kind == "":
		return
	for i: int in range(6):
		var block := Build.box_mesh(Vector3(0.5, 0.25, 0.3), LootBag.color_of(kind))
		block.position = Vector3((i % 3) * 0.55 - 0.55, 0.125 + floori(i / 3.0) * 0.25, 0)
		pile.add_child(block)


func _process(_delta: float) -> void:
	if _alarm_light.visible:
		_alarm_light.light_energy = 2.0 + 2.0 * sin(Time.get_ticks_msec() / 120.0)
