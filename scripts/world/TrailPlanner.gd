class_name TrailPlanner
extends RefCounted
## Routes the trail trailhead → meadow → summit with A* over a coarse grid, where
## climbing steeper than the preferred grade gets expensive fast. That makes the
## path wind around hills and switch back up the summit cone on its own.
## Then smooths it, gives it a gentle height profile, and carves it into the terrain.

## Extra cost multiplier exponent on grade. Higher = stronger dislike of steep segments.
const GRADE_EXPONENT: float = 4.0
## Cost multiplier for routing right along the lake shore.
const SHORE_PENALTY: float = 3.0
## How far from the trail centerline the trail distance field is recorded (m).
const DISTANCE_FIELD_REACH: float = 16.0


class GradeAStar:
	extends AStar3D
	var preferred_grade: float = 0.36
	## Per-point cost multiplier (wander, shore penalty), indexed by point id.
	var weights: PackedFloat32Array = PackedFloat32Array()

	func _compute_cost(from_id: int, to_id: int) -> float:
		var a: Vector3 = get_point_position(from_id)
		var b: Vector3 = get_point_position(to_id)
		var run: float = Vector2(b.x - a.x, b.z - a.z).length()
		var grade: float = absf(b.y - a.y) / run
		var weight: float = (weights[from_id] + weights[to_id]) * 0.5
		return run * weight * (1.0 + pow(grade / preferred_grade, GRADE_EXPONENT))

	func _estimate_cost(from_id: int, to_id: int) -> float:
		var a: Vector3 = get_point_position(from_id)
		var b: Vector3 = get_point_position(to_id)
		return Vector2(b.x - a.x, b.z - a.z).length()


static func plan(data: WorldData, settings: WorldGenSettings) -> void:
	var hf: Heightfield = data.heightfield
	var step: float = settings.trail_grid_step
	var n: int = int(hf.size / step) + 1
	var half: float = hf.size * 0.5
	var rim_start: float = half - settings.edge_wall_width * 0.7
	var astar: GradeAStar = GradeAStar.new()
	astar.preferred_grade = settings.trail_preferred_grade
	astar.reserve_space(n * n)
	astar.weights.resize(n * n)
	astar.weights.fill(1.0)
	# Soft, seeded "obstacles" so the trail bends instead of beelining up the valley.
	var wander: FastNoiseLite = FastNoiseLite.new()
	wander.seed = data.world_seed + 20
	wander.frequency = 1.0 / maxf(settings.trail_wander_scale, 1.0)

	for zi: int in n:
		for xi: int in n:
			var x: float = hf.origin + xi * step
			var z: float = hf.origin + zi * step
			var id: int = zi * n + xi
			astar.add_point(id, Vector3(x, hf.sample_height(x, z), z))
			var lake_gap: float = Vector2(x - data.lake_center.x, z - data.lake_center.z).length() - data.lake_radius * 1.25
			if lake_gap < 3.0 or maxf(absf(x), absf(z)) > rim_start:
				astar.set_point_disabled(id)
			else:
				var weight: float = 1.0 + settings.trail_wander * (wander.get_noise_2d(x, z) * 0.5 + 0.5)
				if lake_gap < 10.0:
					weight *= SHORE_PENALTY
				astar.weights[id] = weight
	for zi: int in n:
		for xi: int in n:
			var id: int = zi * n + xi
			if xi + 1 < n:
				astar.connect_points(id, id + 1)
			if zi + 1 < n:
				astar.connect_points(id, id + n)
				if xi + 1 < n:
					astar.connect_points(id, id + n + 1)
				if xi > 0:
					astar.connect_points(id, id + n - 1)

	var lake_away: Vector3 = (data.meadow - data.lake_center).normalized()
	var meadow_stop: Vector3 = data.meadow + lake_away * 8.0
	var waypoints: Array[Vector3] = [data.trailhead, meadow_stop, data.summit]
	var route: PackedVector3Array = PackedVector3Array()
	for i: int in range(1, waypoints.size()):
		var from_id: int = _grid_id(waypoints[i - 1], hf, step, n)
		var to_id: int = _grid_id(waypoints[i], hf, step, n)
		astar.set_point_disabled(from_id, false)
		astar.set_point_disabled(to_id, false)
		var leg: PackedVector3Array = astar.get_point_path(from_id, to_id)
		if leg.is_empty():
			Log.warn("TrailPlanner", "No route for trail leg %d; using a straight line" % i)
			leg = PackedVector3Array([waypoints[i - 1], waypoints[i]])
		if not route.is_empty():
			leg = leg.slice(1)
		route.append_array(leg)

	route[0] = data.trailhead
	route[route.size() - 1] = data.summit
	route = _chaikin(route, 5)
	route = _resample(route, 1.0)
	data.trail = _profile_heights(route, hf, settings.trail_height_smoothing)


