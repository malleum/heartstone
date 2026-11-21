shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// Where my own weave will land, laid on the ground while it is being made. UV.y
// runs 0 at the near edge to 1 at the far edge; UV.x across. A bright rim with
// dashes marching round it, a faint fill with pale rings rolling outward, so it
// reads against sand by day and does not paint a solid disc at night.
// sides: 1 for a wedge or strip (its side edges have a rim), 0 for a disc.
// cross: the number of dashes round the rim.
uniform vec4 tint : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float sides = 1.0;
uniform float dashes = 24.0;
uniform float ready = 0.0;      // 0 while the weave forms, 1 when it can go

void fragment() {
	float far_rim = smoothstep(0.9, 0.975, UV.y) * (1.0 - smoothstep(0.985, 1.0, UV.y));
	float side_d = min(UV.x, 1.0 - UV.x);
	float side_rim = sides * smoothstep(0.06, 0.015, side_d) * smoothstep(0.0, 0.004, side_d);
	float march = step(0.42, fract(UV.x * dashes - TIME * 0.9));
	float rim = max(far_rim * mix(0.55, 1.0, march), side_rim);
	float wave = smoothstep(0.86, 1.0, fract(UV.y * 3.0 - TIME * (0.7 + ready * 0.8))) * 0.35;
	float fill = 0.035 + wave * (0.35 + 0.5 * ready);
	float a = max(rim * (0.75 + 0.25 * ready), fill);
	// COLOR.a: faded out where the ground climbs away (a cliff face, a bank).
	ALBEDO = tint.rgb * a * (1.2 + 0.6 * ready) * COLOR.a;
}
