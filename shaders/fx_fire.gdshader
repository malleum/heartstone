shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
// Fire (or any of the Powers gathered into a ball) on a sphere: the surface boils
// with noise, the middle is white-hot and the edge licks away to nothing. `burn`
// goes 0 to 1 as it burns out: holes open in it instead of the whole fading like
// a balloon.
uniform sampler2D noise : repeat_enable;
uniform vec4 hot : source_color = vec4(1.0, 0.85, 0.45, 1.0);
uniform vec4 cool : source_color = vec4(0.9, 0.2, 0.02, 1.0);
uniform float energy = 3.0;
uniform float burn = 0.0;
uniform float speed = 1.5;
uniform float swell = 0.25;

void vertex() {
	float nv = texture(noise, UV * vec2(2.0, 1.0) + vec2(0.0, -TIME * speed * 0.3)).r;
	VERTEX += NORMAL * (nv - 0.5) * swell;
}

void fragment() {
	float n = texture(noise, UV * vec2(3.0, 1.5) + vec2(TIME * 0.1, -TIME * speed * 0.5)).r;
	float n2 = texture(noise, UV * vec2(7.0, 3.5) + vec2(-TIME * 0.2, -TIME * speed)).r;
	float f = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.4);
	float h = f * (0.35 + n * 1.0 + n2 * 0.45) - burn * 1.5;
	h = clamp(h, 0.0, 1.5);
	vec3 c = mix(cool.rgb, hot.rgb, smoothstep(0.3, 0.85, h));
	c = mix(c, vec3(1.0), smoothstep(0.95, 1.3, h) * 0.8);
	ALBEDO = c * smoothstep(0.04, 0.35, h) * energy;
}
