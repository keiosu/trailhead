class_name InputActions
extends RefCounted
## Input action names. Always use these constants, never raw strings.
## The bindings themselves live in Project Settings → Input Map.

const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const SPRINT: StringName = &"sprint"
const JUMP: StringName = &"jump"
const INTERACT: StringName = &"interact"
const INVENTORY: StringName = &"inventory"
const PLACE: StringName = &"place"
const CHAT: StringName = &"chat"
const PAUSE: StringName = &"pause"

const ALL: Array[StringName] = [
	MOVE_FORWARD, MOVE_BACK, MOVE_LEFT, MOVE_RIGHT,
	SPRINT, JUMP, INTERACT, INVENTORY, PLACE, CHAT, PAUSE,
]
