class_name Player
extends CharacterBody3D
## A crew member. The owner's machine moves it, aims and decides hits. The host owns everything else
## (health, downs, mask, weapon, bag, look) and replicates it to every machine.

const PLAYER_LAYER: int = 2
const NPC_LAYER: int = 4
const EYE_HEIGHT: float = 1.6
const SKIN: Color = Color(0.9, 0.75, 0.6)

# Set at spawn on every machine.
var peer_id: int = 0
var display_name: String = ""

# Host-owned and replicated.
var net_pos: Vector3 = Vector3.ZERO
var net_yaw: float = 0.0
var max_health: int = 100
var health: int = 100
var downed: bool = false
var bleed: int = 0
var masked: bool = false
var carrying: String = ""
var weapon: String = "pistol"
var look: Dictionary = {}

# Owner only.
var _pitch: Node3D = null
var _camera: Camera3D = null
var _ammo: Dictionary = {}
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0
var _hold_key: String = ""
var _hold_time: float = 0.0
var _hold_spent: bool = false
var _last_health: int = 0
var _gravity: float = 9.8

# Visuals on every machine.
var _model: Node3D = null
var _name_label: Label3D = null
var _shown: String = ""


func setup(peer: int, player_name: String, player_look: Dictionary, pos: Vector3, health_max: int) -> void:
	Catalog.assert_look(player_look)
	peer_id = peer
	name = "P%d" % peer
	display_name = player_name
	look = player_look
	position = pos
	net_pos = pos
	max_health = health_max
	health = health_max
	collision_layer = PLAYER_LAYER
	collision_mask = Build.WORLD_LAYER
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	World.replicate(self, ["net_pos", "net_yaw"], ["max_health", "health", "downed", "bleed", "masked", "carrying", "weapon", "look"], 0.03)


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	if is_local():
		_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		_last_health = health
		for id: String in Catalog.WEAPON_ORDER:
			_ammo[id] = Catalog.WEAPONS[id]["mag"]
		_build_camera()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		set_process_unhandled_input(false)
		_name_label = Build.sign_label(self, display_name, Vector3(0, 2.25, 0), 0.0, 36, Color(1, 1, 1))
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func is_local() -> bool:
	return peer_id == multiplayer.get_unique_id()


func ammo_left() -> int:
	return _ammo[weapon]


func reloading() -> bool:
	return _reload_left > 0.0


# --- Movement -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_local():
		_move(delta)
	elif not multiplayer.is_server():
		_follow(delta)


func _move(delta: float) -> void:
	var input := Vector2.ZERO
	var free: bool = not downed and not GameState.world.hud.captures_input()
	if free:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir: Vector3 = global_transform.basis * Vector3(input.x, 0, input.y)
	var speed: float = _speed()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif free and Input.is_action_just_pressed("jump"):
		velocity.y = Catalog.JUMP_VELOCITY
	move_and_slide()
	if multiplayer.is_server():
		net_pos = position
		net_yaw = rotation.y
	else:
		_submit_motion.rpc_id(1, position, rotation.y)


func _speed() -> float:
	var speed: float = Catalog.WALK_SPEED
	if Input.is_action_pressed("sprint"):
		speed = Catalog.SPRINT_SPEED * GameState.upgrade_value("sneakers")
	if carrying != "":
		var penalty: float = Catalog.CARRY_PENALTY[carrying]
		speed *= 1.0 - penalty * GameState.upgrade_value("duffel")
	return speed


func _follow(delta: float) -> void:
	if position.distance_to(net_pos) > 6.0:
		position = net_pos
	var weight: float = 1.0 - exp(-15.0 * delta)
	position = position.lerp(net_pos, weight)
	rotation.y = lerp_angle(rotation.y, net_yaw, weight)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_motion(pos: Vector3, yaw: float) -> void:
	assert(multiplayer.get_remote_sender_id() == peer_id, "Peer %d tried to move %s" % [multiplayer.get_remote_sender_id(), name])
	position = pos
	rotation.y = yaw
	net_pos = pos
	net_yaw = yaw


## Host: sends the player back to the safehouse, healthy and empty-handed.
func respawn() -> void:
	health = max_health
	downed = false
	bleed = 0
	carrying = ""
	masked = false
	place(Layout.spawn_point(peer_id))


