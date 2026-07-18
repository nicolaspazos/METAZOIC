extends CanvasLayer
## In-game HUD: health bar, blood counter, damage flash, crosshair, power bar,
## banners, boss bar — plus the WEAPON WHEEL (hold Tab: pick which mutation the
## E key triggers) and the CHARACTER MENU (C: kill records + blood upgrades).
## Static bars live in main.tscn; everything else is built here in code.

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
	PowerSystem.Power.SHIELD: Color(0.3, 0.7, 0.4),
	PowerSystem.Power.CLAWS: Color(0.85, 0.45, 0.15),
	PowerSystem.Power.JAWS: Color(0.8, 0.12, 0.08),
	PowerSystem.Power.CHARGE: Color(0.8, 0.68, 0.2),
	PowerSystem.Power.TAIL_SWEEP: Color(0.3, 0.5, 0.85),
}
## Wheel sectors (up/right/down/left) — the mutations E can trigger.
const WHEEL_ORDER := [
	PowerSystem.Power.CLAWS,
	PowerSystem.Power.JAWS,
	PowerSystem.Power.CHARGE,
	PowerSystem.Power.TAIL_SWEEP,
]
const UPGRADES := [
	["vitality", "VITALITY  (+20 max health)"],
	["fists", "PARASITE FISTS  (+4 damage)"],
	["claws", "DUONYCHUS CLAWS  (+dmg, -cooldown)"],
	["jaws", "TYRANT JAWS  (+dmg, -cooldown)"],
	["charge", "PACHY CHARGE  (+dmg, -cooldown)"],
	["tail", "ANKYLO TAIL  (+dmg, -cooldown)"],
]

@onready var health_fill: ColorRect = $HealthFill
@onready var damage_flash: ColorRect = $DamageFlash

var _full_width := 0.0
var _player: Node = null
var _slots := {}
var _banner: Label
var _boss_name: Label
var _boss_back: ColorRect
var _boss_fill: ColorRect
var _boss: Node = null
var _boss_fill_width := 0.0
var _low_pulse: ColorRect
var _beat_timer := 0.0
var _pulse_t := 0.0
var _objective: Label
var _blood_label: Label
var _wheel: Control
var _wheel_labels := {}
var _menu: Panel
var _menu_open := false
var _stamina_back: ColorRect
var _stamina_fill: ColorRect
var _stamina_width := 0.0


func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS  # menu must run while the tree is paused
	_full_width = health_fill.size.x
	_build_crosshair()
	_build_stamina_bar()
	_build_power_bar()
	_build_banner()
	_build_boss_bar()
	_build_low_pulse()
	_build_objective()
	_build_blood_label()
	_build_wheel()
	_build_menu()
	PowerSystem.power_absorbed.connect(_on_power_absorbed)

	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("HUD: no player found in the scene")
		return
	_player.health_changed.connect(_on_health_changed)
	_player.stamina_changed.connect(_on_stamina_changed)
	_player.exhausted.connect(_on_exhausted)
	_player.damaged.connect(_on_damaged)
	if _player.has_signal("parasite_bonded"):
		_player.parasite_bonded.connect(_on_parasite_bonded)
		if not _player.infected:
			_objective.text = "REACH  THE  FALLEN  METEOR"
	_on_health_changed(_player.health, _player.max_health)
	_on_stamina_changed(_player.stamina, _player.max_stamina)
	_stamina_back.visible = _player.infected
	_stamina_fill.visible = _player.infected


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_TAB:
			if event.pressed:
				_open_wheel()
			else:
				_close_wheel()
		elif event.keycode == KEY_C and event.pressed:
			_toggle_menu()
		elif event.keycode == KEY_ESCAPE and event.pressed and _menu_open:
			_toggle_menu()


func _process(delta: float) -> void:
	_blood_label.text = "BLOOD  %d" % Stats.blood
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
		# Highlight the mutation currently bound to E.
		var equipped: bool = _player != null and power == _player.equipped_mutation
		slot.back.color = Color(0.35, 0.1, 0.08, 0.9) if equipped else Color(0.05, 0.04, 0.04, 0.8)
	# Boss bar follows the tracked boss until it dies.
	if _boss and is_instance_valid(_boss) and _boss.is_alive():
		_boss_back.visible = true
		_boss_fill.visible = true
		_boss_name.visible = true
		_boss_fill.size.x = _boss_fill_width * clampf(_boss.health / _boss.max_health, 0.0, 1.0)
	else:
		hide_boss()


