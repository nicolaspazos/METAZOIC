shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
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

instance uniform vec4 tint_i : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform vec4 flash : source_color = vec4(1.0, 0.25, 0.15, 0.0);

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
	vec3 col = texture(albedo_tex, uv).rgb * tint.rgb * tint_i.rgb;
	ALBEDO = mix(col, flash.rgb, flash.a);
}
