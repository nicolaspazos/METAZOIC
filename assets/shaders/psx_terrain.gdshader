shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// psx_lit variant for the terrain: blends grass→dirt by vertex color alpha
// (baked by terrain.gd — dirt in the crater and in scattered patches), and
// multiplies by vertex color RGB for scorch darkening and tonal variation.

uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_nearest, repeat_enable;
uniform float jitter = 160.0;

varying vec2 uv_affine;
varying float clip_w;
varying vec4 vcol;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xyz /= clip.w;
	clip.xy = round(clip.xy * jitter) / jitter;
	clip.xyz *= clip.w;
	POSITION = clip;
	uv_affine = UV * clip.w;
	clip_w = clip.w;
	vcol = COLOR;
}

void fragment() {
	vec2 uv = uv_affine / clip_w;
	vec3 g = texture(grass_tex, uv).rgb;
	vec3 d = texture(dirt_tex, uv).rgb;
	ALBEDO = mix(g, d, vcol.a) * vcol.rgb;
}
