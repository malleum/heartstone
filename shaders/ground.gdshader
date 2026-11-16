shader_type spatial;
// Borderland ground, entirely from world-space noise (no UVs, no textures): dry and
// sickly grass over dirt, a trampled road, layered cliff rock, snow on the heights.
uniform float road = 0.0;   // half-width of the worn track along z through x = 0; 0 for none
varying vec3 wp;
varying vec3 wn;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 x) {
	vec2 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 5; i++) { s += a * noise(p); p = p * 2.03 + 11.0; a *= 0.5; }
	return s;
}
// Noise projected from three sides and blended by the normal: a top-down projection
// alone smears into vertical streaks on a cliff face.
float tri(vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return fbm(p.zy * s) * w.x + fbm(p.xz * s) * w.y + fbm(p.xy * s) * w.z;
}
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = NORMAL;
}
void fragment() {
	vec3 n3 = normalize(wn);
	float macro = fbm(wp.xz * 0.035 + 3.0);
	float mid = fbm(wp.xz * 0.6);
	float fine = tri(wp, n3, 5.0);
	float slope = 1.0 - n3.y;

	vec3 dirt = mix(vec3(0.16, 0.12, 0.085), vec3(0.3, 0.24, 0.17), mid);
	vec3 dry = mix(vec3(0.3, 0.26, 0.11), vec3(0.2, 0.2, 0.08), fbm(wp.xz * 1.7));
	vec3 grass = mix(dry, vec3(0.1, 0.16, 0.06), smoothstep(0.42, 0.7, macro));
	float gmask = smoothstep(0.4, 0.58, fbm(wp.xz * 0.21 + 40.0) + (macro - 0.5) * 0.5);
	vec3 c = mix(dirt, grass * (0.65 + 0.7 * fine), gmask);

	// The road: feet, hooves and wagons have churned it to mud, with ruts along it.
	if (road > 0.0) {
		float rx = wp.x + (noise(vec2(wp.z * 0.045, 2.0)) - 0.5) * 9.0;
		float rmask = 1.0 - smoothstep(road * 0.45, road, abs(rx) + (mid - 0.5) * 2.0);
		float ruts = fbm(vec2(wp.x * 3.5, wp.z * 0.35));
		vec3 mud = vec3(0.14, 0.105, 0.075) * (0.6 + 0.7 * ruts);
		c = mix(c, mud, rmask * 0.9);
	}

	// Cliff rock: beds of uneven thickness that dip and wander, a dark ledge line
	// under each, cracks running down the face, rust where water seeps.
	float by = wp.y + fbm(wp.xz * 0.07) * 7.0 + (wp.x + wp.z) * 0.06;
	float strata = noise(vec2(by * 0.75, 7.0)) * 0.55 + noise(vec2(by * 2.6, 1.0)) * 0.3 + noise(vec2(by * 7.0, 4.0)) * 0.15;
	vec3 rock = mix(vec3(0.15, 0.14, 0.135), vec3(0.4, 0.365, 0.32), smoothstep(0.25, 0.75, strata));
	rock *= 0.82 + 0.36 * fine;
	float lf = fract(by * 0.42 + noise(vec2(by * 0.42, 9.0)) * 0.3);
	float ledge = 1.0 - smoothstep(0.0, 0.07, lf);
	rock *= 1.0 - 0.5 * ledge;
	float hc = wp.x * 0.6 + wp.z;
	float crack = smoothstep(0.6, 0.66, fbm(vec2(hc * 0.55, wp.y * 0.07 + 5.0))) * (1.0 - smoothstep(0.66, 0.74, fbm(vec2(hc * 0.55, wp.y * 0.07 + 5.0))));
	rock *= 1.0 - 0.55 * crack;
	rock = mix(rock, vec3(0.3, 0.19, 0.12), smoothstep(0.55, 0.75, fbm(vec2(hc * 0.3, wp.y * 0.08))) * 0.3);
	rock *= 0.8 + 0.3 * smoothstep(0.25, 0.6, tri(wp, n3, 0.5));
	float rmk = smoothstep(0.1, 0.27, slope + (fine - 0.5) * 0.14);
	c = mix(c, rock, rmk);

	// Snow settles on the heights wherever it is flat enough to hold.
	float snow = smoothstep(24.0, 34.0, wp.y + fbm(wp.xz * 0.2) * 9.0) * (1.0 - smoothstep(0.35, 0.7, slope + (fine - 0.5) * 0.2));
	c = mix(c, vec3(0.78, 0.8, 0.84), snow);

	ALBEDO = c;
	ROUGHNESS = mix(0.96, 0.7, snow);
	float h = fine - rmk * (ledge * 0.5 + crack * 0.8 - strata * 0.8);
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	NORMAL = normalize(abs(det) * NORMAL - 0.06 * sign(det) * (dFdx(h) * r1 + dFdy(h) * r2));
}
