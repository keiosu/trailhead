# PLAN.md — Build plan, 0 → 100

Work top to bottom. Each milestone ends with a **playable build** and a commit.
Check boxes as you go. Don't start a milestone until the previous one meets its acceptance criteria.

---

## M0 — Setup (Caleb does the first part by hand)

**Caleb, before handing off to Claude Code:**
- [ ] Install Godot 4.4+ (standard build, not .NET) and make sure `godot` is on your PATH.
- [ ] Install Blender 4.x and the Blender MCP add-on (enable it in Preferences → Add-ons).
- [x] Create an empty folder, `git init`, and drop in `CLAUDE.md` and `PLAN.md`.
- [ ] Add the MCP servers from that folder:
  ```
  claude mcp add godot -e GODOT_PATH=$(which godot) -- npx @coding-solo/godot-mcp
  claude mcp add godot-docs -s project -- npx -y @nuskey8/godot-docs-mcp@latest
  claude mcp add blender uvx blender-mcp
  ```
- [ ] Start `claude` in that folder and run `/mcp` to confirm all three connect.

**Claude Code:**
- [x] Create the Godot project (`project.godot`): Forward+ renderer, Jolt physics, the folder structure from CLAUDE.md.
- [x] `.gitignore` for Godot 4 (ignore `.godot/`, `*.tmp`, export builds).
- [x] Autoload stubs: `Net`, `GameState`, `Events`, `Settings`, plus a `Log` helper.
- [x] Input map: move (WASD), sprint (Shift), jump (Space), interact (E), inventory (Tab), place (Q), chat (Enter), pause (Esc).
- [x] Install GUT and add one passing smoke test.
- [x] Command-line args: `--host`, `--join=<ip>`, `--name=<name>`.

**Done when:** headless load prints no errors, GUT runs green, first commit is made.

> M0 notes: GUT pinned to **v9.4.0** (last release supporting Godot 4.4; 9.5+ needs 4.5). Jolt is the built-in 4.4 module, verified active at runtime. `Log` and `LaunchArgs` are static `class_name` scripts in `scripts/`, not autoloads. Launch-arg parsing is done; actually hosting/joining is M2.

---

## M1 — One hiker, walking feels good

- [ ] `Player.tscn`: `CharacterBody3D`, capsule collider, placeholder low-poly hiker mesh.
- [ ] Third-person camera rig: `SpringArm3D` with mouse look, collision, smoothing.
- [ ] Movement: walk ~1.6 m/s, sprint ~3.5 m/s, acceleration and deceleration, slope handling up to ~40°, jump, step-up over small rocks.
- [ ] Gray-box test level: hills, a ramp, rocks, a log to step over.
- [ ] Tunables exposed with `@export`.
- [ ] **Toon look v1:** `toon.gdshader` (2-band cel shading, colored shadows, rim light) plus inverted-hull outline pass, applied to the player and gray-box level. Directional sun with hard toon shadows. Establish the look now so every later milestone builds on it.

**Done when:** walking up and down hills feels smooth with no jitter or sliding, and the camera never clips into terrain.

---

## M2 — Networking foundation

- [ ] Main menu: **Host**, **Join (IP field)**, name field, Quit.
- [ ] `Net.gd`: create host/client with `ENetMultiplayerPeer` (default port 24565, max 4 players). Handle connected, disconnected, failed, and server-closed cleanly with UI feedback.
- [ ] Lobby screen: player list with names, host has a **Start** button.
- [ ] `MultiplayerSpawner` spawns a `Player` per peer. Each peer has authority over its own player.
- [ ] `MultiplayerSynchronizer` replicates position, rotation, and animation state, with interpolation on remote players.
- [ ] Floating name tags over remote players.
- [ ] Late join: a player joining mid-session spawns correctly and sees everyone else.
- [ ] Leaving: a disconnected player's node is removed for everyone; if the host leaves, clients return to the menu with a message.

