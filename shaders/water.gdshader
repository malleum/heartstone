shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, specular_schlick_ggx;
// Standing water: dark and still, a little glassy where you look along it, with
// ripples that move with the wind. A flat sheet laid at the surface height; the
// ground is dipped to hold it (Terrain.height, Map.basin).
uniform vec4 deep : source_color = vec4(0.04, 0.1, 0.12, 1.0);
uniform vec4 shallow : source_color = vec4(0.12, 0.24, 0.24, 1.0);
global uniform vec3 wind_vec;

float ripple(vec2 p, float t) {
	return sin(p.x * 3.1 + t * 1.3) * sin(p.y * 2.7 - t * 1.1) + sin((p.x + p.y) * 5.3 + t * 2.1) * 0.5;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * (0.6 + length(wind_vec) * 0.15);
	float r = ripple(wp.xz, t);
	vec3 n = normalize(vec3(r * 0.05, 1.0, ripple(wp.zx + 4.0, t) * 0.05));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, fres * 0.6 + 0.2 * (r * 0.5 + 0.5));
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	METALLIC = 0.2;
	ALPHA = clamp(0.8 + fres * 0.2, 0.0, 1.0);
}
