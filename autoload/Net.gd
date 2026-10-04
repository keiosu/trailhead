extends Node
## Networking singleton (listen server, host = peer 1).
## M0: reads launch args only. ENet host/join, lobby and join-sync arrive in M2.

const LOG_TAG: String = "Net"
const DEFAULT_PORT: int = 24565
const MAX_PLAYERS: int = 4
const HOST_PEER_ID: int = 1

var launch_args: LaunchArgs = LaunchArgs.new()


func _ready() -> void:
	launch_args = LaunchArgs.parse(OS.get_cmdline_user_args())
	if not launch_args.player_name.is_empty():
		Settings.player_name = launch_args.player_name
	if launch_args.has_conflict():
		Log.warn(LOG_TAG, "Both --host and --join given; --host wins.")
	for arg: String in launch_args.unknown:
		Log.warn(LOG_TAG, "Unknown launch arg: %s" % arg)
	Log.info(LOG_TAG, "Launch args: %s" % launch_args)
