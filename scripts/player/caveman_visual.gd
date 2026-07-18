class_name CavemanVisual
extends Node3D
## Procedural animation for the caveman's body — no baked animation data.
##
## Pre-infection his hair hangs over his face and his hands are bare. After the
## parasite bonds (`reveal_face()`), the bangs part and black-red parasite fists
## grow over his hands — these are the weapons behind `play_attack()`.
## Front of the model is local +Z.

@onready var l_arm: Node3D = $LeftArmPivot
@onready var r_arm: Node3D = $RightArmPivot
@onready var l_leg: Node3D = $LeftLegPivot
@onready var r_leg: Node3D = $RightLegPivot
@onready var torso: Node3D = $Torso
@onready var loin_front: Node3D = $LoinFront
@onready var loin_back: Node3D = $LoinBack
@onready var hair_front: Node3D = $HairFront
@onready var fist_l: Node3D = $LeftArmPivot/Fist
@onready var fist_r: Node3D = $RightArmPivot/Fist

## How fast the player is moving, 0..1. Set every frame by player.gd.
var move_amount := 0.0

var _t := 0.0
var _attack_tween: Tween
var _torso_base := 0.0
var _rolling := false


## Soulslike dodge roll — a full forward tumble.
func play_roll() -> void:
	if _rolling:
		return
	_rolling = true
	rotation.x = 0.0
	var t := create_tween()
	t.tween_property(self, "rotation:x", -TAU, 0.34) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		rotation.x = 0.0
		_rolling = false)


func _ready() -> void:
	_torso_base = torso.position.y
	_forge_organics()


## Replace the primitive part meshes with lofted organic shapes — real tapering
## torso, muscled limbs. Materials on the MeshInstances are kept.
func _forge_organics() -> void:
	torso.mesh = MeshForge.tube_y([
		[-0.5, 0.18, 0.14], [-0.32, 0.17, 0.135], [-0.05, 0.23, 0.17],
		[0.22, 0.27, 0.19], [0.4, 0.22, 0.16], [0.5, 0.06, 0.06]], 12)
	for pivot in [l_arm, r_arm]:
		var upper: MeshInstance3D = pivot.get_node("UpperArm")
		upper.mesh = MeshForge.tube_y([
			[-0.24, 0.045, 0.045], [-0.12, 0.085, 0.08],
			[0.06, 0.075, 0.07], [0.2, 0.055, 0.055]], 9)
		var fore: MeshInstance3D = pivot.get_node("Forearm")
		fore.mesh = MeshForge.tube_y([
			[-0.2, 0.04, 0.04], [-0.08, 0.07, 0.065],
			[0.1, 0.06, 0.055], [0.19, 0.045, 0.045]], 9)
	for pivot in [l_leg, r_leg]:
		var thigh: MeshInstance3D = pivot.get_node("Thigh")
		thigh.mesh = MeshForge.tube_y([
			[-0.26, 0.06, 0.06], [-0.12, 0.1, 0.1],
			[0.08, 0.115, 0.11], [0.24, 0.09, 0.09]], 9)
		var shin: MeshInstance3D = pivot.get_node("Shin")
		shin.mesh = MeshForge.tube_y([
			[-0.26, 0.045, 0.05], [-0.1, 0.075, 0.08],
			[0.1, 0.09, 0.09], [0.24, 0.07, 0.07]], 9)
	# A real skull: heavy cranium, hollowed cheeks, tapered jaw.
	var head: MeshInstance3D = $Head
	head.mesh = MeshForge.tube_y([
		[-0.17, 0.1, 0.11], [-0.06, 0.14, 0.155], [0.05, 0.16, 0.17],
		[0.14, 0.145, 0.155], [0.2, 0.06, 0.07]], 12)
	# Shaggy matted crown that hugs the skull instead of a floating helmet.
	var crown: MeshInstance3D = $HairTop
	crown.mesh = MeshForge.tube_y([
		[-0.2, 0.15, 0.17], [-0.05, 0.19, 0.2], [0.08, 0.175, 0.185],
		[0.15, 0.08, 0.1]], 10)
	# Broad working hands (paws, not marbles).
	for pivot in [l_arm, r_arm]:
		var hand: MeshInstance3D = pivot.get_node("Hand")
		hand.mesh = MeshForge.tube_y([
			[-0.1, 0.05, 0.06], [-0.02, 0.078, 0.088],
			[0.05, 0.062, 0.075], [0.1, 0.03, 0.045]], 8)
	# Tuck the deltoids into the torso silhouette.
	for shoulder_name in ["ShoulderL", "ShoulderR"]:
		var s: MeshInstance3D = get_node(shoulder_name)
		s.scale = Vector3(0.85, 0.72, 0.95)
		s.position.x *= 0.9


