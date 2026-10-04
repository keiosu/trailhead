class_name ConsoleCommands
extends RefCounted
## Debug console logic, separate from its UI so it can be tested.
##
## Targets are nodes in Groups.DEBUG_TUNABLE, named by their Groups.DEBUG_NAME_META
## meta (or snake_case node name). Their exported vars can be listed/read/written,
## including one level into exported Resources (`settings.tree_density`).
## Any `console_<cmd>(args: PackedStringArray) -> String` method on a target becomes a
## command; a `CONSOLE_HELP` constant dictionary on its script supplies help lines.

const COMMAND_PREFIX: String = "console_"
const BUILTIN_HELP: Dictionary = {
	"help": "help — this list",
	"targets": "targets — nodes you can tune",
	"list": "list <target> [filter] — exported values on a target",
	"get": "get <target> <property> — read a value",
	"set": "set <target> <property> <value> — change a value (e.g. set player walk_speed 2.2)",
	"clear": "clear — clear the console",
}

var _tree: SceneTree


func _init(tree: SceneTree) -> void:
	_tree = tree


func execute(line: String) -> String:
	var tokens: PackedStringArray = line.strip_edges().split(" ", false)
	if tokens.is_empty():
		return ""
	var command: String = tokens[0].to_lower()
	var args: PackedStringArray = tokens.slice(1)
	match command:
		"help":
			return _help()
		"targets":
			return "Targets: " + ", ".join(_targets().keys())
		"list":
			return _list(args)
		"get":
			return _get_value(args)
		"set":
			return _set_value(args)
	var owner: Node = _command_owner(command)
	if owner != null:
		return str(owner.call(COMMAND_PREFIX + command, args))
	return "Unknown command '%s'. Type help." % command


## Completes the last word of `line`, or returns it unchanged. Second value: the options.
func complete(line: String) -> Array:
	var tokens: PackedStringArray = line.split(" ", true)
	var current: String = tokens[tokens.size() - 1]
	var options: PackedStringArray = PackedStringArray()
	if tokens.size() == 1:
		options = PackedStringArray(BUILTIN_HELP.keys() + _custom_commands().keys())
	elif tokens.size() == 2 and tokens[0] in ["list", "get", "set"]:
		options = PackedStringArray(_targets().keys())
	elif tokens.size() == 3 and tokens[0] in ["get", "set"]:
		var target: Node = _targets().get(tokens[1])
		if target != null:
			options = PackedStringArray(_properties(target).keys())
	var matches: PackedStringArray = PackedStringArray()
	for option: String in options:
		if option.begins_with(current):
			matches.append(option)
	matches.sort()
	if matches.size() == 1:
		tokens[tokens.size() - 1] = matches[0]
		return [" ".join(tokens) + " ", matches]
	if matches.size() > 1:
		tokens[tokens.size() - 1] = _common_prefix(matches)
	return [" ".join(tokens), matches]


## Parses `text` into the same type as `current`. Returns [ok, value].
static func parse_value(text: String, current: Variant) -> Array:
	var t: String = text.strip_edges()
	match typeof(current):
		TYPE_BOOL:
			if t.to_lower() in ["true", "1", "on", "yes"]:
				return [true, true]
			if t.to_lower() in ["false", "0", "off", "no"]:
				return [true, false]
			return [false, null]
		TYPE_INT:
			return [true, t.to_int()] if t.is_valid_int() else [false, null]
		TYPE_FLOAT:
			return [true, t.to_float()] if t.is_valid_float() else [false, null]
		TYPE_STRING:
			return [true, t]
		TYPE_STRING_NAME:
			return [true, StringName(t)]
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR:
			return _parse_numbers(t, current)
	var parsed: Variant = str_to_var(t)
	if parsed == null or (current != null and typeof(parsed) != typeof(current)):
		return [false, null]
	return [true, parsed]


func _help() -> String:
	var lines: PackedStringArray = PackedStringArray(BUILTIN_HELP.values())
	var custom: Dictionary = _custom_commands()
	for command: String in custom:
		var owner: Node = custom[command]
		var help_map: Dictionary = owner.get_script().get_script_constant_map().get("CONSOLE_HELP", {})
		lines.append(help_map.get(command, command))
	return "\n".join(lines)


