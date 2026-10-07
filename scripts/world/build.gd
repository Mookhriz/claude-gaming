class_name Build
extends RefCounted
## Turns layout data into the static town: ground, blocks, buildings with doorways, signs, props and zones.

const WALL_THICKNESS: float = 0.4
const WORLD_LAYER: int = 1

static var _materials: Dictionary = {}


static func material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		if color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[key] = mat
	return _materials[key]


static func mesh(primitive: PrimitiveMesh, color: Color) -> MeshInstance3D:
	primitive.material = material(color)
	var node := MeshInstance3D.new()
	node.mesh = primitive
	return node


static func box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var primitive := BoxMesh.new()
	primitive.size = size
	return mesh(primitive, color)


## A box you can see but walk through.
static func visual_box(parent: Node3D, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := box_mesh(size, color)
	node.position = center
	parent.add_child(node)
	return node


## A box that blocks movement, bullets and sight.
static func solid_box(parent: Node3D, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(box_mesh(size, color))
	parent.add_child(body)
	return body


static func sign_label(parent: Node3D, text: String, pos: Vector3, yaw_degrees: float, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 12
	label.modulate = color
	label.position = pos
	label.rotation.y = deg_to_rad(yaw_degrees)
	parent.add_child(label)
	return label


static func town(parent: Node3D) -> void:
	var size: float = Layout.HALF_SIZE * 2.0
	solid_box(parent, Vector3(0, -0.5, 0), Vector3(size + 20.0, 1.0, size + 20.0), Color(0.22, 0.22, 0.24))
	_blocks(parent)
	_boundary(parent)
	for def: Dictionary in Layout.BUILDINGS:
		building(parent, def)
	for def: Dictionary in Layout.INTERIOR_WALLS:
		wall(parent, def["from"], def["to"], Layout.WALL_HEIGHT, def["color"], def["gaps"])
	for prop: Array in Layout.PROPS:
		solid_box(parent, prop[0], prop[1], prop[2])
	for pos: Vector3 in Layout.TREES:
		tree(parent, pos)
	var pond := CylinderMesh.new()
	pond.top_radius = Layout.POND_RADIUS
	pond.bottom_radius = Layout.POND_RADIUS
	pond.height = 0.06
	var pond_node := mesh(pond, Color(0.2, 0.45, 0.75))
	pond_node.position = Layout.POND_CENTER + Vector3(0, 0.06, 0)
	parent.add_child(pond_node)
	_zone(parent, Layout.VAN_ZONE, "GETAWAY VAN")
	_zone(parent, Layout.STASH_ZONE, "STASH")


static func _blocks(parent: Node3D) -> void:
	for column: int in range(3):
		for row: int in range(3):
			var center := Vector3(Layout.BLOCK_CENTERS[column], 0, Layout.BLOCK_CENTERS[row])
			var side: float = Layout.BLOCK_HALF * 2.0
			visual_box(parent, center + Vector3(0, 0.02, 0), Vector3(side, 0.04, side), Color(0.55, 0.55, 0.53))
			var lot := Color(0.42, 0.42, 0.4)
			if Layout.GRASS_BLOCKS.has([column, row]):
				lot = Color(0.3, 0.52, 0.24)
			visual_box(parent, center + Vector3(0, 0.03, 0), Vector3(side - 4.0, 0.04, side - 4.0), lot)


static func _boundary(parent: Node3D) -> void:
	var half: float = Layout.HALF_SIZE
	var length: float = half * 2.0 + 1.0
	var color := Color(0.4, 0.4, 0.42)
	solid_box(parent, Vector3(0, 2, -half), Vector3(length, 4, 1), color)
	solid_box(parent, Vector3(0, 2, half), Vector3(length, 4, 1), color)
	solid_box(parent, Vector3(-half, 2, 0), Vector3(1, 4, length), color)
	solid_box(parent, Vector3(half, 2, 0), Vector3(1, 4, length), color)


static func building(parent: Node3D, def: Dictionary) -> void:
	var rect: Rect2 = def["rect"]
	var height: float = def["height"]
	var color: Color = def["color"]
	var corners: Dictionary = {
		"n": [Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y)],
		"s": [Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y)],
		"w": [Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.end.y)],
		"e": [Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y)],
	}
	for side: String in corners:
		var gaps: Array = []
		for door: Array in def["doors"]:
			if door[0] == side:
				gaps.append([door[1], door[2]])
		var ends: Array = corners[side]
		wall(parent, ends[0], ends[1], height, color, gaps)
	var center := Vector3(rect.get_center().x, height, rect.get_center().y)
	visual_box(parent, center, Vector3(rect.size.x + 0.6, 0.3, rect.size.y + 0.6), color.darkened(0.4))
	var text: String = def["sign"]
	if text != "":
		var door: Array = def["doors"][0]
		_door_sign(parent, rect, door, text)


