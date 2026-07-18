extends "res://scripts/enemies/raptor.gd"
## Duonychus tsogtbaatari — the parasite-corrupted boss of the first area.
## A hulking therizinosaur with two enormous scythe claws; its "bite" attack is
## reused from the raptor AI as a sweeping claw strike (bigger range and damage,
## set in duonychus.tscn). Killing it grants the DUONYCHUS CLAWS mutation.

var _bar_shown := false
var _enraged := false
var _base_tint := Color(0.75, 0.6, 0.6)
var _sweep_active := false
var _sweep_struck := false
var _sweep_timer := 0.0
var _sweep_cooldown := 2.0
@onready var _left_claw: Node3D = $Mesh/LeftArmPivot
@onready var _right_claw: Node3D = $Mesh/RightArmPivot


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


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		super(delta)
		return
	if _sweep_active:
		_sweep_step(delta)
		return
	_sweep_cooldown -= delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if _enraged and state == State.CHASE and _sweep_cooldown <= 0.0 and player \
			and global_position.distance_to(player.global_position) <= 4.8:
		_begin_sweep()
		return
	super(delta)


func take_damage(amount: float, hit_dir: Vector3 = Vector3.ZERO) -> void:
	if _sweep_active:
		_finish_sweep(true)
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
	_sweep_cooldown = 0.7


func _begin_sweep() -> void:
	_sweep_active = true
	_sweep_struck = false
	_sweep_timer = 0.82
	state = State.RECOVER
	velocity.x = 0.0
	velocity.z = 0.0
	Sfx.play3d("growl", global_position, 2.0, 0.72)
	Gore.spark(global_position + Vector3.UP * 1.8, mesh.global_transform.basis.z, 12)


func _sweep_step(delta: float) -> void:
	_sweep_timer -= delta
	var pose := sin(clampf((0.82 - _sweep_timer) / 0.82, 0.0, 1.0) * PI)
	_left_claw.rotation.z = -pose * 1.35
	_right_claw.rotation.z = pose * 1.35
	if not _sweep_struck and _sweep_timer <= 0.3:
		_sweep_struck = true
		Sfx.play3d("sweep", global_position, 3.0, 0.78)
		for target in get_tree().get_nodes_in_group("player"):
			if target is Node3D and target.has_method("take_damage") \
					and global_position.distance_to(target.global_position) <= 4.8:
				target.take_damage(bite_damage * 1.35, global_position)
	if _sweep_timer <= 0.0:
		_finish_sweep(false)
	move_and_slide()


func _finish_sweep(interrupted: bool) -> void:
	_sweep_active = false
	_left_claw.rotation.z = 0.0
	_right_claw.rotation.z = 0.0
	_sweep_cooldown = 2.8 if interrupted else 4.2
	state = State.RECOVER
	_state_timer = 0.45 if interrupted else 0.75


func _die() -> void:
	PowerSystem.absorb(PowerSystem.Power.CLAWS)
	Sfx.play3d("distant_roar", global_position, 6.0, 1.1)
	get_tree().call_group("hud", "hide_boss")
	super()
