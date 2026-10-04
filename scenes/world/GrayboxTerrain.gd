class_name GrayboxTerrain
extends StaticBody3D
## M1 test ground: flat land with smooth gaussian hills of known steepness, for tuning
## movement. Replaced by real procedural terrain in M3.

const LOG_TAG: String = "GrayboxTerrain"

## Side length in meters. The grid is 1 m per cell, centered on the origin.
@export var size: int = 200
## Each hill is Vector4(center_x, center_z, sigma, height). Steepest slope ≈ atan(0.607 * height / sigma).
@export var hills: Array[Vector4] = [
	Vector4(50.0, -60.0, 14.0, 10.0),  # ~23°, gentle
	Vector4(-40.0, -45.0, 9.0, 10.0),  # ~34°
	Vector4(0.0, -75.0, 16.0, 18.0),   # ~34°, the big one
	Vector4(45.0, 25.0, 7.0, 8.0),     # ~35°
	Vector4(-45.0, 30.0, 5.0, 9.0),    # ~48°, too steep: you should slide off
]
@export var material: Material


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	_build()


func height_at(x: float, z: float) -> float:
	var h: float = 0.0
	for hill: Vector4 in hills:
		var dx: float = x - hill.x
		var dz: float = z - hill.y
		h += hill.w * exp(-(dx * dx + dz * dz) / (2.0 * hill.z * hill.z))
	return h


func normal_at(x: float, z: float) -> Vector3:
	var dh_dx: float = 0.0
	var dh_dz: float = 0.0
	for hill: Vector4 in hills:
		var dx: float = x - hill.x
		var dz: float = z - hill.y
		var sigma_sq: float = hill.z * hill.z
		var g: float = hill.w * exp(-(dx * dx + dz * dz) / (2.0 * sigma_sq))
		dh_dx -= g * dx / sigma_sq
		dh_dz -= g * dz / sigma_sq
	return Vector3(-dh_dx, 1.0, -dh_dz).normalized()


static func steepest_slope_degrees(hill: Vector4) -> float:
	return rad_to_deg(atan(exp(-0.5) * hill.w / hill.z))


func _build() -> void:
	var points: int = size + 1
	var half: float = size * 0.5
	var heights: PackedFloat32Array = PackedFloat32Array()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	heights.resize(points * points)
	vertices.resize(points * points)
	normals.resize(points * points)
	for zi: int in points:
		for xi: int in points:
			var x: float = xi - half
			var z: float = zi - half
			var i: int = zi * points + xi
			heights[i] = height_at(x, z)
			vertices[i] = Vector3(x, heights[i], z)
			normals[i] = normal_at(x, z)

	var indices: PackedInt32Array = PackedInt32Array()
	for zi: int in size:
		for xi: int in size:
			var a: int = zi * points + xi
			var b: int = a + 1
			var c: int = a + points
			var d: int = c + 1
			indices.append_array([a, b, c, b, d, c])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = points
	shape.map_depth = points
	shape.map_data = heights
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	add_child(collision)

	Log.debug(LOG_TAG, "Built %d m terrain, %d hills" % [size, hills.size()])
