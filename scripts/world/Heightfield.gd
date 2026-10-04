class_name Heightfield
extends RefCounted
## A square height grid centered on the origin, plus per-vertex layers the
## generator fills in (distance to trail, patch noise). Sampling between grid
## points uses the same triangle split as the terrain mesh, so sampled heights
## match what you walk on.

const FAR: float = 1.0e6

var size: float
var cell_size: float
## Grid points per side.
var resolution: int
## World x/z of grid point 0.
var origin: float
var heights: PackedFloat32Array = PackedFloat32Array()
## Meters to the nearest trail centerline (FAR when not near the trail).
var trail_distance: PackedFloat32Array = PackedFloat32Array()
## Same, signed by which side of the trail the point is on. Unlike the unsigned
## distance this interpolates exactly across triangles, so the shader gets clean edges.
var trail_signed_distance: PackedFloat32Array = PackedFloat32Array()
## 0..1 low-frequency noise used to break ground color into patches.
var patch: PackedFloat32Array = PackedFloat32Array()
## Per-grid-point normals, filled by compute_normals() once heights are final.
var normals: PackedVector3Array = PackedVector3Array()


func _init(p_size: float = 512.0, p_cell_size: float = 2.0) -> void:
	cell_size = p_cell_size
	resolution = int(round(p_size / p_cell_size)) + 1
	size = (resolution - 1) * cell_size
	origin = -size * 0.5
	var count: int = resolution * resolution
	heights.resize(count)
	trail_distance.resize(count)
	trail_distance.fill(FAR)
	trail_signed_distance.resize(count)
	trail_signed_distance.fill(FAR)
	patch.resize(count)


func index(xi: int, zi: int) -> int:
	return zi * resolution + xi


func grid_position(xi: int, zi: int) -> Vector3:
	return Vector3(origin + xi * cell_size, heights[index(xi, zi)], origin + zi * cell_size)


func grid_coord(world: float) -> float:
	return (world - origin) / cell_size


func contains(x: float, z: float) -> bool:
	var half: float = size * 0.5
	return absf(x) <= half and absf(z) <= half


## Height at any x/z, matching the mesh's triangles.
func sample_height(x: float, z: float) -> float:
	var gx: float = clampf(grid_coord(x), 0.0, resolution - 1.001)
	var gz: float = clampf(grid_coord(z), 0.0, resolution - 1.001)
	var xi: int = int(gx)
	var zi: int = int(gz)
	var u: float = gx - xi
	var v: float = gz - zi
	var a: float = heights[index(xi, zi)]
	var b: float = heights[index(xi + 1, zi)]
	var c: float = heights[index(xi, zi + 1)]
	var d: float = heights[index(xi + 1, zi + 1)]
	# Cells are split along the b–c diagonal.
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1.0 - u) + (b - d) * (1.0 - v)


func sample_trail_distance(x: float, z: float) -> float:
	return _sample_bilinear(trail_distance, x, z)


func sample_patch(x: float, z: float) -> float:
	return _sample_bilinear(patch, x, z)


func normal_at(x: float, z: float) -> Vector3:
	var e: float = cell_size
	var dx: float = sample_height(x + e, z) - sample_height(x - e, z)
	var dz: float = sample_height(x, z + e) - sample_height(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func grid_normal(xi: int, zi: int) -> Vector3:
	var x0: int = maxi(xi - 1, 0)
	var x1: int = mini(xi + 1, resolution - 1)
	var z0: int = maxi(zi - 1, 0)
	var z1: int = mini(zi + 1, resolution - 1)
	var dx: float = (heights[index(x1, zi)] - heights[index(x0, zi)]) / ((x1 - x0) * cell_size)
	var dz: float = (heights[index(xi, z1)] - heights[index(xi, z0)]) / ((z1 - z0) * cell_size)
	return Vector3(-dx, 1.0, -dz).normalized()


func slope_degrees(x: float, z: float) -> float:
	return rad_to_deg(normal_at(x, z).angle_to(Vector3.UP))


## Caches grid normals. Call after the heights stop changing.
func compute_normals() -> void:
	normals.resize(heights.size())
	for zi: int in resolution:
		for xi: int in resolution:
			normals[index(xi, zi)] = grid_normal(xi, zi)


## Cached normal of the nearest grid point. Fast; needs compute_normals().
func nearest_normal(x: float, z: float) -> Vector3:
	var xi: int = clampi(int(round(grid_coord(x))), 0, resolution - 1)
	var zi: int = clampi(int(round(grid_coord(z))), 0, resolution - 1)
	return normals[index(xi, zi)]


## Order-independent fingerprint of the heights, for determinism checks.
func checksum() -> int:
	return hash(heights)


func _sample_bilinear(layer: PackedFloat32Array, x: float, z: float) -> float:
	var gx: float = clampf(grid_coord(x), 0.0, resolution - 1.001)
	var gz: float = clampf(grid_coord(z), 0.0, resolution - 1.001)
	var xi: int = int(gx)
	var zi: int = int(gz)
	var u: float = gx - xi
	var v: float = gz - zi
	var top: float = lerpf(layer[index(xi, zi)], layer[index(xi + 1, zi)], u)
	var bottom: float = lerpf(layer[index(xi, zi + 1)], layer[index(xi + 1, zi + 1)], u)
	return lerpf(top, bottom, v)
