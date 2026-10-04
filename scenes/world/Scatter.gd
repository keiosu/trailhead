class_name Scatter
extends Node3D
## Trees, bushes, rocks, grass and flowers as chunked MultiMeshes, so each chunk is
## frustum-culled and can fade out with distance. Placement is seeded per chunk and
## layer, so it's identical on every peer. Trees and boulders get collision.

const LOG_TAG: String = "Scatter"

enum Kind { PINE, BROADLEAF, BUSH, ROCK, BOULDER, GRASS, FLOWER }

const FLOWER_TINTS: Array[Color] = [Color(1, 1, 0.95), Color(1, 0.86, 0.3), Color(1, 0.6, 0.72), Color(0.72, 0.68, 1)]

@export var foliage_material: ShaderMaterial
@export var rock_material: ShaderMaterial
@export var grass_material: ShaderMaterial

var _meshes: Dictionary = {}


func build(data: WorldData, settings: WorldGenSettings) -> void:
	var started: int = Time.get_ticks_usec()
	for child: Node in get_children():
		child.queue_free()
	if _meshes.is_empty():
		_meshes = {
			Kind.PINE: PropMeshes.pine(), Kind.BROADLEAF: PropMeshes.broadleaf(), Kind.BUSH: PropMeshes.bush(),
			Kind.ROCK: PropMeshes.rock(0), Kind.BOULDER: PropMeshes.rock(1), Kind.GRASS: PropMeshes.grass_tuft(),
			Kind.FLOWER: PropMeshes.flower(),
		}

	var forest: FastNoiseLite = FastNoiseLite.new()
	forest.seed = data.world_seed + 10
	forest.frequency = settings.forest_frequency
	forest.fractal_octaves = 2

	var hf: Heightfield = data.heightfield
	var chunks: int = int(ceil(hf.size / settings.chunk_size))
	var total: int = 0
	for cz: int in chunks:
		for cx: int in chunks:
			var corner: Vector3 = Vector3(hf.origin + cx * settings.chunk_size, 0.0, hf.origin + cz * settings.chunk_size)
			for kind: int in Kind.values():
				total += _build_chunk_layer(data, settings, forest, kind, cx, cz, corner)
	Log.info(LOG_TAG, "%d instances in %d ms" % [total, (Time.get_ticks_usec() - started) / 1000])


func _build_chunk_layer(data: WorldData, settings: WorldGenSettings, forest: FastNoiseLite, kind: int, cx: int, cz: int, corner: Vector3) -> int:
	var hf: Heightfield = data.heightfield
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([data.world_seed, cx, cz, kind])
	var area: float = settings.chunk_size * settings.chunk_size
	var attempts: int = int(_density(settings, kind) * area + rng.randf())
	var center: Vector3 = corner + Vector3(settings.chunk_size, 0.0, settings.chunk_size) * 0.5
	var transforms: Array[Transform3D] = []
	var tints: PackedColorArray = PackedColorArray()
	var treeline: float = data.summit.y * settings.treeline

	for i: int in attempts:
		var x: float = corner.x + rng.randf() * settings.chunk_size
		var z: float = corner.z + rng.randf() * settings.chunk_size
		var roll: float = rng.randf()
		var trail_gap: float = hf.sample_trail_distance(x, z) - settings.trail_width * 0.5
		if trail_gap < 0.3:
			continue
		var y: float = hf.sample_height(x, z)
		var normal: Vector3 = hf.nearest_normal(x, z)
		var slope: float = rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		var lake_gap: float = Vector2(x - data.lake_center.x, z - data.lake_center.z).length() - data.lake_radius * 1.25
		var meadow_d: float = Vector2(x - data.meadow.x, z - data.meadow.z).length()
		var in_clearing: bool = _near(x, z, data.trailhead, settings.trailhead_radius) or _near(x, z, data.summit, settings.summit_plateau_radius + 4.0)
		var scale: float = 1.0
		var tint: Color = Color(1, 1, 1)
		var align_to_ground: bool = false
		var sink: float = 0.0

		match kind:
			Kind.PINE:
				if trail_gap < 2.5 or lake_gap < 4.0 or in_clearing or slope > 34.0 or y > treeline:
					continue
				if meadow_d < settings.meadow_radius * 0.8 or roll > _forest_chance(_forest_value(forest, x, z), settings.forest_threshold):
					continue
				scale = rng.randf_range(1.15, 2.1)
				tint = _vary(rng, 0.12)
			Kind.BROADLEAF:
				if trail_gap < 2.5 or lake_gap < 3.0 or in_clearing or slope > 28.0 or y > treeline * 0.55:
					continue
				if meadow_d < settings.meadow_radius * 0.55 or roll > 0.25 + _forest_chance(_forest_value(forest, x, z), settings.forest_threshold):
					continue
				scale = rng.randf_range(1.0, 1.6)
				tint = _vary(rng, 0.1)
			Kind.BUSH:
				if trail_gap < 1.2 or lake_gap < 1.0 or slope > 32.0 or y > treeline:
					continue
				scale = rng.randf_range(0.7, 1.4)
				tint = _vary(rng, 0.12)
				align_to_ground = true
			Kind.ROCK:
				if trail_gap < 0.6 or lake_gap < -2.0:
					continue
				# Rocks favor steep and high ground.
				if roll > 0.3 + slope / 40.0 + (0.5 if y > treeline else 0.0):
					continue
				scale = rng.randf_range(0.4, 1.0)
				tint = _vary(rng, 0.08)
				align_to_ground = true
			Kind.BOULDER:
				if trail_gap < 2.0 or lake_gap < 0.0 or in_clearing:
					continue
				scale = rng.randf_range(1.8, 3.4)
				tint = _vary(rng, 0.06)
				sink = 0.25 * scale
			Kind.GRASS:
				if trail_gap < 0.3 or y < data.water_level + 0.8 or slope > 30.0 or y > treeline * 0.92:
					continue
				scale = rng.randf_range(0.8, 1.4)
				tint = _vary(rng, 0.1)
				align_to_ground = true
			Kind.FLOWER:
				var in_meadow: bool = meadow_d < settings.meadow_radius
				if trail_gap < 0.4 or y < data.water_level + 0.8 or slope > 25.0 or (not in_meadow and roll > 0.15):
					continue
				scale = rng.randf_range(0.8, 1.3)
				tint = FLOWER_TINTS[rng.randi() % FLOWER_TINTS.size()]

		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU)
		if align_to_ground:
			basis = Basis(Quaternion(Vector3.UP, normal.lerp(Vector3.UP, 0.4).normalized())) * basis
		elif kind == Kind.BOULDER:
			basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		basis = basis.scaled(Vector3.ONE * scale)
		transforms.append(Transform3D(basis, Vector3(x, y - sink, z) - center))
		tints.append(tint)

	if transforms.is_empty():
		return 0
	_spawn_multimesh(kind, transforms, tints, center, settings)
	if kind == Kind.PINE or kind == Kind.BROADLEAF or kind == Kind.BOULDER:
		_spawn_colliders(kind, transforms, center)
	return transforms.size()


