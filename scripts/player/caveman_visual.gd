class_name CavemanVisual
extends Node3D
## Procedural animation for the caveman's body — no baked animation data,
## everything is code so it stays easy to tune and extend.
##
## The player script drives `move_amount` (0 = idle, 1 = full run) and calls
## `play_attack()` for club swings. Front of the model is local +Z.

@onready var l_arm: Node3D = $LeftArmPivot
@onready var r_arm: Node3D = $RightArmPivot
@onready var l_leg: Node3D = $LeftLegPivot
@onready var r_leg: Node3D = $RightLegPivot
@onready var torso: Node3D = $Torso
@onready var loin_front: Node3D = $LoinFront
@onready var loin_back: Node3D = $LoinBack

## How fast the player is moving, 0..1. Set every frame by player.gd.
var move_amount := 0.0

var _t := 0.0
var _attack_tween: Tween
var _torso_base := 0.0


func _ready() -> void:
	_torso_base = torso.position.y


func _process(delta: float) -> void:
	_t += delta * (2.0 + 8.0 * move_amount)
	var swing := sin(_t) * 0.7 * move_amount
	var idle_sway := sin(_t * 2.0) * 0.04 * (1.0 - move_amount)
	l_leg.rotation.x = swing
	r_leg.rotation.x = -swing
	l_arm.rotation.x = -swing * 0.8 + idle_sway
	l_arm.rotation.z = 0.07
	# The club arm is owned by the attack tween while one is running.
	if _attack_tween == null or not _attack_tween.is_running():
		r_arm.rotation = Vector3(swing * 0.8 + idle_sway, 0.0, -0.07)
		torso.rotation.y = 0.0
	# Idle breathing bob.
	torso.position.y = _torso_base + sin(_t * 2.0) * 0.02
	# Loincloth flaps sway with the run.
	loin_front.rotation.x = -absf(swing) * 0.5 - move_amount * 0.15
	loin_back.rotation.x = absf(swing) * 0.5 + move_amount * 0.15


## Play a club swing. 0 = overhead smash, 1 = horizontal swipe, 2 = heavy two-hand slam.
## Timing matches player.gd's windup — the club lands right on the strike frame.
func play_attack(index: int) -> void:
	if _attack_tween:
		_attack_tween.kill()
	_attack_tween = create_tween()
	match index:
		0:
			# Overhead smash with a torso twist behind it.
			_attack_tween.set_parallel(true)
			_attack_tween.tween_property(r_arm, "rotation:x", -2.4, 0.12) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_attack_tween.tween_property(torso, "rotation:y", -0.25, 0.12)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 1.15, 0.09) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			_attack_tween.parallel().tween_property(torso, "rotation:y", 0.2, 0.09)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 0.0, 0.3) \
				.set_delay(0.08)
			_attack_tween.parallel().tween_property(torso, "rotation:y", 0.0, 0.3) \
				.set_delay(0.08)
		1:
			# Side swipe: raise the club forward-and-out, whip it across the body.
			_attack_tween.set_parallel(true)
			_attack_tween.tween_property(r_arm, "rotation:x", -1.5, 0.12)
			_attack_tween.tween_property(r_arm, "rotation:y", 0.9, 0.12)
			_attack_tween.tween_property(torso, "rotation:y", 0.3, 0.12)
			_attack_tween.chain().tween_property(r_arm, "rotation:y", -1.2, 0.09) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			_attack_tween.parallel().tween_property(torso, "rotation:y", -0.3, 0.09)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 0.0, 0.3)
			_attack_tween.parallel().tween_property(r_arm, "rotation:y", 0.0, 0.3)
			_attack_tween.parallel().tween_property(torso, "rotation:y", 0.0, 0.3)
		_:
			# Heavy slam: BOTH arms rear back high, then crash down together.
			_attack_tween.set_parallel(true)
			_attack_tween.tween_property(r_arm, "rotation:x", -2.7, 0.24) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_attack_tween.tween_property(l_arm, "rotation:x", -2.5, 0.24)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 1.3, 0.1) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			_attack_tween.parallel().tween_property(l_arm, "rotation:x", 1.1, 0.1) \
				.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
			_attack_tween.chain().tween_property(r_arm, "rotation:x", 0.0, 0.35) \
				.set_delay(0.1)
			_attack_tween.parallel().tween_property(l_arm, "rotation:x", 0.0, 0.35) \
				.set_delay(0.1)
