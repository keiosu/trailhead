class_name PlayerCamera
extends Node3D
## Third-person orbit camera. Lives under Player but is top_level and follows the
## player's interpolated transform every frame, so it's smooth at any refresh rate.
## A SpringArm3D detects walls/terrain; the camera pulls in instantly and eases back out.

@export_group("Follow")
## Height above the player's feet the camera orbits around.
@export var target_height: float = 1.55
@export var follow_sharpness: float = 14.0

@export_group("Look")
@export_range(-89.0, 0.0) var min_pitch_degrees: float = -70.0
@export_range(0.0, 89.0) var max_pitch_degrees: float = 35.0
@export var start_pitch_degrees: float = -15.0

@export_group("Distance")
@export var distance: float = 4.0:
	set(value):
		distance = value
		if is_node_ready():
			_arm.spring_length = value
## Radius of the probe that keeps the camera off surfaces.
@export var collision_radius: float = 0.25:
	set(value):
		collision_radius = value
		if is_node_ready() and _arm.shape is SphereShape3D:
			(_arm.shape as SphereShape3D).radius = value
## How quickly the camera eases back out after an obstruction clears.
@export var zoom_out_sharpness: float = 5.0

var _target: Node3D
var _yaw: float = 0.0
var _pitch_angle: float = 0.0
var _current_distance: float = 0.0
var _input_blocked: bool = false

@onready var _pitch: Node3D = $Pitch
@onready var _arm: SpringArm3D = $Pitch/SpringArm3D
@onready var _camera: Camera3D = $Pitch/Camera3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_target = get_parent() as Node3D

	var probe: SphereShape3D = SphereShape3D.new()
	probe.radius = collision_radius
	_arm.shape = probe
	_arm.spring_length = distance
	_arm.collision_mask = PhysicsLayers.WORLD
	var body: CollisionObject3D = _target as CollisionObject3D
	if body != null:
		_arm.add_excluded_object(body.get_rid())

	_yaw = _target.global_rotation.y
	_pitch_angle = deg_to_rad(start_pitch_degrees)
	_current_distance = distance
	global_position = _follow_point()
	_apply_rotation()
	_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group(Groups.DEBUG_TUNABLE)
	set_meta(Groups.DEBUG_NAME_META, "camera")
	Events.debug_console_toggled.connect(_on_debug_console_toggled)


func get_yaw() -> float:
	return _yaw


## Points the camera without mouse input (spawning, cutscenes, screenshots).
func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch_angle = clampf(pitch, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees))
	_apply_rotation()


## Jump straight behind the target (after teleports) instead of gliding there.
func snap(yaw: float) -> void:
	set_look(yaw, _pitch_angle)
	global_position = _follow_point()
	_current_distance = _arm.get_hit_length() if _arm.get_hit_length() > 0.0 else distance


func _unhandled_input(event: InputEvent) -> void:
	if _input_blocked:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity: float = Settings.mouse_sensitivity
		var y_sign: float = -1.0 if Settings.invert_mouse_y else 1.0
		set_look(_yaw - motion.relative.x * sensitivity, _pitch_angle - motion.relative.y * sensitivity * y_sign)
	elif event.is_action_pressed(InputActions.PAUSE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	global_position = global_position.lerp(_follow_point(), MovementMath.smoothing_weight(follow_sharpness, delta))
	_apply_rotation()

	var free_length: float = _arm.get_hit_length()
	if free_length < _current_distance:
		_current_distance = free_length # Pull in immediately so we never clip.
	else:
		_current_distance = lerpf(_current_distance, free_length, MovementMath.smoothing_weight(zoom_out_sharpness, delta))
	_camera.position = Vector3(0.0, 0.0, _current_distance)


func _follow_point() -> Vector3:
	return _target.get_global_transform_interpolated().origin + Vector3.UP * target_height


func _apply_rotation() -> void:
	rotation = Vector3(0.0, _yaw, 0.0)
	_pitch.rotation = Vector3(_pitch_angle, 0.0, 0.0)


func _on_debug_console_toggled(is_open: bool) -> void:
	_input_blocked = is_open