func _list(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Usage: " + BUILTIN_HELP["list"]
	var target: Node = _targets().get(args[0])
	if target == null:
		return "No target '%s'. Targets: %s" % [args[0], ", ".join(_targets().keys())]
	var filter: String = args[1] if args.size() > 1 else ""
	var lines: PackedStringArray = PackedStringArray()
	var properties: Dictionary = _properties(target)
	for path: String in properties:
		if filter.is_empty() or path.contains(filter):
			lines.append("  %s = %s" % [path, _format(target.get_indexed(properties[path]))])
	return "%s:\n%s" % [args[0], "\n".join(lines)]


func _get_value(args: PackedStringArray) -> String:
	if args.size() < 2:
		return "Usage: " + BUILTIN_HELP["get"]
	var found: Array = _resolve(args[0], args[1])
	if found.is_empty():
		return "No property '%s' on '%s'" % [args[1], args[0]]
	return "%s %s = %s" % [args[0], args[1], _format((found[0] as Node).get_indexed(found[1]))]


func _set_value(args: PackedStringArray) -> String:
	if args.size() < 3:
		return "Usage: " + BUILTIN_HELP["set"]
	var found: Array = _resolve(args[0], args[1])
	if found.is_empty():
		return "No property '%s' on '%s'" % [args[1], args[0]]
	var target: Node = found[0]
	var path: NodePath = found[1]
	var text: String = " ".join(args.slice(2))
	var parsed: Array = parse_value(text, target.get_indexed(path))
	if not parsed[0]:
		return "Can't read '%s' as %s" % [text, type_string(typeof(target.get_indexed(path)))]
	target.set_indexed(path, parsed[1])
	var note: String = "  (regen to apply)" if args[1].begins_with("settings.") else ""
	return "%s %s = %s%s" % [args[0], args[1], _format(target.get_indexed(path)), note]


## [node, NodePath] for "target", "a.b", or [] if missing.
func _resolve(target_name: String, property: String) -> Array:
	var target: Node = _targets().get(target_name)
	if target == null:
		return []
	var properties: Dictionary = _properties(target)
	if not properties.has(property):
		return []
	return [target, properties[property]]


func _targets() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _tree.get_nodes_in_group(Groups.DEBUG_TUNABLE):
		result[str(node.get_meta(Groups.DEBUG_NAME_META, node.name.to_snake_case()))] = node
	return result


## Exported script vars, keyed "name" or "resource.name", valued with get_indexed paths.
func _properties(target: Object) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in _exported(target):
		var name: String = property["name"]
		var value: Variant = target.get(name)
		if value is Resource and (value as Resource).get_script() != null:
			for inner: Dictionary in _exported(value):
				result["%s.%s" % [name, inner["name"]]] = NodePath(":%s:%s" % [name, inner["name"]])
		else:
			result[name] = NodePath(":" + name)
	return result


static func _exported(object: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var wanted: int = PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_EDITOR
	for property: Dictionary in object.get_property_list():
		if (property["usage"] & wanted) == wanted:
			result.append(property)
	return result


func _custom_commands() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in _tree.get_nodes_in_group(Groups.DEBUG_TUNABLE):
		for method: Dictionary in node.get_method_list():
			var name: String = method["name"]
			if name.begins_with(COMMAND_PREFIX):
				result[name.substr(COMMAND_PREFIX.length())] = node
	return result


func _command_owner(command: String) -> Node:
	return _custom_commands().get(command)


static func _parse_numbers(text: String, current: Variant) -> Array:
	if current is Color and not text.contains(","):
		if Color.html_is_valid(text):
			return [true, Color.html(text)]
	var cleaned: String = text
	for wrapper: String in ["Vector2", "Vector3", "Color", "(", ")"]:
		cleaned = cleaned.replace(wrapper, " ")
	var parts: PackedStringArray = cleaned.replace(",", " ").split(" ", false)
	var numbers: PackedFloat32Array = PackedFloat32Array()
	for part: String in parts:
		if not part.is_valid_float():
			return [false, null]
		numbers.append(part.to_float())
	match typeof(current):
		TYPE_VECTOR2:
			return [true, Vector2(numbers[0], numbers[1])] if numbers.size() == 2 else [false, null]
		TYPE_VECTOR3:
			return [true, Vector3(numbers[0], numbers[1], numbers[2])] if numbers.size() == 3 else [false, null]
		TYPE_COLOR:
			if numbers.size() == 3 or numbers.size() == 4:
				return [true, Color(numbers[0], numbers[1], numbers[2], numbers[3] if numbers.size() == 4 else 1.0)]
	return [false, null]


static func _format(value: Variant) -> String:
	if value is float:
		return String.num(value, 4)
	if value is Resource:
		return (value as Resource).resource_path.get_file() if not (value as Resource).resource_path.is_empty() else type_string(typeof(value))
	return str(value)


static func _common_prefix(words: PackedStringArray) -> String:
	var prefix: String = words[0]
	for word: String in words:
		while not word.begins_with(prefix):
			prefix = prefix.left(prefix.length() - 1)
	return prefix
