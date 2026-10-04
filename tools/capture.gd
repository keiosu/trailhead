extends SceneTree
## Dev tool: boots a scene windowed, waits for it to settle, saves a screenshot, quits.
## Usage (needs a window, not --headless):
##   godot --path . -s res://tools/capture.gd
## Env vars: CAPTURE_SCENE (default Main.tscn), CAPTURE_OUT (default user://capture.png),
##           CAPTURE_FRAMES (default 90), CAPTURE_YAW / CAPTURE_PITCH (degrees, aims the player camera).

const DEFAULT_SCENE: String = "res://scenes/main/Main.tscn"


func _initialize() -> void:
	var scene_path: String = _env("CAPTURE_SCENE", DEFAULT_SCENE)
	var out_path: String = _env("CAPTURE_OUT", "user://capture.png")
	var frames: int = int(_env("CAPTURE_FRAMES", "90"))
	change_scene_to_file(scene_path)
	_capture.call_deferred(out_path, frames)


func _capture(out_path: String, frames: int) -> void:
	# change_scene_to_file is deferred; give the new scene a few frames to enter the tree.
	for i: int in 3:
		await process_frame
	var camera: Node = _find_camera(root)
	if camera != null and OS.has_environment("CAPTURE_YAW"):
		camera.call("set_look", deg_to_rad(float(_env("CAPTURE_YAW", "0"))), deg_to_rad(float(_env("CAPTURE_PITCH", "-15"))))
	for i: int in frames:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(out_path)
	print("capture: saved %s (%s) -> %s" % [out_path, error_string(error), ProjectSettings.globalize_path(out_path)])
	quit()


## Untyped on purpose: naming PlayerCamera here would compile it before autoloads exist.
func _find_camera(node: Node) -> Node:
	if node.has_method("set_look"):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_camera(child)
		if found != null:
			return found
	return null


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.has_environment(key) else fallback
