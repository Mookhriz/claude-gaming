class_name Npc
extends CharacterBody3D
## Civilians, guards and cops. The host runs the sight-based AI and decides NPC hits; every machine draws them.

const NPC_LAYER: int = 4
const EYE_HEIGHT: float = 1.6

var kind: String = "civilian"

# Host-owned and replicated.
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var health: int = 1
## calm, alert or flee. Drives the "!" over the head.
var mood: String = "calm"

## Host: true while this is a cop, or a guard after the alarm, who can see a crew member.
var sees_crew: bool = false

# Host AI.
var _agent: NavigationAgent3D = null
var _post_yaw: float = 0.0
var _detect: float = 0.0
var _fire_cooldown: float = 0.0
var _repath: float = 0.0
var _sight_timer: float = 0.0
var _visible: Array[Player] = []
var _goal: Vector3 = Vector3.ZERO
var _last_heat: Vector3 = Vector3.INF
var _panic: float = 0.0
var _flee_from: Vector3 = Vector3.ZERO

# Visuals.
var _alert_label: Label3D = null


func setup(npc_kind: String, npc_name: String, pos: Vector3, yaw: float) -> void:
	assert(Catalog.NPC_HEALTH.has(npc_kind), "Unknown NPC kind '%s'" % npc_kind)
	kind = npc_kind
	name = npc_name
	position = pos
	rotation.y = yaw
	net_pos = pos
	net_yaw = yaw
	_post_yaw = yaw
	_goal = pos
	health = Catalog.NPC_HEALTH[kind]
	collision_layer = NPC_LAYER
	collision_mask = Build.WORLD_LAYER
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	World.replicate(self, ["net_pos", "net_yaw"], ["health", "mood"], 0.05)


func _ready() -> void:
	_build_model()
	if multiplayer.is_server():
		_agent = NavigationAgent3D.new()
		_agent.radius = 0.4
		_agent.height = 1.8
		_agent.path_desired_distance = 0.8
		_agent.target_desired_distance = 1.2
		add_child(_agent)


func _process(_delta: float) -> void:
	_alert_label.visible = mood != "calm"


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		_follow(delta)
		return
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_repath -= delta
	match kind:
		"guard":
			_see(delta)
			_guard(delta)
		"cop":
			_see(delta)
			_cop(delta)
		"civilian":
			_civilian(delta)
	net_pos = position
	net_yaw = rotation.y


func _follow(delta: float) -> void:
	var weight: float = 1.0 - exp(-12.0 * delta)
	position = position.lerp(net_pos, weight)
	rotation.y = lerp_angle(rotation.y, net_yaw, weight)


# --- Host AI --------------------------------------------------------------------

func _see(delta: float) -> void:
	# A crewmate who left since the last look is freed; forget them now, not at the next look.
	for i: int in range(_visible.size() - 1, -1, -1):
		if not is_instance_valid(_visible[i]) or _visible[i].is_queued_for_deletion():
			_visible.remove_at(i)
	_sight_timer -= delta
	if _sight_timer > 0.0:
		return
	_sight_timer = 0.1
	_visible.clear()
	var eye: Vector3 = global_position + Vector3(0, EYE_HEIGHT, 0)
	var forward: Vector3 = -global_transform.basis.z
	var half_fov: float = deg_to_rad(Catalog.NPC_FOV_DEGREES) / 2.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for player: Player in GameState.world.players():
		if player.downed:
			continue
		var target: Vector3 = player.global_position + Vector3(0, 1.4, 0)
		var to: Vector3 = target - eye
		if to.length() > Catalog.NPC_SIGHT_RANGE:
			continue
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > 0.5 and forward.angle_to(flat) > half_fov:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, target, Build.WORLD_LAYER)
		if space.intersect_ray(query).is_empty():
			_visible.append(player)


func _guard(delta: float) -> void:
	var alarm: bool = GameState.state["bank"]["alarm"]
	sees_crew = alarm and not _visible.is_empty()
	var masked: Array[Player] = []
	for player: Player in _visible:
		if player.masked:
			masked.append(player)
	var target: Player = _nearest(masked)
	if not alarm:
		if target == null:
			_detect = maxf(0.0, _detect - delta)
			if _detect == 0.0:
				mood = "calm"
				rotation.y = lerp_angle(rotation.y, _post_yaw, 1.0 - exp(-3.0 * delta))
			return
		mood = "alert"
		_face(target.global_position, delta)
		_detect += delta
		if _detect >= Catalog.GUARD_DETECT_TIME:
			GameState.world.heist.raise_alarm("A guard spotted a mask!", target.global_position)
		return
	mood = "alert"
	if target == null:
		return
	_face(target.global_position, delta)
	if _fire_cooldown == 0.0 and global_position.distance_to(target.global_position) <= Catalog.NPC_SHOOT_RANGE:
		_shoot_at(target)


