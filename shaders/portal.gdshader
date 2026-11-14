shader_type spatial;
render_mode unshaded, cull_disabled;
// The surface inside a camp doorway: slow light folding over itself in the
// colour of where it leads. `lit` 0 is a door you may not yet pass.
uniform vec3 tint : source_color = vec3(1.0, 0.6, 0.2);
uniform float lit = 1.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV * vec2(2.0, 3.4);
	vec2 q = uv + vec2(n(uv * 1.3 + TIME * 0.25), n(uv * 1.3 - TIME * 0.2)) * 1.4;
	float s = n(q * 1.6 + vec2(0.0, -TIME * 0.35)) * 0.65 + n(q * 4.0 + TIME * 0.2) * 0.35;
	vec2 e = abs(UV * 2.0 - 1.0);
	float rim = smoothstep(0.82, 1.0, max(e.x, e.y));
	vec3 c = tint * (0.25 + s * s * 2.6) + vec3(1.0, 0.97, 0.9) * (rim * 1.4 + pow(s, 6.0) * 2.0);
	ALBEDO = mix(vec3(0.03, 0.03, 0.04) + 0.03 * s, c, lit);
	ALPHA = mix(0.8, 0.93, lit);
}