**Done when:** you can run two (then three) local instances (`--host` and `--join=127.0.0.1`), walk around, and see each other move smoothly. Join late, quit mid-session, and nothing errors.

---

## M3 — The world: terrain, trail, forest

- [ ] Host picks a world seed and sends it on join. Every peer generates the same world locally.
- [ ] Terrain: `FastNoiseLite` heightmap → mesh with collision. Start with ~512 × 512 m, valley at the start, peak at the far end.
- [ ] Terrain material: blend grass / dirt / rock by slope and height (shader).
- [ ] Trail: a `Path3D` from trailhead to summit, flattened into the terrain and textured as dirt. Optional trail markers or cairns.
- [ ] Scatter with `MultiMeshInstance3D`: trees, rocks, bushes, grass. Density masks keep the trail clear. Distance culling and visibility ranges.
- [ ] 3–4 named landmarks: trailhead parking area, creek crossing, lake/meadow campsite area, summit viewpoint.
- [ ] Spawn point at the trailhead.

**Done when:** all players see an identical world from the same seed, the trail is walkable start to summit, and the game holds 60 fps on your machine.

---

## M4 — Sky, time, and weather

- [ ] `WorldEnvironment` with a procedural sky, sun (`DirectionalLight3D`), and fog.
- [ ] Host-driven day/night cycle (default: 1 in-game day = 24 real minutes, tunable). Synced time; late joiners get the current time.
- [ ] Lighting moods: golden hour, blue hour, starry night with moon.
- [ ] Weather states: clear, overcast, light rain, fog. Host-chosen and synced. Rain particles that follow the local camera, wet-ground shader tweak.
- [ ] Ambient audio layers: birds by day, crickets at night, wind, rain.

**Done when:** a full day/night cycle looks good at every hour, and weather changes appear on all clients at the same time.

---

## M5 — Interaction & inventory

- [ ] `ItemData` resource (id, name, icon, weight, stack size, tags).
- [ ] Interactable component: highlight on look, prompt ("E — Pick up firewood").
- [ ] Pickups: firewood, kindling, berries, water bottle, marshmallows. Host spawns them, clients request pickup, host validates and updates inventory.
- [ ] Backpack inventory with weight limit. UI grid with drag/drop, drop item, and give item to a nearby friend.
- [ ] Inventories are host-owned state and included in late-join sync.
- [ ] GUT tests for inventory logic (add, remove, stack, weight limits).

**Done when:** two players can't pick up the same item, inventory stays consistent across clients, and giving items works.

---

## M6 — Making camp

- [ ] `PlaceableData` resource. Placeables: tent (1–2 person), campfire ring, log seat, lantern, camp chair.
- [ ] Placement mode: ghost preview that snaps to terrain, rotates with the scroll wheel, and turns red when the spot is invalid (too steep, overlapping, in water, on the trail).
- [ ] Host validates placement and spawns the object via `MultiplayerSpawner`. Pick-up/pack-away to return items.
- [ ] Campfire states: unlit → lit (needs kindling + firewood) → burning (consumes wood over time) → embers → out. Fire light flicker, particles, crackle audio, smoke.
- [ ] Sit on log seats or chairs (simple sit animation and camera).
- [ ] Tent: enter to sleep. When **all** players are in tents, skip to morning.

**Done when:** a group can pitch camp together, build and feed a fire, sit around it, and sleep through the night, with everything persisting correctly for late joiners.

---

## M7 — Gentle needs

- [ ] Warmth: drops at night, in rain, and at altitude; rises near a lit fire or in a tent.
- [ ] Energy: drains while sprinting and climbing; restores while sitting and sleeping.
- [ ] Hunger: slow drain; berries and campfire food restore it.
- [ ] Effects are soft only: cold → shivering animation and slower sprint; tired → no sprint. No death.
- [ ] Small HUD (icons, no big bars) that fades when all needs are fine.
- [ ] Needs are simulated on the host and synced to each owner.

**Done when:** the needs nudge players toward the campfire and rest without ever feeling like a chore.