static func _door_sign(parent: Node3D, rect: Rect2, door: Array, text: String) -> void:
	var offset: float = door[1]
	var y: float = Layout.DOOR_HEIGHT + 0.9
	var pos := Vector3.ZERO
	var yaw: float = 0.0
	match door[0]:
		"n":
			pos = Vector3(rect.position.x + offset, y, rect.position.y - 0.3)
			yaw = 180.0
		"s":
			pos = Vector3(rect.position.x + offset, y, rect.end.y + 0.3)
			yaw = 0.0
		"w":
			pos = Vector3(rect.position.x - 0.3, y, rect.position.y + offset)
			yaw = -90.0
		"e":
			pos = Vector3(rect.end.x + 0.3, y, rect.position.y + offset)
			yaw = 90.0
	sign_label(parent, text, pos, yaw, 240, Color(1.0, 0.95, 0.75))


## An axis-aligned wall from one ground point to another, with doorway gaps of [offset, width].
static func wall(parent: Node3D, from: Vector2, to: Vector2, height: float, color: Color, gaps: Array) -> void:
	assert(from.x == to.x or from.y == to.y, "Walls must be axis-aligned: %s to %s" % [from, to])
	var length: float = from.distance_to(to)
	var dir: Vector2 = (to - from) / length
	var along_x: bool = from.y == to.y
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var start: float = 0.0
	for gap: Array in cuts:
		var gap_start: float = gap[0] - gap[1] / 2.0
		var gap_end: float = gap[0] + gap[1] / 2.0
		_wall_piece(parent, from, dir, along_x, start, gap_start, 0.0, height, color)
		_wall_piece(parent, from, dir, along_x, gap_start, gap_end, Layout.DOOR_HEIGHT, height, color)
		start = gap_end
	_wall_piece(parent, from, dir, along_x, start, length, 0.0, height, color)


static func _wall_piece(parent: Node3D, from: Vector2, dir: Vector2, along_x: bool, a: float, b: float, bottom: float, top: float, color: Color) -> void:
	if b - a < 0.01 or top - bottom < 0.01:
		return
	var mid: Vector2 = from + dir * ((a + b) / 2.0)
	var center := Vector3(mid.x, (bottom + top) / 2.0, mid.y)
	var size := Vector3(b - a, top - bottom, WALL_THICKNESS)
	if not along_x:
		size = Vector3(WALL_THICKNESS, top - bottom, b - a)
	solid_box(parent, center, size, color)


static func tree(parent: Node3D, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = 3.0
	shape.shape = cylinder
	shape.position.y = 1.5
	body.add_child(shape)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.3
	trunk.height = 3.0
	var trunk_node := mesh(trunk, Color(0.4, 0.28, 0.16))
	trunk_node.position.y = 1.5
	body.add_child(trunk_node)
	var leaves := SphereMesh.new()
	leaves.radius = 1.8
	leaves.height = 3.2
	var leaves_node := mesh(leaves, Color(0.2, 0.5, 0.2))
	leaves_node.position.y = 3.8
	body.add_child(leaves_node)
	parent.add_child(body)


static func _zone(parent: Node3D, rect: Rect2, text: String) -> void:
	var center := Vector3(rect.get_center().x, 0.08, rect.get_center().y)
	visual_box(parent, center, Vector3(rect.size.x, 0.08, rect.size.y), Color(0.2, 0.9, 0.3, 0.45))
	var label := sign_label(parent, text, center + Vector3(0, 1.5, 0), 0.0, 64, Color(0.5, 1.0, 0.55))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
