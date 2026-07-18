extends CharacterBody3D
## Raptor grunt — the basic infected enemy. Wanders near its spawn point, chases
## the player on sight, and lunges to bite. Sprays blood when hurt; dies messily
## and lingers as a corpse before sinking into the ground.
##
## Front of the model is local +Z on the Mesh node (same convention as the player).
## Procedural animation: legs scurry, tail wags, head bobs — all in _process.

enum State { WANDER, CHASE, LUNGE, RECOVER, DEAD }

@export var max_health := 40.0
@export var move_speed := 4.6
@export var wander_speed := 1.5
@export var lunge_speed := 9.5
@export var bite_damage := 9.0
@export var aggro_range := 16.0
@export var attack_range := 2.3
@export var gravity := 18.0

var health: float
var state := State.WANDER
var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _state_timer := 0.0
var _bite_cooldown := 0.0
var _has_bitten := false
var _anim_t := 0.0

@onready var mesh: Node3D = $Mesh
@onready var neck: Node3D = $Mesh/NeckPivot
@onready var jaw: Node3D = $Mesh/NeckPivot/HeadPivot/JawPivot
@onready var tail: Node3D = $Mesh/TailPivot
@onready var tail2: Node3D = $Mesh/TailPivot/Tail2Pivot
@onready var tail3: Node3D = $Mesh/TailPivot/Tail2Pivot/Tail3Pivot
@onready var l_leg: Node3D = $Mesh/LeftLegPivot
@onready var r_leg: Node3D = $Mesh/RightLegPivot

## Cached for the instance-uniform hit flash (psx_lit's `flash` parameter).
var _mesh_instances: Array = []
## How wide the jaw hangs open right now (lerped toward _jaw_target in _process).
var _jaw_target := 0.05
## Which way this raptor circles its prey (+1/-1), re-rolled after each bite.
var _strafe_side := 1.0


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_home = global_position
	_mesh_instances = mesh.find_children("*", "MeshInstance3D")
	_strafe_side = 1.0 if randf() < 0.5 else -1.0


func is_alive() -> bool:
	return state != State.DEAD


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	_bite_cooldown -= delta
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var to_player := Vector3.ZERO
	var dist := INF
	if player:
		to_player = player.global_position - global_position
		to_player.y = 0.0
		dist = to_player.length()

	match state:
		State.WANDER:
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(2.0, 4.5)
				var angle := randf() * TAU
				_wander_target = _home + Vector3(cos(angle), 0, sin(angle)) * randf_range(2.0, 7.0)
			var to_target := _wander_target - global_position
			to_target.y = 0.0
			if to_target.length() > 0.8:
				_move_horizontal(to_target.normalized() * wander_speed, delta)
			else:
				_move_horizontal(Vector3.ZERO, delta)
			if dist < aggro_range:
				state = State.CHASE
				Sfx.play3d("growl", global_position, -2.0)
		State.CHASE:
			if dist > aggro_range * 1.8:
				state = State.WANDER
			elif dist < attack_range and _bite_cooldown <= 0.0:
				# Commit to a lunge: leap at the player, jaws wide.
				state = State.LUNGE
				_state_timer = 0.35
				_has_bitten = false
				_jaw_target = 0.7
				var dir := to_player.normalized()
				velocity.x = dir.x * lunge_speed
				velocity.z = dir.z * lunge_speed
				velocity.y = 2.5
			elif dist < 6.0 and _bite_cooldown > 0.0:
				# Circle the prey while the bite recharges — pack hunter behavior.
				var fwd := to_player.normalized()
				var tangent := Vector3(-fwd.z, 0.0, fwd.x) * _strafe_side
				var desired := (tangent * 0.85 + fwd * 0.3).normalized() * move_speed * 0.6
				_move_horizontal(desired, delta)
			else:
				_move_horizontal(to_player.normalized() * move_speed, delta)
		State.LUNGE:
			_state_timer -= delta
			if not _has_bitten and player and dist < 2.6:
				_has_bitten = true
				Sfx.play3d("bite", global_position)
				if player.has_method("take_damage"):
					player.take_damage(bite_damage, global_position)
					Gore.spray(player.global_position + Vector3.UP, to_player.normalized(), 10)
			if _state_timer <= 0.0:
				state = State.RECOVER
				_state_timer = 0.55
				_bite_cooldown = 1.4
				_jaw_target = 0.05
				_strafe_side = 1.0 if randf() < 0.5 else -1.0
				# Hop back out of club range after committing to the bite.
				if player:
					var back := -to_player.normalized()
					velocity = back * 5.0 + Vector3.UP * 2.0
		State.RECOVER:
			_state_timer -= delta
			_move_horizontal(Vector3.ZERO, delta)
			if _state_timer <= 0.0:
				state = State.CHASE

	# Face travel direction — but lock eyes on the player when close (menace!).
	var face_vec := Vector3(velocity.x, 0, velocity.z)
	if player and dist < 7.0 and state != State.WANDER:
		face_vec = to_player
	if face_vec.length() > 0.5:
		mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(face_vec.x, face_vec.z), 10.0 * delta)

	move_and_slide()


