shader_type spatial;
render_mode cull_disabled;
// Grass tufts: dark at the root, pale at the tip, leaning with a slow wind.
uniform vec3 tip : source_color = vec3(0.42, 0.38, 0.17);
uniform vec3 root : source_color = vec3(0.16, 0.16, 0.07);
varying float h;
void vertex() {
	h = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.3 + w.x * 0.35 + w.z * 0.27) + 0.5 * sin(TIME * 2.9 + w.x * 1.1);
	VERTEX.x += sway * 0.05 * h * h;
}
void fragment() {
	// Lit like the ground it stands on, on both faces: blade normals would make half
	// of every tuft black.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = mix(root, tip, h) * (0.8 + 0.4 * COLOR.r);
	ROUGHNESS = 1.0;
}
