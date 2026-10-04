extends Node
## Host-owned shared world state (seed, time of day, weather, placed objects, ...).
## Stub for now; state is added milestone by milestone, and every field must
## also be added to the late-join sync path in Net.gd.

## Seed every peer generates the world from. Host-chosen.
## TODO(M2): send to joining peers in Net.gd's join sync.
var world_seed: int = 0
