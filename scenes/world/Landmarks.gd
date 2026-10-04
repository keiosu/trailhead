class_name Landmarks
extends Node3D
## Hand-placed-looking props at generated spots: trailhead sign and benches,
## cairns marking the trail, and a big summit cairn. Also the lake's water surface.

@export var prop_material: Material
@export var water_material: Material

var _sign_mesh: ArrayMesh
var _cairn_mesh: ArrayMesh
var _big_cairn_mesh: ArrayMesh
var _bench_mesh: ArrayMesh


func build(data: WorldData, settings: WorldGenSettings) -> void:
	for child: Node in get_children():
		child.queue_free()
	if _sign_mesh == null:
		_sign_mesh = PropMeshes.trail_sign()
		_cairn_mesh = PropMeshes.cairn(4)
		_big_cairn_mesh = PropMeshes.cairn(6)
		_bench_mesh = PropMeshes.log_bench()

	var hf: Heightfield = data.heightfield
	var trail: PackedVector3Array = data.trail
	var start_dir: Vector3 = _trail_direction(trail, 0)
	var side: Vector3 = start_dir.cross(Vector3.UP).normalized()

	# Trailhead: a sign beside the start of the trail and two benches around the clearing.
	_place(_sign_mesh, _on_ground(hf, trail[0] + side * 2.4), atan2(start_dir.x, start_dir.z), Vector3(0.15, 1.6, 0.15))
	_place(_bench_mesh, _on_ground(hf, data.trailhead - side * 6.0 - start_dir * 2.0), atan2(side.x, side.z) + PI / 2.0, Vector3(2.0, 0.6, 0.45))
	_place(_bench_mesh, _on_ground(hf, data.trailhead + side * 6.5 - start_dir * 4.0), atan2(side.x, side.z) + PI / 2.0 + 0.3, Vector3(2.0, 0.6, 0.45))

	# Cairns along the trail, alternating sides.
	var step: int = maxi(int(settings.cairn_spacing), 10)
	var flip: float = 1.0
	for i: int in range(step, trail.size() - step / 2, step):
		var offset: Vector3 = _trail_direction(trail, i).cross(Vector3.UP).normalized() * (settings.trail_width * 0.5 + 0.9) * flip
		_place(_cairn_mesh, _on_ground(hf, trail[i] + offset), float(i), Vector3(0.6, 0.7, 0.6))
		flip = -flip

	_place(_big_cairn_mesh, _on_ground(hf, data.summit + Vector3(1.5, 0, -1.5)), 0.4, Vector3(0.7, 1.0, 0.7), 1.6)
	_place(_sign_mesh, _on_ground(hf, data.summit + Vector3(-2.5, 0, 1.0)), 2.2, Vector3(0.15, 1.6, 0.15))
	_build_water(data, settings)


func _build_water(data: WorldData, settings: WorldGenSettings) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	var extent: float = (data.lake_radius * 1.3 + 14.0) * 2.0
	plane.size = Vector2(extent, extent)
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Lake"
	water.mesh = plane
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(data.lake_center.x, data.water_level, data.lake_center.z)
	add_child(water)


func _place(mesh: Mesh, at: Vector3, yaw: float, collider_size: Vector3, scale: float = 1.0) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = prop_material
	instance.position = at
	instance.rotation.y = yaw
	instance.scale = Vector3.ONE * scale
	add_child(instance)

	# Bodies must not inherit scale, so the collider is a sibling sized in meters.
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = at
	body.rotation.y = yaw
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = collider_size * scale
	shape.shape = box
	shape.position = Vector3(0, box.size.y * 0.5, 0)
	body.add_child(shape)
	add_child(body)


static func _on_ground(hf: Heightfield, p: Vector3) -> Vector3:
	return Vector3(p.x, hf.sample_height(p.x, p.z) - 0.05, p.z)


static func _trail_direction(trail: PackedVector3Array, i: int) -> Vector3:
	var a: Vector3 = trail[maxi(i - 2, 0)]
	var b: Vector3 = trail[mini(i + 2, trail.size() - 1)]
	var d: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.FORWARD