func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	var run_ratio := Vector2(velocity.x, velocity.z).length() / move_speed
	_anim_t += delta * (3.0 + 14.0 * run_ratio)
	var swing := sin(_anim_t) * 0.8 * clampf(run_ratio, 0.1, 1.2)
	l_leg.rotation.x = swing
	r_leg.rotation.x = -swing
	# Whip-like tail: each segment lags the previous one.
	tail.rotation.y = sin(_anim_t * 0.6) * 0.3
	tail2.rotation.y = sin(_anim_t * 0.6 - 0.7) * 0.35
	tail3.rotation.y = sin(_anim_t * 0.6 - 1.4) * 0.4
	neck.rotation.x = sin(_anim_t * 2.0) * 0.06 * run_ratio
	# Jaw eases toward its target (wide during lunges, chattering at rest).
	jaw.rotation.x = lerpf(jaw.rotation.x, _jaw_target, 12.0 * delta)


## Called by the player's attacks. `hit_dir` points from the attacker toward this raptor.
func take_damage(amount: float, hit_dir: Vector3 = Vector3.ZERO) -> void:
	if state == State.DEAD:
		return
	health -= amount
	Gore.spray(global_position + Vector3.UP * 0.9, (hit_dir + Vector3.UP * 0.4).normalized(), 20)
	Sfx.play3d("raptor_hurt", global_position, -2.0)
	velocity += hit_dir * 6.0 + Vector3.UP * 2.5
	# Flinch: quick scale punch + red hit flash (instance shader uniform).
	mesh.scale = Vector3.ONE * 1.15
	var t := create_tween()
	t.tween_property(mesh, "scale", Vector3.ONE, 0.15)
	_set_flash(0.85)
	var ft := create_tween()
	ft.tween_method(_set_flash, 0.85, 0.0, 0.22)
	if health <= 0.0:
		_die()
	else:
		# Getting clubbed staggers the raptor — interrupts even a lunge.
		state = State.RECOVER
		_state_timer = maxf(_state_timer, 0.35)
		_jaw_target = 0.05


## Set the red hit-flash amount on every mesh part (psx_lit instance uniform).
func _set_flash(a: float) -> void:
	for mi in _mesh_instances:
		if is_instance_valid(mi):
			mi.set_instance_shader_parameter("flash", Color(1.0, 0.25, 0.15, a))


func _die() -> void:
	state = State.DEAD
	Sfx.play3d("raptor_die", global_position, 2.0)
	Gore.burst(global_position + Vector3.UP * 0.8)
	Gore.pool(global_position)
	Gore.gibs(global_position + Vector3.UP * 0.7, 4)
	# Corpses only collide with the world, so the player walks over them freely.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 1)
	get_tree().call_group("player", "on_enemy_killed")
	# Topple with a bounce, linger as a corpse, then sink into the ground.
	var t := create_tween()
	t.tween_property(mesh, "rotation:z", PI * 0.55, 0.45) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_interval(9.0)
	t.tween_property(mesh, "position:y", -1.4, 2.5)
	t.tween_callback(queue_free)


func _move_horizontal(target: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target.x, 24.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 24.0 * delta)
