class_name LootBag
extends RigidBody3D
## A bag of cash or gold lying in the world. The host simulates it; every machine draws it.

const BAG_LAYER: int = 8
const SIZE: Vector3 = Vector3(0.5, 0.6, 0.3)

var kind: String = "cash"
## Host only. The security level of the vault this bag came from, which sets its value.
var level: int = 1

# Host-owned and replicated.
var net_pos: Vector3 = Vector3.ZERO
var net_rot: Vector3 = Vector3.ZERO


static func color_of(bag_kind: String) -> Color:
	match bag_kind:
		"cash":
			return Color(0.2, 0.6, 0.25)
		"gold":
			return Color(0.95, 0.75, 0.2)
	assert(false, "Unknown bag kind '%s'" % bag_kind)
	return Color.BLACK


func setup(bag_kind: String, bag_name: String, pos: Vector3, velocity: Vector3) -> void:
	assert(Catalog.CARRY_PENALTY.has(bag_kind), "Unknown bag kind '%s'" % bag_kind)
	kind = bag_kind
	name = bag_name
	position = pos
	net_pos = pos
	linear_velocity = velocity
	collision_layer = BAG_LAYER
	collision_mask = Build.WORLD_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	add_child(Build.box_mesh(SIZE, color_of(kind)))
	World.replicate(self, ["net_pos", "net_rot"], [], 0.05)


## True when no wall stands between the player's chest and the bag.
func in_reach_of(player: Player) -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1.0, 0), global_position, Build.WORLD_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _ready() -> void:
	if not multiplayer.is_server():
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		net_pos = position
		net_rot = rotation
		return
	var weight: float = 1.0 - exp(-12.0 * delta)
	position = position.lerp(net_pos, weight)
	rotation = rotation.lerp(net_rot, weight)
