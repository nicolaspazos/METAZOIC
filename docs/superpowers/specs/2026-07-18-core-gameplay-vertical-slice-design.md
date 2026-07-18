# METAZOIC Core Gameplay Vertical Slice Design

## Objective

Turn the current starting valley into a cohesive dark-fantasy action-RPG vertical slice: the caveman reaches the meteor, bonds with the parasite, fights readable raptor packs, defeats the clawed Duonychus boss, and absorbs its mutation. The pass prioritizes responsiveness, combat decision-making, traversal consistency, audiovisual hierarchy, and reliable automated verification.

## Scope and approach

Three approaches were evaluated:

1. **Content-first:** add several bosses and regions. This increases breadth but multiplies existing controller, combat, and presentation problems.
2. **Foundation-only:** rebuild movement and combat as isolated systems. This is technically clean but yields too little visible improvement to the playable slice.
3. **Balanced vertical slice (selected):** improve the shared gameplay foundation and apply it immediately to the existing first area and boss.

This iteration preserves the existing procedural models, terrain, audio generator, power framework, world layout, and uncommitted work. It does not introduce external binary assets or replace the established PS2 rendering style.

## Player movement and parkour

Movement remains camera-relative and momentum-based, but its rules move into a small testable utility. Ground acceleration, braking, air control, coyote time, and jump buffering have explicit values. Holding jump no longer repeatedly triggers jumps; a press is buffered briefly so a player who presses just before landing still jumps.

Mantling becomes a short state rather than an uncontrolled upward impulse. A chest-height obstruction probe, head-clearance probe, and top-surface probe must all succeed. During the mantle, normal input is suspended and the player travels through a deterministic arc to a safe landing point. Invalid surfaces, occupied landing spaces, combat attacks, and dashes cannot start a mantle.

The camera gains speed-sensitive field of view without competing tweens and uses smoothed trauma offsets, so movement reads faster while ordinary traversal remains stable.

## Combat

Light attacks support one buffered follow-up input during recovery. The combo alternates hands, preserves committed wind-up, and grants modest forward tracking toward a nearby hostile in the camera-facing cone. Heavy attacks remain slower and stronger. Attacks expose consistent phases—idle, wind-up, active, recovery—so input rules and future animation work have a stable contract.

A stamina resource governs dodge, heavy attacks, and mutation dashes. Stamina regenerates after a short delay and prevents repeated defensive or high-impact actions, while basic attacks and ordinary movement remain available. The HUD shows stamina only after infection and communicates insufficient stamina through a brief exhausted state rather than silently ignoring the input.

Damage feedback keeps hit-stop short, differentiates light/heavy impact trauma, and adds directional threat readability. Enemy attacks remain committed and interruptible, with explicit telegraph and recovery durations.

## First boss and progression

Duonychus remains the first boss because its established model and oversized claws already fulfill the intended Therizinosaurus-family fantasy. Player-facing copy identifies it as the claw-bearing therizinosaur of the valley. It keeps the Claws reward, while the power metadata is corrected so the broader progression remains: therizinosaur claws, Triceratops shield, raptor speed/legs, Tyrannosaurus jaws, Pachy charge, and Ankylo tail.

The boss gains a clearer enrage threshold and telegraphed claw sweep behavior by specializing the existing raptor state machine rather than duplicating it. Its boss bar appears on engagement, updates safely, and disappears on death.

## Presentation and audio

The world palette shifts from bright orange daylight toward near-black violet skies, cold desaturated ambient light, warm fire accents, and saturated parasite red. Fog becomes denser and darker, with enough local contrast to retain silhouettes. The post-process vignette and color quantization are tuned for atmosphere without hiding enemies.

The HUD adopts a restrained dark stone/blood palette. Health, stamina, boss health, power cooldowns, blood, and objective text have distinct hierarchy. Tutorial copy is short and contextual.

Audio playback receives category-aware variation and concurrency control so repeated footsteps and impacts do not machine-gun or steal music/ambience voices. Combat, creature, UI, ambience, and music volumes have clear defaults. Existing synthesized assets remain the source material.

## Architecture

- `scripts/player/movement_math.gd` contains deterministic, stateless movement calculations.
- `scripts/player/player.gd` owns input, movement states, stamina, combat phases, and calls presentation services.
- `scripts/enemies/raptor.gd` retains the base predator state machine; `duonychus.gd` adds boss-only phase behavior.
- `scripts/systems/sfx.gd` owns voice pools and category playback policy.
- `scripts/ui/hud.gd` renders state exposed by the player and boss.
- `tools/core_gameplay_test.gd` exercises deterministic rules and instantiated gameplay scenes headlessly.

## Failure handling

Missing optional audio continues to warn without stopping the game. Parkour probes fail closed: if any clearance result is ambiguous, normal movement continues. Target assistance ignores freed, dead, out-of-cone, or occluded targets. UI checks node validity before polling. Invalid power IDs and unaffordable stamina actions are no-ops with no cooldown consumed.

## Verification

The engine import must finish without parse/resource errors. Headless tests cover movement math, jump buffering, stamina spending/regeneration, attack queuing, damage/invulnerability, shield direction, power cooldowns, boss reward, and SFX pool safety. The main scene runs headlessly long enough to surface initialization and runtime errors. A rendered gameplay screenshot is inspected for silhouette readability, HUD hierarchy, and the intended dark-fantasy palette.

## Out of scope

This pass does not build the full open world, save system, all remaining bosses, cinematic camera tooling, externally authored skeletal animation, or production-quality voice acting. Those become safer follow-up milestones after the vertical slice is stable.
