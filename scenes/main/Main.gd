extends Node
## Entry scene. Owns boot and (later) scene switching between menu, lobby and world.

const LOG_TAG: String = "Main"


func _ready() -> void:
	Log.info(LOG_TAG, "Trailhead booting — Godot %s" % Engine.get_version_info().string)
	Log.info(LOG_TAG, "Renderer: %s | Physics 3D: %s" % [
		RenderingServer.get_current_rendering_method(),
		ProjectSettings.get_setting("physics/3d/physics_engine"),
	])
	Log.info(LOG_TAG, "Player name: %s" % Settings.player_name)
