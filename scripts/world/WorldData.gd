class_name WorldData
extends RefCounted
## Output of WorldGenerator: everything needed to build the world's nodes.
## Pure data, identical on every peer for the same seed and settings.

var world_seed: int = 0
var heightfield: Heightfield
## Trail centerline from trailhead to summit, ~1 m spacing, y = trail surface height.
var trail: PackedVector3Array = PackedVector3Array()

var trailhead: Vector3
var summit: Vector3
var meadow: Vector3
var lake_center: Vector3
var lake_radius: float = 0.0
var water_level: float = -1000.0

var spawn_position: Vector3
var spawn_yaw: float = 0.0


## Named spots for teleporting and (later) the trail journal.
func landmarks() -> Dictionary:
	return {
		"trailhead": trailhead,
		"meadow": meadow,
		"lake": lake_center,
		"summit": summit,
	}


## Steepest climb along the trail, in degrees.
func max_trail_grade_degrees() -> float:
	var steepest: float = 0.0
	for i: int in range(1, trail.size()):
		var a: Vector3 = trail[i - 1]
		var b: Vector3 = trail[i]
		var run: float = Vector2(b.x - a.x, b.z - a.z).length()
		if run > 0.001:
			steepest = maxf(steepest, rad_to_deg(atan(absf(b.y - a.y) / run)))
	return steepest
