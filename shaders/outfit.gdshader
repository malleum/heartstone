shader_type spatial;
// Recolours a sourced outfit atlas without repainting it: find the cloth by its
// colour in the original texture and swap in the culture's colours, leaving leather,
// metal and stitching alone. Shading detail survives because the new colour is
// scaled by the old texel's brightness.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform int mode = 0;               // 0: ranger atlas (green cloth). 1: peasant atlas (cream shirt, brown wool).
uniform vec3 primary : source_color = vec3(0.3, 0.5, 0.2);     // tunic / shirt
uniform vec3 secondary : source_color = vec3(0.05, 0.12, 0.06); // trousers, hood / vest
uniform bool has_normal = true;
// Gowns: the pack's bodice is leather (yoke, bust and corset). With alpha above
// zero it is recut in this cloth instead, so a dress is one garment to the hem.
uniform vec4 bodice : source_color = vec4(0.0);
// Cairhienin slashes: `slashes` horizontal bars of House colour across the chest.
uniform int slashes = 0;
uniform vec3 slash_a : source_color = vec3(0.6, 0.1, 0.1);
uniform vec3 slash_b : source_color = vec3(0.75, 0.6, 0.15);
uniform vec3 slash_c : source_color = vec3(0.15, 0.3, 0.6);
// Tairen sleeves: stripes of this colour down the arms (alpha 0 = none).
uniform vec4 sleeve : source_color = vec4(0.0);
// Silk catches the light; mail is rings of steel where the cloth would be.
uniform float sheen = 0.0;
uniform bool mail = false;
// Plate: a smooth breastplate over the chest, lames below it, plates on the
// shoulders, steel where the cloth would be; `mark` (alpha above 0) is a golden
// sunburst on the breast (the Children of the Light).
uniform bool plate = false;
uniform vec4 mark : source_color = vec4(0.0);
varying vec3 rest;

