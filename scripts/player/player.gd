extends CharacterBody3D
## The caveman: third-person movement, orbit camera, club combat, health, and the
## parasite powers absorbed from boss dinosaurs.
##
## The body itself never rotates — the Mesh (visual) turns to face movement, and
## the camera rig (YawPivot → PitchPivot → SpringArm3D → Camera3D) turns with the
## mouse. Front of the visual is local +Z (shared convention with the raptor).
##
## Controls (physical keys — no input-map setup needed):
##   WASD move · mouse orbit · Space jump · LMB club attack · Esc free mouse
##   Q hold Ceratops Shield · E Raptor Claws dash · F Tyrant Jaws chomp
##   Shift Pachy Charge · R Ankylo Tail sweep · P (debug) unlock all powers

const MovementRules := preload("res://scripts/player/movement_math.gd")

signal health_changed(current: float, max_value: float)
signal stamina_changed(current: float, max_value: float)
signal exhausted
signal damaged
signal kills_changed(count: int)
signal died
## Emitted once, when the meteor parasite bonds with the caveman.
signal parasite_bonded

enum AttackPhase { IDLE, WINDUP, ACTIVE, RECOVERY }

const STAMINA_COST_DODGE := 28.0
const STAMINA_COST_HEAVY := 32.0
const STAMINA_COST_CLAWS := 20.0
const STAMINA_COST_CHARGE := 38.0

@export_group("Movement")
@export var move_speed := 6.0
@export var jump_velocity := 6.5
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0025
@export var turn_speed := 12.0
@export var max_stamina := 100.0
@export var stamina_regen := 28.0
@export var stamina_regen_delay := 0.7

@export_group("Combat")
@export var attack_damage := 18.0
@export var max_health := 100.0
## The parasite feeds on the kill: health restored whenever an enemy dies.
@export var kill_heal := 12.0

## Seconds of cooldown per power (SHIELD is hold-based, no cooldown).
const POWER_COOLDOWNS := {
	PowerSystem.Power.CLAWS: 4.0,
	PowerSystem.Power.JAWS: 6.0,
	PowerSystem.Power.CHARGE: 5.0,
	PowerSystem.Power.TAIL_SWEEP: 8.0,
}

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var visual: CavemanVisual = $Mesh
@onready var hitbox: Area3D = $Mesh/AttackHitbox
@onready var shield_frill: Node3D = $Mesh/ShieldFrill
@onready var jaw_top: Node3D = $Mesh/JawTop
@onready var jaw_bottom: Node3D = $Mesh/JawBottom
@onready var fist_node: Node3D = $Mesh/RightArmPivot/Hand

var health: float
var stamina: float
var kills := 0
## False until the player touches the meteor shard. Pre-infection the caveman is
## unarmed (no attacks) and the wildlife leaves him alone.
var infected := false
var _pitch := -0.25
var _attacking := false
var _attack_phase := AttackPhase.IDLE
var _queued_attack := false
var _queued_heavy := false
var _attack_index := 0
var _invuln := 0.0
var _trauma := 0.0
var _spawn_point := Vector3.ZERO
var _step_accum := 0.0

# Powers state
var _shielding := false
var _power_ready := {}      # Power -> timestamp (sec) when usable again
var _dashing := false
var _dash_dir := Vector3.ZERO
var _dash_speed := 0.0
var _dash_timer := 0.0
var _dash_power := -1
var _dash_hits: Array = []
var _dash_fx_accum := 0.0
var _dodge_ready := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _club_prev := Vector3.ZERO
## Which mutation the E key triggers — set from the weapon wheel (hold Tab).
var equipped_mutation: int = PowerSystem.Power.CLAWS
var _coyote := 0.0
var _mantle_ready := 0.0
var _mantling := false
var _mantle_start := Vector3.ZERO
var _mantle_target := Vector3.ZERO
var _mantle_elapsed := 0.0
var _mantle_duration := 0.34
var _jump_buffer := 0.0
var _stamina_regen_block := 0.0
var _exhausted_feedback_cooldown := 0.0


