extends Node3D
## Builds the visible sky elements in code: a glowing sun billboard low on the
## horizon (matching the DirectionalLight's direction) and a ring of soft
## billboard clouds that drift slowly. Pure PS2 sky theatre.

const CLOUD_COUNT := 9
const DRIFT_SPEED := 1.1

var _clouds: Array = []


func _ready() -> void:
	_build_sun()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var tex: Texture2D = load("res://assets/textures/cloud.png")
	for i in CLOUD_COUNT:
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(rng.randf_range(30.0, 52.0), rng.randf_range(9.0, 16.0))
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.albedo_color = Color(0.45, 0.3, 0.32, 0.8)  # bruised storm clouds
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = mat
		mi.mesh = quad
		mi.extra_cull_margin = 60.0
		var ang := rng.randf() * TAU
		var r := rng.randf_range(85.0, 135.0)
		mi.position = Vector3(cos(ang) * r, rng.randf_range(38.0, 68.0), sin(ang) * r)
		add_child(mi)
		_clouds.append(mi)


func _process(delta: float) -> void:
	for c in _clouds:
		c.position.x += DRIFT_SPEED * delta
		if c.position.x > 150.0:
			c.position.x = -150.0


func _build_sun() -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(34.0, 34.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/sun.png")
	mat.albedo_color = Color(0.85, 0.3, 0.18, 1.0)  # a dying red sun
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	mi.mesh = quad
	mi.extra_cull_margin = 40.0
	# Roughly opposite the Sun light's beam, but dropped near the horizon where a
	# dusk sun belongs (and where the player actually sees it).
	mi.position = Vector3(0.53, 0.2, 0.63).normalized() * 140.0
	add_child(mi)
