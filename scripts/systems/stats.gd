extends Node
## "Stats" autoload — blood currency, kill records, and upgrade levels.
##
## Blood is harvested from kills and spent in the character menu (C) to level
## the caveman and his mutations. Kills are recorded per species and shown in
## the same menu (no HUD kill counter).

var blood := 0
var kills := {}  # species name -> count

## Upgrade levels. vitality = +20 max HP each; fists = +4 punch damage each;
## mutation keys = +25% damage and -8% cooldown per level.
var levels := {
	"vitality": 0,
	"fists": 0,
	"claws": 0,
	"jaws": 0,
	"charge": 0,
	"tail": 0,
}

const BASE_COSTS := {
	"vitality": 50,
	"fists": 60,
	"claws": 80,
	"jaws": 80,
	"charge": 80,
	"tail": 80,
}

const POWER_KEYS := {
	PowerSystem.Power.CLAWS: "claws",
	PowerSystem.Power.JAWS: "jaws",
	PowerSystem.Power.CHARGE: "charge",
	PowerSystem.Power.TAIL_SWEEP: "tail",
}


func add_kill(species: String, reward: int) -> void:
	kills[species] = int(kills.get(species, 0)) + 1
	blood += reward


func cost(key: String) -> int:
	return int(BASE_COSTS.get(key, 80) * pow(1.6, levels.get(key, 0)))


func buy(key: String) -> bool:
	var c := cost(key)
	if blood < c or not levels.has(key):
		return false
	blood -= c
	levels[key] += 1
	return true


## Damage multiplier for a mutation power.
func power_damage_mult(power: int) -> float:
	return 1.0 + 0.25 * levels.get(POWER_KEYS.get(power, ""), 0)


## Cooldown multiplier for a mutation power (lower = faster).
func power_cooldown_mult(power: int) -> float:
	return pow(0.92, levels.get(POWER_KEYS.get(power, ""), 0))
