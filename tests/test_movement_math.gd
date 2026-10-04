extends GutTest


func test_approach_horizontal_keeps_vertical_velocity() -> void:
	var result: Vector3 = MovementMath.approach_horizontal(Vector3(0.0, -3.0, 0.0), Vector3(5.0, 99.0, 0.0), 10.0, 0.1)
	assert_almost_eq(result.x, 1.0, 0.0001)
	assert_eq(result.y, -3.0, "vertical speed is untouched")


func test_approach_horizontal_does_not_overshoot() -> void:
	var result: Vector3 = MovementMath.approach_horizontal(Vector3(1.5, 0.0, 0.0), Vector3(1.6, 0.0, 0.0), 10.0, 0.1)
	assert_almost_eq(result.x, 1.6, 0.0001)


func test_jump_velocity_reaches_height() -> void:
	var gravity: float = 9.8
	var v: float = MovementMath.jump_velocity(0.9, gravity)
	# Apex height = v² / 2g
	assert_almost_eq(v * v / (2.0 * gravity), 0.9, 0.0001)
	assert_eq(MovementMath.jump_velocity(-1.0, gravity), 0.0, "negative heights clamp to zero")


func test_input_forward_follows_yaw() -> void:
	var forward: Vector3 = MovementMath.input_to_world(Vector2(0.0, -1.0), 0.0)
	assert_almost_eq(forward.z, -1.0, 0.0001, "forward is -Z at yaw 0")
	var turned: Vector3 = MovementMath.input_to_world(Vector2(0.0, -1.0), PI / 2.0)
	assert_almost_eq(turned.x, -1.0, 0.0001, "yaw +90° turns forward to -X")


func test_smoothing_weight_is_frame_rate_independent() -> void:
	var one_step: float = MovementMath.smoothing_weight(10.0, 0.02)
	var half: float = MovementMath.smoothing_weight(10.0, 0.01)
	var two_steps: float = 1.0 - (1.0 - half) * (1.0 - half)
	assert_almost_eq(one_step, two_steps, 0.0001)
