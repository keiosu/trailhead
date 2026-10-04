class_name Player
extends CharacterBody3D
## A hiker: walking, sprinting, jumping, slopes and step-up.
## Camera lives in PlayerCamera, looks in PlayerVisual.
## Movement intent (move_input, move_yaw, sprint_held, request_jump) is read from local
## input when `read_local_input` is on; otherwise something else drives it (tests, later remote peers).

const LOG_TAG: String = "Player"
## Rises smaller than this are left to the capsule's rounded bottom.
const MIN_STEP_RISE: float = 0.02

@export_group("Speed")
@export var walk_speed: float = 1.6
@export var sprint_speed: float = 3.5
## m/s² while speeding up on the ground.
@export var ground_acceleration: float = 10.0
## m/s² while slowing down on the ground with no input.
@export var ground_deceleration: float = 14.0
## m/s² of steering in the air.
@export var air_acceleration: float = 2.5

@export_group("Jump")
@export var jump_height: float = 0.9
## Seconds after walking off a ledge during which a jump still counts.
@export var coyote_time: float = 0.12
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12
## Extra gravity while falling, so jumps feel less floaty.
@export var fall_gravity_multiplier: float = 1.6

@export_group("Terrain")
@export_range(0.0, 89.0) var max_slope_degrees: float = 42.0
## Tallest ledge (m) the hiker walks onto without jumping.
@export var step_height: float = 0.4
## How far past the capsule's front edge to look for a step top.
@export var step_probe_reach: float = 0.1
## How far down the hiker sticks to the ground when walking over crests and down slopes.
@export var floor_snap: float = 0.35

@export_group("Control")
@export var read_local_input: bool = true

## x = strafe (right +), y = forward/back (forward -). Length is clamped to 1.
var move_input: Vector2 = Vector2.ZERO
## World yaw (radians) that "forward" input points along; normally the camera's yaw.
var move_yaw: float = 0.0
var sprint_held: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var _visual: PlayerVisual = $Visual
@onready var _camera: PlayerCamera = $CameraRig
@onready var _capsule: CapsuleShape3D = ($CollisionShape3D as CollisionShape3D).shape as CapsuleShape3D


func _ready() -> void:
	collision_layer = PhysicsLayers.PLAYERS
	collision_mask = PhysicsLayers.WORLD
	floor_max_angle = deg_to_rad(max_slope_degrees)
	floor_snap_length = floor_snap
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	if not read_local_input:
		_camera.queue_free()
		_camera = null


## Queue a jump; it fires on the next physics tick we're grounded (or within coyote time).
func request_jump() -> void:
	_jump_buffer_timer = jump_buffer_time


func _physics_process(delta: float) -> void:
	if read_local_input:
		_read_local_input()

	var on_floor: bool = is_on_floor()
	_coyote_timer = coyote_time if on_floor else maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if not on_floor:
		var gravity_scale: float = fall_gravity_multiplier if velocity.y < 0.0 else 1.0
		velocity.y -= _gravity * gravity_scale * delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = MovementMath.jump_velocity(jump_height, _gravity)
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		on_floor = false

	var input: Vector2 = move_input.limit_length(1.0)
	var speed: float = sprint_speed if sprint_held else walk_speed
	var target: Vector3 = MovementMath.input_to_world(input, move_yaw) * speed
	var rate: float = air_acceleration
	if on_floor:
		rate = ground_acceleration if input != Vector2.ZERO else ground_deceleration
	velocity = MovementMath.approach_horizontal(velocity, target, rate, delta)

	if on_floor:
		_try_step_up(delta)
	move_and_slide()
	_visual.update_motion(velocity, is_on_floor(), sprint_speed)


func _read_local_input() -> void:
	move_input = Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_FORWARD, InputActions.MOVE_BACK)
	sprint_held = Input.is_action_pressed(InputActions.SPRINT)
	if Input.is_action_just_pressed(InputActions.JUMP):
		request_jump()
	if _camera != null:
		move_yaw = _camera.get_yaw()


## If we're walking into a low ledge (rock, log, stair) whose top is walkable,
## pop up onto it. Only the vertical rise is applied here; move_and_slide carries us forward
## and PlayerVisual eases the mesh up so it doesn't snap.
func _try_step_up(delta: float) -> void:
	var flat_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat_velocity.length_squared() < 0.01:
		return
	var collision: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(global_transform, flat_velocity * delta, collision):
		return
	if collision.get_normal().angle_to(up_direction) <= floor_max_angle:
		return # A walkable slope; move_and_slide handles it.

	var direction: Vector3 = flat_velocity.normalized()
	var probe: Vector3 = global_position + direction * (_capsule.radius + step_probe_reach)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		probe + up_direction * (step_height + 0.05), probe - up_direction * 0.05, collision_mask, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var rise: float = ((hit["position"] as Vector3) - global_position).dot(up_direction)
	if rise < MIN_STEP_RISE or rise > step_height:
		return
	if (hit["normal"] as Vector3).angle_to(up_direction) > floor_max_angle:
		return

	# The capsule must fit at the new height and be able to move forward from there.
	var lift: Vector3 = up_direction * rise
	if test_move(global_transform, lift):
		return
	if test_move(global_transform.translated(lift), direction * step_probe_reach):
		return
	global_position += lift
	velocity.y = maxf(velocity.y, 0.0)
	_visual.absorb_step(rise)