// The rest pose, baked into CUSTOM0 by Hero._bake_rest: VERTEX here is already posed.
void vertex() { rest = CUSTOM0.xyz; }

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 o = c;
	if (mode == 0) {
		// Relative greenness: the trousers are so dark that an absolute difference misses them.
		float cloth = smoothstep(0.15, 0.35, (c.g - max(c.r, c.b)) / max(c.g, 0.001)) * smoothstep(0.003, 0.01, c.g);
		float light = smoothstep(0.04, 0.1, lum);
		vec3 t = mix(secondary * min(lum / 0.016, 2.4), primary * min(lum / 0.19, 1.8), light);
		o = mix(c, t, cloth);
	} else {
		// Measured from the atlas (linear light): the shirt is a tan of luminance
		// 0.13 to 0.26 and middling saturation; leather is darker and far more
		// saturated; buckles are brighter and grey; the wool is nearly black.
		float shirt = smoothstep(0.09, 0.14, lum) * (1.0 - smoothstep(0.7, 0.85, sat)) * smoothstep(0.12, 0.25, sat);
		float wool = 1.0 - smoothstep(0.02, 0.04, lum);
		o = mix(o, primary * min(lum / 0.25, 1.5), shirt);
		o = mix(o, secondary * min(lum / 0.012, 2.4), wool);
		if (bodice.a > 0.0) {
			float leather = smoothstep(0.5, 0.72, sat) * smoothstep(0.012, 0.03, lum) * (1.0 - shirt);
			o = mix(o, bodice.rgb * clamp(lum / 0.075, 0.45, 1.5), leather * bodice.a);
		}
	}
	// How much of this texel is cloth of the main colour (shirt, tunic, coat).
	float body = 0.0;
	if (mode == 0) {
		body = smoothstep(0.15, 0.35, (c.g - max(c.r, c.b)) / max(c.g, 0.001)) * smoothstep(0.04, 0.1, lum);
	} else {
		body = smoothstep(0.09, 0.14, lum) * (1.0 - smoothstep(0.7, 0.85, sat)) * smoothstep(0.12, 0.25, sat);
	}
	// Worked on the body at rest (arms out), so the marks ride the cloth.
	if (slashes > 0 && abs(rest.x) < 0.2 && rest.z > 0.0) {
		float band = (1.46 - rest.y) / 0.062;
		if (band >= 0.0 && band < float(slashes) && fract(band) < 0.62) {
			int k = int(band) % 3;
			o = mix(o, (k == 0 ? slash_a : (k == 1 ? slash_b : slash_c)) * min(lum / 0.3, 1.3), body);
		}
	}
	if (sleeve.a > 0.0 && abs(rest.x) > 0.24 && fract(abs(rest.x) * 9.0) < 0.45) {
		o = mix(o, sleeve.rgb * min(lum / 0.3, 1.3), body * sleeve.a);
	}
	float rough = 0.86;
	if (mail) {
		// Rows of small rings: bright where a ring catches light, dark between.
		vec2 g = UV * vec2(210.0, 300.0);
		g.x += 0.5 * floor(g.y);
		float ring = abs(length(fract(g) - 0.5) - 0.3);
		float steel = 0.16 + 0.5 * (1.0 - smoothstep(0.03, 0.14, ring));
		o = mix(o, vec3(steel) * min(lum / 0.2, 1.4), body);
		METALLIC = body * 0.85;
		rough = mix(rough, 0.42, body);
	}
	if (plate) {
		// Worked on the rest pose, so the plates ride the body.
		float y = rest.y; float ax = abs(rest.x);
		float torso = step(ax, 0.2) * step(0.92, y) * step(y, 1.5);
		float shoulder = smoothstep(0.15, 0.18, ax) * (1.0 - smoothstep(0.34, 0.38, ax)) * step(1.28, y);
		float steel_here = max(torso, shoulder) * body;
		// The breastplate: one curved piece, brighter where it faces up.
		float lit = 0.32 + 0.22 * smoothstep(1.2, 1.45, y);
		if (y < 1.16) {
			// Lames below it: overlapping bands, each bright at its top edge, dark at the seam.
			float b = fract((1.16 - y) / 0.06);
			lit = 0.24 + 0.22 * (1.0 - b) - 0.18 * smoothstep(0.9, 1.0, b);
		}
		if (shoulder > 0.5) {
			float b2 = fract((ax - 0.16) / 0.055);
			lit = 0.3 + 0.2 * (1.0 - b2) - 0.15 * smoothstep(0.88, 1.0, b2);
		}
		vec3 st = vec3(lit) * vec3(0.95, 0.97, 1.0) * min(lum / 0.15 + 0.5, 1.3);
		// Rivets along the breastplate's edge.
		float rv = step(length(vec2(fract(rest.x * 25.0) - 0.5, (y - 1.17) * 25.0)), 0.25) * step(ax, 0.18);
		st = mix(st, vec3(0.75), rv);
		if (mark.a > 0.0 && rest.z > 0.0) {
			// A sunburst: a disc with rays, over the heart (beside the coat's placket).
			vec2 q = vec2(rest.x - 0.075, y - 1.445);
			float rr = length(q);
			float ray = step(0.5, fract(atan(q.y, q.x) * 16.0 / 6.2831853));
			float sun = step(rr, 0.017) + step(rr, 0.045) * step(0.02, rr) * ray;
			st = mix(st, mark.rgb, clamp(sun, 0.0, 1.0) * mark.a);
		}
		o = mix(o, st, steel_here);
		METALLIC = steel_here * 0.9;
		rough = mix(rough, 0.28, steel_here);
	}
	ALBEDO = o;
	ROUGHNESS = mix(rough, 0.34, sheen * body);
	SPECULAR = 0.5 + 0.4 * sheen * body;
	if (has_normal) { NORMAL_MAP = texture(normal_tex, UV).rgb; }
}
