shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// psx_lit variant for alpha-cut foliage (ferns and other crossed-quad plants):
// double-sided, hard alpha scissor (no soft blending — very period-correct).

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float jitter = 160.0;

varying vec2 uv_affine;
varying float clip_w;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xyz /= clip.w;
	clip.xy = round(clip.xy * jitter) / jitter;
	clip.xyz *= clip.w;
	POSITION = clip;
	uv_affine = UV * clip.w;
	clip_w = clip.w;
}

void fragment() {
	vec2 uv = uv_affine / clip_w;
	vec4 tex = texture(albedo_tex, uv);
	ALBEDO = tex.rgb * tint.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
