extends Node3D
## The caveman's home camp — snaps itself onto the procedural terrain at load.
## Must sit BELOW the Terrain node in the scene tree.


func _ready() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain:
		position.y = terrain.height_at(global_position.x, global_position.z)
