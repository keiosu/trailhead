extends GutTest
## Physics integration tests: a real Player on real Jolt geometry, driven without input.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const PHYSICS_FPS: int = 60

var _world: Node3D


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)
	# Ground: top face at y = 0.
	_add_box(Vector3(60.0, 1.0, 60.0), Vector3(0.0, -0.5, 0.0))


func _add_box(size: Vector3, center: Vector3, pitch_degrees: float = 0.0) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	body.rotation_degrees.x = pitch_degrees
	_world.add_child(body)
	return body


## A ramp rising toward -Z whose low end sits on the ground at z = 0.
func _add_ramp(degrees: float, length: float = 10.0) -> void:
	var t: float = 0.5
	var angle: float = deg_to_rad(degrees)
	var center: Vector3 = Vector3(0.0, -t / 2.0 * cos(angle) + length / 2.0 * sin(angle), -t / 2.0 * sin(angle) - length / 2.0 * cos(angle))
	_add_box(Vector3(4.0, t, length), center, degrees)


func _spawn_player(at: Vector3) -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.read_local_input = false
	player.position = at
	_world.add_child(player)
	return player


func _simulate(seconds: float) -> void:
	await wait_physics_frames(int(seconds * PHYSICS_FPS))


func test_walk_and_sprint_reach_target_speed() -> void:
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 20.0))
	await _simulate(0.3)
	player.move_input = Vector2(0.0, -1.0)
	await _simulate(1.0)
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), player.walk_speed, 0.05, "walk speed")
	player.sprint_held = true
	await _simulate(1.0)
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), player.sprint_speed, 0.05, "sprint speed")
	assert_true(player.is_on_floor())


func test_stops_when_input_released() -> void:
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 20.0))
	player.move_input = Vector2(1.0, 0.0)
	await _simulate(1.0)
	player.move_input = Vector2.ZERO
	await _simulate(0.5)
	assert_almost_eq(player.velocity.length(), 0.0, 0.01)


func test_standing_on_walkable_slope_does_not_slide() -> void:
	_add_ramp(35.0)
	# Drop onto the middle of the ramp.
	var player: Player = _spawn_player(Vector3(0.0, 3.2, -4.0))
	await _simulate(1.0)
	assert_true(player.is_on_floor(), "landed on the ramp")
	var start: Vector3 = player.global_position
	await _simulate(2.0)
	assert_lt(player.global_position.distance_to(start), 0.02, "no sliding on a 35° slope")


func test_can_walk_up_walkable_slope() -> void:
	_add_ramp(35.0)
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 2.0))
	player.move_input = Vector2(0.0, -1.0)
	await _simulate(4.0)
	assert_gt(player.global_position.y, 2.0, "climbed the 35° ramp")


func test_cannot_walk_up_too_steep_slope() -> void:
	_add_ramp(50.0)
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 2.0))
	player.move_input = Vector2(0.0, -1.0)
	player.sprint_held = true
	await _simulate(4.0)
	assert_lt(player.global_position.y, 0.6, "blocked by a 50° slope")


func test_steps_onto_low_ledge() -> void:
	_add_box(Vector3(4.0, 0.3, 2.0), Vector3(0.0, 0.15, -2.0))
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 1.0))
	player.move_input = Vector2(0.0, -1.0)
	await _simulate(2.5)
	assert_almost_eq(player.global_position.y, 0.3, 0.05, "standing on the 0.3 m ledge")
	assert_lt(player.global_position.z, -1.2, "and moved onto it")


func test_blocked_by_tall_ledge() -> void:
	_add_box(Vector3(4.0, 0.6, 2.0), Vector3(0.0, 0.3, -2.0))
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 1.0))
	player.move_input = Vector2(0.0, -1.0)
	await _simulate(2.5)
	assert_lt(player.global_position.y, 0.05, "0.6 m is above step height")
	assert_gt(player.global_position.z, -0.75, "stopped at the ledge face")


func test_jump_leaves_ground_and_lands() -> void:
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 20.0))
	await _simulate(0.3)
	assert_true(player.is_on_floor())
	player.request_jump()
	var peak: float = 0.0
	for i: int in 30:
		await wait_physics_frames(1)
		peak = maxf(peak, player.global_position.y)
	assert_almost_eq(peak, player.jump_height, 0.1, "jump apex near jump_height")
	await _simulate(1.0)
	assert_true(player.is_on_floor(), "landed again")


func test_low_ledge_blocks_without_step_up() -> void:
	# Control for test_steps_onto_low_ledge: proves step-up, not the capsule shape, does the work.
	_add_box(Vector3(4.0, 0.3, 2.0), Vector3(0.0, 0.15, -2.0))
	var player: Player = _spawn_player(Vector3(0.0, 0.05, 1.0))
	player.step_height = 0.0
	player.move_input = Vector2(0.0, -1.0)
	await _simulate(2.5)
	assert_lt(player.global_position.y, 0.05)


func test_camera_stays_in_front_of_wall_behind_player() -> void:
	# Wall 2 m behind the player; the camera's default distance is 4 m, so it must pull in.
	_add_box(Vector3(10.0, 6.0, 0.5), Vector3(0.0, 3.0, 2.25))
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector3(0.0, 0.05, 0.0)
	_world.add_child(player)
	var camera: Camera3D = player.get_node("CameraRig/Pitch/Camera3D") as Camera3D
	await _simulate(0.5)
	assert_lt(camera.global_position.z, 2.0, "camera is in front of the wall face (z = 2)")
	assert_gt(camera.global_position.z, 0.3, "but still behind the player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
