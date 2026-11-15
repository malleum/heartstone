shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
// The path of a blow, drawn where it cuts. UV.x runs along the sweep (0 where the
// blade starts, 1 where it ends) and UV.y from the inner edge (0) to the edge the
// blade's tip draws (1). `progress` goes 0 to 1 over the life of the streak: the
// bright front runs along the sweep and what is behind it fades.
uniform vec4 tint : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float sweep = 1.0;   // 1: the front runs along the sweep; 0: it all shows at once

void fragment() {
	float front = progress * 1.9;
	float shown = mix(1.0, smoothstep(0.0, 0.08, front - UV.x), sweep);
	float tail = mix(1.0, clamp(1.0 - (front - UV.x) * 0.9, 0.0, 1.0), sweep);
	// Thin and white at the tip's edge, soft and coloured behind it.
	float edge = smoothstep(0.55, 1.0, UV.y);
	float body = UV.y * UV.y;
	float ends = sin(clamp(UV.x, 0.0, 1.0) * 3.14159);
	float a = (body * 0.55 + edge * 1.2) * shown * tail * (1.0 - smoothstep(0.55, 1.0, progress)) * (0.35 + 0.65 * ends);
	ALBEDO = mix(tint.rgb, vec3(1.0), edge * 0.8) * a * 2.2;
	ALPHA = clamp(a, 0.0, 1.0);
}