## Host: moves the player. The owner's machine is told, since it drives the position.
func place(pos: Vector3) -> void:
	position = pos
	net_pos = pos
	if is_local():
		velocity = Vector3.ZERO
	else:
		_teleport.rpc_id(peer_id, pos)


@rpc("authority", "call_remote", "reliable")
func _teleport(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO


# --- Owner controls ---------------------------------------------------------------

func _build_camera() -> void:
	_pitch = Node3D.new()
	_pitch.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(_pitch)
	var arm := SpringArm3D.new()
	arm.spring_length = 3.2
	arm.margin = 0.2
	arm.position = Vector3(0.55, 0.15, 0)
	arm.collision_mask = Build.WORLD_LAYER
	arm.add_excluded_object(get_rid())
	_pitch.add_child(arm)
	_camera = Camera3D.new()
	arm.add_child(_camera)
	_camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not event is InputEventMouseMotion:
		return
	var motion: InputEventMouseMotion = event
	rotate_y(-motion.relative.x * Catalog.MOUSE_SENSITIVITY)
	_pitch.rotation.x = clampf(_pitch.rotation.x - motion.relative.y * Catalog.MOUSE_SENSITIVITY, -1.2, 0.9)


func _process(delta: float) -> void:
	_refresh_model()
	if not is_local():
		return
	_react_to_damage()
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_ammo[weapon] = Catalog.WEAPONS[weapon]["mag"]
	var hud: Hud = GameState.world.hud
	if downed or hud.captures_input():
		_clear_hold()
		hud.set_focus("", false, 0.0)
		return
	if Input.is_action_just_pressed("mask"):
		GameState.request("set_mask", [not masked])
	for i: int in range(Catalog.WEAPON_ORDER.size()):
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			_select_weapon(Catalog.WEAPON_ORDER[i])
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	if Input.is_action_just_pressed("throw") and carrying != "":
		GameState.request("throw_bag", [-_camera.global_transform.basis.z])
	var automatic: bool = Catalog.WEAPONS[weapon]["auto"]
	if Input.is_action_just_pressed("shoot") or (automatic and Input.is_action_pressed("shoot")):
		_shoot()
	_update_focus(delta)


func _react_to_damage() -> void:
	if health < _last_health:
		Sfx.play_ui(self, "down" if health == 0 else "hurt")
		GameState.world.hud.flash_damage()
	_last_health = health


func _select_weapon(id: String) -> void:
	if not GameState.owns(id):
		GameState.world.hud.flash_hint("Buy the %s at Pew Pew Pawn" % Catalog.WEAPONS[id]["name"])
		return
	if id != weapon:
		_reload_left = 0.0
		GameState.request("set_weapon", [id])


func _start_reload() -> void:
	var mag: int = Catalog.WEAPONS[weapon]["mag"]
	if _reload_left > 0.0 or _ammo[weapon] == mag:
		return
	_reload_left = Catalog.WEAPONS[weapon]["reload"]
	Sfx.play_ui(self, "click")


func _shoot() -> void:
	if not masked:
		if Input.is_action_just_pressed("shoot"):
			GameState.world.hud.flash_hint("Mask up to shoot (F)")
		return
	if _fire_cooldown > 0.0 or _reload_left > 0.0:
		return
	if _ammo[weapon] <= 0:
		_start_reload()
		return
	var def: Dictionary = Catalog.WEAPONS[weapon]
	_ammo[weapon] -= 1
	_fire_cooldown = def["interval"]
	var spread: float = def["spread"]
	var reach: float = def["range"]
	var center: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var ray_dir: Vector3 = _camera.project_ray_normal(center)
	var ray_from: Vector3 = _camera.project_ray_origin(center)
	# Start at the player, so nothing between the camera and the player gets hit.
	ray_from += ray_dir * ray_from.distance_to(global_position + Vector3(0, EYE_HEIGHT, 0))
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ends: Array = []
	var targets: Array = []
	for i: int in range(def["pellets"]):
		var jitter := Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
		var to: Vector3 = ray_from + (ray_dir + jitter).normalized() * reach
		var query := PhysicsRayQueryParameters3D.create(ray_from, to, Build.WORLD_LAYER | NPC_LAYER, [get_rid()])
		var hit: Dictionary = space.intersect_ray(query)
		var target: String = ""
		if not hit.is_empty():
			to = hit["position"]
			var collider: Object = hit["collider"]
			if collider is Npc:
				target = (collider as Npc).name
		ends.append(to)
		targets.append(target)
	var origin: Vector3 = muzzle()
	GameState.world.play_fx("shot", [origin, ends])
	GameState.request("shoot", [weapon, origin, ends, targets])
	if _ammo[weapon] == 0:
		_start_reload()


func muzzle() -> Vector3:
	return global_position + Vector3(0, 1.3, 0) + global_transform.basis * Vector3(0.3, 0, -0.6)


# --- Interacting ------------------------------------------------------------------

func _update_focus(delta: float) -> void:
	var hud: Hud = GameState.world.hud
	var focus: Dictionary = _find_focus()
	if focus.is_empty():
		_clear_hold()
		hud.set_focus("", false, 0.0)
		return
	var key: String = focus["key"]
	var hold: float = focus["hold"]
	if not Input.is_action_pressed("interact") or not focus["allowed"]:
		_clear_hold()
	elif not _hold_spent:
		if key != _hold_key:
			_hold_key = key
			_hold_time = 0.0
		_hold_time += delta
		if _hold_time >= hold:
			_hold_spent = true
			_act(focus)
	var progress: float = 0.0
	if hold > 0.0 and key == _hold_key and not _hold_spent:
		progress = _hold_time / hold
	hud.set_focus(focus["text"], focus["allowed"], progress)


func _clear_hold() -> void:
	_hold_key = ""
	_hold_time = 0.0
	_hold_spent = false


## The nearest thing in reach: an interactable, a loot bag, or a downed crewmate.
func _find_focus() -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = Catalog.INTERACT_RANGE
	for id: String in Layout.INTERACTABLES:
		var distance: float = _flat_distance(Layout.interactable_pos(id))
		if distance > best_distance:
			continue
		var rule: Dictionary = Interactions.describe(id, self)
		if not rule["visible"]:
			continue
		best_distance = distance
		best = {"key": id, "kind": "interact", "id": id, "ui": Layout.INTERACTABLES[id]["ui"], "text": rule["text"], "allowed": rule["allowed"], "hold": rule["hold"]}
	for bag: LootBag in GameState.world.bags():
		var distance: float = _flat_distance(bag.global_position)
		if distance > best_distance:
			continue
		best_distance = distance
		if carrying == "":
			best = {"key": String(bag.name), "kind": "bag", "id": String(bag.name), "text": "Pick up the %s bag" % bag.kind, "allowed": true, "hold": 0.0}
		else:
			best = {"key": String(bag.name), "kind": "bag", "id": String(bag.name), "text": "Your hands are full (G to throw)", "allowed": false, "hold": 0.0}
	for other: Player in GameState.world.players():
		if other == self or not other.downed:
			continue
		var distance: float = _flat_distance(other.global_position)
		if distance > best_distance:
			continue
		best_distance = distance
		best = {"key": String(other.name), "kind": "revive", "peer": other.peer_id, "text": "Revive %s" % other.display_name, "allowed": true, "hold": Catalog.REVIVE_TIME}
	return best


func _flat_distance(pos: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(pos.x, pos.z))


func _act(focus: Dictionary) -> void:
	match focus["kind"]:
		"interact":
			var ui: String = focus["ui"]
			if ui != "":
				GameState.world.hud.open_panel(ui)
			else:
				GameState.request("interact", [focus["id"]])
		"bag":
			GameState.request("pick_bag", [focus["id"]])
		"revive":
			GameState.request("revive", [focus["peer"]])


# --- Model ----------------------------------------------------------------------

func _refresh_model() -> void:
	var signature: String = "%s|%s|%s|%s|%s" % [look, masked, carrying, downed, weapon]
	if signature == _shown:
		return
	_shown = signature
	for child: Node in _model.get_children():
		child.free()
	var outfit: Dictionary = Catalog.OUTFITS[look["outfit"]]
	var torso := CapsuleMesh.new()
	torso.radius = 0.35
	torso.height = 1.3
	_part(torso, outfit["color"], Vector3(0, 0.75, 0))
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	_part(head, SKIN, Vector3(0, 1.62, 0))
	if masked:
		_add_head(look["mask"])
	_add_hat(look["hat"])
	var gun := BoxMesh.new()
	gun.size = Vector3(0.08, 0.12, 0.45)
	_part(gun, Color(0.1, 0.1, 0.1), Vector3(0.3, 1.2, -0.35))
	if carrying != "":
		var bag := BoxMesh.new()
		bag.size = Vector3(0.5, 0.6, 0.3)
		_part(bag, LootBag.color_of(carrying), Vector3(0, 1.1, 0.4))
	if downed:
		_model.rotation.x = -PI / 2.0
		_model.position = Vector3(0, 0.35, 0.8)
	else:
		_model.rotation.x = 0.0
		_model.position = Vector3.ZERO
	if _name_label != null:
		_name_label.text = display_name + (" (DOWN)" if downed else "")
		_name_label.modulate = UiTheme.BAD if downed else Color(1, 1, 1)


func _part(primitive: PrimitiveMesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var node := Build.mesh(primitive, color)
	node.position = pos
	_model.add_child(node)
	return node


func _box(size: Vector3, color: Color, pos: Vector3) -> void:
	var primitive := BoxMesh.new()
	primitive.size = size
	_part(primitive, color, pos)


func _sphere(radius: float, color: Color, pos: Vector3) -> void:
	var primitive := SphereMesh.new()
	primitive.radius = radius
	primitive.height = radius * 2.0
	_part(primitive, color, pos)


## The mask model, worn over the face (forward is -Z).
func _add_head(mask: String) -> void:
	var color: Color = Catalog.MASKS[mask]["color"]
	var face := Vector3(0, 1.62, -0.2)
	match mask:
		"classic":
			_box(Vector3(0.38, 0.42, 0.08), color, face)
			_box(Vector3(0.08, 0.05, 0.02), Color.BLACK, face + Vector3(-0.08, 0.06, -0.05))
			_box(Vector3(0.08, 0.05, 0.02), Color.BLACK, face + Vector3(0.08, 0.06, -0.05))
		"clown":
			_sphere(0.24, color, Vector3(0, 1.62, 0))
			_sphere(0.07, Color(0.9, 0.1, 0.1), face + Vector3(0, 0, -0.08))
			_sphere(0.12, Color(0.2, 0.5, 1.0), Vector3(-0.22, 1.75, 0))
			_sphere(0.12, Color(0.2, 0.5, 1.0), Vector3(0.22, 1.75, 0))
		"skull":
			_box(Vector3(0.42, 0.46, 0.1), color, face)
			_box(Vector3(0.1, 0.09, 0.02), Color.BLACK, face + Vector3(-0.09, 0.06, -0.06))
			_box(Vector3(0.1, 0.09, 0.02), Color.BLACK, face + Vector3(0.09, 0.06, -0.06))
			_box(Vector3(0.2, 0.04, 0.02), Color.BLACK, face + Vector3(0, -0.12, -0.06))
		"pig":
			_sphere(0.25, color, Vector3(0, 1.62, 0))
			_box(Vector3(0.14, 0.1, 0.1), color.darkened(0.15), face + Vector3(0, -0.03, -0.1))
			_box(Vector3(0.08, 0.1, 0.04), color, Vector3(-0.15, 1.85, -0.05))
			_box(Vector3(0.08, 0.1, 0.04), color, Vector3(0.15, 1.85, -0.05))
		_:
			assert(false, "No model for mask '%s'" % mask)


func _add_hat(hat: String) -> void:
	var color: Color = Catalog.HATS[hat]["color"]
	match hat:
		"none":
			pass
		"beanie":
			_sphere(0.24, color, Vector3(0, 1.74, 0))
		"cowboy":
			var brim := CylinderMesh.new()
			brim.top_radius = 0.42
			brim.bottom_radius = 0.42
			brim.height = 0.03
			_part(brim, color, Vector3(0, 1.8, 0))
			var crown := CylinderMesh.new()
			crown.top_radius = 0.18
			crown.bottom_radius = 0.22
			crown.height = 0.22
			_part(crown, color, Vector3(0, 1.92, 0))
		"crown":
			var band := CylinderMesh.new()
			band.top_radius = 0.22
			band.bottom_radius = 0.22
			band.height = 0.1
			_part(band, color, Vector3(0, 1.84, 0))
			for i: int in range(5):
				var angle: float = TAU * i / 5.0
				_box(Vector3(0.06, 0.12, 0.06), color, Vector3(cos(angle) * 0.2, 1.94, sin(angle) * 0.2))
		_:
			assert(false, "No model for hat '%s'" % hat)
