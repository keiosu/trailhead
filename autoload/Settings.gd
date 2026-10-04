extends Node
## Local, per-player preferences. Never replicated.

const DEFAULT_PLAYER_NAME: String = "Hiker"
const MAX_PLAYER_NAME_LENGTH: int = 16

var player_name: String = DEFAULT_PLAYER_NAME:
	set(value):
		player_name = sanitize_player_name(value)
## Mouse look sensitivity in radians per pixel.
var mouse_sensitivity: float = 0.0025
var invert_mouse_y: bool = false


static func sanitize_player_name(raw: String) -> String:
	var cleaned: String = raw.strip_edges().left(MAX_PLAYER_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else DEFAULT_PLAYER_NAME
