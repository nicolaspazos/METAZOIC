class_name MeshForge
extends RefCounted
## Generates organic lofted meshes in code — smooth tapered tubes with muscle
## bulges — so characters stop looking like stacks of primitives. Used by
## caveman_visual.gd and raptor.gd at _ready to replace primitive part meshes.


## Loft an elliptical tube along local +Y. `profile` is an array of
## [y, radius_x, radius_z] rings from bottom to top. Ends should taper small.
## UVs wrap around (u) and run along the length (v) so textures flow naturally.
static func tube_y(profile: Array, radial := 10) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ring_count := profile.size()

	for i in ring_count:
		var y: float = profile[i][0]
		var rx: float = profile[i][1]
		var rz: float = profile[i][2] if profile[i].size() > 2 else profile[i][1]
		for j in radial + 1:
			var ang := TAU * float(j) / radial
			verts.append(Vector3(cos(ang) * rx, y, sin(ang) * rz))
			# Cross-section normal (good enough under lambert + soft specular).
			normals.append(Vector3(cos(ang) / maxf(rx, 0.01), 0.0,
				sin(ang) / maxf(rz, 0.01)).normalized())
			uvs.append(Vector2(float(j) / radial, float(i) / (ring_count - 1)))

	var stride := radial + 1
	for i in ring_count - 1:
		for j in radial:
			var a := i * stride + j
			var b := i * stride + j + 1
			var c := (i + 1) * stride + j
			var d := (i + 1) * stride + j + 1
			# Winding: front faces point outward (Godot clockwise convention).
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
