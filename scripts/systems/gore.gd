extends Node
## "Gore" autoload — all blood and impact juice in one place.
##
## Everything is generated in code (particles, pools, gibs), so there are no FX
## scenes to keep in sync. Call from anywhere:
##   Gore.spray(pos, dir)    — directional blood spray on a hit
##   Gore.burst(pos)         — big omnidirectional fountain on a death
##   Gore.pool(pos)          — persistent blood pool, raycast-snapped to the ground
##   Gore.gibs(pos, n)       — small physical chunks that bounce and settle
##   Gore.spark(pos, dir)    — green parasite sparks (shield blocks, power FX)
##   Gore.streak(pos, dir, color) — a fading motion streak (dashes, sweeps)
##   Gore.hitstop()          — brief global freeze-frame for impact feel

var _blood_mat: StandardMaterial3D
var _gib_mat: StandardMaterial3D
var _pool_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _dust_mat: StandardMaterial3D
var _hitstopped := false


func _ready() -> void:
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.albedo_color = Color(0.62, 0.03, 0.03)
	_blood_mat.roughness = 1.0

	_gib_mat = StandardMaterial3D.new()
	_gib_mat.albedo_color = Color(0.45, 0.05, 0.06)
	_gib_mat.roughness = 1.0

	_pool_mat = StandardMaterial3D.new()
	_pool_mat.albedo_color = Color(0.3, 0.01, 0.02)
	_pool_mat.roughness = 0.4

	# Parasite energy is black-red.
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.albedo_color = Color(0.9, 0.12, 0.08)
	_spark_mat.emission_enabled = true
	_spark_mat.emission = Color(1.0, 0.15, 0.08)
	_spark_mat.emission_energy_multiplier = 2.0

	_dust_mat = StandardMaterial3D.new()
	_dust_mat.albedo_color = Color(0.5, 0.42, 0.3)
	_dust_mat.roughness = 1.0


## Directional spray — use when something takes a hit. `dir` points away from the attacker.
func spray(pos: Vector3, dir: Vector3, amount: int = 18) -> void:
	_emit_particles(pos, dir, amount, 35.0, 4.0, 9.0, 0.6, _blood_mat)


## Big omnidirectional fountain — use on deaths.
func burst(pos: Vector3, amount: int = 48) -> void:
	_emit_particles(pos, Vector3.UP, amount, 180.0, 3.0, 8.0, 0.9, _blood_mat)


## Green parasite sparks — shield blocks and power impacts.
func spark(pos: Vector3, dir: Vector3 = Vector3.UP, amount: int = 14) -> void:
	_emit_particles(pos, dir, amount, 60.0, 3.0, 7.0, 0.4, _spark_mat)


## Dust puff — landings, dodges, charges. Drifts up instead of falling.
func puff(pos: Vector3, amount: int = 10) -> void:
	_emit_particles(pos, Vector3.UP, amount, 180.0, 0.8, 2.4, 0.55, _dust_mat,
		Vector3(0, 1.0, 0), 0.16)


## A dark pool that grows on the ground and lingers, then fades.
## Raycasts down to sit on the terrain wherever the kill happened.
func pool(pos: Vector3) -> void:
	var ground_y := pos.y
	var scene := get_tree().current_scene
	if scene is Node3D:
		var space := (scene as Node3D).get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			pos + Vector3.UP * 1.5, pos + Vector3.DOWN * 8.0, 1)
		var hit := space.intersect_ray(query)
		if hit:
			ground_y = hit.position.y
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 0.04
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.material = _pool_mat
	disc.mesh = cyl
	_attach(disc, Vector3(pos.x, ground_y + 0.05, pos.z))
	if not disc.is_inside_tree():
		return
	disc.scale = Vector3(0.1, 1.0, 0.1)
	var t := disc.create_tween()
	t.tween_property(disc, "scale", Vector3(1.1, 1.0, 1.1), 1.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(25.0)
	t.tween_property(disc, "transparency", 1.0, 4.0)
	t.tween_callback(disc.queue_free)


## Physical chunks that fly out, bounce on the ground, and despawn later.
func gibs(pos: Vector3, count: int = 5) -> void:
	for i in count:
		var gib := RigidBody3D.new()
		gib.collision_layer = 0
		gib.collision_mask = 1  # world only — gibs never block gameplay

		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.07
		col.shape = sphere
		gib.add_child(col)

		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.15, 0.1, 0.12)
		box.material = _gib_mat
		mi.mesh = box
		gib.add_child(mi)

		_attach(gib, pos + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)))
		if not gib.is_inside_tree():
			return
		gib.linear_velocity = Vector3(
			randf_range(-3.5, 3.5), randf_range(3.0, 7.0), randf_range(-3.5, 3.5))
		gib.angular_velocity = Vector3(
			randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		get_tree().create_timer(8.0 + randf() * 3.0).timeout.connect(gib.queue_free)


## A glowing motion streak that stretches along `dir` and fades — dash/sweep trails.
func streak(pos: Vector3, dir: Vector3, color: Color, length := 1.6) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	mi.mesh = box
	_attach(mi, pos)
	if not mi.is_inside_tree():
		return
	if dir.length() > 0.01 and absf(dir.normalized().dot(Vector3.UP)) < 0.99:
		mi.look_at(pos + dir, Vector3.UP)
	var t := mi.create_tween()
	t.tween_property(mi, "transparency", 1.0, 0.3)
	t.tween_callback(mi.queue_free)


## Brief global slow-motion freeze for impact feel. Safe to call every hit.
func hitstop(time_scale: float = 0.05, duration: float = 0.07) -> void:
	if _hitstopped:
		return
	_hitstopped = true
	Engine.time_scale = time_scale
	# The timer must ignore time_scale, or it would take forever to fire.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstopped = false


func _emit_particles(pos: Vector3, dir: Vector3, amount: int, spread: float,
		vel_min: float, vel_max: float, lifetime: float,
		mat: StandardMaterial3D, gravity := Vector3(0, -30, 0),
		size := 0.09) -> void:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime

	var m := ParticleProcessMaterial.new()
	m.direction = dir
	m.spread = spread
	m.initial_velocity_min = vel_min
	m.initial_velocity_max = vel_max
	m.gravity = gravity
	m.scale_min = 0.6
	m.scale_max = 1.4
	p.process_material = m

	var mesh := BoxMesh.new()
	mesh.size = Vector3(size, size, size)
	mesh.material = mat
	p.draw_pass_1 = mesh

	_attach(p, pos)
	if not p.is_inside_tree():
		return
	p.emitting = true
	p.finished.connect(p.queue_free)


func _attach(node: Node3D, pos: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		node.queue_free()
		return
	scene.add_child(node)
	node.global_position = pos
