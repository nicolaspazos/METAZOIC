# Organic Models and Materials Design

## Goal

Replace METAZOIC's visible primitive silhouettes with cohesive, higher-polygon low-poly forms and more realistic organic materials while retaining deterministic Godot-native assets, dark-fantasy readability, and responsive gameplay.

## Selected approach

The project will extend `MeshForge` instead of importing a disconnected Blender/glTF asset pipeline. Raising sphere/capsule segment counts alone is rejected because it preserves toy-like silhouettes. External models are deferred because they would make the current text-first workflow and procedural animation harder to maintain.

The forge becomes a small modeling library with curved sweeps, closed lofts, wedges, irregular rocks, and branched forms. Runtime model scripts use those primitives to form continuous anatomy and props while existing scene nodes remain animation pivots and material anchors.

## Character and creature forms

The caveman gains a defined rib cage, pelvis, neck, brow, jaw, palms, fingers, heel/toe feet, layered hair, fur cloth, and parasite claws. The silhouette must read anatomically at gameplay distance without becoming photorealistic or losing the prehistoric exaggeration.

Raptors gain continuous skull/snout shapes, cheek and brow planes, digitigrade feet with toes, thicker tail bases, scapular shoulders, and visible claws. Duonychus receives its own heavy torso, feather-like mantle plates, beaked skull, broad feet, and long curved scythe claws instead of inheriting a swollen raptor outline.

## World forms

Tree trunks use irregular tapered rings and branching limbs; foliage becomes clustered leaf cards rather than large spheres. Rocks use deterministic irregular polyhedra with fractured planes. Bone piles use tapered curved ribs, skull wedges, and long-bone lofts. Meteor shards use jagged faceted crystal meshes. Camp logs and hide panels gain irregular profiles and thickness.

## Materials and textures

New 512px seamless albedo textures provide realistic-but-stylized skin, dinosaur scale/feather hide, bark, and stone/soil detail. They remain color-graded for the moonlit scene and avoid photographic lighting baked into the maps. The spatial shader keeps PSX vertex motion optional but uses perspective-correct UVs for characters, adjustable roughness/specular response, macro color breakup, and distance-safe contrast.

Generated textures are added under versioned filenames and referenced explicitly; the procedural generator remains available for fallback assets.

## Camera and gameplay readability

The player starts beside the camp instead of on its roof. The camera sits lower and closer in an over-shoulder composition with a limited downward pitch, responsive collision, and a modest combat-distance pullback. Character scale, collision, attack range, mantle probes, and camera framing are checked together so higher-detail geometry does not change combat rules accidentally.

Player movement code remains in `player.gd`, deterministic calculations remain in `movement_math.gd`, and mesh construction remains presentation-only. New geometry never becomes the source of combat state.

## Testing

Headless tests validate forge surface counts, finite normals, UV counts, closed indices, deterministic irregular meshes, minimum character/dinosaur vertex budgets, camera spawn/framing, and unchanged combat contracts. Godot import and runtime tests must exit zero. Real-render captures are inspected at the initial camp and infected boss encounter for anatomy, prop silhouettes, texture scale, exposure, and HUD readability.

## Scope limits

This milestone improves the current player, raptor, Duonychus, and starting-area props. It does not add skeletal animation software, new regions, additional bosses, ray-traced rendering, or external commercial asset packs.
