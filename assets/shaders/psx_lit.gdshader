shader_type spatial;
render_mode diffuse_lambert;
// The core PS2-era surface shader used by characters, props, and trees:
//  - vertex snapping  → polygons wobble as things move (the iconic PSX jitter)
//  - affine texture mapping → textures warp on receding faces (no perspective correction)
//  - nearest-filtered low-res textures, simple lambert light, no speculars
// `flash` (instance uniform) lets gameplay tint a mesh red for a hit flash;
// `tint_i` lets a single scene recolor per instance (e.g. the Alpha Raptor).

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float jitter = 160.0;  // vertex snap grid — lower = wobblier

uniform float roughness : hint_range(0.0, 1.0) = 0.78;

instance uniform vec4 tint_i : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 flash : source_color = vec4(1.0, 0.25, 0.15, 0.0);
// 0..1 — how carved-up this creature is. Raises wet dark-red gore mottling.
instance uniform float wound = 0.0;

varying vec2 uv_affine;
varying float clip_w;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xyz /= clip.w;
	clip.xy = round(clip.xy * jitter) / jitter;
	clip.xyz *= clip.w;
	POSITION = clip;
	// Multiplying by w here and dividing by the (perspective-correct) interpolated w
	// in fragment() cancels the GPU's perspective correction → affine warping.
	uv_affine = UV * uv_scale * clip.w;
	clip_w = clip.w;
}

void fragment() {
	vec2 uv = uv_affine / clip_w;
	vec3 tex = texture(albedo_tex, uv).rgb;
	vec3 col = tex * tint.rgb * tint_i.rgb;
	// Wounds: chunky wet-blood mottling keyed off the texture itself.
	float mask = step(0.42, fract(dot(tex, vec3(7.13, 5.71, 3.97))));
	vec3 gore = col * vec3(0.9, 0.16, 0.12) + vec3(0.08, 0.0, 0.0);
	col = mix(col, gore, clamp(wound, 0.0, 1.0) * mask * 0.9);
	ALBEDO = mix(col, flash.rgb, flash.a);
	// Subtle wet-hide speculars; wounds glisten more.
	ROUGHNESS = roughness - wound * 0.25;
	SPECULAR = 0.32;
}
