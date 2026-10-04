extends Node
## Entry scene. Owns boot and (later) scene switching between menu, lobby and world.

const LOG_TAG: String = "Main"

## Scene loaded on boot: the procedural world. M2 swaps this for the main menu.
## (The M1 gray-box course is still at res://scenes/world/GrayboxLevel.tscn.)
@export var start_scene: PackedScene


func _ready() -> void:
	Log.info(LOG_TAG, "Trailhead booting — Godot %s" % Engine.get_version_info().string)
	Log.info(LOG_TAG, "Renderer: %s | Physics 3D: %s" % [
		RenderingServer.get_current_rendering_method(),
		ProjectSettings.get_setting("physics/3d/physics_engine"),
	])
	Log.info(LOG_TAG, "Player name: %s" % Settings.player_name)
	# TODO(M2): only the host picks the seed; clients receive it on join.
	GameState.world_seed = Net.launch_args.world_seed if Net.launch_args.has_seed() else randi() % 1000000
	if start_scene != null:
		add_child(start_scene.instantiate())
