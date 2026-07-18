extends CanvasLayer
## In-game HUD: health bar, kill counter, damage flash, crosshair, the power
## bar (5 slots with cooldown overlays), the power-absorbed banner, and the
## boss health bar. Static bars live in main.tscn; everything else is built
## here in code to keep the scene file small.

const POWER_ORDER := [
	PowerSystem.Power.SHIELD,
	PowerSystem.Power.CLAWS,
	PowerSystem.Power.JAWS,
	PowerSystem.Power.CHARGE,
	PowerSystem.Power.TAIL_SWEEP,
]
const POWER_KEYS := {
	PowerSystem.Power.SHIELD: "Q",
	PowerSystem.Power.CLAWS: "E",
	PowerSystem.Power.JAWS: "F",
	PowerSystem.Power.CHARGE: "SHF",
	PowerSystem.Power.TAIL_SWEEP: "R",
}
const POWER_COLORS := {
	PowerSystem.Power.SHIELD: Color(0.3, 0.9, 0.45),
	PowerSystem.Power.CLAWS: Color(1.0, 0.55, 0.15),
	PowerSystem.Power.JAWS: Color(0.9, 0.15, 0.1),
	PowerSystem.Power.CHARGE: Color(0.95, 0.8, 0.2),
	PowerSystem.Power.TAIL_SWEEP: Color(0.35, 0.6, 1.0),
}

@onready var health_fill: ColorRect = $HealthFill
@onready var kills_label: Label = $KillsLabel
@onready var damage_flash: ColorRect = $DamageFlash

var _full_width := 0.0
var _player: Node = null
var _slots := {}          # Power -> {icon: ColorRect, cool: ColorRect}
var _banner: Label
var _boss_name: Label
var _boss_back: ColorRect
var _boss_fill: ColorRect
var _boss: Node = null
var _boss_fill_width := 0.0
var _low_pulse: ColorRect
var _beat_timer := 0.0
var _pulse_t := 0.0


func _ready() -> void:
	add_to_group("hud")
	_full_width = health_fill.size.x
	_build_crosshair()
	_build_power_bar()
	_build_banner()
	_build_boss_bar()
	_build_low_pulse()
	PowerSystem.power_absorbed.connect(_on_power_absorbed)

	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("HUD: no player found in the scene")
		return
	_player.health_changed.connect(_on_health_changed)
	_player.kills_changed.connect(_on_kills_changed)
	_player.damaged.connect(_on_damaged)
	_on_health_changed(_player.health, _player.max_health)


func _process(delta: float) -> void:
	# Low-health warning: pulsing red edges + heartbeat.
	if _player and _player.health < 30.0 and _player.health > 0.0:
		_pulse_t += delta * 5.0
		_low_pulse.color.a = 0.1 + 0.09 * sin(_pulse_t)
		_beat_timer -= delta
		if _beat_timer <= 0.0:
			_beat_timer = 1.05
			Sfx.play("heartbeat", -5.0)
	elif _low_pulse.color.a > 0.0:
		_low_pulse.color.a = 0.0
	# Power slots: dark while locked, colored when owned, wiped by cooldown.
	for power in _slots:
		var slot: Dictionary = _slots[power]
		var owned: bool = PowerSystem.has_power(power)
		var color: Color = POWER_COLORS[power]
		slot.icon.color = color if owned else Color(color.r, color.g, color.b, 0.16)
		var frac := 0.0
		if owned and _player and _player.has_method("cooldown_frac"):
			frac = _player.cooldown_frac(power)
		slot.cool.size.y = 40.0 * frac
	# Boss bar follows the tracked boss until it dies.
	if _boss and is_instance_valid(_boss) and _boss.is_alive():
		_boss_back.visible = true
		_boss_fill.visible = true
		_boss_name.visible = true
		_boss_fill.size.x = _boss_fill_width * clampf(_boss.health / _boss.max_health, 0.0, 1.0)
	else:
		hide_boss()


# ------------------------------------------------------------------ boss bar API

func show_boss(display_name: String, node: Node) -> void:
	_boss = node
	_boss_name.text = display_name


func hide_boss() -> void:
	_boss = null
	if _boss_back:
		_boss_back.visible = false
		_boss_fill.visible = false
		_boss_name.visible = false


