extends GutTest


func test_empty_args() -> void:
	var args: LaunchArgs = LaunchArgs.parse(PackedStringArray())
	assert_false(args.host)
	assert_false(args.wants_join())
	assert_eq(args.player_name, "")
	assert_eq(args.unknown.size(), 0)


func test_host_with_name() -> void:
	var args: LaunchArgs = LaunchArgs.parse(PackedStringArray(["--host", "--name=Caleb"]))
	assert_true(args.host)
	assert_false(args.wants_join())
	assert_eq(args.player_name, "Caleb")


func test_join_address() -> void:
	var args: LaunchArgs = LaunchArgs.parse(PackedStringArray(["--join=127.0.0.1"]))
	assert_false(args.host)
	assert_true(args.wants_join())
	assert_eq(args.join_address, "127.0.0.1")


func test_empty_join_is_not_a_join() -> void:
	var args: LaunchArgs = LaunchArgs.parse(PackedStringArray(["--join="]))
	assert_false(args.wants_join())


func test_host_and_join_conflict() -> void:
	var args: LaunchArgs = LaunchArgs.parse(PackedStringArray(["--host", "--join=10.0.0.2"]))
	assert_true(args.has_conflict())


func test_unknown_args_are_collected() -> void:
	var args: LaunchArgs = LaunchArgs.parse(PackedStringArray(["--hots", "--join"]))
	assert_eq(args.unknown, PackedStringArray(["--hots", "--join"]))


func test_settings_sanitizes_names() -> void:
	assert_eq(Settings.sanitize_player_name("  Sam  "), "Sam")
	assert_eq(Settings.sanitize_player_name("   "), Settings.DEFAULT_PLAYER_NAME)
	assert_eq(Settings.sanitize_player_name("ABCDEFGHIJKLMNOPQRSTUVWXYZ").length(), Settings.MAX_PLAYER_NAME_LENGTH)
