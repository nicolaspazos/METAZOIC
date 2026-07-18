extends CharacterBody3D
## The caveman: third-person movement, orbit camera, club combat, and health.
##
## The body itself never rotates — the Mesh (visual) turns to face movement, and
## the camera rig (YawPivot → PitchPivot → Camera3D) turns with the mouse.
## Front of the visual is local +Z (shared convention with the raptor).
##
## Input is read from physical keys / raw mouse buttons so no input-map setup is
## needed: WASD move, mouse orbits, Space jumps, Left Click attacks, Esc frees the mouse.

signal health_changed(current: float, max_value: float)
signal damaged
signal kills_changed(count: int)
signal died

@export_group("Movement")
@export var move_speed := 6.0
@export var jump_velocity := 6.5
@export var gravity := 18.0
@export var mouse_sensitivity := 0.0025
@export var turn_speed := 12.0

@export_group("Combat")
@export var attack_damage := 18.0
@export var max_health := 100.0
## The parasite feeds on the kill: health restored whenever an enemy dies.
@export var kill_heal := 12.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var camera: Camera3D = $YawPivot/PitchPivot/Camera3D
@onready var visual: CavemanVisual = $Mesh
@onready var hitbox: Area3D = $Mesh/AttackHitbox

var health: float
var kills := 0
var _pitch := -0.25
var _attacking := false
var _attack_index := 0
var _invuln := 0.0
var _trauma := 0.0
var _spawn_point := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	health = max_health
	_spawn_point = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.2, 0.5)
		pitch_pivot.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_try_attack()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)


func _physics_process(delta: float) -> void:
	_invuln -= delta

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

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
	var direction := (cam_basis.z * input_dir.y) + (cam_basis.x * input_dir.x)
	direction.y = 0.0
	direction = direction.normalized()

	# Nearly rooted while swinging the club.
	var speed := move_speed * (0.15 if _attacking else 1.0)

	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not _attacking:
			var target_yaw := atan2(direction.x, direction.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	visual.move_amount = Vector2(velocity.x, velocity.z).length() / move_speed

	move_and_slide()


func _process(delta: float) -> void:
	# Camera shake driven by trauma (decays over time, offset scales quadratically).
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - 2.2 * delta)
		var shake := _trauma * _trauma
		camera.h_offset = randf_range(-1.0, 1.0) * 0.35 * shake
		camera.v_offset = randf_range(-1.0, 1.0) * 0.35 * shake
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _try_attack() -> void:
	if _attacking:
		return
	_attacking = true
	_attack_index = (_attack_index + 1) % 2
	# Face where the camera looks, so the swing goes where the player aims.
	visual.rotation.y = yaw_pivot.rotation.y + PI
	visual.play_attack(_attack_index)
	await get_tree().create_timer(0.18).timeout  # windup — club is mid-air
	_strike()
	await get_tree().create_timer(0.32).timeout  # recovery
	_attacking = false


## The strike frame: damage everything hostile inside the hitbox.
func _strike() -> void:
	var hit := false
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var dir := (body.global_position - global_position)
			dir.y = 0.0
			body.take_damage(attack_damage, dir.normalized())
			hit = true
	if hit:
		Gore.hitstop()
		_trauma = maxf(_trauma, 0.5)


## Called by enemies. `from_position` is where the hit came from (for knockback).
func take_damage(amount: float, from_position: Vector3) -> void:
	if _invuln > 0.0 or health <= 0.0:
		return
	health -= amount
	_invuln = 0.6
	var away := global_position - from_position
	away.y = 0.0
	velocity += away.normalized() * 6.0 + Vector3.UP * 2.0
	_trauma = maxf(_trauma, 0.65)
	damaged.emit()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	died.emit()
	Gore.burst(global_position + Vector3.UP)
	Gore.pool(global_position)
	# Arcade-style: respawn at the start of the area with full health.
	global_position = _spawn_point
	velocity = Vector3.ZERO
	health = max_health
	_invuln = 1.5
	health_changed.emit(health, max_health)


## Called via call_group by dying enemies.
func on_enemy_killed() -> void:
	kills += 1
	health = minf(max_health, health + kill_heal)
	kills_changed.emit(kills)
	health_changed.emit(health, max_health)
