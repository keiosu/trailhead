extends GutTest
## Proves GUT runs and the project's core setup is wired.


func test_gut_runs() -> void:
	assert_true(true, "GUT is alive")


func test_autoloads_present() -> void:
	for autoload_name: String in ["Events", "Settings", "GameState", "Net"]:
		assert_not_null(get_tree().root.get_node_or_null(autoload_name), "%s autoload exists" % autoload_name)


func test_jolt_is_the_physics_engine() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_all_input_actions_are_mapped() -> void:
	for action: StringName in InputActions.ALL:
		assert_true(InputMap.has_action(action), "action '%s' exists" % action)
		assert_gt(InputMap.action_get_events(action).size(), 0, "action '%s' has a binding" % action)
