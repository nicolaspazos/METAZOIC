extends Node3D
## Scatters vegetation and rocks across the terrain (deterministic — fixed seed).
## Everything snaps to terrain height, avoids the crater, and leaves breathing
## room at the arena center. Must sit BELOW the Terrain node in the scene tree.

@export var tree_scene: PackedScene
@export var big_tree_scene: PackedScene
@export var rock_scene: PackedScene
@export var fern_scene: PackedScene
@export var bones_scene: PackedScene
@export var dead_tree_scene: PackedScene
@export var dead_tree_count := 12

@export var tree_count := 42
@export var big_tree_count := 9
@export var rock_count := 26
@export var fern_count := 72
@export var bones_count := 10

const CRATER := Vector2(0.0, -18.0)
const POND := Vector2(26.0, 26.0)
const CAMP := Vector2(-26.0, 24.0)


func _ready() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain == null:
		push_warning("WorldDresser: no terrain found — nothing scattered")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_scatter(tree_scene, tree_count, 16.0, 86.0, 0.85, 1.35, rng, terrain)
	_scatter(big_tree_scene, big_tree_count, 22.0, 78.0, 0.9, 1.4, rng, terrain)
	_scatter(rock_scene, rock_count, 12.0, 88.0, 0.6, 2.2, rng, terrain)
	_scatter(fern_scene, fern_count, 8.0, 80.0, 0.8, 1.5, rng, terrain)
	_scatter(bones_scene, bones_count, 10.0, 70.0, 0.8, 1.6, rng, terrain)
	_scatter(dead_tree_scene, dead_tree_count, 14.0, 84.0, 0.8, 1.5, rng, terrain)


func _scatter(scene: PackedScene, count: int, r_min: float, r_max: float,
		s_min: float, s_max: float, rng: RandomNumberGenerator, terrain: Node) -> void:
	if scene == null:
		return
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 4:
		attempts += 1
		var angle := rng.randf() * TAU
		# sqrt distributes evenly by area instead of clumping at the center.
		var radius := sqrt(lerpf(r_min * r_min, r_max * r_max, rng.randf()))
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if Vector2(x, z).distance_to(CRATER) < 12.0:
			continue  # keep the crash site clear
		if Vector2(x, z).distance_to(POND) < 10.0:
			continue  # nothing growing in the waterhole
		if Vector2(x, z).distance_to(CAMP) < 9.0:
			continue  # keep the caveman's camp clear
		var inst: Node3D = scene.instantiate()
		add_child(inst)
		inst.global_position = Vector3(x, terrain.height_at(x, z) - 0.05, z)
		inst.rotation.y = rng.randf() * TAU
		inst.scale = Vector3.ONE * rng.randf_range(s_min, s_max)
		placed += 1