# ------------------------------------------------------------------ weapon wheel

func _open_wheel() -> void:
	if _menu_open or _player == null:
		return
	_wheel.visible = true
	Engine.time_scale = 0.15
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.warp_mouse(get_viewport().get_visible_rect().size / 2.0)


func _close_wheel() -> void:
	if not _wheel.visible:
		return
	_wheel.visible = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var center := get_viewport().get_visible_rect().size / 2.0
	var v := get_viewport().get_mouse_position() - center
	if v.length() < 40.0 or _player == null:
		return  # released in the dead zone — no change
	# Sectors: up / right / down / left.
	var ang := atan2(v.y, v.x)  # -PI..PI, 0 = right, -PI/2 = up
	var idx := wrapi(int(roundf((ang + PI / 2.0) / (PI / 2.0))), 0, 4)
	_player.equipped_mutation = WHEEL_ORDER[idx]
	Sfx.play("block", -8.0, 1.4)


func _build_wheel() -> void:
	_wheel = Control.new()
	_wheel.anchor_right = 1.0
	_wheel.anchor_bottom = 1.0
	_wheel.visible = false
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wheel)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.02, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(dim)

	var title := Label.new()
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.5
	title.anchor_bottom = 0.5
	title.offset_left = -160
	title.offset_right = 160
	title.offset_top = -14
	title.offset_bottom = 14
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "CHOOSE  MUTATION"
	title.add_theme_font_size_override("font_size", 16)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(title)

	var offsets := [Vector2(0, -170), Vector2(200, 0), Vector2(0, 170), Vector2(-200, 0)]
	for i in WHEEL_ORDER.size():
		var power: int = WHEEL_ORDER[i]
		var box := ColorRect.new()
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.anchor_top = 0.5
		box.anchor_bottom = 0.5
		box.offset_left = offsets[i].x - 85
		box.offset_right = offsets[i].x + 85
		box.offset_top = offsets[i].y - 34
		box.offset_bottom = offsets[i].y + 34
		var c: Color = POWER_COLORS[power]
		box.color = Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, 0.92)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wheel.add_child(box)
		var lbl := Label.new()
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var info: Dictionary = PowerSystem.POWER_INFO.get(power, {})
		lbl.text = str(info.get("name", "?")).to_upper()
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", c.lightened(0.4))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lbl)
		_wheel_labels[power] = box


# ------------------------------------------------------------------ character menu

func _toggle_menu() -> void:
	if _wheel.visible:
		return
	_menu_open = not _menu_open
	_menu.visible = _menu_open
	get_tree().paused = _menu_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _menu_open else Input.MOUSE_MODE_CAPTURED
	if _menu_open:
		_refresh_menu()


func _build_menu() -> void:
	_menu = Panel.new()
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 0.5
	_menu.anchor_bottom = 0.5
	_menu.offset_left = -260
	_menu.offset_right = 260
	_menu.offset_top = -250
	_menu.offset_bottom = 250
	_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.03, 0.96)
	style.border_color = Color(0.45, 0.1, 0.08)
	style.set_border_width_all(2)
	_menu.add_theme_stylebox_override("panel", style)
	add_child(_menu)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 24
	vbox.offset_right = -24
	vbox.offset_top = 16
	vbox.offset_bottom = -16
	vbox.add_theme_constant_override("separation", 6)
	_menu.add_child(vbox)


