extends Node
## Global signal bus for cross-system events.
## Declare signals here as systems need them (e.g. `signal item_picked_up(...)`) and
## annotate each with @warning_ignore("unused_signal"), since they're emitted from elsewhere.

## The debug console opened or closed. Gameplay input should pause while it's open.
@warning_ignore("unused_signal")
signal debug_console_toggled(is_open: bool)
