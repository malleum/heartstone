shader_type spatial;
// Skin, fur and horn in one material. COLOR.a says which: 0 hard and glossy,
// 0.5 skin, 1 fur. Patterns are sampled at the rest-pose position (packed into
// the UVs by the generator) so they stay glued to the body under animation.

uniform float detail = 1.0;
varying vec3 rest;
varying float occ;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1); p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x), f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.0) * 0.3 + noise(p * 4.3 + 3.0) * 0.15;
}

void vertex() {
	rest = vec3(UV, UV2.x);
	occ = UV2.y;
}

void fragment() {
	float kind = COLOR.a;
	float fur = smoothstep(0.6, 0.95, kind);
	float hard = 1.0 - smoothstep(0.05, 0.4, kind);
	float blotch = fbm(rest * 9.0);
	// Fur reads as streaks running down the body; skin as fine pores.
	float strands = fbm(rest * vec3(110.0, 22.0, 110.0));
	float pores = fbm(rest * 70.0);
	float ridge = sin(length(rest.yz) * 260.0 + blotch * 6.0) * (1.0 - smoothstep(0.0, 0.08, kind));
	float hgt = (mix(pores * 0.25, strands, fur) * (1.0 - hard) + ridge * 0.35 * hard) * detail;
	vec3 c = COLOR.rgb * mix(0.8, 1.15, blotch);
	c *= mix(1.0, mix(0.5, 1.35, strands), fur);
	c *= mix(1.0, mix(0.9, 1.08, pores), (1.0 - fur) * (1.0 - hard));
	c *= 1.0 - (0.25 + 0.2 * ridge) * (1.0 - smoothstep(0.0, 0.08, kind));
	float ao = mix(0.35, 1.0, occ);
	ALBEDO = c * ao;
	AO = ao;
	ROUGHNESS = mix(mix(0.6, 0.92, fur), 0.28, hard);
	SPECULAR = mix(0.35, 0.15, fur);
	// Bump from the height's screen-space derivatives: no tangents needed.
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	float dhx = dFdx(hgt), dhy = dFdy(hgt);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.004 * grad);
}
