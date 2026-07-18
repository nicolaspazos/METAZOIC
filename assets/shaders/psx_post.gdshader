shader_type canvas_item;
// PS2-era post filter: color quantization + ordered (Bayer) dithering.
// The 3D scene is also rendered at reduced resolution (see project.godot,
// rendering/scaling_3d/scale) — this shader then crunches the colors on top,
// giving the banded, dithered look of a 2001 console pushed through composite video.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels : hint_range(2.0, 64.0) = 28.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.72;

const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
);

uniform float scanline_strength : hint_range(0.0, 0.3) = 0.055;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.58;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 px = ivec2(FRAGCOORD.xy);
	float threshold = BAYER[px.x % 4][px.y % 4] / 16.0 - 0.5;
	col += threshold * dither_strength / color_levels;
	col = floor(col * color_levels + 0.5) / color_levels;
	// Dark-fantasy contrast curve — crush shadows, keep highlights biting.
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.42);
	// Keep the moonlit world cold while preserving parasite/fire reds.
	col *= vec3(0.92, 0.94, 1.04);
	// CRT flavor: faint scanlines + corner vignette.
	if (px.y % 2 == 0) {
		col *= 1.0 - scanline_strength;
	}
	vec2 v = SCREEN_UV - 0.5;
	col *= 1.0 - dot(v, v) * vignette_strength;
	COLOR = vec4(col, 1.0);
}
