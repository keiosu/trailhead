class_name World
extends Node3D
## The procedural hiking world. Generates WorldData from GameState.world_seed and
## builds terrain, scatter and landmarks from it. Everything is derived from the seed
## and settings, so every peer builds the same world locally (M2 sends the seed).
## Debug console: `list world`, `set world settings.<name> <value>`, then `regen`.

const LOG_TAG: String = "World"
const CONSOLE_HELP: Dictionary = {
	"regen": "regen [seed|random] — rebuild the world (keeps the seed if none given)",
	"seed": "seed — print the current world seed",
	"tp": "tp <trailhead|meadow|lake|summit|spawn|x y z> — teleport the player",
	"respawn": "respawn — back to the trailhead",
}

@export var settings: WorldGenSettings

var data: WorldData

@onready var _terrain: Terrain = $Terrain
@onready var _scatter: Scatter = $Scatter
@onready var _landmarks: Landmarks = $Landmarks
@onready var _player: Player = $Player


func _ready() -> void:
	add_to_group(Groups.DEBUG_TUNABLE)
	set_meta(Groups.DEBUG_NAME_META, "world")
	regenerate(GameState.world_seed)


func regenerate(world_seed: int) -> void:
	var started: int = Time.get_ticks_msec()
	GameState.world_seed = world_seed
	data = WorldGenerator.generate(settings, world_seed)
	_terrain.build(data)
	_scatter.build(data, settings)
	_landmarks.build(data, settings)
	respawn_player()
	Log.info(LOG_TAG, "World ready in %d ms (seed %d)" % [Time.get_ticks_msec() - started, world_seed])


func respawn_player() -> void:
	_player.teleport(data.spawn_position, data.spawn_yaw)


func console_regen(args: PackedStringArray) -> String:
	var next_seed: int = GameState.world_seed
	if args.size() > 0:
		if args[0] == "random":
			next_seed = randi() % 1000000
		elif args[0].is_valid_int():
			next_seed = args[0].to_int()
		else:
			return "Usage: " + CONSOLE_HELP["regen"]
	regenerate(next_seed)
	return "Regenerated world with seed %d" % next_seed


func console_seed(_args: PackedStringArray) -> String:
	return "Seed: %d" % GameState.world_seed


func console_respawn(_args: PackedStringArray) -> String:
	respawn_player()
	return "Back at the trailhead"


func console_tp(args: PackedStringArray) -> String:
	var spots: Dictionary = data.landmarks()
	spots["spawn"] = data.spawn_position
	var target: Vector3
	if args.size() == 1 and spots.has(args[0]):
		target = spots[args[0]]
	elif args.size() == 3 and args[0].is_valid_float() and args[1].is_valid_float() and args[2].is_valid_float():
		target = Vector3(args[0].to_float(), args[1].to_float(), args[2].to_float())
	else:
		return "Usage: %s" % CONSOLE_HELP["tp"]
	# Land on the ground (or the lake surface), just beside the named spot.
	target.y = maxf(data.heightfield.sample_height(target.x, target.z), data.water_level) + 0.5
	_player.teleport(target, _player.get_yaw())
	return "Teleported to (%.0f, %.0f, %.0f)" % [target.x, target.y, target.z]
