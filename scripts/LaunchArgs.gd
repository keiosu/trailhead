class_name LaunchArgs
extends RefCounted
## Parses user command-line args (everything after `--`).
## Example: godot --path . -- --host --name=Caleb
##          godot --path . -- --join=127.0.0.1 --name=Sam

const ARG_HOST: String = "--host"
const ARG_JOIN_PREFIX: String = "--join="
const ARG_NAME_PREFIX: String = "--name="

var host: bool = false
var join_address: String = ""
var player_name: String = ""
## Args we didn't recognise, kept so callers can warn about typos.
var unknown: PackedStringArray = PackedStringArray()


static func parse(args: PackedStringArray) -> LaunchArgs:
	var result: LaunchArgs = LaunchArgs.new()
	for arg: String in args:
		if arg == ARG_HOST:
			result.host = true
		elif arg.begins_with(ARG_JOIN_PREFIX):
			result.join_address = arg.substr(ARG_JOIN_PREFIX.length()).strip_edges()
		elif arg.begins_with(ARG_NAME_PREFIX):
			result.player_name = arg.substr(ARG_NAME_PREFIX.length()).strip_edges()
		else:
			result.unknown.append(arg)
	return result


func wants_join() -> bool:
	return not join_address.is_empty()


## Hosting and joining at once makes no sense; host wins.
func has_conflict() -> bool:
	return host and wants_join()


func _to_string() -> String:
	return "host=%s join=%s name=%s" % [host, join_address if wants_join() else "-", player_name if not player_name.is_empty() else "-"]
