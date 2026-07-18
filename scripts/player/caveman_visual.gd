class_name CavemanVisual
extends Node3D
## Procedural animation for the caveman's blocky body — no baked animation data,
## everything is code so it stays easy to tune and extend.
##
## The player script drives `move_amount` (0 = idle, 1 = full run) and calls
## `play_attack()` for club swings. Front of the model is local +Z.

@onready var l_arm: Node3D = $LeftArmPivot
@onready var r_arm: Node3D = $RightArmPivot
@onready var l_leg: Node3D = $LeftLegPivot
@onready var r_leg: Node3D = $RightLegPivot
@onready var torso: Node3D = $Torso

## How fast the player is moving, 0..1. Set every frame by player.gd.
var move_amount := 0.0

var _t := 0.0
var _attack_tween: Tween


func _process(delta: float) -> void:
	_t += delta * (2.0 + 8.0 * move_amount)
	var swing := sin(_t) * 0.7 * move_amount
	l_leg.rotation.x = swing
	r_leg.rotation.x = -swing
	l_arm.rotation.x = -swing * 0.8
	# The club arm is owned by the attack tween while one is running.
	if _attack_tween == null or not _attack_tween.is_running():
		r_arm.rotation = Vector3(swing * 0.8, 0.0, 0.0)
	# Idle breathing bob.
	torso.position.y = 1.2 + sin(_t * 2.0) * 0.02


## Play a club swing. index 0 = overhead smash, 1 = horizontal swipe.
## Timing matches player.gd's windup (0.18s) — the club lands right on the strike frame.
func play_attack(index: int) -> void:
	if _attack_tween:
		_attack_tween.kill()
	_attack_tween = create_tween()
	if index == 0:
		# Overhead smash: rear the club back, slam it down, recover.
		_attack_tween.tween_property(r_arm, "rotation:x", -2.4, 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_attack_tween.tween_property(r_arm, "rotation:x", 1.15, 0.09) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		_attack_tween.tween_property(r_arm, "rotation:x", 0.0, 0.3) \
			.set_delay(0.08)
	else:
		# Side swipe: raise the club forward-and-out, whip it across the body.
		_attack_tween.set_parallel(true)
		_attack_tween.tween_property(r_arm, "rotation:x", -1.5, 0.12)
		_attack_tween.tween_property(r_arm, "rotation:y", 0.9, 0.12)
		_attack_tween.chain().tween_property(r_arm, "rotation:y", -1.2, 0.09) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		_attack_tween.chain().tween_property(r_arm, "rotation:x", 0.0, 0.3)
		_attack_tween.parallel().tween_property(r_arm, "rotation:y", 0.0, 0.3)
