shader_type spatial;
#include "res://shaders/face_deform.gdshaderinc"
// Hair that moves: its colour as the pack's material had it, and the lower it hangs
// from the crown the more it drifts back and stirs (Hero.cloak_motion sets gust).
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool use_tex = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float top = 1.8;     // the crown, in the model's space
uniform float span = 0.4;    // how far down from it the hair reaches
uniform float mid_z = 0.0;   // the middle of the head, front to back
uniform vec3 wind = vec3(0.0, 0.0, -1.0);
uniform float gust = 0.3;

void vertex() {
	// Measured on the rest pose (CUSTOM0, Hero._bake_rest), so a nod does not move it.
	// Only what hangs free moves: below the jaw and behind the head. Hair on the
	// scalp, at the temples and over the brow stays where it grows (it had lifted
	// off the head in a run).
	vec3 r = CUSTOM0.xyz;
	float below = top - r.y;
	float hang = smoothstep(0.17, 0.42, below);
	float back = smoothstep(mid_z + 0.02, mid_z - 0.07, r.z);
	float w = hang * back;
	vec3 stir = vec3(sin(TIME * 3.1 + r.x * 20.0), 0.0, sin(TIME * 2.3 + r.z * 17.0 + 1.3));
	VERTEX += (wind * 0.03 + stir * 0.008) * min(gust, 1.6) * w;
	// A beard follows the jaw and chin it grows on (zero for the hair of the head).
	VERTEX += face_shape(r);
}

void fragment() {
	vec4 c = use_tex ? texture(tex, UV) : vec4(1.0);
	ALBEDO = c.rgb * tint.rgb;
	if (use_tex && c.a < 0.5) { discard; }
	ROUGHNESS = 0.75;
}
