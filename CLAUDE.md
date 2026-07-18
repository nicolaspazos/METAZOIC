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
- **`scenes/main.tscn`** is the world: `WorldEnvironment` + `DirectionalLight3D` (Sun) +
  a `Ground` static body + some rocks + an instance of the player scene.
- **`scenes/player/player.tscn`** is the caveman. Hierarchy:
  - `Player` (`CharacterBody3D`, script `player.gd`)
    - `CollisionShape3D` (capsule)
    - `Mesh` (`Node3D`) — visual body; rotated to face movement (kept separate from collision)
    - `YawPivot` (`Node3D`) → `PitchPivot` (`Node3D`) → `Camera3D` — the orbit camera rig
- **`PowerSystem`** (autoload singleton, `scripts/systems/power_system.gd`) is the spine of
  the game's hook: it holds the `Power` enum, per-power metadata, and the set of absorbed
  powers. Call `PowerSystem.absorb(power)` / `PowerSystem.has_power(power)` from anywhere.
- **`boss_dinosaur.gd`** is the base class for bosses. On death it calls
  `PowerSystem.absorb(self.power)`. Concrete bosses `extend` it.

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
```

There is no automated test suite yet. Prefer small, self-contained changes and describe how
to see them working in-editor (press F5).

## Conventions recap

- Indent with **tabs**. Type your variables. Document with `##`.
- One responsibility per script; keep the `PowerSystem` the single source of truth for powers.
- Update `GAME_DESIGN.md` when you change mechanics, and this file when you change conventions.
