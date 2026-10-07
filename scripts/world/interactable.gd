class_name Interactable
extends RefCounted
## Builds the thing you see at each interactable: clerks, quest givers, ATMs, the register and the casino games.
## Loot piles and bank doors follow the crew state, so world.gd draws those.


static func build_all(parent: Node3D) -> void:
	for id: String in Layout.INTERACTABLES:
		var def: Dictionary = Layout.INTERACTABLES[id]
		_build(parent, id, def)


static func _build(parent: Node3D, id: String, def: Dictionary) -> void:
	var pos: Vector3 = def["pos"]
	var label: String = def["label"]
	match def["prop"]:
		"none":
			return
		"clerk":
			person(parent, pos, Color(0.3, 0.3, 0.35), label)
		"person":
			person(parent, pos, Color.from_hsv(float(absi(id.hash()) % 360) / 360.0, 0.55, 0.8), label)
		"cop":
			var cop := person(parent, pos, Color(0.12, 0.17, 0.35), label)
			cop.add_child(_cap(Color(0.08, 0.1, 0.2)))
		"atm":
			var atm := Build.solid_box(parent, pos + Vector3(0, 0.9, 0), Vector3(0.8, 1.8, 0.6), Color(0.35, 0.38, 0.42))
			Build.visual_box(atm, Vector3(0, 0.35, 0.31), Vector3(0.5, 0.35, 0.02), Color(0.3, 0.8, 1.0))
			_floating_label(parent, pos, label)
		"register":
			Build.solid_box(parent, pos + Vector3(-1.0, 0.5, 0), Vector3(0.8, 1.0, 2.0), Color(0.6, 0.6, 0.6))
			Build.visual_box(parent, pos + Vector3(-1.0, 1.15, 0), Vector3(0.5, 0.3, 0.4), Color(0.2, 0.2, 0.2))
		"slots":
			for i: int in range(3):
				var machine := Build.solid_box(parent, pos + Vector3(-1.2 + i * 1.2, 0.9, -1.0), Vector3(0.9, 1.8, 0.7), Color(0.75, 0.15, 0.2))
				Build.visual_box(machine, Vector3(0, 0.3, 0.36), Vector3(0.6, 0.4, 0.02), Color(1.0, 0.9, 0.3))
			_floating_label(parent, pos, label)
		"roulette":
			var table := Build.solid_box(parent, pos + Vector3(0, 0.45, -1.4), Vector3(2.6, 0.9, 1.4), Color(0.1, 0.45, 0.2))
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.45
			wheel.bottom_radius = 0.45
			wheel.height = 0.1
			var wheel_node := Build.mesh(wheel, Color(0.5, 0.1, 0.1))
			wheel_node.position = Vector3(-0.7, 0.5, 0)
			table.add_child(wheel_node)
			_floating_label(parent, pos, label)
		_:
			assert(false, "Unknown prop '%s' for interactable '%s'" % [def["prop"], id])


## A standing figure with a name over its head, facing south.
static func person(parent: Node3D, pos: Vector3, color: Color, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = Build.WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	var torso := CapsuleMesh.new()
	torso.radius = 0.35
	torso.height = 1.3
	var torso_node := Build.mesh(torso, color)
	torso_node.position.y = 0.75
	body.add_child(torso_node)
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	var head_node := Build.mesh(head, Color(0.9, 0.75, 0.6))
	head_node.position.y = 1.62
	body.add_child(head_node)
	parent.add_child(body)
	_floating_label(parent, pos, label)
	return body


static func _cap(color: Color) -> MeshInstance3D:
	var cap := CylinderMesh.new()
	cap.top_radius = 0.2
	cap.bottom_radius = 0.24
	cap.height = 0.12
	var node := Build.mesh(cap, color)
	node.position.y = 1.85
	return node


static func _floating_label(parent: Node3D, pos: Vector3, text: String) -> void:
	var label := Build.sign_label(parent, text, pos + Vector3(0, 2.3, 0), 0.0, 40, Color(1, 1, 1))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
