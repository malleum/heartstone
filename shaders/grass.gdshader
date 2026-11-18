shader_type spatial;
render_mode cull_disabled;
// Grass tufts: dark at the root, pale at the tip, leaning with a slow wind.
uniform vec3 tip : source_color = vec3(0.42, 0.38, 0.17);
uniform vec3 root : source_color = vec3(0.16, 0.16, 0.07);
varying float h;
global uniform vec3 wind_vec;
global uniform vec4 gust;
void vertex() {
	h = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = length(wind_vec);
	vec3 along = k > 0.001 ? wind_vec / k : vec3(1.0, 0.0, 0.0);
	// Waves running across the field the way the wind blows, over a steady lean.
	float run = dot(w.xz, along.xz);
	float sway = sin(TIME * (1.3 + k) - run * 0.4 + w.x * 0.1) + 0.5 * sin(TIME * 2.9 + w.x * 1.1 + w.z * 0.7);
	vec3 off = along * (k * 0.12 + sway * (0.03 + 0.05 * k));
	// A gust flattens the grass outward from where it came from.
	vec3 gd = vec3(w.x - gust.x, 0.0, w.z - gust.z);
	float gl = length(gd);
	if (gust.w > 0.0 && gl > 0.01) {
		off += gd / gl * gust.w * clamp(1.0 - gl / 12.0, 0.0, 1.0) * 0.35;
	}
	VERTEX += inverse(mat3(MODEL_MATRIX)) * (off * h * h);
}
void fragment() {
	// Lit like the ground it stands on, on both faces: blade normals would make half
	// of every tuft black.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = mix(root, tip, h) * (0.8 + 0.4 * COLOR.r);
	ROUGHNESS = 1.0;
}
