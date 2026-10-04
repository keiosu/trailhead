class_name Terrain
extends StaticBody3D
## Turns a Heightfield into a render mesh and heightmap collision.

## Vertex COLOR.r stores signed trail distance / this * 0.5 + 0.5, COLOR.a the unsigned
## distance / this. Must match terrain.gdshader.
const TRAIL_DISTANCE_SCALE: float = 16.0
## Sand is only painted this far beyond the lake's radius.
const SHORE_REACH: float = 10.0

@export var material: ShaderMaterial

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0


func build(data: WorldData) -> void:
	var hf: Heightfield = data.heightfield
	var n: int = hf.resolution
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	vertices.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for zi: int in n:
		for xi: int in n:
			var i: int = hf.index(xi, zi)
			vertices[i] = hf.grid_position(xi, zi)
			normals[i] = hf.normals[i]
			var trail: float = clampf(hf.trail_signed_distance[i] / TRAIL_DISTANCE_SCALE, -1.0, 1.0) * 0.5 + 0.5
			var p: Vector3 = vertices[i]
			var lake_distance: float = Vector2(p.x - data.lake_center.x, p.z - data.lake_center.z).length()
			var shore: float = 1.0 - smoothstep(data.lake_radius * 1.3, data.lake_radius * 1.3 + SHORE_REACH, lake_distance)
			var trail_unsigned: float = minf(hf.trail_distance[i] / TRAIL_DISTANCE_SCALE, 1.0)
			colors[i] = Color(trail, hf.patch[i], shore, trail_unsigned)

	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var k: int = 0
	for zi: int in n - 1:
		for xi: int in n - 1:
			var a: int = zi * n + xi
			var b: int = a + 1
			var c: int = a + n
			var d: int = c + 1
			# Clockwise from above (Godot front faces); split along b–c like Heightfield.sample_height.
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		add_child(_mesh_instance)
		_collision = CollisionShape3D.new()
		_collision.name = "Collision"
		add_child(_collision)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	if material != null:
		material.set_shader_parameter("water_level", data.water_level)

	# HeightMapShape3D always has 1-unit spacing; scale the shape node to the cell size.
	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = hf.heights
	_collision.shape = shape
	_collision.scale = Vector3(hf.cell_size, 1.0, hf.cell_size)
