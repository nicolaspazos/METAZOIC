extends CanvasLayer
## In-game HUD: health bar, kill counter, and the red damage flash.
## Wires itself to the player (found via the "player" group) at scene start.

@onready var health_fill: ColorRect = $HealthFill
@onready var kills_label: Label = $KillsLabel
@onready var damage_flash: ColorRect = $DamageFlash

var _full_width := 0.0


func _ready() -> void:
	_full_width = health_fill.size.x
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HUD: no player found in the scene")
		return
	player.health_changed.connect(_on_health_changed)
	player.kills_changed.connect(_on_kills_changed)
	player.damaged.connect(_on_damaged)
	_on_health_changed(player.health, player.max_health)


func _on_health_changed(current: float, max_value: float) -> void:
	health_fill.size.x = _full_width * clampf(current / max_value, 0.0, 1.0)


func _on_kills_changed(count: int) -> void:
	kills_label.text = "SLAIN  %d" % count


func _on_damaged() -> void:
	damage_flash.color = Color(0.8, 0.05, 0.05, 0.45)
	var t := create_tween()
	t.tween_property(damage_flash, "color:a", 0.0, 0.5)
