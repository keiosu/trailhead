extends GutTest

const CONSOLE_SCENE: PackedScene = preload("res://scenes/ui/DebugConsole.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")

var _console: DebugConsole


func before_each() -> void:
	_console = CONSOLE_SCENE.instantiate() as DebugConsole
	add_child_autofree(_console)


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_opening_broadcasts_and_closing_restores() -> void:
	watch_signals(Events)
	_console.set_open(true)
	assert_true(_console.is_open())
	assert_signal_emitted_with_parameters(Events, "debug_console_toggled", [true])
	_console.set_open(false)
	assert_false(_console.is_open())
	assert_signal_emitted_with_parameters(Events, "debug_console_toggled", [false])


func test_player_ignores_movement_while_open() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	_console.set_open(true)
	Input.action_press(InputActions.MOVE_FORWARD)
	await wait_physics_frames(2)
	assert_eq(player.move_input, Vector2.ZERO, "blocked while the console is open")
	_console.set_open(false)
	await wait_physics_frames(2)
	assert_ne(player.move_input, Vector2.ZERO, "moves again once closed")
	Input.action_release(InputActions.MOVE_FORWARD)


func test_console_tunes_the_player() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	_console.run_command("set player walk_speed 2.2")
	assert_almost_eq(player.walk_speed, 2.2, 0.0001)
	_console.run_command("set player max_slope_degrees 30")
	assert_almost_eq(player.floor_max_angle, deg_to_rad(30.0), 0.0001, "setter applies immediately")
