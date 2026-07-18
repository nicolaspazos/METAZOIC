# METAZOIC — Game Design Document

> Living document. This is the source of truth for the game's concept and mechanics.
> Update it as decisions are made.

## Logline

A meteorite streaks into Earth's prehistoric sky and shatters in the atmosphere. It
carries a **parasitic, venom-like organism** that scatters across the land, bonding with
a lone **caveman** and a handful of **apex dinosaurs**. Each infected dinosaur becomes a
**boss** wielding a signature power. The caveman hunts them down, and by defeating a boss
he **absorbs its power** for himself.

## Genre & Presentation

- **Perspective:** Third-person, over-the-shoulder.
- **Structure:** Open world (single large explorable map for the prototype; can grow into
  regions later).
- **Art style:** Deliberately **PS2-era** — low-poly models, low-res textures, punchy
  vertex-lit lighting, moderate draw distance with fog. This is an aesthetic choice, not a
  limitation, and it keeps assets cheap to produce.
- **Engine:** Godot 4 (see [README](README.md) and [CLAUDE.md](CLAUDE.md)).

## Core Loop

1. **Explore** the open world.
2. **Find** a boss dinosaur (each guards a power).
3. **Fight** using the powers absorbed so far.
4. **Defeat** the boss → **absorb** its power permanently.
5. New power opens up new traversal/combat options → repeat.

## Powers ↔ Bosses

The mapping lives in code in [`scripts/systems/power_system.gd`](scripts/systems/power_system.gd)
(`PowerSystem.Power` enum + `POWER_INFO`). Keep this table in sync with that file.

| Boss dinosaur       | Power granted   | Feel / use                                  |
|---------------------|-----------------|---------------------------------------------|
| Triceratops         | Ceratops Shield | Raise a frontal shield / barrier            |
| Tyrannosaurus       | Tyrant Jaws     | Powerful bite — high-damage close attack    |
| Velociraptor        | Raptor Claws    | Fast slashing combo / lunge                 |
| Pachycephalosaurus  | Pachy Charge    | Headbutt charge — dash + knockback          |
| Ankylosaurus        | Ankylo Tail     | Heavy tail-club sweep — AoE                  |

New bosses = add an enum value + a `POWER_INFO` entry, then build a boss scene that
extends [`scripts/enemies/boss_dinosaur.gd`](scripts/enemies/boss_dinosaur.gd).

## Systems Roadmap

- [x] Third-person player controller (walk, jump, camera orbit)
- [x] Power-absorption framework (`PowerSystem` singleton + boss base class)
- [x] Player combat — club combo (overhead smash / side swipe), hitbox, hit-stop, camera shake
- [x] Health / damage for the player (knockback, i-frames, HUD bar, damage flash, respawn)
- [x] Enemy AI — raptor grunts (wander → chase → lunge-bite → recover) + respawning spawner
- [x] Gore system — blood sprays, death fountains, persistent pools, physics gibs (`Gore` autoload)
- [x] PS2 presentation pass — 40% render scale, color-quantize + Bayer-dither post shader, dusk fog
- [x] Starting area — meteor crash site (glowing shards), rocks, trees, walled arena
- [x] Headless combat smoke test (`tools/combat_smoke_test.tscn`)
- [ ] First boss: Triceratops (shield power)
- [ ] Ability activation & UI (show owned powers, bind to inputs)
- [ ] The meteorite intro / opening cinematic
- [ ] Bigger world (regions beyond the starting arena)
- [ ] Audio (ambient, combat SFX, music)

## Narrative Beats (draft)

1. **Impact.** The meteorite breaks apart entering the atmosphere; glowing shards fall.
2. **Infection.** The parasite bonds with the caveman (tutorial) and with distant dinosaurs.
3. **The Hunt.** Each region holds an infected apex predator/herbivore boss.
4. **Absorption.** Defeating a boss grants its power, escalating the caveman's abilities.
5. **Climax.** (TBD) A final infected host — or the parasite itself — as the last boss.
