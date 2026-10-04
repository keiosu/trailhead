class_name Log
extends RefCounted
## Tiny leveled logger. Use instead of bare print().
## Usage: Log.info("Net", "Hosting on port %d" % port)

enum Level { DEBUG, INFO, WARN, ERROR, NONE }

## Messages below this level are dropped.
static var level: Level = Level.DEBUG if OS.is_debug_build() else Level.INFO


static func debug(tag: String, message: String) -> void:
	if level <= Level.DEBUG:
		print(_format("DEBUG", tag, message))


static func info(tag: String, message: String) -> void:
	if level <= Level.INFO:
		print(_format("INFO", tag, message))


static func warn(tag: String, message: String) -> void:
	if level <= Level.WARN:
		push_warning(_format("", tag, message))


static func error(tag: String, message: String) -> void:
	if level <= Level.ERROR:
		push_error(_format("", tag, message))


## push_warning/push_error already label the level, so those pass an empty level_name.
static func _format(level_name: String, tag: String, message: String) -> String:
	if level_name.is_empty():
		return "[%s] %s" % [tag, message]
	return "[%s] [%s] %s" % [level_name, tag, message]
