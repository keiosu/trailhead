# CLAUDE.md — Trailhead (working title)

This file is the standing context for Claude Code on this project. Read it at the start of every session.
The phased build plan lives in `PLAN.md`. Work through it in order, one milestone at a time.

## What we're building

A cozy, stylized **3D co-op hiking & camping game for 2–4 friends**. Players hike a trail together,
gather supplies, pick a spot, pitch tents, build a campfire, and hang out as day turns to night.
Gentle survival (warmth, energy, hunger) adds texture but never kills you.

**Design pillars** (use these to break ties on any decision):
1. **Together > alone.** Every system should be more fun with friends nearby.
2. **Cozy, not punishing.** No permadeath, no griefing, failure is a nudge, not a loss.
3. **The walk is the game.** Movement, views, light, and weather must feel good before anything else.
4. **Small and finished > big and broken.** Cut scope before cutting quality.

## Tech stack (do not change without asking)

- **Engine:** Godot 4.4+ (stable), **Forward+** renderer, **Jolt** physics.
- **Language:** GDScript with **static typing everywhere** (`var speed: float = 5.0`, typed function signatures and return types).
- **Networking:** Godot high-level multiplayer: `ENetMultiplayerPeer`, `MultiplayerSpawner`, `MultiplayerSynchronizer`, `@rpc`.
  - Model: **listen server**. One player hosts; the host is the authority for world state.
- **Tests:** GUT (Godot Unit Test) addon in `addons/gut/`.
- **Art:** Toon / cel-shaded, low-poly, bright and saturated (Wind Waker–inspired look, all-original designs). Assets as `.glb` (glTF binary). See Art rules.
- **Version control:** git. Commit after every working step.

## MCP tools available

- `godot`: launch the editor, run the project, read debug output. **After any code change, run the project and read the debug output before saying a task is done.**
- `godot-docs`: search official Godot docs. **Check here before using any API you're not 100% sure exists in Godot 4.4.** Never use Godot 3 APIs (e.g. `KinematicBody`, `yield`, `export var`, `onready var`).
- `blender`: create and export 3D props (see Art rules).

## Project structure

```
res://
  addons/            # third-party plugins (gut, mcp bridge) — don't edit
  autoload/          # singletons: Net.gd, GameState.gd, Events.gd, Settings.gd
  scenes/
    main/            # Main.tscn (entry), boot + scene switching
    ui/              # menus, HUD, lobby, inventory
    player/          # Player.tscn, camera rig, animation
    world/           # terrain, trail, scatter, sky, weather
    camp/            # tent, campfire, placeable objects
    items/           # pickups, interactables
  scripts/           # shared non-scene scripts and helpers
  resources/
    items/           # ItemData .tres files
    placeables/      # PlaceableData .tres files
  assets/
    models/          # .glb, one folder per object
    textures/
    audio/
    fonts/
  tests/             # GUT tests, mirror the scripts/ layout
```

## Code conventions

- One responsibility per script. If a script passes ~300 lines, propose a split.
- Communicate **up via signals, down via method calls**. Cross-system events go through the `Events` autoload (a signal bus).
- Data lives in custom `Resource` classes (`ItemData`, `PlaceableData`), not hard-coded dictionaries.
- Use `@export` for anything a designer might tune. Group tunables with `@export_group`.
- Constants in `SCREAMING_SNAKE_CASE`, classes in `PascalCase` with `class_name`, everything else `snake_case`.
- No magic strings for input actions or groups. Define them as constants in one place.
- Units: **1 unit = 1 meter**, Y-up. Player is ~1.8 m tall.

## Networking rules (most important section)

Multiplayer bugs are the most expensive bugs in this project. Follow these strictly.

1. **The host owns the world.** Item spawns, inventory contents, placed objects, fire state, time of day, weather, and the world seed are decided by the host (peer id 1).
2. **Clients request, the host decides.** A client never changes shared state directly. It calls an RPC like `request_pickup(item_id)`; the host validates (distance, existence, inventory space) and then broadcasts the result.
3. **Movement is the one exception.** Each player has authority over their own `Player` node (`set_multiplayer_authority(peer_id)`) so movement feels instant. Position, rotation, and animation state replicate via `MultiplayerSynchronizer`.
4. **Annotate every RPC explicitly**, e.g. `@rpc("any_peer", "call_remote", "reliable")`. In every `any_peer` RPC that runs on the host, check `multiplayer.get_remote_sender_id()` and validate the request.
5. **Spawn networked nodes only through `MultiplayerSpawner`**, never `add_child` on a client for shared objects.
6. **Determinism from seeds.** Procedural content (terrain, scatter) is generated locally on every peer from a seed the host sends. Never replicate thousands of trees.
7. **Late joiners must get full state.** Whenever you add shared state, also add it to the join-sync path in `Net.gd` and test with a player who joins late.
8. Unreliable channel for high-frequency data (movement), reliable for events (pickup, placement, chat).