func _ready() -> void:
	add_to_group("player")
	health = max_health
	stamina = max_stamina
	_spawn_point = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.2, 0.5)
		pitch_pivot.rotation.x = _pitch
		return
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			queue_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			queue_attack(true)
		return
	if event is InputEventKey and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if event.pressed:
					_jump_buffer = 0.14
			KEY_ESCAPE:
				if event.pressed:
					Input.mouse_mode = (
						Input.MOUSE_MODE_VISIBLE
						if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
						else Input.MOUSE_MODE_CAPTURED
					)
			KEY_Q:
				if event.pressed:
					start_shield()
				else:
					stop_shield()
			KEY_E:
				if event.pressed:
					activate_power(equipped_mutation)
			KEY_F:
				if event.pressed:
					activate_power(PowerSystem.Power.JAWS)
			KEY_SHIFT:
				if event.pressed:
					activate_power(PowerSystem.Power.CHARGE)
			KEY_R:
				if event.pressed:
					activate_power(PowerSystem.Power.TAIL_SWEEP)
			KEY_CTRL:
				if event.pressed:
					dodge()
			KEY_P:
				if event.pressed:  # debug: unlock everything
					print("[debug] unlocking all powers")
					for p in PowerSystem.Power.values():
						PowerSystem.absorb(p)


func _physics_process(delta: float) -> void:
	_invuln -= delta
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_stamina_regen_block -= delta
	_exhausted_feedback_cooldown -= delta
	if _stamina_regen_block <= 0.0 and stamina < max_stamina:
		var before := stamina
		stamina = MovementRules.regenerate_resource(
			stamina, max_stamina, stamina_regen, delta)
		if stamina != before:
			stamina_changed.emit(stamina, max_stamina)
	if _mantling:
		_mantle_step(delta)
		return

	# Committed dash (Claws / Charge) overrides normal movement entirely.
	if _dashing:
		_dash_step(delta)
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
		_coyote -= delta
	else:
		_coyote = 0.12  # coyote time — forgiving jumps off ledges

	if _jump_buffer > 0.0 and (is_on_floor() or _coyote > 0.0) and velocity.y <= 0.5:
		velocity.y = jump_velocity
		_coyote = 0.0
		_jump_buffer = 0.0
		Sfx.play3d("jump", global_position, -8.0)

	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	# Camera-relative movement direction.
	var cam_basis := yaw_pivot.global_transform.basis
	var direction: Vector3 = MovementRules.camera_relative(input_dir, cam_basis)

	# Nearly rooted while swinging; slowed while shielding.
	var speed := move_speed
	if _attacking:
		speed *= 0.15
	elif _shielding:
		speed *= 0.45

	# Smooth acceleration toward the target velocity (no instant starts/stops).
	# Grounded turns are snappy; airborne there's still real control (parkour feel).
	var accel := 45.0 if is_on_floor() else 18.0
	if direction.length() > 0.01:
		velocity = MovementRules.horizontal_velocity(
			velocity, direction * speed, accel, delta)
		if not _attacking:
			var target_yaw := atan2(direction.x, direction.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)
		# Auto-mantle: only starts when obstruction, top surface, and clearance agree.
		_mantle_ready -= delta
		if is_on_wall() and _mantle_ready <= 0.0 and velocity.y <= 1.0:
			try_begin_mantle(direction)
	else:
		velocity = MovementRules.horizontal_velocity(velocity, Vector3.ZERO,
			38.0 if is_on_floor() else 6.0, delta)

	var hspeed := Vector2(velocity.x, velocity.z).length()
	visual.move_amount = lerpf(visual.move_amount, hspeed / move_speed, 10.0 * delta)

	# Footsteps paced by distance travelled.
	if is_on_floor() and hspeed > 1.5:
		_step_accum += hspeed * delta
		if _step_accum > 2.6:
			_step_accum = 0.0
			Sfx.play3d("step", global_position, -12.0)

	# Parasite-fist motion trail while a punch is in flight.
	if _attacking:
		var fist_pos := fist_node.global_position
		if _club_prev != Vector3.ZERO:
			var seg := fist_pos - _club_prev
			if seg.length() > 0.12:
				Gore.streak(_club_prev.lerp(fist_pos, 0.5), seg,
					Color(0.95, 0.15, 0.1, 0.7), clampf(seg.length() * 1.3, 0.3, 1.6))
		_club_prev = fist_pos
	else:
		_club_prev = Vector3.ZERO

	_fall_speed = -velocity.y
	move_and_slide()

	# Landing thump after a real fall.
	if is_on_floor() and not _was_on_floor and _fall_speed > 6.0:
		Gore.puff(global_position, 12)
		Sfx.play3d("land", global_position, -4.0)
		_trauma = maxf(_trauma, 0.3)
	_was_on_floor = is_on_floor()


