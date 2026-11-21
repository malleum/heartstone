shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, specular_schlick_ggx;
// Standing water. A flat sheet at the surface height over ground dipped to hold it
// (Terrain.height, Map.basin). How deep it is under each pixel comes from the depth
// buffer: clear and pale over the shallows, dark where deep, a soft edge where it
// meets the bank instead of a cut line, and a thin lap of foam there. Ripples move
// with the wind; it is glossy enough to carry the sky and firelight.
uniform vec4 deep : source_color = vec4(0.02, 0.07, 0.09, 1.0);
uniform vec4 shallow : source_color = vec4(0.16, 0.24, 0.2, 1.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
global uniform vec3 wind_vec;

float ripple(vec2 p, float t) {
	// Long, crossing swells in three directions (summed, never multiplied: a product
	// of sines tiles the surface into a checkerboard).
	return sin(dot(p, vec2(0.83, 0.55)) * 2.3 + t * 1.3) * 0.5
		+ sin(dot(p, vec2(-0.47, 0.88)) * 3.7 - t * 1.6) * 0.32
		+ sin(dot(p, vec2(0.99, -0.12)) * 6.9 + t * 2.4) * 0.18;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * (0.6 + length(wind_vec) * 0.15);
	vec2 drift = wind_vec.xz * TIME * 0.05;
	float r = ripple(wp.xz + drift, t);
	float r2 = ripple(wp.zx * 1.3 - drift + 4.0, t * 1.1);
	vec3 n = normalize(vec3(r * 0.06, 1.0, r2 * 0.06));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	// Water depth under this pixel, along the view ray, in metres.
	float zd = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 back = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	back.xyz /= back.w;
	float thick = max(length(back.xyz) - length(VERTEX), 0.0);
	float d = clamp(thick / 1.2, 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	float foam = (1.0 - smoothstep(0.0, 0.12, thick)) * (0.6 + 0.4 * sin(TIME * 1.7 + wp.x * 2.0 + wp.z * 1.3));
	ALBEDO = mix(shallow.rgb, deep.rgb, d) + vec3(0.55, 0.6, 0.58) * foam * 0.5;
	ROUGHNESS = 0.05 + foam * 0.6;
	SPECULAR = 0.7;
	METALLIC = 0.0;
	ALPHA = clamp(smoothstep(0.0, 0.25, thick) * (0.72 + 0.25 * d) + fres * 0.3 + foam * 0.3, 0.0, 0.97);
}
