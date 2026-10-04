class_name MovementMath
extends RefCounted
## Pure movement helpers, kept separate from Player so they can be unit tested.


## Moves the horizontal part of `current` toward `target` by at most `rate * delta`.
## The vertical component of `current` is preserved.
static func approach_horizontal(current: Vector3, target: Vector3, rate: float, delta: float) -> Vector3:
	var flat: Vector3 = Vector3(current.x, 0.0, current.z)
	var flat_target: Vector3 = Vector3(target.x, 0.0, target.z)
	flat = flat.move_toward(flat_target, rate * delta)
	return Vector3(flat.x, current.y, flat.z)


## Initial upward speed needed to reach `height` meters under `gravity`.
static func jump_velocity(height: float, gravity: float) -> float:
	return sqrt(2.0 * gravity * maxf(height, 0.0))


## Turns 2D stick/WASD input into a world-space direction on the XZ plane,
## relative to a camera yaw (radians). Input y = -1 means "forward".
static func input_to_world(input: Vector2, yaw: float) -> Vector3:
	var local: Vector3 = Vector3(input.x, 0.0, input.y)
	return local.rotated(Vector3.UP, yaw)


## Frame-rate independent exponential smoothing factor for lerp().
static func smoothing_weight(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)
