extends Node3D

# Store fields in spatial cells so only nearby floors participate in selection.
const CELL := 20.0
const DOOR_SCENE := preload("res://scenes/world/sections/screen_door.tscn")
var cells := {}

func register_floor(frame: Transform3D, half_size: Vector3) -> void:
	var field := {"inverse": frame.affine_inverse(), "up": frame.basis.y.normalized(), "extent": half_size}
	var bounds := frame * AABB(-half_size, half_size * 2)
	var start := Vector3i((bounds.position / CELL).floor())
	var end := Vector3i((bounds.end / CELL).floor())
	for x in range(start.x,end.x+1):
		for y in range(start.y,end.y+1):
			for z in range(start.z,end.z+1):
				var key := Vector3i(x,y,z)
				if not cells.has(key): cells[key] = []
				cells[key].append(field)

func sample_up(point: Vector3, previous: Vector3) -> Vector3:
	var best := INF
	var offset := point - preload("res://scripts/gravity/outer_gallery.gd").CENTER
	var radii := preload("res://scripts/gravity/outer_gallery.gd").RADII
	var result := previous
	if (offset / radii).length() > 0.78 or point.y < -72:
		result = -(offset / (radii*radii)).normalized()
	for field in cells.get(Vector3i((point/CELL).floor()), []):
		var local: Vector3 = field.inverse * point
		var extent: Vector3 = field.extent
		if local.abs().x > extent.x or absf(local.y)>extent.y or absf(local.z)>extent.z: continue
		var up: Vector3 = field.up
		var score := absf(local.y + extent.y - 0.7) + (1.0-previous.dot(up))*0.24
		if score < best:
			best = score
			result = up
	return result

func register_piece(t: Transform3D, mesh: Mesh):
	var path := mesh.resource_path
	var size: Vector3
	if path.ends_with("lantern_house.res"):
		size = Vector3(6.5,5.5,5.0)
		var door := DOOR_SCENE.instantiate() as Node3D
		door.transform = global_transform.affine_inverse() * t.translated_local(Vector3(0,0.115,3.83))
		add_child(door)
	elif path.ends_with("gallery_span.res"): size = Vector3(8.2,2.0,1.55)
	else: return
	register_floor(t.translated_local(Vector3.UP*(size.y-0.7)),size)

func _ready():
	add_to_group("castle_gravity")
	add_child(preload("res://scripts/gravity/outer_gallery.gd").new())
	for piece in $LanternDistrict.get_children():
		if piece is MeshInstance3D:
			register_piece(piece.global_transform,piece.mesh)
			if piece.mesh is BoxMesh:
				register_floor(piece.global_transform.translated_local(Vector3.UP*1.4),piece.mesh.size/2+Vector3.UP*2)
	for batch in $CastleShell.get_children():
		if batch is MultiMeshInstance3D:
			var multi: MultiMesh = batch.multimesh
			for i in multi.instance_count:
				register_piece(batch.global_transform*multi.get_instance_transform(i),multi.mesh)
	for floor_piece in $StartingBalcony.find_children("*","MeshInstance3D",true,false):
		if floor_piece.name in [&"Foundation",&"Deck"] or str(floor_piece.name).begins_with("DistantBridge"):
			register_floor(floor_piece.global_transform.translated_local(Vector3.UP*2),floor_piece.mesh.size/2 + Vector3(0.2,2.6,0.2))
