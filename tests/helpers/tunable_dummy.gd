extends Node
## Test double for the debug console: a tunable node with assorted exported types.

const CONSOLE_HELP: Dictionary = {"ping": "ping — answers pong"}

@export var speed: float = 1.5
@export var count: int = 3
@export var enabled: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var tint: Color = Color.WHITE
@export var settings: WorldGenSettings = WorldGenSettings.new()

var not_exported: float = 9.0


func console_ping(args: PackedStringArray) -> String:
	return "pong %s" % " ".join(args)
