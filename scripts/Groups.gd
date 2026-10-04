class_name Groups
extends RefCounted
## Scene-tree group names and shared metadata keys. Always use these constants.

## Nodes whose exported vars the debug console can list/get/set, and whose
## `console_<name>(args)` methods become console commands.
const DEBUG_TUNABLE: StringName = &"debug_tunable"
## Optional meta on a DEBUG_TUNABLE node: the short name the console uses for it.
const DEBUG_NAME_META: StringName = &"debug_name"
