shader_type spatial;
render_mode cull_disabled;
// A banner streaming from its pole: waves run out along it from the pole (UV.x 0)
// to the free edge, harder in a strong wind (the global wind_vec).
uniform vec3 cloth : source_color = vec3(0.55, 0.1, 0.08);
global uniform vec3 wind_vec;
global uniform vec4 gust;
void vertex() {
	float u = UV.x;
	float k = length(wind_vec) + gust.w * 0.3;
	float wave = sin(TIME * (4.0 + 3.0 * k) - u * 7.0) * (0.06 + 0.14 * k) + sin(TIME * 7.3 - u * 13.0) * 0.03 * k;
	// The quad lies in its local XY plane with the pole at x = 0: ripple across (z),
	// and a little droop at the free edge when the wind is light.
	VERTEX.z += wave * u;
	VERTEX.y -= (1.0 - clamp(k, 0.0, 1.0)) * 0.35 * u * u;
}
void fragment() {
	ALBEDO = cloth * (0.85 + 0.15 * UV.y);
	ROUGHNESS = 0.85;
}
