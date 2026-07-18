shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// PS2-style animated water: two scrolling copies of the caustic texture blended
// together, semi-transparent, with the same vertex jitter as everything else.

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float jitter = 160.0;

varying vec2 uv_affine;
varying float clip_w;

void vertex() {
	// Gentle vertex bob so the surface feels alive.
	VERTEX.y += sin(TIME * 1.2 + VERTEX.x * 0.8 + VERTEX.z * 0.6) * 0.05;
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
	vec3 a = texture(albedo_tex, uv + vec2(TIME * 0.025, TIME * 0.015)).rgb;
	vec3 c = texture(albedo_tex, uv * 1.7 - vec2(TIME * 0.02, -TIME * 0.012)).rgb;
	ALBEDO = mix(a, c, 0.5) * tint.rgb;
	ALPHA = 0.78;
}
