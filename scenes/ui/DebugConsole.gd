class_name DebugConsole
extends CanvasLayer
## In-game developer console. Toggle with ` (backtick) or F1.
## Type `help`. History: Up/Down. Completion: Tab. Commands live in ConsoleCommands.

const LOG_TAG: String = "Console"
const CONSOLE_HELP: Dictionary = {
	"stats": "stats — toggle the FPS / draw-call overlay",
}
const MAX_HISTORY: int = 50

var _commands: ConsoleCommands
var _history: PackedStringArray = PackedStringArray()
var _history_index: int = -1
var _panel: PanelContainer
var _output: RichTextLabel
var _line_edit: LineEdit
var _stats: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_commands = ConsoleCommands.new(get_tree())
	add_to_group(Groups.DEBUG_TUNABLE)
	set_meta(Groups.DEBUG_NAME_META, "console")
	_build_ui()
	_panel.visible = false
	_print("Trailhead debug console. Type [b]help[/b].")


func is_open() -> bool:
	return _panel.visible


func set_open(open: bool) -> void:
	if open == is_open():
		return
	_panel.visible = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_line_edit.grab_focus()
	else:
		_line_edit.release_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.debug_console_toggled.emit(open)


## Runs a command as if typed, echoing it to the log. Used by tools/capture.gd too.
func run_command(line: String) -> String:
	_print("[color=#9ad]> %s[/color]" % line.replace("[", "[lb]"))
	if line.strip_edges() == "clear":
		_output.clear()
		return ""
	var result: String = _commands.execute(line)
	if not result.is_empty():
		_print(result.replace("[", "[lb]"))
	return result


func console_stats(_args: PackedStringArray) -> String:
	_stats.visible = not _stats.visible
	return "Stats overlay %s" % ("on" if _stats.visible else "off")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.DEBUG_CONSOLE):
		set_open(not is_open())
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed(InputActions.PAUSE):
		set_open(false)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _stats.visible:
		return
	var where: String = ""
	var player: Player = null
	for node: Node in get_tree().get_nodes_in_group(Groups.DEBUG_TUNABLE):
		if node is Player:
			player = node as Player
	if player != null:
		var p: Vector3 = player.global_position
		where = "\npos %.0f, %.1f, %.0f" % [p.x, p.y, p.z]
	_stats.text = "%d fps  %.1f ms\n%d draws  %dk prims\nseed %d%s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
		GameState.world_seed, where]


func _on_submitted(text: String) -> void:
	_line_edit.clear()
	if text.strip_edges().is_empty():
		return
	if _history.is_empty() or _history[_history.size() - 1] != text:
		_history.append(text)
		if _history.size() > MAX_HISTORY:
			_history.remove_at(0)
	_history_index = -1
	run_command(text)


func _on_input_gui(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	match key.keycode:
		KEY_UP:
			_step_history(-1)
		KEY_DOWN:
			_step_history(1)
		KEY_TAB:
			var completion: Array = _commands.complete(_line_edit.text)
			_line_edit.text = completion[0]
			_line_edit.caret_column = _line_edit.text.length()
			var options: PackedStringArray = completion[1]
			if options.size() > 1:
				_print("  ".join(options))
		_:
			return
	_line_edit.accept_event()


func _step_history(direction: int) -> void:
	if _history.is_empty():
		return
	if _history_index == -1:
		_history_index = _history.size()
	_history_index = clampi(_history_index + direction, 0, _history.size())
	_line_edit.text = _history[_history_index] if _history_index < _history.size() else ""
	_line_edit.caret_column = _line_edit.text.length()


func _print(bbcode: String) -> void:
	_output.append_text(bbcode + "\n")


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 0.45
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.88)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	_panel.add_child(column)
	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_color_override("default_color", Color(0.92, 0.9, 0.84))
	column.add_child(_output)

	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "help · targets · list world settings · set player walk_speed 2 · regen random · tp summit"
	_line_edit.keep_editing_on_text_submit = true
	_line_edit.text_submitted.connect(_on_submitted)
	_line_edit.gui_input.connect(_on_input_gui)
	column.add_child(_line_edit)

	_stats = Label.new()
	_stats.anchor_left = 1.0
	_stats.anchor_right = 1.0
	_stats.offset_left = -260
	_stats.offset_right = -12
	_stats.offset_top = 10
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.12))
	_stats.add_theme_constant_override("outline_size", 6)
	_stats.visible = false
	add_child(_stats)