func _refresh_menu() -> void:
	var vbox: VBoxContainer = _menu.get_node("VBox")
	for child in vbox.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "THE  PARASITE  REMEMBERS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
	vbox.add_child(title)

	var blood := Label.new()
	blood.text = "Blood harvested:  %d" % Stats.blood
	blood.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(blood)

	var slain_head := Label.new()
	slain_head.text = "— SLAIN —"
	slain_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slain_head.add_theme_color_override("font_color", Color(0.6, 0.5, 0.45))
	vbox.add_child(slain_head)
	if Stats.kills.is_empty():
		var none := Label.new()
		none.text = "Nothing yet. The valley waits."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_font_size_override("font_size", 14)
		vbox.add_child(none)
	for species in Stats.kills:
		var line := Label.new()
		line.text = "%s  ×%d" % [species, Stats.kills[species]]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", 15)
		vbox.add_child(line)

	var up_head := Label.new()
	up_head.text = "— OFFER BLOOD —"
	up_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_head.add_theme_color_override("font_color", Color(0.6, 0.5, 0.45))
	vbox.add_child(up_head)
	for upgrade in UPGRADES:
		var key: String = upgrade[0]
		var btn := Button.new()
		btn.text = "%s   Lv %d   —   %d blood" % [upgrade[1], Stats.levels[key], Stats.cost(key)]
		btn.disabled = Stats.blood < Stats.cost(key)
		btn.pressed.connect(func():
			if Stats.buy(key):
				get_tree().call_group("player", "refresh_stats")
				Sfx.play("absorb", -4.0, 1.3)
				_refresh_menu())
		vbox.add_child(btn)

	var hint := Label.new()
	hint.text = "C or Esc to return to the hunt"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.42, 0.4))
	vbox.add_child(hint)


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


func _on_stamina_changed(current: float, max_value: float) -> void:
	_stamina_fill.size.x = _stamina_width * clampf(current / max_value, 0.0, 1.0)


func _on_exhausted() -> void:
	_stamina_fill.color = Color(0.85, 0.12, 0.08, 1.0)
	var t := create_tween()
	t.tween_property(_stamina_fill, "color", Color(0.34, 0.43, 0.38, 0.95), 0.35)


func _on_damaged() -> void:
	damage_flash.color = Color(0.8, 0.05, 0.05, 0.45)
	var t := create_tween()
	t.tween_property(damage_flash, "color:a", 0.0, 0.5)


func _on_power_absorbed(power: int) -> void:
	var info: Dictionary = PowerSystem.POWER_INFO.get(power, {})
	Sfx.play("absorb", 2.0)
	Gore.hitstop(0.25, 0.7)  # savor the moment
	_show_banner("%s  ABSORBED" % str(info.get("name", "POWER")).to_upper())


func _on_parasite_bonded() -> void:
	_objective.text = ""
	_stamina_back.visible = true
	_stamina_fill.visible = true
	_show_banner("THE  PARASITE  BONDS  WITH  YOU")


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.modulate = Color(1, 1, 1, 0)
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


func _build_stamina_bar() -> void:
	_stamina_width = 220.0
	_stamina_back = ColorRect.new()
	_stamina_back.position = Vector2(20, 44)
	_stamina_back.size = Vector2(_stamina_width + 4.0, 10.0)
	_stamina_back.color = Color(0.015, 0.012, 0.02, 0.9)
	_stamina_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_back)
	_stamina_fill = ColorRect.new()
	_stamina_fill.position = Vector2(22, 46)
	_stamina_fill.size = Vector2(_stamina_width, 6.0)
	_stamina_fill.color = Color(0.34, 0.43, 0.38, 0.95)
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_fill)


func _build_blood_label() -> void:
	_blood_label = Label.new()
	_blood_label.offset_left = 20
	_blood_label.offset_top = 60
	_blood_label.offset_right = 280
	_blood_label.offset_bottom = 86
	_blood_label.text = "BLOOD  0"
	_blood_label.add_theme_font_size_override("font_size", 16)
	_blood_label.add_theme_color_override("font_color", Color(0.8, 0.15, 0.1))
	_blood_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blood_label)


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

		_slots[power] = {"icon": icon, "cool": cool, "back": back}


func _build_banner() -> void:
	_banner = Label.new()
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 120
	_banner.offset_bottom = 180
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18))
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func _build_objective() -> void:
	_objective = Label.new()
	_objective.anchor_left = 0.0
	_objective.anchor_right = 1.0
	_objective.offset_top = 70
	_objective.offset_bottom = 100
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.add_theme_font_size_override("font_size", 18)
	_objective.add_theme_color_override("font_color", Color(0.85, 0.72, 0.6, 0.85))
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective)


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
	_boss_name.offset_left = -220
	_boss_name.offset_right = 220
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
