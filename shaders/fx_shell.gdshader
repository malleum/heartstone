shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A wall of Air (or any shell of the Power): nearly nothing face on, bright at
// the rim, with threads of the weave running round it.
uniform sampler2D noise : repeat_enable;
uniform vec4 tint : source_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform float energy = 1.0;
uniform float fade = 1.0;

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float n = texture(noise, UV * vec2(4.0, 2.0) + vec2(TIME * 0.05, TIME * 0.02)).r;
	float thread = smoothstep(0.47, 0.5, n) * (1.0 - smoothstep(0.5, 0.53, n));
	float band = smoothstep(0.9, 1.0, sin(UV.y * 40.0 + TIME * 1.5 + n * 6.0));
	ALBEDO = tint.rgb * (rim * 0.9 + thread * 0.55 + band * 0.12 + 0.02) * energy * fade;
}
