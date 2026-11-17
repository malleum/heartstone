shader_type canvas_item;
// Inside a doorway's light while stepping through: the same slow folding light as
// the doorway's face, filling the screen, brightest where you are going.
uniform vec3 tint : source_color = vec3(1.0, 0.6, 0.2);
uniform float amount = 0.0;   // 0 clear, 1 nothing but the light

// Value noise that wraps every `per` cells across x, so the angle round the
// middle of the screen has no seam where it comes back to its start.
float h(vec2 p, float per) { p.x = mod(p.x, per); return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p, float per) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i, per), h(i + vec2(1, 0), per), f.x), mix(h(i + vec2(0, 1), per), h(i + vec2(1, 1), per), f.x), f.y);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	c.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(c);
	float a = atan(c.y, c.x);
	// Light streaming past: folds that rush outward from the middle.
	// x runs 0..12 once round; each octave keeps a whole number of cells per turn.
	float u = (a / 6.2831853 + 0.5) * 12.0;
	float d = 1.0 / (r + 0.15) - TIME * 1.6;
	float s = n(vec2(u, d * 1.7 + n(vec2(u * 0.5, d * 0.8), 6.0) * 1.5), 12.0) * 0.7 + n(vec2(u * 3.0, d * 5.0), 36.0) * 0.3;
	vec3 col = tint * (0.35 + s * s * 2.2) + vec3(1.0, 0.97, 0.9) * (pow(s, 5.0) * 1.6 + smoothstep(0.5, 0.0, r) * 0.9);
	// It closes in from the edges as it comes, and leaves from the middle out.
	float edge = smoothstep(amount * 1.9 - 0.25, amount * 1.9, 1.6 - r);
	COLOR = vec4(col, clamp(amount * 1.4, 0.0, 1.0) * mix(edge, 1.0, step(0.999, amount)));
}
