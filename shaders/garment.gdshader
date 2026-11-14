shader_type spatial;
render_mode cull_disabled;
// Generated garments (skirt, cloak, shawl). UV: x runs around, y is 0 at the top
// edge and 1 at the hem, so hems, bands and fringes are one line each.
uniform vec3 base : source_color = vec3(0.2, 0.25, 0.18);
uniform vec3 trim : source_color = vec3(0.9, 0.9, 0.85);
uniform int style = 0;   // 0 plain wool, 1 seven-banded hem (Accepted), 2 fringed shawl with vines, 3 fancloth, 4 trimmed hem
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// The seven Ajahs, in the order of the bands on an Accepted's dress.
const vec3 AJAH[7] = vec3[](vec3(0.05, 0.12, 0.5), vec3(0.05, 0.3, 0.08), vec3(0.7, 0.55, 0.05), vec3(0.5, 0.03, 0.03), vec3(0.85, 0.85, 0.82), vec3(0.3, 0.3, 0.32), vec3(0.22, 0.12, 0.05));

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float v = UV.y, u = UV.x;
	vec3 c = base;
	// Woven texture: fine threads plus broad uneven dye.
	c *= 0.86 + 0.1 * noise(UV * vec2(340.0, 420.0)) + 0.1 * noise(UV * vec2(9.0, 5.0));
	if (style == 1 && v > 0.845) {
		c = AJAH[clamp(int((v - 0.845) / 0.022), 0, 6)];
	} else if (style == 2) {
		// A vine worked along the edge, and a knotted fringe below it.
		float vine = abs(v - 0.74 - 0.03 * sin(u * 75.0));
		c = mix(c, trim, 1.0 - smoothstep(0.006, 0.016, vine));
		float leaf = step(0.75, fract(u * 24.0 + 0.5)) * (1.0 - smoothstep(0.02, 0.05, vine));
		c = mix(c, trim, leaf * 0.8);
		if (v > 0.86 && fract(u * 110.0) > 0.45) { discard; }
	} else if (style == 3) {
		// Fancloth takes the colours of whatever is around it: slow drifting patches
		// of stone, earth and leaf that never quite settle.
		float a = noise(wp.xz * 0.9 + wp.y * 0.6 + TIME * 0.07);
		float b = noise(wp.zy * 1.3 - TIME * 0.05 + 7.0);
		c = mix(mix(vec3(0.16, 0.17, 0.15), vec3(0.3, 0.27, 0.22), a), vec3(0.14, 0.2, 0.12), b * 0.6);
		c *= 0.85 + 0.25 * noise(UV * vec2(200.0, 260.0));
	} else if (style == 4 && v > 0.93) {
		c = trim;
	}
	if (!FRONT_FACING) { c *= 0.55; }
	ALBEDO = c;
	ROUGHNESS = 0.92;
}
