class_name PropMeshes
extends RefCounted
## Chunky low-poly meshes built in code, with colors baked into vertex COLOR.
## Placeholder-quality but on-style; Blender versions replace them in M10.

const TRUNK: Color = Color(0.5, 0.33, 0.2)
const PINE_DARK: Color = Color(0.17, 0.46, 0.35)
const PINE_LIGHT: Color = Color(0.24, 0.56, 0.38)
const LEAF: Color = Color(0.42, 0.7, 0.3)
const LEAF_LIGHT: Color = Color(0.52, 0.78, 0.34)
const BUSH: Color = Color(0.33, 0.62, 0.3)
const STONE: Color = Color(0.66, 0.65, 0.7)
const STONE_DARK: Color = Color(0.55, 0.54, 0.6)
const WOOD: Color = Color(0.62, 0.42, 0.24)
const WOOD_LIGHT: Color = Color(0.82, 0.64, 0.4)
const STEM: Color = Color(0.36, 0.62, 0.3)


static func pine() -> ArrayMesh:
	var st: SurfaceTool = _begin()
	_add(st, _cylinder(0.12, 0.2, 1.4, 6), Transform3D(Basis(), Vector3(0, 0.7, 0)), TRUNK)
	var tiers: Array = [[1.5, 1.8, 1.7], [1.2, 1.6, 2.7], [0.85, 1.4, 3.6]]
	for i: int in tiers.size():
		var radius: float = tiers[i][0]
		var height: float = tiers[i][1]
		var color: Color = PINE_DARK if i % 2 == 0 else PINE_LIGHT
		_add(st, _cylinder(0.0, radius, height, 7), Transform3D(Basis(Vector3.UP, i * 0.6), Vector3(0, tiers[i][2], 0)), color)
	return _commit(st)


static func broadleaf() -> ArrayMesh:
	var st: SurfaceTool = _begin()
	_add(st, _cylinder(0.14, 0.22, 2.2, 6), Transform3D(Basis(), Vector3(0, 1.1, 0)), TRUNK)
	_add(st, _sphere(1.4, 8, 5), Transform3D(Basis(), Vector3(0, 3.0, 0)), LEAF)
	_add(st, _sphere(0.95, 8, 5), Transform3D(Basis(), Vector3(0.9, 2.5, 0.3)), LEAF_LIGHT)
	_add(st, _sphere(0.9, 8, 5), Transform3D(Basis(), Vector3(-0.7, 2.6, -0.5)), LEAF_LIGHT)
	return _commit(st)


static func bush() -> ArrayMesh:
	var st: SurfaceTool = _begin()
	_add(st, _sphere(0.55, 8, 5), Transform3D(Basis(), Vector3(0, 0.35, 0)), BUSH)
	_add(st, _sphere(0.4, 8, 5), Transform3D(Basis(), Vector3(0.45, 0.25, 0.15)), LEAF)
	_add(st, _sphere(0.38, 8, 5), Transform3D(Basis(), Vector3(-0.35, 0.22, -0.25)), BUSH)
	return _commit(st)


## A lumpy, flat-shaded stone. Different `variant`s give different shapes.
static func rock(variant: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9000 + variant
	var arrays: Array = _sphere(0.5, 7, 4).get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	# Jitter per unique position so shared vertices stay welded.
	var offsets: Dictionary = {}
	for i: int in vertices.size():
		var key: Vector3i = Vector3i((vertices[i] * 1000.0).round())
		if not offsets.has(key):
			offsets[key] = Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.55, 0.85), rng.randf_range(0.8, 1.2))
		vertices[i] *= offsets[key]
	var st: SurfaceTool = _begin()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t: int in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[t]]
		var b: Vector3 = vertices[indices[t + 1]]
		var c: Vector3 = vertices[indices[t + 2]]
		var normal: Vector3 = (c - a).cross(b - a).normalized()
		var color: Color = STONE if normal.y > 0.3 else STONE_DARK
		for v: Vector3 in [a, b, c]:
			st.set_color(color)
			st.set_normal(normal)
			st.add_vertex(v + Vector3(0, 0.2, 0))
	return _commit(st)


