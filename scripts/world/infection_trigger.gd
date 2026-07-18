extends Area3D
## Placed around the meteor shard. When the uninfected caveman gets close,
## the parasite bonds with him — the game's inciting moment.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("infect"):
		body.infect()