func _spawn_multimesh(kind: int, transforms: Array[Transform3D], tints: PackedColorArray, center: Vector3, settings: WorldGenSettings) -> void:
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _meshes[kind]
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, tints[i])

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "%s_%d_%d" % [Kind.keys()[kind], int(center.x), int(center.z)]
	instance.multimesh = multimesh
	instance.position = center
	var chunk_reach: float = settings.chunk_size * 0.75
	match kind:
		Kind.GRASS, Kind.FLOWER:
			instance.material_override = grass_material if kind == Kind.GRASS else foliage_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.visibility_range_end = settings.grass_view_distance + chunk_reach
		Kind.ROCK, Kind.BUSH:
			instance.material_override = rock_material if kind == Kind.ROCK else foliage_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == Kind.ROCK else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			instance.visibility_range_end = settings.small_prop_view_distance + chunk_reach
		Kind.BOULDER:
			instance.material_override = rock_material
		_:
			instance.material_override = foliage_material
	add_child(instance)


func _spawn_colliders(kind: int, transforms: Array[Transform3D], center: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Colliders_%s_%d_%d" % [Kind.keys()[kind], int(center.x), int(center.z)]
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = center
	for xform: Transform3D in transforms:
		var scale: float = xform.basis.get_scale().x
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		if kind == Kind.BOULDER:
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = 0.42 * scale
			shape_node.shape = sphere
			shape_node.position = xform.origin + Vector3(0, 0.2 * scale, 0)
		else:
			var trunk: CylinderShape3D = CylinderShape3D.new()
			trunk.radius = 0.2 * scale
			trunk.height = 2.5 * scale
			shape_node.shape = trunk
			shape_node.position = xform.origin + Vector3(0, trunk.height * 0.5, 0)
		body.add_child(shape_node)
	add_child(body)


static func _density(settings: WorldGenSettings, kind: int) -> float:
	match kind:
		Kind.PINE: return settings.pine_density
		Kind.BROADLEAF: return settings.broadleaf_density
		Kind.BUSH: return settings.bush_density
		Kind.ROCK: return settings.rock_density
		Kind.BOULDER: return settings.boulder_density
		Kind.GRASS: return settings.grass_density
		Kind.FLOWER: return settings.flower_density
	return 0.0


static func _forest_value(forest: FastNoiseLite, x: float, z: float) -> float:
	return forest.get_noise_2d(x, z) * 0.5 + 0.5


## 0 below the threshold, ramping to 1 in dense forest.
static func _forest_chance(value: float, threshold: float) -> float:
	return clampf((value - threshold) / 0.18, 0.0, 1.0)


static func _near(x: float, z: float, point: Vector3, radius: float) -> bool:
	return Vector2(x - point.x, z - point.z).length() < radius


static func _vary(rng: RandomNumberGenerator, amount: float) -> Color:
	var v: float = 1.0 + rng.randf_range(-amount, amount)
	return Color(v * rng.randf_range(0.97, 1.03), v, v * rng.randf_range(0.95, 1.02))
