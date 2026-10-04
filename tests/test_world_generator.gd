extends GutTest
## World generation: determinism, sane layout, and collision matching the mesh.

const SETTINGS: WorldGenSettings = preload("res://resources/world/default_worldgen.tres")

var _cache: Dictionary = {}


## Generation takes ~0.5 s, so share results across tests.
func _world(world_seed: int) -> WorldData:
	if not _cache.has(world_seed):
		_cache[world_seed] = WorldGenerator.generate(SETTINGS, world_seed)
	return _cache[world_seed]


func test_same_seed_gives_identical_world() -> void:
	var a: WorldData = WorldGenerator.generate(SETTINGS, 1234)
	var b: WorldData = _world(1234)
	assert_eq(a.heightfield.checksum(), b.heightfield.checksum(), "heights match")
	assert_eq(a.trail, b.trail, "trail matches")
	assert_eq(a.spawn_position, b.spawn_position, "spawn matches")


func test_different_seeds_differ() -> void:
	assert_ne(_world(1234).heightfield.checksum(), _world(99).heightfield.checksum())


func test_trail_runs_trailhead_to_summit() -> void:
	for world_seed: int in [1234, 99, 7]:
		var data: WorldData = _world(world_seed)
		assert_gt(data.trail.size(), 300, "seed %d: trail is a real hike" % world_seed)
		assert_lt(_flat_distance(data.trail[0], data.trailhead), 1.0, "seed %d: starts at the trailhead" % world_seed)
		assert_lt(_flat_distance(data.trail[data.trail.size() - 1], data.summit), 1.0, "seed %d: ends at the summit" % world_seed)
		assert_gt(data.summit.y - data.trailhead.y, 60.0, "seed %d: summit is well above the trailhead" % world_seed)


func test_trail_is_walkable() -> void:
	for world_seed: int in [1234, 99, 7]:
		var data: WorldData = _world(world_seed)
		assert_lt(data.max_trail_grade_degrees(), 34.0, "seed %d: trail grade stays well under the 42° slope limit" % world_seed)
		var hf: Heightfield = data.heightfield
		var dry: bool = true
		for p: Vector3 in data.trail:
			if hf.sample_height(p.x, p.z) < data.water_level and _flat_distance(p, data.lake_center) < data.lake_radius * 1.4:
				dry = false
		assert_true(dry, "seed %d: trail never goes into the lake" % world_seed)


func test_spawn_is_on_dry_ground_at_trailhead() -> void:
	var data: WorldData = _world(1234)
	var ground: float = data.heightfield.sample_height(data.spawn_position.x, data.spawn_position.z)
	assert_almost_eq(data.spawn_position.y, ground + 0.1, 0.01)
	assert_lt(_flat_distance(data.spawn_position, data.trailhead), 10.0)


func test_lake_holds_water() -> void:
	var data: WorldData = _world(1234)
	var bottom: float = data.heightfield.sample_height(data.lake_center.x, data.lake_center.z)
	assert_lt(bottom, data.water_level - 1.0, "lake center is under water")
	var meadow_ground: float = data.heightfield.sample_height(data.meadow.x, data.meadow.z)
	assert_gt(meadow_ground, data.water_level, "meadow is dry")


func test_sample_height_matches_grid_points() -> void:
	var hf: Heightfield = _world(1234).heightfield
	for i: int in 20:
		var xi: int = (i * 37) % hf.resolution
		var zi: int = (i * 53) % hf.resolution
		var p: Vector3 = hf.grid_position(xi, zi)
		assert_almost_eq(hf.sample_height(p.x, p.z), p.y, 0.001)


func test_collision_matches_terrain_heights() -> void:
	var data: WorldData = _world(1234)
	var terrain: Terrain = Terrain.new()
	add_child(terrain)
	terrain.build(data)
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = terrain.get_world_3d().direct_space_state
	var worst: float = 0.0
	for i: int in 30:
		var x: float = -200.0 + (i * 97) % 400 + 0.37
		var z: float = -200.0 + (i * 61) % 400 + 0.71
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, 500.0, z), Vector3(x, -500.0, z))
		var hit: Dictionary = space.intersect_ray(query)
		assert_false(hit.is_empty(), "ray at (%.0f, %.0f) hits the terrain" % [x, z])
		if not hit.is_empty():
			worst = maxf(worst, absf((hit["position"] as Vector3).y - data.heightfield.sample_height(x, z)))
	assert_lt(worst, 0.05, "collision surface matches the rendered heights")
	remove_child(terrain)
	terrain.free()


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
