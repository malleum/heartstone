shader_type spatial;
// Blighted, stony ground. World-space noise: no UVs or textures needed.
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
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = NORMAL;
}
void fragment() {
	float n = fbm(wp.xz * 0.6);
	float fine = fbm(wp.xz * 6.0);
	float slope = 1.0 - wn.y;
	vec3 dirt = mix(vec3(0.13, 0.125, 0.115), vec3(0.24, 0.23, 0.21), n);
	vec3 rock = mix(vec3(0.16, 0.155, 0.15), vec3(0.3, 0.29, 0.27), fine);
	vec3 grass = vec3(0.13, 0.14, 0.06) * (0.6 + fine);
	vec3 c = mix(dirt, grass, smoothstep(0.5, 0.65, fbm(wp.xz * 0.23 + 40.0)) * 0.7);
	c = mix(c, rock, smoothstep(0.03, 0.12, slope + (fine - 0.5) * 0.08));
	ALBEDO = c * (0.75 + 0.5 * fine) * 0.7;
	ROUGHNESS = 0.95;
	float h = fine;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	NORMAL = normalize(abs(det) * NORMAL - 0.05 * sign(det) * (dFdx(h) * r1 + dFdy(h) * r2));
}
