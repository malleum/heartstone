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
		float shirt = smoothstep(0.26, 0.4, lum) * (1.0 - smoothstep(0.5, 0.75, sat));
		float wool = 1.0 - smoothstep(0.035, 0.085, lum);
		o = mix(o, primary * min(lum / 0.5, 1.5), shirt);
		o = mix(o, secondary * min(lum / 0.025, 2.4), wool);
	}
	ALBEDO = o;
	ROUGHNESS = 0.86;
	if (has_normal) { NORMAL_MAP = texture(normal_tex, UV).rgb; }
}
