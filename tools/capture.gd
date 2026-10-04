extends SceneTree
## Dev tool: boots a scene windowed, waits for it to settle, saves a screenshot, quits.
## Usage (needs a window, not --headless):
##   godot --path . -s res://tools/capture.gd
## Env vars: CAPTURE_SCENE (default Main.tscn), CAPTURE_OUT (default user://capture.png),
##           CAPTURE_FRAMES (default 90), CAPTURE_YAW / CAPTURE_PITCH (degrees, aims the player camera),
##           CAPTURE_CMDS (debug console commands separated by ';', run before aiming, e.g. "tp summit").

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
	var console: Node = _find_method(root, "run_command")
	if console != null and OS.has_environment("CAPTURE_CMDS"):
		for command: String in _env("CAPTURE_CMDS", "").split(";", false):
			print("capture: > %s
%s" % [command, console.call("run_command", command)])
		for i: int in 3:
			await process_frame
	var camera: Node = _find_method(root, "set_look")
	if camera != null and OS.has_environment("CAPTURE_YAW"):
		camera.call("set_look", deg_to_rad(float(_env("CAPTURE_YAW", "0"))), deg_to_rad(float(_env("CAPTURE_PITCH", "-15"))))
	for i: int in frames:
		await process_frame
	print("capture: %d fps, process %.1f ms, physics %.1f ms, %d draw calls, %dk primitives" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(out_path)
	print("capture: saved %s (%s) -> %s" % [out_path, error_string(error), ProjectSettings.globalize_path(out_path)])
	quit()


## Duck-typed on purpose: naming game classes here would compile them before autoloads exist.
func _find_method(node: Node, method: String) -> Node:
	if node.has_method(method):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_method(child, method)
		if found != null:
			return found
	return null


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.has_environment(key) else fallback
