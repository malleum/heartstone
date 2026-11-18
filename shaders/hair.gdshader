shader_type spatial;
// Hair that moves: its colour as the pack's material had it, and the lower it hangs
// from the crown the more it drifts back and stirs (Hero.cloak_motion sets gust).
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform bool use_tex = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float top = 1.8;     // the crown, in the model's space
uniform float span = 0.4;    // how far down from it the hair reaches
uniform vec3 wind = vec3(0.0, 0.0, -1.0);
uniform float gust = 0.3;

void vertex() {
	float h = clamp((top - VERTEX.y) / max(span, 0.01), 0.0, 1.0);
	float w = h * h;
	vec3 stir = vec3(sin(TIME * 3.1 + VERTEX.x * 20.0), 0.0, sin(TIME * 2.3 + VERTEX.z * 17.0 + 1.3));
	VERTEX += (wind * 0.035 + stir * 0.012) * gust * w;
}

void fragment() {
	vec4 c = use_tex ? texture(tex, UV) : vec4(1.0);
	ALBEDO = c.rgb * tint.rgb;
	if (use_tex && c.a < 0.5) { discard; }
	ROUGHNESS = 0.75;
}
