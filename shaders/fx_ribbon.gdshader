shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// A thread of the Power: a strip that follows a moving point. UV.x runs along it
// (0 at the head), UV.y across it; COLOR.a is how much of it is left at that
// point. A bright core with a softer body round it, broken up by noise that runs
// down its length so it looks like something flowing, not a painted line.
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 3.0;
uniform sampler2D noise : repeat_enable;
uniform float flow = 2.0;
uniform float rough = 0.4;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float n = texture(noise, vec2(UV.x * 2.5 + TIME * flow, UV.y * 0.6)).r;
	float body = smoothstep(0.0, 0.85, across) * mix(1.0, smoothstep(0.25, 0.75, n) * 1.6, rough);
	float core = smoothstep(0.6, 1.0, across);
	ALBEDO = (tint.rgb * body + vec3(1.0) * core * 0.7) * COLOR.a * energy;
}
