extends Node
## Headless smoke test for the combat loop. Run with:
##   godot --headless --path . res://tools/combat_smoke_test.tscn
## Exit code 0 = pass. Exercises raptor damage/death (incl. all Gore FX paths),
## player damage/knockback, kill rewards, and the PowerSystem.

var _errors := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok: %s" % what)
	else:
		_errors += 1
		push_error("FAIL: %s" % what)


func _ready() -> void:
	print("[smoke] combat test starting")

	# Player far away so wandering raptors can't interfere with assertions.
	var player: CharacterBody3D = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector3(30, 0, 30)

	var raptor: CharacterBody3D = preload("res://scenes/enemies/raptor.tscn").instantiate()
	add_child(raptor)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# --- Raptor takes hits and dies (3 x 18 > 40 hp) ---
	_check(raptor.is_alive(), "raptor starts alive")
	raptor.take_damage(18.0, Vector3.FORWARD)
	_check(raptor.is_alive(), "raptor survives first hit")
	_check(raptor.health < raptor.max_health, "raptor lost health")
	raptor.take_damage(18.0, Vector3.FORWARD)
	raptor.take_damage(18.0, Vector3.FORWARD)
	_check(not raptor.is_alive(), "raptor dies on third hit")

	# --- Kill reward reached the player via call_group ---
	_check(player.kills == 1, "kill was credited to the player")

	# --- Player damage / knockback ---
	var hp_before: float = player.health
	player.take_damage(10.0, player.global_position + Vector3.FORWARD)
	_check(player.health == hp_before - 10.0, "player took damage")
	player.take_damage(50.0, Vector3.ZERO)
	_check(player.health == hp_before - 10.0, "invulnerability window blocks the second hit")

	# --- PowerSystem ---
	PowerSystem.absorb(PowerSystem.Power.CLAWS)
	_check(PowerSystem.has_power(PowerSystem.Power.CLAWS), "power absorbed")
	_check(not PowerSystem.has_power(PowerSystem.Power.JAWS), "unabsorbed power not owned")

	# Let gore particles, pools, gibs, and death tweens tick a while.
	await get_tree().create_timer(1.5).timeout

	print("[smoke] %s" % ("PASS" if _errors == 0 else "FAIL (%d errors)" % _errors))
	get_tree().quit(_errors)
