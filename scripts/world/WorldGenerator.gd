class_name WorldGenerator
extends RefCounted
## Builds WorldData from settings + seed. Deterministic: no node access, no time,
## no global RNG. Every peer runs this locally with the host's seed.
##
## Layout: trailhead in a valley at the south (+Z) edge, summit cone near the north (-Z)
## edge, a meadow with a lake partway up, all inside a steep rim.

const LOG_TAG: String = "WorldGen"


static func generate(settings: WorldGenSettings, world_seed: int) -> WorldData:
	var started: int = Time.get_ticks_usec()
	var data: WorldData = WorldData.new()
	data.world_seed = world_seed
	data.heightfield = Heightfield.new(settings.world_size, settings.cell_size)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed

	_place_landmarks(data, settings, rng)
	_shape_terrain(data, settings, world_seed, rng.randf() * TAU)
	_flatten_landmarks(data, settings, world_seed)
	TrailPlanner.plan(data, settings)
	TrailPlanner.carve(data, settings)
	_paint_patches(data, world_seed)
	data.heightfield.compute_normals()
	_place_spawn(data)

	Log.info(LOG_TAG, "Seed %d generated in %d ms (trail %d m, steepest %.1f°)" % [
		world_seed, (Time.get_ticks_usec() - started) / 1000, data.trail.size(), data.max_trail_grade_degrees()])
	return data


static func _place_landmarks(data: WorldData, settings: WorldGenSettings, rng: RandomNumberGenerator) -> void:
	var half: float = data.heightfield.size * 0.5
	data.trailhead = Vector3(rng.randf_range(-30.0, 30.0), 0.0, half - settings.trailhead_inset)
	data.summit = Vector3(rng.randf_range(-35.0, 35.0), 0.0, -half + settings.summit_inset)
	var along: Vector3 = data.trailhead.lerp(data.summit, settings.meadow_progress)
	data.meadow = along + Vector3(rng.randf_range(-45.0, 45.0), 0.0, 0.0)
	var lake_angle: float = rng.randf() * TAU
	data.lake_center = data.meadow + Vector3(cos(lake_angle), 0.0, sin(lake_angle)) * settings.lake_offset
	data.lake_radius = settings.lake_radius


static func _shape_terrain(data: WorldData, settings: WorldGenSettings, world_seed: int, valley_phase: float) -> void:
	var hf: Heightfield = data.heightfield
	var half: float = hf.size * 0.5
	var noise: FastNoiseLite = _make_noise(world_seed, settings.noise_frequency, settings.noise_octaves)
	var detail: FastNoiseLite = _make_noise(world_seed + 1, settings.detail_frequency, 2)
	var sigma_sq_2: float = 2.0 * settings.peak_radius * settings.peak_radius
	var span: float = data.trailhead.z - data.summit.z

	for zi: int in hf.resolution:
		var z: float = hf.origin + zi * hf.cell_size
		var t: float = clampf((data.trailhead.z - z) / span, 0.0, 1.0)
		var valley_x: float = lerpf(data.trailhead.x, data.summit.x, t) + sin(z * 0.012 + valley_phase) * settings.valley_wiggle
		var rise: float = settings.rise_height * smoothstep(0.0, 1.0, t)
		for xi: int in hf.resolution:
			var x: float = hf.origin + xi * hf.cell_size
			var side: float = clampf(absf(x - valley_x) / half, 0.0, 1.5)
			var h: float = rise + settings.side_height * pow(side, 1.6)
			var dx: float = x - data.summit.x
			var dz: float = z - data.summit.z
			h += settings.peak_height * exp(-(dx * dx + dz * dz) / sigma_sq_2)
			# Calmer valley floor, rougher slopes.
			var roughness: float = 0.35 + 0.65 * clampf(side * 1.6, 0.0, 1.0)
			h += noise.get_noise_2d(x, z) * settings.noise_amplitude * roughness
			h += detail.get_noise_2d(x, z) * settings.detail_amplitude
			var edge: float = maxf(absf(x), absf(z))
			h += settings.edge_wall_height * smoothstep(half - settings.edge_wall_width, half, edge)
			hf.heights[hf.index(xi, zi)] = h


