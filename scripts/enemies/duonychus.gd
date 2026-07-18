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
	_forge_boss_bulk()
	# Parasite corruption: dark hide veined red.
	for mi in _mesh_instances:
		mi.set_instance_shader_parameter("tint_i", Color(0.75, 0.6, 0.6))


## The boss gets its own lofted anatomy — a mountain of muscle, not capsules.
func _forge_boss_bulk() -> void:
	var body := mesh.get_node_or_null("Body") as MeshInstance3D
	if body:  # barrel gut swelling from hips to a deep chest
		body.mesh = MeshForge.tube_y([
			[-1.15, 0.22, 0.26], [-0.7, 0.56, 0.62], [-0.1, 0.68, 0.74],
			[0.5, 0.56, 0.6], [0.95, 0.36, 0.4], [1.15, 0.16, 0.18]], 14)
	for arm_path in ["LeftArmPivot/Arm", "RightArmPivot/Arm"]:
		var arm := mesh.get_node_or_null(arm_path) as MeshInstance3D
		if arm:  # scythe-bearing arms thick with muscle
			arm.mesh = MeshForge.tube_y([
				[-0.55, 0.09, 0.09], [-0.25, 0.17, 0.16],
				[0.1, 0.15, 0.14], [0.45, 0.11, 0.11]], 9)
	var neck_low := mesh.get_node_or_null("NeckPivot/NeckLow") as MeshInstance3D
	if neck_low:
		neck_low.mesh = MeshForge.tube_y([
			[-0.42, 0.15, 0.17], [0.0, 0.22, 0.24], [0.42, 0.17, 0.19]], 10)
	var neck_up := mesh.get_node_or_null("NeckPivot/NeckUp") as MeshInstance3D
	if neck_up:
		neck_up.mesh = MeshForge.tube_y([
			[-0.35, 0.11, 0.12], [0.0, 0.155, 0.165], [0.35, 0.12, 0.13]], 10)
	for thigh_path in ["LeftLegPivot/Thigh", "RightLegPivot/Thigh"]:
		var thigh := mesh.get_node_or_null(thigh_path) as MeshInstance3D
		if thigh:
			thigh.mesh = MeshForge.tube_y([
				[-0.45, 0.15, 0.19], [-0.15, 0.26, 0.31],
				[0.15, 0.28, 0.31], [0.42, 0.19, 0.23]], 10)


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