func _process(delta: float) -> void:
	var speed_ratio := clampf(Vector2(velocity.x, velocity.z).length() / 16.0, 0.0, 1.0)
	var target_fov := 70.0 + speed_ratio * 7.0 + (4.0 if _dashing else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * 8.0))
	# Camera shake driven by trauma (decays over time, offset scales quadratically).
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - 2.2 * delta)
		var shake := _trauma * _trauma
		camera.h_offset = randf_range(-1.0, 1.0) * 0.35 * shake
		camera.v_offset = randf_range(-1.0, 1.0) * 0.35 * shake
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


# ------------------------------------------------------------------ club combat

## The infection moment: parasite fists grow in, hair parts, the hunt begins.
func infect() -> void:
	if infected:
		return
	infected = true
	visual.reveal_face()
	Gore.spark(global_position + Vector3.UP * 1.5, Vector3.UP, 50)
	Gore.hitstop(0.15, 1.1)
	Sfx.play("absorb", 4.0, 0.72)
	_trauma = maxf(_trauma, 0.9)
	parasite_bonded.emit()


func queue_attack(heavy := false) -> bool:
	if not infected or _dashing or _mantling:
		return false
	if heavy and not can_spend_stamina(STAMINA_COST_HEAVY):
		_reject_exhausted()
		return false
	if _attacking:
		if _attack_phase != AttackPhase.RECOVERY or _queued_attack:
			return false
		_queued_attack = true
		_queued_heavy = heavy
		return true
	_try_attack(heavy)
	return true


func attack_phase_name() -> String:
	return AttackPhase.keys()[_attack_phase].to_lower()


func _try_attack(heavy := false) -> void:
	if not infected:
		return  # unarmed until the parasite bonds
	if _attacking or _dashing or _mantling:
		return
	if heavy and not spend_stamina(STAMINA_COST_HEAVY):
		return
	_attacking = true
	_attack_phase = AttackPhase.WINDUP
	# Claws make every swing faster — the parasite quickens the arm.
	var has_claws := PowerSystem.has_power(PowerSystem.Power.CLAWS)
	var windup: float
	var recovery: float
	if heavy:
		windup = 0.34
		recovery = 0.42
		visual.play_attack(2)
		Sfx.play3d("heavy", global_position, -3.0)
	else:
		_attack_index = (_attack_index + 1) % 2  # alternate right/left fists
		windup = 0.1 if has_claws else 0.13
		recovery = 0.2 if has_claws else 0.28
		visual.play_attack(_attack_index)
		Sfx.play3d("swing", global_position, -6.0, 1.15)
	# Face where the camera looks, and lunge a step into the swing.
	visual.rotation.y = yaw_pivot.rotation.y + PI
	var facing := -yaw_pivot.global_transform.basis.z
	facing.y = 0.0
	velocity += facing.normalized() * (3.2 if heavy else 2.2)
	await get_tree().create_timer(windup).timeout
	_attack_phase = AttackPhase.ACTIVE
	_strike(heavy)
	_attack_phase = AttackPhase.RECOVERY
	await get_tree().create_timer(recovery).timeout
	_attacking = false
	_attack_phase = AttackPhase.IDLE
	if _queued_attack:
		var next_heavy := _queued_heavy
		_queued_attack = false
		_queued_heavy = false
		queue_attack.call_deferred(next_heavy)


## The strike frame: damage everything hostile inside the hitbox.
func _strike(heavy := false) -> void:
	var damage := 32.0 if heavy else attack_damage
	damage += Stats.levels.get("fists", 0) * 4.0  # blood-bought fist levels
	if PowerSystem.has_power(PowerSystem.Power.CLAWS):
		damage += 6.0
	var hit := false
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var dir := (body.global_position - global_position)
			dir.y = 0.0
			body.take_damage(damage, dir.normalized() * (1.8 if heavy else 1.0))
			hit = true
	if heavy:
		# The slam always shakes the ground, hit or not.
		Gore.puff(global_position + visual.global_transform.basis.z * 1.2, 14)
		_trauma = maxf(_trauma, 0.55)
	if hit:
		Sfx.play3d("hit", global_position, 0.0)
		Gore.hitstop(0.05, 0.1 if heavy else 0.07)
		_trauma = maxf(_trauma, 0.7 if heavy else 0.5)


