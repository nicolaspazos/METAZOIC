extends Node3D
## Keeps the starting area stocked with raptors so combat can be tested endlessly.
##
## Add Marker3D children as spawn points. Spawns `initial_spawns` immediately,
## then tops the pack back up to `max_alive` every `spawn_interval` seconds.
## Corpses (State.DEAD) don't count toward the alive total.

@export var raptor_scene: PackedScene
@export var max_alive := 4
@export var initial_spawns := 3
@export var spawn_interval := 10.0

var _spawned: Array = []
var _markers: Array = []
var _timer := 0.0


func _ready() -> void:
	for child in get_children():
		if child is Marker3D:
			_markers.append(child)
	for i in mini(initial_spawns, _markers.size()):
		_spawn_at(_markers[i])
	_timer = spawn_interval


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = spawn_interval
	_spawned = _spawned.filter(
		func(r): return is_instance_valid(r) and r.is_alive())
	if _spawned.size() < max_alive and not _markers.is_empty():
		_spawn_at(_markers.pick_random())


func _spawn_at(marker: Node3D) -> void:
	if raptor_scene == null:
		return
	var raptor := raptor_scene.instantiate()
	add_child(raptor)
	# Snap to the procedural terrain so raptors never spawn underground.
	var pos := marker.global_position
	var terrain := get_tree().get_first_node_in_group("terrain")
	var y := pos.y + 0.5
	if terrain:
		y = terrain.height_at(pos.x, pos.z) + 0.8
	raptor.global_position = Vector3(pos.x, y, pos.z)
	# Slight size variance so the pack doesn't look cloned.
	var visual := raptor.get_node_or_null("Mesh")
	if visual:
		visual.scale = Vector3.ONE * randf_range(0.88, 1.15)
	_spawned.append(raptor)
