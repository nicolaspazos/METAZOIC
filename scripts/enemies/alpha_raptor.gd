extends "res://scripts/enemies/raptor.gd"
## The Alpha Raptor — first mini-boss. A hulking, red-tinted pack leader that
## guards the meteor crash site. Killing it grants the RAPTOR CLAWS power
## (faster club swings, +damage, and the E shredding dash).
##
## Stats (health, damage, speed) are overridden in alpha_raptor.tscn.


func _ready() -> void:
	super()
	# Parasite-red hide via psx_lit's per-instance tint.
	for mi in _mesh_instances:
		mi.set_instance_shader_parameter("tint_i", Color(1.35, 0.55, 0.5))
	get_tree().call_group("hud", "show_boss", "ALPHA RAPTOR", self)


func _die() -> void:
	PowerSystem.absorb(PowerSystem.Power.CLAWS)
	Sfx.play3d("growl", global_position, 6.0, 0.55)  # deep death bellow
	get_tree().call_group("hud", "hide_boss")
	super()
