extends Node
## Random wildlife ambience: bird calls, raptor chitters, and the occasional
## distant roar, played at random positions around the player every few seconds.
## Makes the world feel inhabited beyond the arena.

const CALLS := ["bird1", "bird1", "bird2", "chitter", "distant_roar"]

var _timer := 4.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(6.0, 14.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var call_name: String = CALLS.pick_random()
	var ang := randf() * TAU
	var dist := randf_range(18.0, 35.0)
	var pos := player.global_position + Vector3(cos(ang) * dist, randf_range(3.0, 10.0), sin(ang) * dist)
	var vol := -6.0 if call_name == "distant_roar" else -10.0
	Sfx.play3d(call_name, pos, vol)
