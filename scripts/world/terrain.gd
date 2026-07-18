extends Node3D
## Procedural low-poly terrain, generated at load (deterministic — fixed seed).
##
## Rolling faceted hills, a flattened combat arena in the middle, the meteor
## crater (with raised rim) at CRATER_POS, and a mountain ring past the arena
## walls for a natural horizon. Vertex colors carry scorch darkening + dirt
## blending, consumed by psx_terrain.gdshader.
##
## Other systems query ground height via `height_at(x, z)` — this node adds
## itself to the "terrain" group and must sit ABOVE spawners in the scene tree.

const SIZE := 180.0
const RES := 90                       # quads per side
const CRATER_POS := Vector2(0.0, -18.0)
const CRATER_FLOOR := -1.5
const POND_POS := Vector2(26.0, 26.0)
const POND_FLOOR := -1.7
const WATER_LEVEL := -0.55

var _heights := PackedFloat32Array()  # (RES+1)^2 grid
var _step := SIZE / RES

var _noise := FastNoiseLite.new()
var _patch_noise := FastNoiseLite.new()


func _ready() -> void:
	add_to_group("terrain")
	_noise.seed = 4242
	_noise.frequency = 0.013
	_noise.fractal_octaves = 4
	_patch_noise.seed = 4243
	_patch_noise.frequency = 0.06
	_compute_heights()
	_build_mesh_and_collision()
	_build_water()


## Ground height at any world XZ (bilinear over the height grid).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + SIZE * 0.5) / _step, 0.0, RES - 0.001)
	var fz := clampf((z + SIZE * 0.5) / _step, 0.0, RES - 0.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var h00 := _h(i, j)
	var h10 := _h(i + 1, j)
	var h01 := _h(i, j + 1)
	var h11 := _h(i + 1, j + 1)
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)


func _h(i: int, j: int) -> float:
	return _heights[j * (RES + 1) + i]


func _compute_heights() -> void:
	_heights.resize((RES + 1) * (RES + 1))
	for j in RES + 1:
		for i in RES + 1:
			var x := -SIZE * 0.5 + i * _step
			var z := -SIZE * 0.5 + j * _step
			var h := _noise.get_noise_2d(x, z) * 3.4

			# Gentle in the combat arena, wilder outside.
			var r := Vector2(x, z).length()
			h *= lerpf(0.3, 1.0, smoothstep(30.0, 55.0, r))

			# Mountain ring past the walls — natural-looking bounds.
			if r > 48.0:
				h += (r - 48.0) * 0.45

			# The meteor crater: bowl blended to the noise, plus a raised rim.
			var d := Vector2(x, z).distance_to(CRATER_POS)
			if d < 9.0:
				h = lerpf(CRATER_FLOOR, h, smoothstep(0.0, 9.0, d))
			h += 0.9 * exp(-pow((d - 9.5) / 2.0, 2.0))

			# The pond basin (no rim — a natural waterhole).
			var pd := Vector2(x, z).distance_to(POND_POS)
			if pd < 8.0:
				h = lerpf(POND_FLOOR, h, smoothstep(0.0, 8.0, pd))

			_heights[j * (RES + 1) + i] = h


func _build_mesh_and_collision() -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()

	for j in RES:
		for i in RES:
			var x0 := -SIZE * 0.5 + i * _step
			var z0 := -SIZE * 0.5 + j * _step
			var p00 := Vector3(x0, _h(i, j), z0)
			var p10 := Vector3(x0 + _step, _h(i + 1, j), z0)
			var p01 := Vector3(x0, _h(i, j + 1), z0 + _step)
			var p11 := Vector3(x0 + _step, _h(i + 1, j + 1), z0 + _step)
			# Two triangles with duplicated verts + face normals → faceted low-poly look.
			# Winding is clockwise seen from above (Godot front face) so the ground
			# isn't back-face-culled.
			_tri(verts, normals, colors, uvs, p00, p10, p11)
			_tri(verts, normals, colors, uvs, p00, p11, p01)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/psx_terrain.gdshader")
	mat.set_shader_parameter("grass_tex", load("res://assets/textures/grass.png"))
	mat.set_shader_parameter("dirt_tex", load("res://assets/textures/dirt.png"))

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	# Exact-match collision from the same triangles.
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(verts)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _tri(verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, uvs: PackedVector2Array,
		a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	for p in [a, b, c]:
		verts.append(p)
		normals.append(n)
		colors.append(_vertex_color(p))
		uvs.append(Vector2(p.x, p.z) / 3.5)


## The pond surface — animated scrolling water plane over the basin.
func _build_water() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/psx_water.gdshader")
	mat.set_shader_parameter("albedo_tex", load("res://assets/textures/water.png"))
	var plane := PlaneMesh.new()
	plane.size = Vector2(17.0, 17.0)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(POND_POS.x, WATER_LEVEL, POND_POS.y)
	add_child(mi)


## RGB = scorch/tone shading, A = grass→dirt blend for the terrain shader.
func _vertex_color(p: Vector3) -> Color:
	var d := Vector2(p.x, p.z).distance_to(CRATER_POS)
	var burn := 1.0 - smoothstep(4.0, 12.0, d)         # dark scorched ring
	var dirt := 1.0 - smoothstep(9.0, 13.0, d)          # bare dirt in the crater
	if _patch_noise.get_noise_2d(p.x, p.z) > 0.42:      # scattered dirt patches
		dirt = maxf(dirt, 0.7)
	# Muddy shore ring around the pond.
	var pd := Vector2(p.x, p.z).distance_to(POND_POS)
	dirt = maxf(dirt, 1.0 - smoothstep(6.0, 10.0, pd))
	var tone := 0.85 + 0.3 * (_patch_noise.get_noise_2d(p.x * 3.0, p.z * 3.0) * 0.5 + 0.5)
	var shade := tone * lerpf(1.0, 0.35, burn)
	return Color(shade, shade, shade, dirt)
