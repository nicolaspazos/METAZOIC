extends CharacterBody3D
## Base class for the boss dinosaurs that carry a parasite-granted power.
##
## Attach this to any boss scene and pick its `power` in the inspector. When the boss
## is defeated, it transfers that power to the player through the PowerSystem singleton.
## Specific bosses (T-Rex, Triceratops, ...) can extend this script to add their own
## attacks and AI while reusing the health/death/absorb flow.

## Which power this boss grants when defeated.
@export var power: PowerSystem.Power = PowerSystem.Power.SHIELD
@export var max_health: float = 100.0

var health: float


func _ready() -> void:
	health = max_health


## Apply damage. Call this from the player's attacks.
## `hit_dir` points from the attacker toward this boss (for knockback/blood in subclasses).
func take_damage(amount: float, hit_dir: Vector3 = Vector3.ZERO) -> void:
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		die()


## Defeat the boss: hand its power to the player, then remove it from the world.
## Override to play death animations / VFX before calling super().
func die() -> void:
	PowerSystem.absorb(power)
	queue_free()
