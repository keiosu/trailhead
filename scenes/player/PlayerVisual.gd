class_name PlayerVisual
extends Node3D
## The hiker's mesh: faces the direction of travel, bobs while walking, and eases
## over step-ups. Updated on physics ticks so physics interpolation smooths it.

@export var turn_sharpness: float = 12.0
## How quickly the mesh catches up after a step-up (higher = snappier).
@export var step_sharpness: float = 16.0
@export var bob_height: float = 0.035
## Bobs per meter traveled.
@export var bob_frequency: float = 1.4

var _velocity: Vector3 = Vector3.ZERO
var _on_floor: bool = true
var _max_speed: float = 1.0
var _step_offset: float = 0.0
var _bob_phase: float = 0.0


## Called by Player every physics tick.
func update_motion(velocity: Vector3, on_floor: bool, max_speed: float) -> void:
	_velocity = velocity
	_on_floor = on_floor
	_max_speed = maxf(max_speed, 0.01)


## Snap to face `yaw` (teleports, spawning).
func face(yaw: float) -> void:
	rotation.y = yaw
	_step_offset = 0.0


## The body just popped up `rise` meters; keep the mesh where it was and ease it up.
func absorb_step(rise: float) -> void:
	_step_offset -= rise


func _physics_process(delta: float) -> void:
	var flat: Vector3 = Vector3(_velocity.x, 0.0, _velocity.z)
	var speed: float = flat.length()
	if speed > 0.1:
		var target_yaw: float = atan2(-flat.x, -flat.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, MovementMath.smoothing_weight(turn_sharpness, delta))

	_step_offset = lerpf(_step_offset, 0.0, MovementMath.smoothing_weight(step_sharpness, delta))

	var bob: float = 0.0
	if _on_floor and speed > 0.1:
		_bob_phase = fmod(_bob_phase + speed * bob_frequency * PI * delta, TAU)
		bob = absf(sin(_bob_phase)) * bob_height * clampf(speed / _max_speed, 0.3, 1.0)
	else:
		_bob_phase = 0.0
	position.y = _step_offset + bob