## How to work

For every milestone in `PLAN.md`:

1. **Plan first.** Briefly list the files you'll create or change and how you'll test it. Ask me only if a decision is genuinely ambiguous or hard to undo.
2. **Build in small steps.** Get something running, then extend it.
3. **Verify.**
   - Parse/load check: `godot --headless --path . --quit` must print no errors.
   - Run GUT tests for any logic you added (`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`).
   - For anything networked, run **two instances**: one host, one client. Use launch args after `--` (read with `OS.get_cmdline_user_args()`): `--host` auto-hosts, `--join=127.0.0.1` auto-joins. Read both instances' output.
   - Use the `godot` MCP to run the project and read debug output.
4. **Commit** with a clear message (`feat(camp): campfire placement with host validation`).
5. **Report** what works, what you tested, and anything you cut or left as a TODO. Update the milestone checklist in `PLAN.md`.

Never say something works unless you ran it. If you couldn't test something (e.g. it needs a second machine), say so.

## Art rules

**Target look:** toon / cel-shaded, inspired by the *style* of Zelda: Wind Waker. Bright, clean, chunky shapes, readable silhouettes. All characters, props, and designs are our own. Never recreate Nintendo characters, items, or assets.

**Toon rendering (the look lives in shaders, not in the models):**
- One shared `toon.gdshader` (spatial) in `res://assets/shaders/` used by almost everything. Its `light()` function:
  - Quantizes diffuse into **2 bands** (lit / shadow) with a soft-but-short edge (`smoothstep` over ~0.02), or samples a 1D **ramp texture** (`@export`-able) so bands can be art-directed.
  - Uses **colored shadows** (shadow tint uniform, cool blue/purple), never black.
  - Applies `ATTENUATION` to the band so cast shadows are hard-edged and toon-banded too.
  - Adds a small hard-edged **specular highlight** (optional per material) and a subtle **rim light**.
- **Outlines:** inverted-hull outline as a `next_pass` material (`cull_front`, vertex pushed out along normal, unshaded dark color, width in world units, scaled down with distance). Use on characters, props, and placeables. **No outlines on MultiMesh foliage or grass** (too costly, too noisy).
- **Terrain:** same banding plus slope/height color blending, with flat color regions instead of photographic textures.
- **Sky & weather:** gradient sky shader, stylized puffy clouds (flat-shaded cards or meshes), stylized wind-swirl trail particles.
- **Effects:** fire as shaped, flat-colored flame meshes or particles with a bright core (not realistic smoke); smoke as round cartoon puffs; water as flat color with animated foam lines at edges.
- **Environment settings:** keep tonemapping simple (Linear or mild Filmic), light glow on fire and sun only, no SSAO/SSR. Fog uses sky-matched colors.
- Any imported model (CC0 packs included) should look on-style once `toon.gdshader` is applied. If one doesn't, fix the material, not the mesh.

- **Palette:** sky blue, grass green, warm wood brown, cream, sunset orange, with deep teal/purple shadow tints. Saturated but harmonious; keep a palette swatch in `assets/textures/palette.png`.
- **Blender (via MCP):**
  - **Colors come from a shared palette texture:** UV-map faces onto swatches in `palette.png` (one small texture for the whole game) rather than unique textures per model. This keeps everything consistent and cheap.
  - Chunky, simple, exaggerated shapes: big heads and hands on characters, rounded silhouettes, minimal small detail. Detail comes from shape and color, not texture.
  - Smooth normals on organic shapes (so banding looks clean), hard edges on wood, rocks, and tents.
  - Model at real-world scale in meters, apply all transforms, origin at the object's base.
  - Low poly: props under ~2k tris, trees under ~1.5k tris with a simple LOD.
  - Export glTF binary (`.glb`) to `res://assets/models/<name>/<name>.glb`.
  - Save the `.blend` source to `art_src/` (outside the Godot project, or ignored by Godot with a `.gdignore` file).
- **Third-party assets:** CC0 only (e.g. Kenney, Quaternius, Poly Haven, Poly Pizza CC0 items). Log every external asset in `CREDITS.md` with source and license.
- Prefer shaders and procedural generation (terrain, grass sway, sky, fire) over hand-made assets wherever it looks good.

## Don'ts

- Don't commit `.godot/` (import cache). Do commit `*.uid` and `*.import` files.
- Don't add plugins, change the engine version, or switch the networking model without asking.
- Don't hand-edit large `.tscn` files when the editor or MCP can do it. If you must, preserve `uid=` values.
- Don't leave placeholder `print()` spam. Use a small `Log` helper with levels.
- Don't build features from later milestones early.
