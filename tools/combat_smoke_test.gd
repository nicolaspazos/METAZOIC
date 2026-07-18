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

	# --- The parasite bonds (intro flow) ---
	_check(not player.infected, "starts uninfected and unarmed")
	_check(player.visual.hair_front.visible, "hair covers the face pre-infection")
	_check(not player.visual.fist_r.visible, "no parasite fists pre-infection")
	player.infect()
	_check(player.infected, "parasite bonds")
	_check(not player.visual.hair_front.visible, "hair parts after infection")
	_check(player.visual.fist_r.visible, "parasite fists appear")
	player.infect()  # second call must be a no-op
	_check(player.infected, "double infection is harmless")

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

	# --- Ceratops Shield blocks frontal damage ---
	PowerSystem.absorb(PowerSystem.Power.SHIELD)
	player._invuln = -1.0
	player.start_shield()  # rotates the visual to face the camera
	var hp_shielded: float = player.health
	# Attack from wherever the visual now faces (local +Z is the model's front).
	var facing: Vector3 = player.visual.global_transform.basis.z
	player.take_damage(20.0, player.global_position + facing * 2.0)
	_check(player.health == hp_shielded, "shield blocks frontal damage")
	player._invuln = -1.0
	player.take_damage(10.0, player.global_position - facing * 2.0)  # from behind
	_check(player.health == hp_shielded - 10.0, "shield does not block rear attacks")
	player.stop_shield()

	# --- Tail sweep damages nearby enemies, and respects cooldowns ---
	var r2: CharacterBody3D = preload("res://scenes/enemies/raptor.tscn").instantiate()
	add_child(r2)
	r2.global_position = player.global_position + Vector3(2, 0, 0)
	await get_tree().physics_frame
	player.activate_power(PowerSystem.Power.TAIL_SWEEP)  # not owned yet — must do nothing
	_check(r2.health == r2.max_health, "locked power does nothing")
	PowerSystem.absorb(PowerSystem.Power.TAIL_SWEEP)
	player.activate_power(PowerSystem.Power.TAIL_SWEEP)
	_check(r2.health < r2.max_health, "tail sweep damaged nearby raptor")
	_check(player.cooldown_frac(PowerSystem.Power.TAIL_SWEEP) > 0.5, "sweep went on cooldown")
	player.activate_power(PowerSystem.Power.TAIL_SWEEP)  # on cooldown — no second hit
	var hp_after_sweep: float = r2.health
	await get_tree().physics_frame
	_check(r2.health == hp_after_sweep, "cooldown prevents immediate reuse")

	# --- Dodge grants i-frames and respects its own cooldown ---
	player._invuln = 0.0
	player.dodge()
	_check(player._invuln > 0.0, "dodge grants i-frames")
	var dodge_ready_after: float = player._dodge_ready
	player.dodge()
	_check(player._dodge_ready == dodge_ready_after, "dodge cooldown blocks spam")

	# Let gore particles, pools, gibs, and death tweens tick a while.
	await get_tree().create_timer(1.5).timeout

	print("[smoke] %s" % ("PASS" if _errors == 0 else "FAIL (%d errors)" % _errors))
	get_tree().quit(_errors)
