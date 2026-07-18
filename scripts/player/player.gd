extends CharacterBody3D
## Third-person controller for the caveman protagonist of METAZOIC.
##
## Movement is camera-relative (WASD), the mouse orbits the camera, Space jumps,
## and Escape toggles the mouse capture. Input is read directly from physical keys
## so the project runs correctly regardless of keyboard layout and needs no input-map
## configuration in project.godot.

@export var move_speed: float = 6.0
@export var jump_velocity: float = 6.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var turn_speed: float = 12.0

## Node that yaws (left/right) with the mouse — the basis we move relative to.
@onready var yaw_pivot: Node3D = $YawPivot
## Node that pitches (up/down) with the mouse. Child of the yaw pivot.
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
## Visual mesh, rotated to face the movement direction (kept separate from collision).
@onready var mesh: Node3D = $Mesh

var _pitch: float = -0.25


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.2, 0.5)
		pitch_pivot.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)


func _physics_process(delta: float) -> void:
	# Gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump.
	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = jump_velocity

	# Gather WASD input.
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

	# Convert to a world-space direction relative to where the camera is facing.
	var cam_basis := yaw_pivot.global_transform.basis
	var direction := (cam_basis.z * input_dir.y) + (cam_basis.x * input_dir.x)
	direction.y = 0.0
	direction = direction.normalized()

	if direction.length() > 0.01:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		# Smoothly turn the visible mesh toward the movement direction.
		var target_yaw := atan2(direction.x, direction.z)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_yaw, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()
