# Organic Models and Materials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace visible primitive silhouettes with reusable higher-detail organic meshes and realistic materials while improving camera and gameplay readability.

**Architecture:** `MeshForge` owns deterministic geometry generation, focused presentation scripts apply meshes to existing scene pivots, and gameplay state remains in existing controllers. New versioned raster textures feed the existing material system without removing procedural fallback generation.

**Tech Stack:** Godot 4.7.1, typed GDScript, ArrayMesh, ShaderMaterial, PNG albedo textures, headless Godot tests.

## Global Constraints

- Preserve the current Godot-native text-first workflow and procedural animation pivots.
- Keep the dark-fantasy palette while making forms readable at gameplay distance.
- Add versioned texture files instead of silently replacing procedural source assets.
- Geometry generation must be deterministic, finite, UV-mapped, and collision-independent.
- Every code behavior begins with a failing headless assertion.

---

### Task 1: MeshForge geometry foundation

**Files:** Modify `scripts/world/mesh_forge.gd`; modify `tools/core_gameplay_test.gd`.

**Interfaces:** Produce `sweep(points, radii, radial, closed) -> ArrayMesh`, `wedge(points) -> ArrayMesh`, `irregular_rock(seed, radius, rings, radial) -> ArrayMesh`, and `mesh_stats(mesh) -> Dictionary`.

- [ ] Add assertions for vertex/index/UV counts, finite normals, deterministic vertices, and minimum 300-triangle hero forms.
- [ ] Run the core test and confirm failures for missing forge APIs.
- [ ] Implement tangent-oriented sweep rings, cap triangles, wedge faces, seeded rock displacement, and stats extraction.
- [ ] Re-run the core test and confirm all geometry assertions pass.

### Task 2: Higher-detail character and dinosaur silhouettes

**Files:** Modify `scripts/player/caveman_visual.gd`, `scripts/enemies/raptor.gd`, and `scripts/enemies/duonychus.gd`; test in `tools/core_gameplay_test.gd`.

**Interfaces:** Each visual exposes `visual_vertex_count() -> int`; existing node paths and combat hitboxes remain unchanged.

- [ ] Add failing minimum-budget assertions: caveman 4,000 vertices, raptor 5,000 vertices, Duonychus 6,000 vertices.
- [ ] Replace head, torso, hands, feet, cloth, tail, skull, and claw silhouettes with forged curved anatomy while keeping pivots.
- [ ] Add secondary procedural motion for toes, shoulders, cloth, feather mantle, and claws.
- [ ] Re-run core and combat tests; confirm vertex budgets and gameplay contracts pass.

### Task 3: Realistic seamless texture set

**Files:** Create `assets/textures/skin_realistic.png`, `scales_realistic.png`, `bark_realistic.png`, and `stone_ground_realistic.png`; modify scene material references.

**Interfaces:** 512×512 tileable albedo textures with neutral lighting and no text/watermark.

- [ ] Generate each texture with the built-in image-generation workflow using one focused seamless-material prompt per asset.
- [ ] Inspect each output for seams, baked lighting, unwanted objects, and value-range readability.
- [ ] Copy selected outputs into `assets/textures/` and update character, dinosaur, tree, rock, and terrain material references.
- [ ] Run Godot import and confirm every texture loads.

### Task 4: World prop forge

**Files:** Create `scripts/world/prop_visuals.gd`; modify `tree.tscn`, `big_tree.tscn`, `rock.tscn`, `bones.tscn`, `camp.tscn`, and `main.tscn`; test in `tools/core_gameplay_test.gd`.

**Interfaces:** `PropVisuals` replaces primitive meshes on ready using deterministic exported seeds and preserves collision nodes.

- [ ] Add failing assertions that tree, rock, bone, meteor, and camp hero props exceed their minimum triangle budgets and expose no visible BoxMesh/SphereMesh hero surfaces at runtime.
- [ ] Implement irregular trunks/branches, clustered foliage cards, fractured rocks, curved bones, jagged meteor shards, and rough-hewn camp forms.
- [ ] Re-run core tests and inspect runtime scenes for stable placement and collision.

### Task 5: Camera, spawn, and presentation structure

**Files:** Modify `scenes/player/player.tscn`, `scripts/player/player.gd`, `scenes/main.tscn`, and `assets/shaders/psx_lit.gdshader`; test in `tools/core_gameplay_test.gd`.

**Interfaces:** Expose `camera_profile() -> Dictionary` with distance, pitch limits, and combat pullback; retain existing movement/combat public methods.

- [ ] Add failing assertions for a ground-safe camp spawn, 3.4–4.2m camera distance, downward pitch no steeper than -0.65, and perspective-correct character UV mode.
- [ ] Lower the camera pivot, constrain pitch, add smoothed combat pullback, and relocate the start clear of camp collision.
- [ ] Add shader controls for affine strength, macro breakup, and material response; disable full affine warp on hero anatomy.
- [ ] Run movement/combat tests and real-render the initial and infected views.

### Task 6: Verification and documentation

**Files:** Modify `README.md`, `CLAUDE.md`, and `GAME_DESIGN.md`.

**Interfaces:** Document forge APIs, texture ownership, camera behavior, visual budgets, and verification commands.

- [ ] Run Godot editor import, core gameplay tests, combat smoke tests, and a 300-frame main runtime.
- [ ] Run `git diff --check` and scan logs for project parse/runtime errors.
- [ ] Capture Vulkan frames and inspect anatomy, world silhouettes, material tiling, exposure, and HUD readability.
- [ ] Update documentation only for features proven by tests and captures.