# ------------------------------------------------------------------ signal handlers

func _on_health_changed(current: float, max_value: float) -> void:
	health_fill.size.x = _full_width * clampf(current / max_value, 0.0, 1.0)


func _on_kills_changed(count: int) -> void:
	kills_label.text = "SLAIN  %d" % count


func _on_damaged() -> void:
	damage_flash.color = Color(0.8, 0.05, 0.05, 0.45)
	var t := create_tween()
	t.tween_property(damage_flash, "color:a", 0.0, 0.5)


func _on_power_absorbed(power: int) -> void:
	var info: Dictionary = PowerSystem.POWER_INFO.get(power, {})
	_banner.text = "%s  ABSORBED" % str(info.get("name", "POWER")).to_upper()
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
	Sfx.play("absorb", 2.0)
	Gore.hitstop(0.25, 0.7)  # savor the moment
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.15)
	t.tween_interval(2.2)
	t.tween_property(_banner, "modulate:a", 0.0, 0.6)
	t.tween_callback(func(): _banner.visible = false)


# ------------------------------------------------------------------ UI construction

func _build_crosshair() -> void:
	var dot := ColorRect.new()
	dot.anchor_left = 0.5
	dot.anchor_right = 0.5
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = -2
	dot.offset_right = 2
	dot.offset_top = -2
	dot.offset_bottom = 2
	dot.color = Color(1, 1, 1, 0.55)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)


func _build_power_bar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -136
	bar.offset_right = 136
	bar.offset_top = -66
	bar.offset_bottom = -18
	bar.add_theme_constant_override("separation", 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	for power in POWER_ORDER:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(48, 48)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(slot)

		var back := ColorRect.new()
		back.size = Vector2(48, 48)
		back.color = Color(0.05, 0.04, 0.04, 0.8)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(back)

		var icon := ColorRect.new()
		icon.position = Vector2(4, 4)
		icon.size = Vector2(40, 40)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var cool := ColorRect.new()
		cool.position = Vector2(4, 4)
		cool.size = Vector2(40, 0)
		cool.color = Color(0, 0, 0, 0.72)
		cool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cool)

		var key := Label.new()
		key.text = POWER_KEYS[power]
		key.position = Vector2(4, 28)
		key.size = Vector2(40, 18)
		key.add_theme_font_size_override("font_size", 12)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key)

		_slots[power] = {"icon": icon, "cool": cool}


func _build_banner() -> void:
	_banner = Label.new()
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.0
	_banner.anchor_bottom = 0.0
	_banner.offset_top = 120
	_banner.offset_bottom = 180
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func _build_low_pulse() -> void:
	_low_pulse = ColorRect.new()
	_low_pulse.anchor_right = 1.0
	_low_pulse.anchor_bottom = 1.0
	_low_pulse.color = Color(0.6, 0.0, 0.0, 0.0)
	_low_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_low_pulse)
	move_child(_low_pulse, 0)  # under the bars


func _build_boss_bar() -> void:
	_boss_name = Label.new()
	_boss_name.anchor_left = 0.5
	_boss_name.anchor_right = 0.5
	_boss_name.offset_left = -200
	_boss_name.offset_right = 200
	_boss_name.offset_top = 30
	_boss_name.offset_bottom = 56
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 20)
	_boss_name.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_boss_name.visible = false
	_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_name)

	_boss_back = ColorRect.new()
	_boss_back.anchor_left = 0.5
	_boss_back.anchor_right = 0.5
	_boss_back.offset_left = -201
	_boss_back.offset_right = 201
	_boss_back.offset_top = 58
	_boss_back.offset_bottom = 74
	_boss_back.color = Color(0.05, 0.04, 0.04, 0.85)
	_boss_back.visible = false
	_boss_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_back)

	_boss_fill = ColorRect.new()
	_boss_fill.anchor_left = 0.5
	_boss_fill.anchor_right = 0.5
	_boss_fill.offset_left = -198
	_boss_fill.offset_right = 198
	_boss_fill.offset_top = 61
	_boss_fill.offset_bottom = 71
	_boss_fill.color = Color(0.85, 0.2, 0.12)
	_boss_fill.visible = false
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_fill)
	_boss_fill_width = 396.0