## Quick evasive burst (Ctrl) — brief i-frames, moves with input or backsteps.
func dodge() -> void:
	if _dashing or _attacking or _mantling or _now() < _dodge_ready:
		return
	if not spend_stamina(STAMINA_COST_DODGE):
		_reject_exhausted()
		return
	_dodge_ready = _now() + 1.2
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1.0
	var cam_basis := yaw_pivot.global_transform.basis
	var dir := (cam_basis.z * input_dir.y) + (cam_basis.x * input_dir.x)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = cam_basis.z  # no input → backstep away from where we're looking
	dir = dir.normalized()
	velocity = dir * 13.0 + Vector3.UP * 3.0
	_invuln = maxf(_invuln, 0.35)
	Gore.puff(global_position, 8)
	Sfx.play3d("dash", global_position, -8.0, 1.3)


# ------------------------------------------------------------------ powers

func has_cooldown_elapsed(power: int) -> bool:
	return _now() >= float(_power_ready.get(power, 0.0))


## 0 = ready, 1 = just used. HUD polls this for the cooldown overlay.
func cooldown_frac(power: int) -> float:
	var cd: float = POWER_COOLDOWNS.get(power, 0.0)
	if cd <= 0.0:
		return 0.0
	var remain := float(_power_ready.get(power, 0.0)) - _now()
	return clampf(remain / cd, 0.0, 1.0)


func activate_power(power: int) -> void:
	if not PowerSystem.has_power(power):
		return
	if _attacking or _dashing or _shielding or _mantling:
		return
	if not has_cooldown_elapsed(power):
		return
	var stamina_cost := 0.0
	if power == PowerSystem.Power.CLAWS:
		stamina_cost = STAMINA_COST_CLAWS
	elif power == PowerSystem.Power.CHARGE:
		stamina_cost = STAMINA_COST_CHARGE
	if stamina_cost > 0.0 and not spend_stamina(stamina_cost):
		_reject_exhausted()
		return
	# Cooldowns shrink as the mutation is leveled with blood.
	_power_ready[power] = _now() \
		+ float(POWER_COOLDOWNS.get(power, 0.0)) * Stats.power_cooldown_mult(power)
	match power:
		PowerSystem.Power.CLAWS:
			_begin_dash(power, 16.0, 0.28, Color(1.0, 0.55, 0.15))
		PowerSystem.Power.CHARGE:
			_begin_dash(power, 20.0, 0.5, Color(0.95, 0.8, 0.2))
		PowerSystem.Power.JAWS:
			_jaws_chomp()
		PowerSystem.Power.TAIL_SWEEP:
			_tail_sweep()


## Ceratops Shield — hold Q. Blocks all frontal damage while raised.
func start_shield() -> void:
	if not PowerSystem.has_power(PowerSystem.Power.SHIELD) or _dashing:
		return
	_shielding = true
	shield_frill.visible = true
	# Face the camera so "frontal" matches where the player is looking.
	visual.rotation.y = yaw_pivot.rotation.y + PI


func stop_shield() -> void:
	_shielding = false
	if shield_frill:
		shield_frill.visible = false


## Raptor Claws (E) / Pachy Charge (Shift) — a committed dash that hurts
## everything in its path. Claws is a fast shredding lunge; Charge is a heavy
## ram that sends enemies flying.
func _begin_dash(power: int, speed: float, duration: float, _color: Color) -> void:
	_dashing = true
	_dash_power = power
	_dash_speed = speed
	_dash_timer = duration
	_dash_hits.clear()
	_dash_fx_accum = 0.0
	var fwd := -yaw_pivot.global_transform.basis.z
	fwd.y = 0.0
	_dash_dir = fwd.normalized()
	visual.rotation.y = yaw_pivot.rotation.y + PI
	visual.move_amount = 1.0
	Sfx.play3d("dash", global_position, -2.0)


