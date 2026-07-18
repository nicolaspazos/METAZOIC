extends "res://scripts/enemies/raptor.gd"
## Duonychus tsogtbaatari — the parasite-corrupted boss of the first area.
## A hulking therizinosaur with two enormous scythe claws; its "bite" attack is
## reused from the raptor AI as a sweeping claw strike (bigger range and damage,
## set in duonychus.tscn). Killing it grants the DUONYCHUS CLAWS mutation.

var _bar_shown := false
var _enraged := false
var _base_tint := Color(0.75, 0.6, 0.6)


func _ready() -> void:
	super()
	# Parasite corruption: dark hide veined red.
	for mi in _mesh_instances:
		mi.set_instance_shader_parameter("tint_i", Color(0.75, 0.6, 0.6))


func _process(delta: float) -> void:
	super(delta)
	if _enraged and is_alive():
		var pulse := 0.72 + sin(Time.get_ticks_msec() * 0.008) * 0.12
		for mi in _mesh_instances:
			mi.set_instance_shader_parameter("tint_i", Color(pulse, 0.38, 0.38))
	# The boss bar appears the moment it first notices you.
	if not _bar_shown and state == State.CHASE:
		_bar_shown = true
		Sfx.play3d("distant_roar", global_position, 4.0, 1.3)
		get_tree().call_group("hud", "show_boss", "DUONYCHUS  ·  THE SCYTHE-BEARER", self)


func take_damage(amount: float, hit_dir: Vector3 = Vector3.ZERO) -> void:
	super(amount, hit_dir)
	if not _enraged and is_alive() and health <= max_health * 0.5:
		_enter_enrage()


func _enter_enrage() -> void:
	_enraged = true
	move_speed *= 1.22
	lunge_speed *= 1.18
	bite_damage *= 1.15
	Sfx.play3d("distant_roar", global_position, 5.0, 0.82)
	Gore.spark(global_position + Vector3.UP * 2.0, Vector3.UP, 28)


func _die() -> void:
	PowerSystem.absorb(PowerSystem.Power.CLAWS)
	Sfx.play3d("distant_roar", global_position, 6.0, 1.1)
	get_tree().call_group("hud", "hide_boss")
	super()
