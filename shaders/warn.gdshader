shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// Where an enemy's blow is about to fall, laid on the ground. UV.y is 0 at the
// attacker and 1 at the far edge. `fill` rises 0 to 1 as the blow comes: the wedge
// fills outward, and its edge burns bright at the instant it lands.
uniform vec4 tint : source_color = vec4(1.0, 0.1, 0.05, 1.0);
uniform float fill = 0.0;

void fragment() {
	float rim = smoothstep(0.9, 1.0, UV.y) + smoothstep(0.94, 1.0, abs(UV.x * 2.0 - 1.0));
	float inside = 1.0 - smoothstep(fill - 0.05, fill, UV.y);
	// (The filled part kept fainter than the rim: at night, unshaded, a strong fill
	// read as a solid disc of paint on the ground.)
	float a = 0.08 + 0.2 * inside + 0.55 * clamp(rim, 0.0, 1.0);
	a *= 0.45 + 0.55 * fill;
	ALBEDO = tint.rgb * (0.6 + 0.6 * fill);
	ALPHA = clamp(a, 0.0, 0.9);
}
