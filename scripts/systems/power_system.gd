extends Node
## Global registry of the powers the caveman has absorbed from boss dinosaurs.
##
## Autoloaded as "PowerSystem" (see the [autoload] section of project.godot), so any
## script can call `PowerSystem.absorb(...)` or `PowerSystem.has_power(...)` directly.
##
## The design: the meteorite parasite grants each boss dinosaur a signature power.
## When the player defeats a boss, that power transfers to the player permanently.

## Emitted whenever a new power is absorbed. UI, VFX, and the player can listen to this.
signal power_absorbed(power: Power)

## Every power the player can gain, tagged with the dinosaur it comes from.
enum Power {
	SHIELD,      ## Triceratops        — a protective barrier / frill shield
	JAWS,        ## Tyrannosaurus      — a devastating bite attack
	CLAWS,       ## Duonychus          — therizinosaur scythe claws / lunge
	CHARGE,      ## Pachycephalosaurus — a headbutt charge
	TAIL_SWEEP,  ## Ankylosaurus       — a heavy tail-club sweep
	SPEED,       ## Alpha Raptor       — enhanced legs and sustained sprint
}

## Human-facing metadata for each power. Extend this as new bosses are designed.
const POWER_INFO := {
	Power.SHIELD:     {"name": "Ceratops Shield", "source": "Triceratops"},
	Power.JAWS:       {"name": "Tyrant Jaws",     "source": "Tyrannosaurus"},
	Power.CLAWS:      {"name": "Duonychus Claws", "source": "Duonychus tsogtbaatari"},
	Power.CHARGE:     {"name": "Pachy Charge",    "source": "Pachycephalosaurus"},
	Power.TAIL_SWEEP: {"name": "Ankylo Tail",     "source": "Ankylosaurus"},
	Power.SPEED:      {"name": "Raptor Legs",     "source": "Alpha Raptor"},
}

## Set of powers the player currently owns. Keys are Power values; values are always true.
var unlocked: Dictionary = {}


## Grant a power to the player. No-op if it's already owned.
func absorb(power: Power) -> void:
	if unlocked.has(power):
		return
	unlocked[power] = true
	var info: Dictionary = POWER_INFO.get(power, {})
	print("[METAZOIC] Absorbed power: %s (from %s)" % [
		info.get("name", "Unknown"),
		info.get("source", "?"),
	])
	power_absorbed.emit(power)


## True if the player has already absorbed the given power.
func has_power(power: Power) -> bool:
	return unlocked.has(power)


## Convenience: the list of powers the player currently owns.
func owned_powers() -> Array:
	return unlocked.keys()