func _cop(delta: float) -> void:
	sees_crew = not _visible.is_empty()
	mood = "alert"
	var target: Player = _nearest(_visible)
	if target != null:
		GameState.world.police.report_sighting(target.global_position)
		_face(target.global_position, delta)
		if global_position.distance_to(target.global_position) <= Catalog.NPC_SHOOT_RANGE:
			velocity = Vector3.ZERO
			if _fire_cooldown == 0.0:
				_shoot_at(target)
			return
		if _repath <= 0.0:
			_repath = 0.5
			_agent.target_position = target.global_position
		_step(Catalog.NPC_SPEED[kind], delta)
		return
	# Nobody in sight: head for the last sighting, then search the streets around it.
	if _repath <= 0.0:
		_repath = 0.5
		var heat: Vector3 = GameState.world.police.heat
		if heat != _last_heat:
			_last_heat = heat
			_goal = heat
		elif _agent.is_navigation_finished():
			_goal = _walk_point_near(heat, 40.0)
		_agent.target_position = _goal
	_step(Catalog.NPC_SPEED[kind], delta)


func _civilian(delta: float) -> void:
	var speed: float = Catalog.NPC_SPEED[kind]
	if _panic > 0.0:
		_panic -= delta
		mood = "flee"
		speed = Catalog.CIVILIAN_RUN_SPEED
		if _repath <= 0.0:
			_repath = 2.0
			_goal = _walk_point_away(_flee_from)
			_agent.target_position = _goal
	else:
		mood = "calm"
		if _repath <= 0.0 and _agent.is_navigation_finished():
			_repath = 0.5
			_goal = Layout.walk_points().pick_random()
			_agent.target_position = _goal
	_step(speed, delta)


func _step(speed: float, delta: float) -> void:
	if _agent.is_navigation_finished():
		velocity = Vector3.ZERO
		return
	var dir: Vector3 = _agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	velocity = dir * speed
	_face(global_position + dir, delta)
	move_and_slide()


func _face(target: Vector3, delta: float) -> void:
	var to: Vector3 = target - global_position
	if Vector2(to.x, to.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-10.0 * delta))


func _nearest(players: Array[Player]) -> Player:
	var best: Player = null
	var best_distance: float = INF
	for player: Player in players:
		var distance: float = global_position.distance_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = player
	return best


func _walk_point_near(center: Vector3, radius: float) -> Vector3:
	var near: Array[Vector3] = []
	for point: Vector3 in Layout.walk_points():
		if point.distance_to(center) <= radius:
			near.append(point)
	if near.is_empty():
		return center
	return near.pick_random()


func _walk_point_away(danger: Vector3) -> Vector3:
	var best: Vector3 = global_position
	var best_distance: float = -1.0
	for i: int in range(4):
		var point: Vector3 = Layout.walk_points().pick_random()
		var distance: float = point.distance_to(danger)
		if distance > best_distance:
			best_distance = distance
			best = point
	return best


func _shoot_at(player: Player) -> void:
	_fire_cooldown = Catalog.NPC_FIRE_INTERVAL[kind]
	var from: Vector3 = global_position + Vector3(0, 1.3, 0) - global_transform.basis.z * 0.5
	var aim: Vector3 = player.global_position + Vector3(0, 1.1, 0)
	var closeness: float = clampf(from.distance_to(aim) / Catalog.NPC_SHOOT_RANGE, 0.0, 1.0)
	var hit: bool = randf() < lerpf(Catalog.NPC_HIT_CHANCE_NEAR, Catalog.NPC_HIT_CHANCE_FAR, closeness)
	if not hit:
		aim += Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5))
	GameState.fx("shot", [from, [aim]], 0)
	if hit:
		GameState.world.crew.damage_player(player, Catalog.NPC_DAMAGE[kind])


## Host: a crew member's bullet hit this NPC.
func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	match kind:
		"guard":
			GameState.world.heist.raise_alarm("A guard was shot!", global_position)
		"civilian":
			panic(global_position)
	if health <= 0:
		_die()


## Host: run from danger for a while. Civilians only.
func panic(from: Vector3) -> void:
	_panic = Catalog.CIVILIAN_PANIC_TIME
	_flee_from = from
	_repath = 0.0


func _die() -> void:
	GameState.fx("poof", [global_position], 0)
	if kind == "civilian":
		GameState.world.police.add_stars(Catalog.CIVILIAN_KILL_STARS, global_position)
	queue_free()


# --- Model ----------------------------------------------------------------------

func _build_model() -> void:
	var color: Color
	match kind:
		"guard":
			color = Color(0.45, 0.48, 0.52)
		"cop":
			color = Color(0.12, 0.17, 0.38)
		"civilian":
			color = Color.from_hsv(float(absi(String(name).hash()) % 360) / 360.0, 0.45, 0.75)
	var torso := CapsuleMesh.new()
	torso.radius = 0.35
	torso.height = 1.3
	var torso_node := Build.mesh(torso, color)
	torso_node.position.y = 0.75
	add_child(torso_node)
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	var head_node := Build.mesh(head, Player.SKIN)
	head_node.position.y = 1.62
	add_child(head_node)
	if kind != "civilian":
		var cap := CylinderMesh.new()
		cap.top_radius = 0.2
		cap.bottom_radius = 0.24
		cap.height = 0.12
		var cap_node := Build.mesh(cap, color.darkened(0.4))
		cap_node.position.y = 1.85
		add_child(cap_node)
		var gun := Build.box_mesh(Vector3(0.08, 0.12, 0.45), Color(0.1, 0.1, 0.1))
		gun.position = Vector3(0.3, 1.2, -0.35)
		add_child(gun)
	_alert_label = Build.sign_label(self, "!", Vector3(0, 2.3, 0), 0.0, 72, UiTheme.BAD)
	_alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert_label.visible = false