func _dash_step(delta: float) -> void:
	_dash_timer -= delta
	velocity = _dash_dir * _dash_speed
	velocity.y = 0.0

	# Trail streaks.
	_dash_fx_accum += delta
	if _dash_fx_accum > 0.04:
		_dash_fx_accum = 0.0
		var col := Color(1.0, 0.55, 0.15) if _dash_power == PowerSystem.Power.CLAWS \
			else Color(0.95, 0.8, 0.2)
		Gore.streak(global_position + Vector3.UP, -_dash_dir, col)

	# Damage everything we plow through — once per target per dash.
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and not _dash_hits.has(body) \
				and body.has_method("take_damage"):
			_dash_hits.append(body)
			var dir := (body.global_position - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			if _dash_power == PowerSystem.Power.CHARGE:
				# Ram: moderate damage, massive knockback (scaled dir = big fling).
				body.take_damage(15.0 * Stats.power_damage_mult(_dash_power), dir * 4.0)
				_trauma = maxf(_trauma, 0.7)
			else:
				# Claws: heavy shredding damage, extra blood.
				body.take_damage(22.0 * Stats.power_damage_mult(_dash_power), dir)
				Gore.spray(body.global_position + Vector3.UP, dir, 26)
			Sfx.play3d("hit", body.global_position)
			Gore.hitstop()

	if _dash_timer <= 0.0:
		_dashing = false
		velocity *= 0.25
	move_and_slide()


## Tyrant Jaws (F) — spectral parasite jaws devour the closest enemy in front.
## Executes weakened prey outright and feeds the parasite (big heal).
func _jaws_chomp() -> void:
	var target: Node3D = null
	var best := INF
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var d := global_position.distance_squared_to(body.global_position)
			if d < best:
				best = d
				target = body
	if target == null:
		_power_ready[PowerSystem.Power.JAWS] = 0.0  # nothing bitten — no cooldown
		return

	visual.rotation.y = yaw_pivot.rotation.y + PI
	_animate_jaws()
	Sfx.play3d("chomp", global_position, 2.0)

	var dir := (target.global_position - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	var ratio: float = target.health / target.max_health
	if ratio <= 0.35:
		# Execute: bite the weakened prey in half.
		target.take_damage(9999.0, dir)
		Gore.burst(target.global_position + Vector3.UP, 60)
		Gore.gibs(target.global_position + Vector3.UP * 0.6, 8)
		health = minf(max_health, health + 25.0)
		Gore.hitstop(0.05, 0.14)
	else:
		target.take_damage(30.0 * Stats.power_damage_mult(PowerSystem.Power.JAWS), dir)
		health = minf(max_health, health + 8.0)
		Gore.hitstop()
	_trauma = maxf(_trauma, 0.6)
	health_changed.emit(health, max_health)


func _animate_jaws() -> void:
	jaw_top.visible = true
	jaw_bottom.visible = true
	var top_y := jaw_top.position.y
	var bot_y := jaw_bottom.position.y
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(jaw_top, "position:y", top_y - 0.32, 0.12) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	t.tween_property(jaw_bottom, "position:y", bot_y + 0.32, 0.12) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	t.chain().tween_interval(0.15)
	t.chain().tween_callback(func():
		jaw_top.position.y = top_y
		jaw_bottom.position.y = bot_y
		jaw_top.visible = false
		jaw_bottom.visible = false)


## Ankylo Tail (R) — a 360° sweep that batters everything around the caveman.
func _tail_sweep() -> void:
	Sfx.play3d("sweep", global_position, 2.0)
	var hit := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D) or not enemy.has_method("take_damage"):
			continue
		if not enemy.has_method("is_alive") or not enemy.is_alive():
			continue
		if global_position.distance_to(enemy.global_position) > 4.2:
			continue
		var dir: Vector3 = enemy.global_position - global_position
		dir.y = 0.0
		enemy.take_damage(20.0 * Stats.power_damage_mult(PowerSystem.Power.TAIL_SWEEP),
			dir.normalized() * 2.0)
		hit = true
	for k in 10:  # radial shockwave streaks
		var ang := TAU * k / 10.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		Gore.streak(global_position + Vector3.UP * 0.7 + dir * 1.4, dir,
			Color(0.4, 0.65, 1.0), 2.2)
	_trauma = maxf(_trauma, 0.8)
	if hit:
		Gore.hitstop()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func is_mantling() -> bool:
	return _mantling


func mantle_clearance_mask() -> int:
	return collision_mask


func try_begin_mantle(direction: Vector3) -> bool:
	if _mantling or _attacking or _dashing or direction.length_squared() < 0.1:
		return false
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var chest_from := global_position + Vector3.UP * 1.0
	var chest_query := PhysicsRayQueryParameters3D.create(
		chest_from, chest_from + direction * 0.9, 1, exclude)
	if space.intersect_ray(chest_query).is_empty():
		return false
	var head_from := global_position + Vector3.UP * 2.15
	var head_query := PhysicsRayQueryParameters3D.create(
		head_from, head_from + direction * 1.1, 1, exclude)
	if not space.intersect_ray(head_query).is_empty():
		return false
	var top_from := head_from + direction * 1.0
	var top_query := PhysicsRayQueryParameters3D.create(
		top_from, top_from + Vector3.DOWN * 1.7, 1, exclude)
	var top_hit := space.intersect_ray(top_query)
	if top_hit.is_empty():
		return false
	var rise: float = top_hit.position.y - global_position.y
	if rise < 0.35 or rise > 1.65:
		return false
	var candidate: Vector3 = top_hit.position + direction * 0.45 + Vector3.UP * 0.08
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = $CollisionShape3D.shape
	clearance.transform = Transform3D(global_transform.basis, candidate + Vector3.UP)
	clearance.collision_mask = mantle_clearance_mask()
	clearance.exclude = exclude
	if not space.intersect_shape(clearance, 1).is_empty():
		return false
	_mantling = true
	_mantle_elapsed = 0.0
	_mantle_start = global_position
	_mantle_target = candidate
	velocity = Vector3.ZERO
	_mantle_ready = 0.6
	Gore.puff(global_position + direction * 0.5, 6)
	Sfx.play3d("jump", global_position, -10.0, 0.85)
	return true


func _mantle_step(delta: float) -> void:
	_mantle_elapsed += delta
	var progress := minf(1.0, _mantle_elapsed / _mantle_duration)
	global_position = MovementRules.mantle_position(
		_mantle_start, _mantle_target, progress, 0.28)
	if progress >= 1.0:
		_mantling = false
		velocity = Vector3.ZERO


func can_spend_stamina(amount: float) -> bool:
	return amount >= 0.0 and stamina >= amount


func spend_stamina(amount: float) -> bool:
	if not can_spend_stamina(amount):
		return false
	stamina -= amount
	_stamina_regen_block = stamina_regen_delay
	stamina_changed.emit(stamina, max_stamina)
	return true


func _reject_exhausted() -> void:
	if _exhausted_feedback_cooldown > 0.0:
		return
	_exhausted_feedback_cooldown = 0.3
	exhausted.emit()
	Sfx.play("heartbeat", -12.0, 1.45, 0.02, "ui")


# ------------------------------------------------------------------ damage & death

## Called by enemies. `from_position` is where the hit came from (for knockback).
func take_damage(amount: float, from_position: Vector3) -> void:
	if _invuln > 0.0 or health <= 0.0 or _dashing:
		return

	# Ceratops Shield: blocks everything coming from the front.
	if _shielding and from_position != Vector3.ZERO:
		var to_attacker := from_position - global_position
		to_attacker.y = 0.0
		var facing := visual.global_transform.basis.z  # local +Z = front
		if to_attacker.normalized().dot(facing.normalized()) > 0.25:
			Sfx.play3d("block", global_position, 2.0)
			Gore.spark(global_position + Vector3.UP + facing * 0.7, facing)
			_trauma = maxf(_trauma, 0.3)
			return

	health -= amount
	_invuln = 0.6
	var away := global_position - from_position
	away.y = 0.0
	velocity += away.normalized() * 6.0 + Vector3.UP * 2.0
	_trauma = maxf(_trauma, 0.65)
	Sfx.play3d("player_hurt", global_position, 2.0)
	damaged.emit()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	died.emit()
	Sfx.play3d("player_hurt", global_position, 4.0, 0.7)
	Gore.burst(global_position + Vector3.UP)
	Gore.pool(global_position)
	# Arcade-style: respawn at the start of the area with full health.
	global_position = _spawn_point
	velocity = Vector3.ZERO
	health = max_health
	_invuln = 1.5
	stop_shield()
	health_changed.emit(health, max_health)


## Called via call_group by dying enemies (species + blood bounty).
func on_enemy_killed(species := "Raptor", blood_reward := 25) -> void:
	kills += 1
	Stats.add_kill(species, blood_reward)
	health = minf(max_health, health + kill_heal)
	kills_changed.emit(kills)
	health_changed.emit(health, max_health)


## Re-apply blood-bought character upgrades (called after menu purchases).
func refresh_stats() -> void:
	var new_max: float = 100.0 + float(Stats.levels.get("vitality", 0)) * 20.0
	if new_max > max_health:
		health += new_max - max_health  # vitality levels heal the difference
	max_health = new_max
	health_changed.emit(health, max_health)
