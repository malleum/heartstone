shader_type spatial;
render_mode unshaded, cull_disabled;
// The surface inside a camp doorway: slow light folding over itself in the
// colour of where it leads. `lit` 0 is a door you may not yet pass.
uniform vec3 tint : source_color = vec3(1.0, 0.6, 0.2);
uniform float lit = 1.0;
// What lies beyond, as a dark shape against the light: 0 nothing, 1 a mountain
// pass, 2 a ring of wagons, 3 a yard of posts, 4 stars.
uniform int scene = 0;

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
	// The place beyond, in silhouette. p: x across (-1..1), y up from the sill (0..1).
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float shape = 0.0;
	if (scene == 1) {
		// Two cliffs leaning in over a pale gap.
		float wall = 0.28 + 0.5 * abs(p.x) + 0.06 * n(vec2(p.x * 9.0, 2.0));
		shape = step(p.y, wall) * step(0.16, abs(p.x) + p.y * 0.15) + step(p.y, 0.1 + 0.02 * n(p * 20.0));
	} else if (scene == 2) {
		// Wagon tilts in a row, wheels below, on open ground.
		float bump = 0.2 + 0.11 * sqrt(max(0.0, 1.0 - pow(fract(p.x * 1.6 + 0.5) * 2.0 - 1.0, 2.0)));
		shape = step(p.y, bump) * step(0.07, p.y) + step(p.y, 0.09);
	} else if (scene == 3) {
		// Practice posts standing in a yard.
		shape = step(abs(fract(p.x * 2.2 + 0.5) - 0.5), 0.07) * step(p.y, 0.34) + step(p.y, 0.1);
	} else if (scene == 4) {
		// The World of Dreams: stars that are not the waking world's.
		shape = -step(0.985, h(floor(UV * vec2(34.0, 58.0)))) * (0.6 + 0.4 * sin(TIME * 2.0 + UV.x * 40.0));
	}
	c = mix(c, scene == 4 ? c + vec3(1.2) : tint * 0.05, clamp(abs(shape), 0.0, 1.0) * (scene == 4 ? 1.0 : 0.88));
	ALBEDO = mix(vec3(0.03, 0.03, 0.04) + 0.03 * s, c, lit);
	ALPHA = mix(0.8, 0.93, lit);
}