## The parasite bonds: hair parts to reveal the face, parasite fists grow in.
func reveal_face() -> void:
	hair_front.visible = false
	fist_l.visible = true
	fist_r.visible = true


func _process(delta: float) -> void:
	_t += delta * (2.0 + 8.0 * move_amount)
	var swing := sin(_t) * 0.7 * move_amount
	var idle_sway := sin(_t * 2.0) * 0.04 * (1.0 - move_amount)
	l_leg.rotation.x = swing
	r_leg.rotation.x = -swing
	# Knees flex as each leg swings back — no more stiff peg legs.
	var l_shin := l_leg.get_node("Shin") as Node3D
	var r_shin := r_leg.get_node("Shin") as Node3D
	l_shin.rotation.x = -0.08 + maxf(0.0, -sin(_t)) * 0.85 * move_amount
	r_shin.rotation.x = -0.08 + maxf(0.0, sin(_t)) * 0.85 * move_amount
	# Arms are owned by the attack tween while one is running.
	if _attack_tween == null or not _attack_tween.is_running():
		l_arm.rotation = Vector3(-swing * 0.8 + idle_sway, 0.0, 0.07)
		r_arm.rotation = Vector3(swing * 0.8 + idle_sway, 0.0, -0.07)
		torso.rotation.y = 0.0
		# Elbows trail the swing.
		(l_arm.get_node("Forearm") as Node3D).rotation.x = \
			-0.3 - maxf(0.0, swing) * 0.5
		(r_arm.get_node("Forearm") as Node3D).rotation.x = \
			-0.3 - maxf(0.0, -swing) * 0.5
	# Whole-body weight: gallop bob, forward lean, hip roll.
	position.y = -absf(sin(_t)) * 0.05 * move_amount
	if not _rolling:
		rotation.x = -0.1 * move_amount
	rotation.z = sin(_t) * 0.045 * move_amount
	# Idle breathing bob.
	torso.position.y = _torso_base + sin(_t * 2.0) * 0.02
	# Loincloth flaps sway with the run.
	loin_front.rotation.x = -absf(swing) * 0.5 - move_amount * 0.15
	loin_back.rotation.x = absf(swing) * 0.5 + move_amount * 0.15


## Play a fist attack. 0 = right straight, 1 = left straight, 2 = heavy double hammer.
## Timing matches player.gd's windup — the fist lands right on the strike frame.
func play_attack(index: int) -> void:
	if _attack_tween:
		_attack_tween.kill()
	_attack_tween = create_tween()
	match index:
		0:
			# Right straight punch with a torso twist behind it.
			_attack_tween.set_parallel(true)
			_attack_tween.tween_property(r_arm, "rotation:x", -1.75, 0.09) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			_attack_tween.tween_property(torso, "rotation:y", -0.35, 0.09)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 0.0, 0.28) \
				.set_delay(0.06)
			_attack_tween.parallel().tween_property(torso, "rotation:y", 0.0, 0.28) \
				.set_delay(0.06)
		1:
			# Left straight punch, opposite twist.
			_attack_tween.set_parallel(true)
			_attack_tween.tween_property(l_arm, "rotation:x", -1.75, 0.09) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			_attack_tween.tween_property(torso, "rotation:y", 0.35, 0.09)
			_attack_tween.chain().tween_property(l_arm, "rotation:x", 0.0, 0.28) \
				.set_delay(0.06)
			_attack_tween.parallel().tween_property(torso, "rotation:y", 0.0, 0.28) \
				.set_delay(0.06)
		_:
			# Heavy hammer: BOTH fists rear back high, then crash down together.
			_attack_tween.set_parallel(true)
			_attack_tween.tween_property(r_arm, "rotation:x", -2.7, 0.24) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_attack_tween.tween_property(l_arm, "rotation:x", -2.7, 0.24)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 0.9, 0.1) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			_attack_tween.parallel().tween_property(l_arm, "rotation:x", 0.9, 0.1) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 0.0, 0.35) \
				.set_delay(0.1)
			_attack_tween.parallel().tween_property(l_arm, "rotation:x", 0.0, 0.35) \
				.set_delay(0.1)