static func _flatten_landmarks(data: WorldData, settings: WorldGenSettings, world_seed: int) -> void:
	var hf: Heightfield = data.heightfield
	data.summit.y = hf.sample_height(data.summit.x, data.summit.z)
	_flatten_disc(hf, data.summit, settings.summit_plateau_radius, 6.0, data.summit.y, 1.0)
	data.trailhead.y = hf.sample_height(data.trailhead.x, data.trailhead.z)
	_flatten_disc(hf, data.trailhead, settings.trailhead_radius, 10.0, data.trailhead.y, 1.0)
	data.meadow.y = hf.sample_height(data.meadow.x, data.meadow.z)
	_flatten_disc(hf, data.meadow, settings.meadow_radius, 22.0, data.meadow.y, 0.92)

	data.water_level = data.meadow.y - 1.3
	data.lake_center.y = data.water_level
	_carve_lake(data, settings, world_seed)


## Pull heights toward `target` inside `radius`, blending out over `falloff`.
static func _flatten_disc(hf: Heightfield, center: Vector3, radius: float, falloff: float, target: float, strength: float) -> void:
	var reach: float = radius + falloff
	_for_grid_in_radius(hf, center, reach, func(i: int, distance: float) -> void:
		var w: float = (1.0 - smoothstep(radius, reach, distance)) * strength
		hf.heights[i] = lerpf(hf.heights[i], target, w))


static func _carve_lake(data: WorldData, settings: WorldGenSettings, world_seed: int) -> void:
	var hf: Heightfield = data.heightfield
	var shore_noise: FastNoiseLite = _make_noise(world_seed + 2, 0.08, 1)
	var center: Vector3 = data.lake_center
	_for_grid_in_radius(hf, center, data.lake_radius * 1.3 + 12.0, func(i: int, distance: float) -> void:
		var p: Vector3 = Vector3(hf.origin + (i % hf.resolution) * hf.cell_size, 0.0, hf.origin + (i / hf.resolution) * hf.cell_size)
		var angle_dir: Vector3 = (p - center).normalized() * 6.0
		var radius: float = data.lake_radius * (1.0 + 0.22 * shore_noise.get_noise_2d(angle_dir.x, angle_dir.z))
		var target: float
		if distance < radius:
			var k: float = distance / radius
			target = data.water_level - settings.lake_depth * (1.0 - k * k) - 0.15
		else:
			target = data.water_level - 0.15 + (distance - radius) * 0.3
		hf.heights[i] = minf(hf.heights[i], target))


static func _paint_patches(data: WorldData, world_seed: int) -> void:
	var hf: Heightfield = data.heightfield
	var noise: FastNoiseLite = _make_noise(world_seed + 3, 0.025, 2)
	for zi: int in hf.resolution:
		for xi: int in hf.resolution:
			var p: Vector3 = hf.grid_position(xi, zi)
			hf.patch[hf.index(xi, zi)] = noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5


static func _place_spawn(data: WorldData) -> void:
	var start: Vector3 = data.trail[0] if not data.trail.is_empty() else data.trailhead
	var ahead: Vector3 = data.trail[mini(12, data.trail.size() - 1)] if data.trail.size() > 1 else start + Vector3.FORWARD
	# Stand a few meters back from the trail start, facing up the trail.
	var direction: Vector3 = Vector3(ahead.x - start.x, 0.0, ahead.z - start.z).normalized()
	var spot: Vector3 = start - direction * 4.0
	data.spawn_position = Vector3(spot.x, data.heightfield.sample_height(spot.x, spot.z) + 0.1, spot.z)
	data.spawn_yaw = atan2(-direction.x, -direction.z)


## Calls fn(index, distance) for every grid point within `radius` of `center` (x/z only).
static func _for_grid_in_radius(hf: Heightfield, center: Vector3, radius: float, fn: Callable) -> void:
	var x0: int = maxi(int(floor(hf.grid_coord(center.x - radius))), 0)
	var x1: int = mini(int(ceil(hf.grid_coord(center.x + radius))), hf.resolution - 1)
	var z0: int = maxi(int(floor(hf.grid_coord(center.z - radius))), 0)
	var z1: int = mini(int(ceil(hf.grid_coord(center.z + radius))), hf.resolution - 1)
	for zi: int in range(z0, z1 + 1):
		for xi: int in range(x0, x1 + 1):
			var dx: float = hf.origin + xi * hf.cell_size - center.x
			var dz: float = hf.origin + zi * hf.cell_size - center.z
			var distance: float = sqrt(dx * dx + dz * dz)
			if distance <= radius:
				fn.call(hf.index(xi, zi), distance)


static func _make_noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	return noise
