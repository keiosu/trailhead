extends SceneTree
## Dev tool: renders a top-down map of a generated world (no window needed).
## Usage: godot --headless --path . -s res://tools/world_map.gd -- --seed=42
## Env: MAP_OUT (default user://world_map.png). North (-Z) is up.

const SETTINGS_PATH: String = "res://resources/world/default_worldgen.tres"
const PIXELS_PER_CELL: int = 2


func _initialize() -> void:
	var world_seed: int = 42
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed=") and arg.substr(7).is_valid_int():
			world_seed = arg.substr(7).to_int()
	var out_path: String = OS.get_environment("MAP_OUT") if OS.has_environment("MAP_OUT") else "user://world_map.png"
	# Loaded dynamically so this tool doesn't compile game classes before autoloads exist.
	var generator: GDScript = load("res://scripts/world/WorldGenerator.gd")
	var data: RefCounted = generator.call("generate", load(SETTINGS_PATH), world_seed)
	var image: Image = _draw(data)
	image.save_png(out_path)
	print("world_map: seed %d -> %s" % [world_seed, ProjectSettings.globalize_path(out_path)])
	quit()


func _draw(data: Object) -> Image:
	var hf: Object = data.get("heightfield")
	var n: int = hf.get("resolution")
	var heights: PackedFloat32Array = hf.get("heights")
	var trail_distance: PackedFloat32Array = hf.get("trail_distance")
	var water_level: float = data.get("water_level")
	var lake_center: Vector3 = data.get("lake_center")
	var lake_reach: float = float(data.get("lake_radius")) * 1.4
	var cell: float = hf.get("cell_size")
	var origin: float = hf.get("origin")
	var lo: float = INF
	var hi: float = -INF
	for h: float in heights:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	var image: Image = Image.create(n * PIXELS_PER_CELL, n * PIXELS_PER_CELL, false, Image.FORMAT_RGB8)
	for zi: int in n:
		for xi: int in n:
			var i: int = zi * n + xi
			var h: float = heights[i]
			var t: float = (h - lo) / maxf(hi - lo, 0.001)
			var normal: Vector3 = hf.call("grid_normal", xi, zi)
			var shade: float = clampf(0.55 + normal.dot(Vector3(-0.5, 0.7, -0.5).normalized()) * 0.6, 0.3, 1.2)
			var color: Color = Color(0.35, 0.65, 0.3).lerp(Color(0.85, 0.85, 0.8), t) * shade
			if rad_to_deg(acos(normal.y)) > 42.0:
				color = color.lerp(Color(0.5, 0.45, 0.55), 0.5)
			var at: Vector2 = Vector2(origin + xi * cell - lake_center.x, origin + zi * cell - lake_center.z)
			if h < water_level and at.length() < lake_reach:
				color = Color(0.25, 0.55, 0.85)
			if trail_distance[i] < 1.6:
				color = Color(0.85, 0.45, 0.15)
			image.fill_rect(Rect2i(xi * PIXELS_PER_CELL, zi * PIXELS_PER_CELL, PIXELS_PER_CELL, PIXELS_PER_CELL), color)
	var landmarks: Dictionary = data.call("landmarks")
	for key: String in landmarks:
		_dot(image, hf, landmarks[key], Color.RED if key == "summit" else Color.MAGENTA)
	_dot(image, hf, data.get("spawn_position"), Color.WHITE)
	return image


func _dot(image: Image, hf: Object, p: Vector3, color: Color) -> void:
	var cell: float = hf.get("cell_size")
	var origin: float = hf.get("origin")
	var px: int = int((p.x - origin) / cell) * PIXELS_PER_CELL
	var pz: int = int((p.z - origin) / cell) * PIXELS_PER_CELL
	image.fill_rect(Rect2i(px - 4, pz - 4, 9, 9), color)