## Flatten the terrain across the trail and record each grid point's distance to it.
static func carve(data: WorldData, settings: WorldGenSettings) -> void:
	var hf: Heightfield = data.heightfield
	var half_width: float = settings.trail_width * 0.5
	var reach: float = maxf(half_width + settings.trail_shoulder, DISTANCE_FIELD_REACH)
	var target: PackedFloat32Array = PackedFloat32Array()
	target.resize(hf.heights.size())
	var trail: PackedVector3Array = data.trail

	for s: int in range(1, trail.size()):
		var a: Vector3 = trail[s - 1]
		var b: Vector3 = trail[s]
		var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
		var length_sq: float = maxf(ab.length_squared(), 0.0001)
		var x0: int = maxi(int(floor(hf.grid_coord(minf(a.x, b.x) - reach))), 0)
		var x1: int = mini(int(ceil(hf.grid_coord(maxf(a.x, b.x) + reach))), hf.resolution - 1)
		var z0: int = maxi(int(floor(hf.grid_coord(minf(a.z, b.z) - reach))), 0)
		var z1: int = mini(int(ceil(hf.grid_coord(maxf(a.z, b.z) + reach))), hf.resolution - 1)
		for zi: int in range(z0, z1 + 1):
			for xi: int in range(x0, x1 + 1):
				var p: Vector2 = Vector2(hf.origin + xi * hf.cell_size - a.x, hf.origin + zi * hf.cell_size - a.z)
				var t: float = clampf(p.dot(ab) / length_sq, 0.0, 1.0)
				var distance: float = (p - ab * t).length()
				var i: int = hf.index(xi, zi)
				if distance < hf.trail_distance[i]:
					hf.trail_distance[i] = distance
					# Past the trail's two ends the side is meaningless; keep those unsigned.
					var at_cap: bool = (s == 1 and t <= 0.0) or (s == trail.size() - 1 and t >= 1.0)
					hf.trail_signed_distance[i] = distance if at_cap or ab.cross(p) >= 0.0 else -distance
					target[i] = lerpf(a.y, b.y, t)

	var blend_end: float = half_width + settings.trail_shoulder
	for i: int in hf.heights.size():
		var distance: float = hf.trail_distance[i]
		if distance < blend_end:
			var w: float = 1.0 - smoothstep(half_width, blend_end, distance)
			hf.heights[i] = lerpf(hf.heights[i], target[i], w)


static func _grid_id(p: Vector3, hf: Heightfield, step: float, n: int) -> int:
	var xi: int = clampi(int(round((p.x - hf.origin) / step)), 0, n - 1)
	var zi: int = clampi(int(round((p.z - hf.origin) / step)), 0, n - 1)
	return zi * n + xi


## Corner-cutting smoothing; keeps the endpoints.
static func _chaikin(points: PackedVector3Array, iterations: int) -> PackedVector3Array:
	var result: PackedVector3Array = points
	for _i: int in iterations:
		if result.size() < 3:
			return result
		var next: PackedVector3Array = PackedVector3Array([result[0]])
		for j: int in range(result.size() - 1):
			next.append(result[j].lerp(result[j + 1], 0.25))
			next.append(result[j].lerp(result[j + 1], 0.75))
		next.append(result[result.size() - 1])
		result = next
	return result


## Even spacing along the polyline (x/z only).
static func _resample(points: PackedVector3Array, spacing: float) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array([points[0]])
	var carry: float = 0.0
	for j: int in range(1, points.size()):
		var a: Vector3 = points[j - 1]
		var b: Vector3 = points[j]
		var length: float = Vector2(b.x - a.x, b.z - a.z).length()
		var d: float = spacing - carry
		while d <= length:
			result.append(a.lerp(b, d / length))
			d += spacing
		carry = length - (d - spacing)
	if result[result.size() - 1].distance_to(points[points.size() - 1]) > spacing * 0.3:
		result.append(points[points.size() - 1])
	return result


## Terrain height along the route, moving-averaged so the tread climbs smoothly.
static func _profile_heights(route: PackedVector3Array, hf: Heightfield, window: int) -> PackedVector3Array:
	var raw: PackedFloat32Array = PackedFloat32Array()
	for p: Vector3 in route:
		raw.append(hf.sample_height(p.x, p.z))
	var result: PackedVector3Array = PackedVector3Array()
	var last: int = route.size() - 1
	for i: int in route.size():
		var lo: int = maxi(i - window, 0)
		var hi: int = mini(i + window, last)
		var total: float = 0.0
		for k: int in range(lo, hi + 1):
			total += raw[k]
		result.append(Vector3(route[i].x, total / (hi - lo + 1), route[i].z))
	return result
