# CLAUDE.md — working notes for AI agents

This file orients an AI (or human) contributor working on **METAZOIC**. Read it before
making changes. Keep it up to date when conventions change.

## What this is

A **Godot 4.4** game, GDScript only (no C#/.NET). PS2-style third-person open-world action.
Concept and roadmap live in [GAME_DESIGN.md](GAME_DESIGN.md).

## Golden rules

- **Godot files are text.** `.tscn` (scenes), `.tres` (resources), `.gd` (scripts), and
  `project.godot` are all editable directly. Prefer editing them as text over describing
  manual editor steps.
- **GDScript, not C#.** There is no .NET SDK on this machine. Do not add `.cs` files or the
  Mono build.
- **Match the existing style:** tabs for indentation (Godot standard), typed variables
  (`var x: float = 0.0`), `snake_case` for funcs/vars, `PascalCase` for nodes and classes,
  `##` doc comments on scripts and public members.
- **Don't commit generated data.** `.godot/` is the editor cache and is git-ignored; never
  add it. Same for `tools/godot/` (the local engine binary).

## How the pieces connect

- **Entry point:** `project.godot` → `run/main_scene` = `res://scenes/main.tscn`.
- **`scenes/main.tscn`** is the starting area: dusk `WorldEnvironment` (fog + glow), Sun,
  ground, meteor crash site (emissive shards + green light), rocks, trees, invisible arena
  walls, the player, a raptor `Spawner`, the `HUD` CanvasLayer, and the `PSXPost` layer.
- **`scenes/player/player.tscn`** is the caveman (`player.gd`). The body never rotates —
  `Mesh` (script `caveman_visual.gd`, class `CavemanVisual`) turns to face movement and is
  procedurally animated (walk cycle, club swings). `YawPivot → PitchPivot → Camera3D` is the
  mouse-orbit rig. `Mesh/AttackHitbox` (Area3D) is the club's damage volume.
- **Movement rules** that do not require scene state live in
  `scripts/player/movement_math.gd`. It owns camera-relative direction, horizontal
  acceleration, resource clamping, and mantle-arc interpolation so those rules are
  deterministic under headless tests.
- **`scenes/enemies/raptor.tscn`** (`raptor.gd`) is the grunt enemy: state machine
  WANDER → CHASE → LUNGE → RECOVER → DEAD, procedural leg/tail/head animation.
- **`Gore`** (autoload, `scripts/systems/gore.gd`) is all blood/impact FX, generated in
  code: `spray(pos, dir)`, `burst(pos)`, `pool(pos)`, `gibs(pos, n)`, `hitstop()`.
- **`PowerSystem`** (autoload, `scripts/systems/power_system.gd`) is the spine of the
  game's hook: `Power` enum, metadata, absorbed set. `absorb(p)` / `has_power(p)`.
- **`boss_dinosaur.gd`** is the base class for bosses. On death it calls
  `PowerSystem.absorb(self.power)`. Concrete bosses `extend` it.
- **PS2 look** = four layers working together:
  1. `rendering/scaling_3d/scale=0.4` (low-res render, upscaled)
  2. `assets/shaders/psx_lit.gdshader` on every surface — vertex snapping (polygon
     jitter), affine texture warping, nearest-filtered textures. Variants:
     `psx_foliage.gdshader` (alpha-scissor, double-sided), `psx_terrain.gdshader`
     (grass/dirt blend by vertex color).
  3. `assets/shaders/psx_post.gdshader` (color quantization + Bayer dither fullscreen).
  4. Procedural 128px textures from `tools/asset_gen/generate_textures.gd`.
- **Terrain** (`scripts/world/terrain.gd`, group "terrain") is generated at load:
  faceted heightfield, crater at (0,-18) with floor y=-1.5, arena flattening, mountain
  ring. Query ground height with `terrain.height_at(x, z)`. `world_dresser.gd` scatters
  trees/rocks/ferns (scenes in `scenes/world/`). Both deterministic (fixed seeds).
  IMPORTANT: terrain triangles wind clockwise seen from above (Godot front face).
- **Audio**: `Sfx` autoload (`scripts/systems/sfx.gd`) — `Sfx.play(name)` /
  `Sfx.play3d(name, pos)`. All WAVs synthesized by `tools/asset_gen/generate_audio.gd`;
  loops (music/wind/hum) get their loop flags set at runtime in Sfx._ready.
- **Powers**: implemented in player.gd (`activate_power`, `start_shield`/`stop_shield`,
  cooldowns in `POWER_COOLDOWNS`). The Alpha Raptor (`alpha_raptor.gd`, red tint,
  boss bar) grants CLAWS on death. HUD (`hud.gd`) builds the power bar, absorb banner,
  and boss bar in code; static bars live in main.tscn.
- **Hit flash / per-instance tinting**: psx_lit has `instance uniform` params `flash`
  and `tint_i` — set via `set_instance_shader_parameter` on each MeshInstance3D
  (see raptor.gd `_set_flash`, alpha_raptor.gd `_ready`).

## Intro flow & the parasite

- The player starts **uninfected** at the Camp (safe, unarmed, hair over face).
  `player.infected == false` → `_try_attack` no-ops, raptors' `_is_prey()` returns
  false (they ignore him), and the raptor `Spawner` stays dormant.
- The `InfectionTrigger` Area3D at the crash site calls `player.infect()`:
  reveals the face (`CavemanVisual.reveal_face()`), shows the black-red parasite
  fists, emits `parasite_bonded` (HUD clears the objective + shows the banner),
  and everything hostile activates.
- **The parasite is black and red** — parasite materials use crystal.png (black
  chitin + red veins). Keep all parasite FX (sparks, shards, fists, power FX,
  banners) in that palette, never green.
- Models are **rounded**: CapsuleMesh/SphereMesh limbs and bodies, CylinderMesh
  cones (top_radius 0) for teeth/claws/spikes, low radial_segments (6-12) for
  the PS2 facet look. Avoid plain BoxMesh for organic shapes.

## Gameplay conventions

- **Facing:** the front of every character model is **local +Z** on its `Mesh` node.
- **Collision layers:** 1 = world, 2 = player, 4 = enemies. Player mask 5; raptor mask 7;
  player attack hitbox mask 4; gibs/corpses mask 1.
- **Groups:** the player is in `"player"`, enemies add themselves to `"enemies"`.
- **Damage flow:** attacker calls `take_damage(amount, dir_or_pos)`. Victims spawn their
  own blood via `Gore`. Enemies announce death with
  `get_tree().call_group("player", "on_enemy_killed")` (heals the player — the parasite feeds).
- **Animation is procedural** (code + tweens), not baked `AnimationPlayer` data — keep it
  that way unless there's a strong reason; it's far easier to edit as text.

## Common tasks — where to start

- **Add a new power:** add a value to the `Power` enum and a `POWER_INFO` entry in
  `scripts/systems/power_system.gd`, then update the table in `GAME_DESIGN.md`.
- **Add a boss:** make `scenes/enemies/<name>.tscn` with a `CharacterBody3D` root, attach a
  script that `extends "res://scripts/enemies/boss_dinosaur.gd"`, set its `power`, and place
  an instance in `main.tscn` (or a region scene).
- **Add player combat:** create an attack in `player.gd` that detects a boss (e.g. via an
  `Area3D` hitbox) and calls `boss.take_damage(amount)`.
- **Tune movement/camera:** exported vars at the top of `player.gd`
  (`move_speed`, `jump_velocity`, `mouse_sensitivity`, ...).

## Editing `.tscn` files safely

- Keep the `[gd_scene load_steps=N ...]` count roughly correct — Godot tolerates a wrong
  `load_steps` but keep it sane. `format=3` is Godot 4.
- `ext_resource` references files by `path`; `sub_resource` defines inline resources by `id`.
- `Transform3D(xx,xy,xz, yx,yy,yz, zx,zy,zz, ox,oy,oz)` = 3 basis-axis vectors then origin.
- When in doubt, it's fine to build/adjust a scene inside the Godot editor and commit the
  resulting text.

## Verifying changes

Godot can import and check the project headlessly (once the editor is installed — see
`tools/install-godot.ps1`):

```powershell
# Import assets and quit — surfaces script/scene parse errors.
& <path-to-godot.exe> --headless --path . --editor --quit

# Run the game headless briefly — surfaces runtime errors.
& <path-to-godot.exe> --headless --quit-after 120 --path .

# Combat smoke test — asserts damage/death/kill-reward/PowerSystem behavior. Exit 0 = pass.
& <path-to-godot.exe> --headless --path . res://tools/combat_smoke_test.tscn

# Core gameplay test — movement math, stamina, attack buffering, audio, and boss phase.
& <path-to-godot.exe> --headless --path . --quit-after 600 res://tools/core_gameplay_test.tscn
```

Run all four after any gameplay change. Extend `tools/core_gameplay_test.gd` for
controller/resource rules and `tools/combat_smoke_test.gd` for full combat-loop behavior.

## Conventions recap

- Indent with **tabs**. Type your variables. Document with `##`.
- One responsibility per script; keep the `PowerSystem` the single source of truth for powers.
- Update `GAME_DESIGN.md` when you change mechanics, and this file when you change conventions.
