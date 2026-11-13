shader_type spatial;
// Armour, cloth and weapons. COLOR.a picks the material:
// 0 cloth/hide, 0.33 leather, 0.66 mail, 1 plate or blade.
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
	float cloth = 1.0 - smoothstep(0.1, 0.25, kind);
	float mail = smoothstep(0.5, 0.6, kind) * (1.0 - smoothstep(0.75, 0.9, kind));
	float plate = smoothstep(0.8, 0.95, kind);
	float leather = clamp(1.0 - cloth - mail - plate, 0.0, 1.0);
	float grime = fbm(rest * 7.0);
	float fine = fbm(rest * 60.0);
	// Rows of rings, each row offset by half a ring.
	float row = rest.y * 95.0;
	float ring = sin(row * 6.2832) * sin((rest.x + rest.z * 0.9) * 95.0 * 6.2832 + floor(row) * 3.1416);
	float weave = sin(rest.y * 900.0) * sin((rest.x + rest.z) * 900.0);
	float hgt = cloth * (fine * 0.6 + weave * 0.08) + leather * fine * 0.3 + mail * ring * 0.6 + plate * fine * 0.25;
	vec3 c = COLOR.rgb * mix(0.7, 1.15, grime);
	c *= 1.0 + mail * ring * 0.35;
	// Rust in the low spots of plate.
	c = mix(c, vec3(0.16, 0.07, 0.03), plate * smoothstep(0.55, 0.8, grime) * 0.6);
	float ao = mix(0.4, 1.0, occ);
	ALBEDO = c * ao;
	AO = ao;
	METALLIC = mail * 0.75 + plate * 0.85;
	ROUGHNESS = cloth * 0.95 + leather * 0.6 + mail * 0.5 + plate * mix(0.35, 0.7, grime);
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	NORMAL = normalize(abs(det) * NORMAL - 0.004 * sign(det) * (dFdx(hgt) * r1 + dFdy(hgt) * r2));
}
