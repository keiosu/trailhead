class_name WorldGenSettings
extends Resource
## Every knob for procedural world generation. The same settings + seed always
## produce the same world on every peer.

@export_group("Size")
## Side length of the square world in meters.
@export var world_size: float = 512.0
## Terrain grid spacing in meters (mesh and collision).
@export var cell_size: float = 2.0

@export_group("Shape")
## How much the valley floor climbs from trailhead to the foot of the summit.
@export var rise_height: float = 32.0
## Extra height of the summit cone.
@export var peak_height: float = 62.0
## Gaussian radius (sigma) of the summit cone.
@export var peak_radius: float = 50.0
## Height of the valley's side ridges at the world edge.
@export var side_height: float = 46.0
## How far the valley center line wanders left/right (m).
@export var valley_wiggle: float = 26.0
@export var noise_amplitude: float = 11.0
@export var noise_frequency: float = 0.0065
@export_range(1, 8) var noise_octaves: int = 4
@export var detail_amplitude: float = 1.6
@export var detail_frequency: float = 0.035
## Steep rim around the map edge keeps hikers in and hides the edge.
@export var edge_wall_height: float = 38.0
@export var edge_wall_width: float = 36.0

@export_group("Landmarks")
## Distance of the trailhead from the south edge.
@export var trailhead_inset: float = 62.0
@export var trailhead_radius: float = 15.0
## Distance of the summit from the north edge.
@export var summit_inset: float = 78.0
@export var summit_plateau_radius: float = 7.0
## 0 = trailhead, 1 = summit.
@export_range(0.0, 1.0) var meadow_progress: float = 0.42
@export var meadow_radius: float = 38.0
@export var lake_radius: float = 15.0
@export var lake_depth: float = 3.0
## Distance from the meadow center to the lake center.
@export var lake_offset: float = 19.0

@export_group("Trail")
@export var trail_width: float = 2.6
## Width of the cut/fill blend on each side of the trail.
@export var trail_shoulder: float = 3.0
## Pathfinding grid spacing (m).
@export var trail_grid_step: float = 4.0
## Grade (rise/run) the trail prefers; steeper costs rise steeply.
@export var trail_preferred_grade: float = 0.36
## How strongly the trail wanders off the straight line (0 = beeline).
@export var trail_wander: float = 3.5
## Size (m) of the bends the wander produces.
@export var trail_wander_scale: float = 60.0
## Moving-average half-window (m) for the trail's height profile.
@export var trail_height_smoothing: int = 7
## Spacing (m) of trail-side cairns.
@export var cairn_spacing: float = 70.0

@export_group("Scatter")
@export var chunk_size: float = 32.0
## Instances per square meter, before masks.
@export var pine_density: float = 0.022
@export var broadleaf_density: float = 0.006
@export var bush_density: float = 0.012
@export var rock_density: float = 0.004
@export var boulder_density: float = 0.0008
@export var grass_density: float = 0.55
@export var flower_density: float = 0.02
## Pines stop growing above this fraction of the summit height.
@export_range(0.0, 1.0) var treeline: float = 0.72
## Frequency of the noise that groups trees into forests and clearings.
@export var forest_frequency: float = 0.012
## Trees grow only where the forest noise (0..1) is above this.
@export_range(0.0, 1.0) var forest_threshold: float = 0.42
@export var grass_view_distance: float = 55.0
@export var small_prop_view_distance: float = 140.0
