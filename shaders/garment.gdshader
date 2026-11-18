shader_type spatial;
render_mode cull_disabled;
// Generated garments (skirt, cloak, shawl). UV: x runs around, y is 0 at the top
// edge and 1 at the hem, so hems, bands and fringes are one line each.
uniform vec3 base : source_color = vec3(0.2, 0.25, 0.18);
uniform vec3 trim : source_color = vec3(0.9, 0.9, 0.85);
uniform int style = 0;   // 0 plain wool, 1 seven-banded hem (Accepted), 2 fringed shawl with vines, 3 fancloth, 4 trimmed hem, 5 gleeman's patches, 6 silk with a worked border, 7 fur-trimmed, 8 lined (inside is trim), 9 embroidered vines
// Skirts: creases are shaded where the mesh folds inward (pleat() matches
// tools/blender/build_heroes.py), with a band and gathers at the waist.
uniform bool pleats = false;
// Cloaks worn short: everything below this much of the length is cut away.
uniform float cut = 1.0;
varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// The seven Ajahs, in the order of the bands on an Accepted's dress.
const vec3 AJAH[7] = vec3[](vec3(0.05, 0.12, 0.5), vec3(0.05, 0.3, 0.08), vec3(0.7, 0.55, 0.05), vec3(0.5, 0.03, 0.03), vec3(0.85, 0.85, 0.82), vec3(0.3, 0.3, 0.32), vec3(0.22, 0.12, 0.05));

// A cloak in motion: it lifts and streams back more the further down it hangs, with a
// little flutter, set each frame from how fast the wearer goes (Hero.cloak_motion).
uniform vec3 sway = vec3(0.0);
uniform float flutter = 0.0;

void vertex() {
	// More the further down it hangs; nothing at the shoulders.
	float d = UV.y * UV.y;
	// Ripples that run down the cloth from shoulder to hem, two of them crossing,
	// so it moves like cloth and not like a board.
	float w1 = sin(TIME * 4.3 - UV.y * 7.0 + UV.x * 3.1);
	float w2 = sin(TIME * 2.7 - UV.y * 4.0 - UV.x * 5.3 + 1.7);
	vec3 ripple = vec3(0.35 * w2, 0.12 * w1, w1 + 0.5 * w2) * flutter * 0.06;
	VERTEX += (sway + ripple) * d;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float v = UV.y, u = UV.x;
	if (cut < 0.999) {
		if (v > cut) { discard; }
		v /= cut;      // hems, borders and fur sit at the new edge
	}
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
	} else if (style == 5) {
		// A gleeman's cloak: covered in patches of every colour, that flutter.
		vec2 cell = floor(vec2(u * 26.0, v * 13.0) + vec2(0.5 * floor(v * 13.0), 0.0));
		float h1 = hash(cell), h2 = hash(cell + 17.0);
		vec3 patch = 0.5 + 0.5 * cos(6.2831 * (h1 + vec3(0.0, 0.33, 0.67)));
		vec2 f = fract(vec2(u * 26.0, v * 13.0) + vec2(0.5 * floor(v * 13.0), 0.0));
		float edge = step(0.08, f.x) * step(0.08, f.y);
		c = mix(c, mix(base, patch * 0.75, 0.35 + 0.65 * step(0.25, h2)), edge);
		c *= 0.86 + 0.14 * noise(UV * vec2(300.0, 380.0));
	} else if (style == 6) {
		// Silk with a worked border: smooth, and trimmed at hem and edge.
		if (v > 0.9 || (v > 0.84 && v < 0.865)) { c = trim; }
	} else if (style == 7) {
		// Fur at the collar and along the hem: pale, tufted, uneven at its edge.
		float tuft = noise(UV * vec2(160.0, 60.0));
		float edge = 0.03 * noise(vec2(u * 40.0, 3.0));
		if (v < 0.075 + edge || v > 0.9 - edge) { c = trim * (0.7 + 0.5 * tuft); }
	} else if (style == 8) {
		// Lined: the inside is the trim colour, and it shows as a line at the hem.
		if (!FRONT_FACING) { c = trim * 1.8; }
		else if (v > 0.975) { c = trim; }
	} else if (style == 9) {
		// Vines worked in thread above the hem, with leaves.
		float vine = abs(v - 0.86 - 0.035 * sin(u * 60.0));
		c = mix(c, trim, 1.0 - smoothstep(0.005, 0.013, vine));
		float leaf = step(0.7, fract(u * 19.0 + 0.5)) * (1.0 - smoothstep(0.02, 0.05, vine));
		c = mix(c, trim, leaf * 0.8);
		if (v > 0.965) { c = trim; }
	}
	if (pleats) {
		float a = 3.14159265 + u * 6.2831853;
		float f = 0.7 * sin(a * 9.0 + 0.7 * sin(a * 2.0)) + 0.3 * sin(a * 15.0 + 1.3);
		if (f < -0.55) { f = -0.55 + (f + 0.55) * 0.25; }
		float deep = 0.25 + 0.75 * smoothstep(0.1, 0.9, v);
		c *= 1.0 - 0.5 * deep * (1.0 - smoothstep(-0.66, 0.35, f));
		c *= 1.0 + 0.1 * deep * smoothstep(0.3, 1.0, f);
		// Gathers stitched under the waistband.
		float gather = smoothstep(0.1, 0.0, v) * (0.5 + 0.5 * sin(u * 6.2831853 * 66.0));
		c *= 1.0 - 0.22 * gather;
		if (v < 0.055) { c = base * 0.62; }
	}
	// The inside of a garment is in its own shade.
	if (!FRONT_FACING) { c *= pleats ? 0.22 : 0.55; }
	ALBEDO = c;
	ROUGHNESS = 0.92;
	// Nothing shines on the inside: the sky's reflection made it look see-through.
	if (!FRONT_FACING) { ROUGHNESS = 1.0; SPECULAR = 0.0; }
}
