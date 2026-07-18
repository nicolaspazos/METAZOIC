extends Node
## Focused headless checks for the player controller's deterministic contracts.

var _errors := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok: %s" % what)
	else:
		_errors += 1
		push_error("FAIL: %s" % what)


func _ready() -> void:
	print("[core] gameplay test starting")
	var player: CharacterBody3D = preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().physics_frame
	_check(player.health == player.max_health, "player starts at full health")
	_check(not player.infected, "player starts uninfected")

	# Deterministic movement rules stay testable without synthesizing keyboard input.
	var movement_path := "res://scripts/player/movement_math.gd"
	_check(ResourceLoader.exists(movement_path), "movement math helper exists")
	if ResourceLoader.exists(movement_path):
		var movement_math: Script = load(movement_path)
		var diagonal: Vector3 = movement_math.camera_relative(
			Vector2(1.0, -1.0), Basis.IDENTITY)
		_check(is_equal_approx(diagonal.length(), 1.0), "diagonal input is normalized")
		_check(diagonal.is_equal_approx(Vector3(0.707107, 0.0, -0.707107)),
			"camera-relative input uses the expected axes")
		var accelerated: Vector3 = movement_math.horizontal_velocity(
			Vector3(0.0, 3.0, 0.0), Vector3(6.0, 0.0, 0.0), 10.0, 0.1)
		_check(accelerated.is_equal_approx(Vector3(1.0, 3.0, 0.0)),
			"horizontal acceleration preserves vertical velocity")
		_check(movement_math.regenerate_resource(95.0, 100.0, 20.0, 1.0) == 100.0,
			"resource regeneration clamps to maximum")
		var mantle_mid: Vector3 = movement_math.mantle_position(
			Vector3.ZERO, Vector3(0.0, 1.0, 2.0), 0.5, 0.6)
		_check(mantle_mid.is_equal_approx(Vector3(0.0, 1.1, 1.0)),
			"mantle path follows a raised deterministic arc")

	_check(player.has_method("can_spend_stamina"), "player exposes stamina affordability")
	_check(player.has_method("spend_stamina"), "player exposes stamina spending")
	if player.has_method("can_spend_stamina") and player.has_method("spend_stamina"):
		var initial_stamina: float = player.stamina
		_check(not player.can_spend_stamina(initial_stamina + 1.0),
			"stamina rejects unaffordable actions")
		_check(player.spend_stamina(25.0), "affordable stamina spend succeeds")
		_check(player.stamina == initial_stamina - 25.0, "stamina spend subtracts once")
		_check(not player.spend_stamina(initial_stamina), "failed spend does not overdraw")
		_check(player.stamina == initial_stamina - 25.0, "failed spend preserves stamina")

	_check(player.has_method("is_mantling"), "player exposes mantle state")
	_check(player.has_method("queue_attack"), "player exposes buffered attack input")
	_check(player.has_method("attack_phase_name"), "player exposes attack phase")
	if player.has_method("queue_attack") and player.has_method("attack_phase_name"):
		player.infected = true
		player._attacking = true
		_check(player.queue_attack(), "one follow-up attack can be buffered")
		_check(not player.queue_attack(), "attack buffer accepts only one follow-up")
		_check(player.attack_phase_name() == "recovery", "buffering occurs during recovery")
		player._attacking = false
		player._attack_phase = player.AttackPhase.IDLE
		player._queued_attack = false
		player.stamina = 0.0
		_check(not player.queue_attack(true), "heavy attack rejects insufficient stamina")
		_check(not player._attacking, "rejected heavy attack never enters wind-up")

	_check("SPEED" in PowerSystem.Power, "raptor speed progression power exists")
	var claw_info: Dictionary = PowerSystem.POWER_INFO.get(PowerSystem.Power.CLAWS, {})
	_check(claw_info.get("source", "").contains("Duonychus"),
		"first claw reward names the therizinosaur boss")
	if "SPEED" in PowerSystem.Power:
		var speed_info: Dictionary = PowerSystem.POWER_INFO.get(PowerSystem.Power.SPEED, {})
		_check(speed_info.get("source", "").contains("Raptor"),
			"raptor boss is reserved for enhanced legs and speed")

	_check(Sfx.has_method("category_budget"), "audio service exposes voice budgets")
	if Sfx.has_method("category_budget"):
		_check(Sfx.category_budget("footstep") == 3, "footsteps have a bounded voice budget")
		_check(Sfx.category_budget("combat") >= 6, "combat retains enough impact voices")
	_check(Sfx.has_method("choose_voice_index"), "audio voice selection is testable")
	if Sfx.has_method("choose_voice_index"):
		var capped_index: int = Sfx.choose_voice_index(
			["footstep", "footstep", "footstep", ""],
			[true, true, true, false], "footstep", 3, 3)
		_check(capped_index == 0, "category budget reuses a voice before taking an idle slot")
		var idle_index: int = Sfx.choose_voice_index(
			["combat", "", ""], [true, false, false], "footstep", 3, 2)
		_check(idle_index == 1, "uncapped category prefers an idle voice")
	for required in ["swing", "hit", "step", "music", "wind", "distant_roar"]:
		_check(Sfx._streams.has(required), "required audio loaded: %s" % required)

	PowerSystem.unlocked.erase(PowerSystem.Power.CLAWS)
	var boss: CharacterBody3D = preload("res://scenes/enemies/duonychus.tscn").instantiate()
	add_child(boss)
	await get_tree().physics_frame
	boss.take_damage(boss.max_health * 0.55, Vector3.FORWARD)
	await get_tree().process_frame
	_check(boss._enraged, "Duonychus enrages below half health")
	_check(boss.move_speed > 4.0, "enraged boss becomes more aggressive")
	boss.take_damage(9999.0, Vector3.FORWARD)
	_check(PowerSystem.has_power(PowerSystem.Power.CLAWS), "Duonychus grants claws on defeat")
	_check(not PowerSystem.has_power(PowerSystem.Power.SPEED),
		"Duonychus does not grant the reserved raptor speed power")

	player.queue_free()
	boss.queue_free()
	await get_tree().process_frame
	print("[core] %s" % ("PASS" if _errors == 0 else "FAIL (%d errors)" % _errors))
	get_tree().quit(_errors)