---

## M8 — Social & fun

- [ ] Text chat with a fading chat log, plus proximity labels above heads.
- [ ] Emote wheel: wave, point, sit, cheer, dance.
- [ ] Campfire cooking: roast marshmallows/hot dogs (hold over the fire; raw → golden → burnt timing mini-game).
- [ ] Throwable pinecones or snowballs (harmless, just physics plus a funny sound).
- [ ] Photo mode: free camera, hide HUD, filters, saves to `user://photos/`.
- [ ] Ping marker: look at a spot and press a key to show a marker to friends ("over here!").

**Done when:** a playtest group laughs at least once without being prompted.

---

## M9 — Goals & persistence

- [ ] Trail journal: discover landmarks, collect stamps at viewpoints, spot wildlife (deer, birds, a fox, ambient AI only).
- [ ] Summit moment: reaching the peak triggers a shared panoramic camera moment and a journal entry.
- [ ] Save/load: host saves world seed, time, weather, placed objects, fire states, inventories, and journal to `user://saves/<name>.json`. Load from the host menu.
- [ ] Versioned save format so later updates don't break old saves.

**Done when:** a group can play, quit, come back the next day, and find their camp exactly as they left it.

---

## M10 — Art & audio pass

- [ ] Create `palette.png` (shared color swatches) and a Blender template file that maps to it.
- [ ] Toon shader v2: ramp textures per material type, outline width/color tuning by distance, hit-flash and highlight for interactables.
- [ ] Use the Blender MCP to build a consistent prop set: tents (2 colors), backpack, campfire ring, logs, stumps, lantern, chair, cooler, trail signs, cairns.
- [ ] Trees: 3–4 species (pine, fir, birch, dead snag) with simple LODs and a wind-sway vertex shader.
- [ ] Characters: rigged low-poly hikers (CC0 pack or Blender), 4 color variants, hats/backpacks as cosmetics.
- [ ] Animations: idle, walk, run, jump, sit, sleep, emotes, roast.
- [ ] Water: creek and lake shader with simple foam and reflection.
- [ ] Music: sparse acoustic tracks for menu, summit, and night by the fire.
- [ ] Fill in `CREDITS.md`.

**Done when:** a screenshot from any spot on the trail looks intentional and cohesive.

---

## M11 — Play over the internet

- [ ] **Stage 1 (easiest):** play over a virtual LAN such as Tailscale or ZeroTier, with friends joining by IP. Document the steps in `docs/PLAYING_WITH_FRIENDS.md`.
- [ ] **Stage 2:** UPnP port mapping attempt on host (Godot's `UPNP` class) with a clear fallback message.
- [ ] **Stage 3 (if shipping on Steam):** GodotSteam with Steam lobbies and invites. Ask Caleb before starting this; it requires a Steam app ID.
- [ ] Test with real latency: run a remote session and tune interpolation and buffer settings.

**Done when:** a friend on a different network can join and play a full session.

---

## M12 — Polish, performance, release

- [ ] Settings menu: graphics presets, resolution, FOV, mouse sensitivity, volume sliders, keybinds.
- [ ] Performance: profile, then fix the worst items (MultiMesh visibility ranges, shadow distance, LODs). Target 60 fps on mid-range hardware.
- [ ] Onboarding: a short first-hike tutorial through prompts, not walls of text.
- [ ] Bug bash: test checklist covering host leaves, client leaves, late join at night, full inventory, placing at map edges, and save/load mid-fire.
- [ ] Export presets for Windows, macOS, and Linux. Build script `tools/build.sh` that exports all three.
- [ ] `README.md` with how to play, controls, and credits.

**Done when:** you can hand a zip to three friends and have a full evening of play without help.

---

## Backlog (don't start without asking)
- Proximity voice chat
- Multiple trails/maps, seasonal variants (snow, autumn)
- Fishing, canoeing, stargazing constellation mini-game
- Wildlife photography challenges
- Dedicated server mode
