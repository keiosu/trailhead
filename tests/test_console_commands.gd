extends GutTest

const DUMMY_SCRIPT: GDScript = preload("res://tests/helpers/tunable_dummy.gd")

var _dummy: Node
var _console: ConsoleCommands


func before_each() -> void:
	_dummy = DUMMY_SCRIPT.new()
	_dummy.add_to_group(Groups.DEBUG_TUNABLE)
	_dummy.set_meta(Groups.DEBUG_NAME_META, "dummy")
	add_child_autofree(_dummy)
	_console = ConsoleCommands.new(get_tree())


func test_set_and_get_float() -> void:
	_console.execute("set dummy speed 2.75")
	assert_eq(_dummy.get("speed"), 2.75)
	assert_string_contains(_console.execute("get dummy speed"), "2.75")


func test_set_int_bool_vector_color() -> void:
	_console.execute("set dummy count 7")
	_console.execute("set dummy enabled on")
	_console.execute("set dummy offset 1, 2.5, -3")
	_console.execute("set dummy tint #ff8800")
	assert_eq(_dummy.get("count"), 7)
	assert_eq(_dummy.get("enabled"), true)
	assert_eq(_dummy.get("offset"), Vector3(1.0, 2.5, -3.0))
	assert_eq(_dummy.get("tint"), Color.html("#ff8800"))


func test_set_nested_resource_property() -> void:
	var result: String = _console.execute("set dummy settings.pine_density 0.5")
	assert_almost_eq((_dummy.get("settings") as WorldGenSettings).pine_density, 0.5, 0.0001)
	assert_string_contains(result, "regen")


func test_bad_values_are_rejected() -> void:
	var result: String = _console.execute("set dummy count lots")
	assert_eq(_dummy.get("count"), 3, "unchanged")
	assert_string_contains(result, "Can't read")


func test_only_exported_properties_are_reachable() -> void:
	assert_string_contains(_console.execute("set dummy not_exported 1"), "No property")
	assert_string_contains(_console.execute("set nobody speed 1"), "No property")


func test_list_shows_exports() -> void:
	var listing: String = _console.execute("list dummy")
	assert_string_contains(listing, "speed = 1.5")
	assert_string_contains(listing, "settings.pine_density")


func test_custom_commands_and_help() -> void:
	assert_eq(_console.execute("ping a b"), "pong a b")
	assert_string_contains(_console.execute("help"), "ping — answers pong")
	assert_string_contains(_console.execute("nonsense"), "Unknown command")


func test_tab_completion() -> void:
	assert_eq(_console.complete("pi")[0], "ping ")
	assert_eq(_console.complete("set dum")[0], "set dummy ")
	assert_eq(_console.complete("set dummy spe")[0], "set dummy speed ")


func test_parse_value_types() -> void:
	assert_eq(ConsoleCommands.parse_value("3.5", 1.0), [true, 3.5])
	assert_eq(ConsoleCommands.parse_value("x", 1.0), [false, null])
	assert_eq(ConsoleCommands.parse_value("Vector2(1, 2)", Vector2.ZERO), [true, Vector2(1, 2)])
	assert_eq(ConsoleCommands.parse_value("0.2 0.4 0.6", Color.WHITE), [true, Color(0.2, 0.4, 0.6, 1.0)])
