# Core Gameplay Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a substantially more responsive, readable, and atmospheric version of METAZOIC's infection-to-first-boss gameplay loop.

**Architecture:** Deterministic movement rules live in a stateless helper, while the player scene owns state transitions and presentation hooks. Existing enemy, SFX, HUD, and environment systems are extended in place to preserve the current procedural-content workflow.

**Tech Stack:** Godot 4.7.1 Standard, typed GDScript, text `.tscn` scenes, headless Godot tests.

## Global Constraints

- Preserve all existing uncommitted work and do not replace procedural assets with external binaries.
- Use typed GDScript, tabs, `snake_case`, and the existing collision-layer conventions.
- Keep the parasite black-red and organic models low-poly and rounded.
- Every behavior change starts with a failing headless test and ends with engine import plus runtime verification.

---

### Task 1: Restore a parse-clean baseline and build a gameplay test harness

**Files:**
- Modify: `scripts/player/player.gd`
- Create: `tools/core_gameplay_test.gd`
- Create: `tools/core_gameplay_test.tscn`

**Interfaces:**
- Consumes: player scene, raptor scene, `PowerSystem`, `Stats`.
- Produces: a headless test scene that exits with the number of failed assertions.

- [ ] Add a regression assertion that instantiates the player and verifies initial health and infection state.
- [ ] Run `Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tools/core_gameplay_test.tscn`; expect failure while the new scene/script is absent or the player script does not parse.
- [ ] Give `new_max` an explicit `float` type and add the minimal test harness.
- [ ] Re-run the focused test; expect exit code 0.

### Task 2: Deterministic movement, jump buffering, and stamina

**Files:**
- Create: `scripts/player/movement_math.gd`
- Modify: `scripts/player/player.gd`
- Modify: `scripts/ui/hud.gd`
- Test: `tools/core_gameplay_test.gd`

**Interfaces:**
- Produces: `MovementMath.camera_relative(input, basis) -> Vector3`, `MovementMath.horizontal_velocity(current, target, acceleration, delta) -> Vector3`, and `MovementMath.regenerate_resource(current, maximum, rate, delta) -> float`.
- Player exposes `stamina`, `max_stamina`, `stamina_changed`, `can_spend_stamina(amount)`, and `spend_stamina(amount)`.

- [ ] Add failing assertions for normalized diagonal camera-relative direction, horizontal acceleration preserving vertical velocity, clamped regeneration, stamina rejection, and stamina spending.
- [ ] Run the focused test; expect missing `MovementMath` and stamina APIs.
- [ ] Implement the helper and player resource contract, then wire press-based jump buffering and regeneration into `_physics_process`.
- [ ] Add a dark stamina bar under health that updates from `stamina_changed` and stays hidden before infection.
- [ ] Re-run the focused test; expect all movement/resource assertions to pass.

### Task 3: Controlled mantle and camera motion

**Files:**
- Modify: `scripts/player/player.gd`
- Modify: `scenes/player/player.tscn`
- Test: `tools/core_gameplay_test.gd`

**Interfaces:**
- Produces: `is_mantling() -> bool`, `try_begin_mantle(direction) -> bool`, and a single camera FOV target updated each frame.

- [ ] Add failing state assertions that attacks and dashes cannot begin while mantling and that a completed mantle returns to normal movement.
- [ ] Run the focused test; expect missing mantle-state API.
- [ ] Replace the wall impulse with three clearance probes, a bounded mantle target, and a tween-free physics interpolation state.
- [ ] Replace competing FOV tweens with a smoothed target derived from horizontal speed and dash state.
- [ ] Re-run the focused test and main scene; expect assertions to pass with no invalid physics queries.

### Task 4: Attack phases, buffered combo, and stamina costs

**Files:**
- Modify: `scripts/player/player.gd`
- Modify: `scripts/player/caveman_visual.gd`
- Test: `tools/core_gameplay_test.gd`

**Interfaces:**
- Produces: `queue_attack(heavy := false) -> bool`, `attack_phase_name() -> String`, and cost constants for dodge, heavy, claws, and charge.

- [ ] Add failing assertions that a second light input buffers exactly once, heavy attacks fail without stamina, successful heavy attacks spend stamina, and dodge cannot spend twice.
- [ ] Run the focused test; expect missing queue/phase APIs.
- [ ] Implement explicit attack phases and one-slot buffering while preserving current strike timing and damage.
- [ ] Apply stamina costs only after an action is accepted; rejected actions consume neither stamina nor cooldown.
- [ ] Add subtle anticipation/recovery posing to the procedural visual.
- [ ] Re-run focused and combat smoke tests; expect all combat assertions to pass.

### Task 5: First-boss identity and progression metadata

**Files:**
- Modify: `scripts/systems/power_system.gd`
- Modify: `scripts/enemies/duonychus.gd`
- Modify: `scenes/enemies/duonychus.tscn`
- Modify: `GAME_DESIGN.md`
- Test: `tools/core_gameplay_test.gd`

**Interfaces:**
- Produces: `Power.SPEED`, metadata for Therizinosaur Claws and Raptor Legs, and Duonychus phase behavior below 50% health.

- [ ] Add failing assertions for the six-power metadata map and the boss granting claws exactly once.
- [ ] Run the focused test; expect missing speed power and incorrect claw source metadata.
- [ ] Add the speed progression entry without binding an unfinished ability, and correct the first boss/player-facing naming.
- [ ] Add a telegraphed enrage phase by tuning boss-only speed, recovery, tint pulse, and sweep cadence.
- [ ] Re-run the test and a headless boss encounter initialization; expect metadata and scene checks to pass.

### Task 6: Audio hierarchy, HUD readability, and dark-fantasy environment

**Files:**
- Modify: `scripts/systems/sfx.gd`
- Modify: `scripts/ui/hud.gd`
- Modify: `scenes/main.tscn`
- Modify: `assets/shaders/psx_post.gdshader`
- Test: `tools/core_gameplay_test.gd`

**Interfaces:**
- SFX accepts an optional category and enforces per-category pool/volume policy.
- HUD polls valid player/boss nodes and renders health, stamina, blood, powers, and objective hierarchy.

- [ ] Add failing assertions that all required streams load and repeated category playback stays within its voice budget.
- [ ] Run the focused test; expect category APIs to be absent.
- [ ] Add category configuration and safe voice reuse while retaining existing call compatibility.
- [ ] Retune the environment to violet-black sky, cold low ambient light, dense red-gray fog, and stronger local parasite/fire accents.
- [ ] Retune vignette/quantization and HUD colors for silhouette and state readability.
- [ ] Re-run tests, main-scene headless runtime, and capture a screenshot for visual inspection.

### Task 7: Full verification and documentation sync

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `GAME_DESIGN.md`

**Interfaces:**
- Produces: accurate controls, architecture notes, power mapping, and verification commands.

- [ ] Run editor import; expect exit code 0 and no script/resource errors.
- [ ] Run `core_gameplay_test.tscn` and `combat_smoke_test.tscn`; expect exit code 0 from both.
- [ ] Run the main scene headlessly for 180 frames; expect no runtime errors.
- [ ] Search output for `ERROR`, `SCRIPT ERROR`, `Parse Error`, and `Invalid`; expect no matches caused by the project.
- [ ] Review `git diff --check` and the complete diff, preserving unrelated pre-existing changes.
- [ ] Update documentation to match only mechanics verified in this iteration.