## A tuft of blades; COLOR.r runs 0 (root) → 1 (tip) for the grass shader.
static func grass_tuft() -> ArrayMesh:
	var st: SurfaceTool = _begin()
	var blades: int = 6
	for i: int in blades:
		var angle: float = TAU * i / blades + 0.4 * (i % 2)
		var dir: Vector3 = Vector3(cos(angle), 0, sin(angle))
		var side: Vector3 = dir.cross(Vector3.UP).normalized() * 0.045
		var root: Vector3 = dir * 0.06
		var height: float = 0.32 + 0.12 * ((i * 7) % 3) / 2.0
		var tip: Vector3 = root + dir * 0.12 + Vector3(0, height, 0)
		for v: Vector3 in [root - side, tip, root + side]:
			st.set_color(Color(1.0 if v == tip else 0.0, 0, 0))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return _commit(st)


## Stem plus a white blossom; per-instance tint colors the petals.
static func flower() -> ArrayMesh:
	var st: SurfaceTool = _begin()
	_add(st, _cylinder(0.015, 0.02, 0.26, 4), Transform3D(Basis(), Vector3(0, 0.13, 0)), STEM)
	_add(st, _sphere(0.05, 6, 3), Transform3D(Basis().scaled(Vector3(1.6, 0.45, 1.6)), Vector3(0.06, 0.06, 0.04)), STEM)
	for i: int in 5:
		var angle: float = TAU * i / 5.0
		var petal_at: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.07 + Vector3(0, 0.28, 0)
		_add(st, _sphere(0.055, 6, 3), Transform3D(Basis().scaled(Vector3(1, 0.5, 1)), petal_at), Color.WHITE)
	_add(st, _sphere(0.04, 6, 3), Transform3D(Basis(), Vector3(0, 0.3, 0)), Color(1.0, 0.85, 0.35))
	return _commit(st)


static func cairn(stones: int = 4) -> ArrayMesh:
	var st: SurfaceTool = _begin()
	var y: float = 0.0
	for i: int in stones:
		var radius: float = 0.38 - i * 0.07
		var height: float = radius * 0.7
		var basis: Basis = Basis(Vector3.UP, i * 1.3).scaled(Vector3(1.0, 0.6, 0.85))
		_add(st, _sphere(radius, 7, 4), Transform3D(basis, Vector3(0.03 * (i % 2), y + height * 0.5, 0)), STONE if i % 2 == 0 else STONE_DARK)
		y += height * 0.8
	return _commit(st)


static func trail_sign() -> ArrayMesh:
	var st: SurfaceTool = _begin()
	_add(st, _box(Vector3(0.14, 1.6, 0.14)), Transform3D(Basis(), Vector3(0, 0.8, 0)), WOOD)
	_add(st, _box(Vector3(1.1, 0.42, 0.08)), Transform3D(Basis(), Vector3(0, 1.35, 0.1)), WOOD_LIGHT)
	_add(st, _box(Vector3(0.7, 0.26, 0.07)), Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3(0.2, 0.92, 0.1)), WOOD_LIGHT)
	return _commit(st)


static func log_bench() -> ArrayMesh:
	var st: SurfaceTool = _begin()
	_add(st, _cylinder(0.22, 0.22, 2.0, 8), Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0, 0.42, 0)), WOOD)
	for x: float in [-0.7, 0.7]:
		_add(st, _cylinder(0.16, 0.18, 0.24, 7), Transform3D(Basis(), Vector3(x, 0.12, 0)), TRUNK)
	return _commit(st)


static func _begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool) -> ArrayMesh:
	st.index()
	return st.commit()


## Appends a primitive's triangles with a transform and a flat vertex color.
static func _add(st: SurfaceTool, mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> void:
	var arrays: Array = mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis: Basis = xform.basis.inverse().transposed()
	for i: int in indices:
		st.set_color(color)
		st.set_normal((normal_basis * normals[i]).normalized())
		st.add_vertex(xform * vertices[i])


static func _cylinder(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


static func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh
