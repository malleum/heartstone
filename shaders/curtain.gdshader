shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// A Wall of Water: a standing sheet falling without end. UV.y is 0 at the top and
// 1 at the foot, where it foams. `fade` takes it away when the weave is let go.
uniform vec4 tint : source_color = vec4(0.45, 0.75, 1.0, 1.0);
uniform float fade = 1.0;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float cx = UV.x * 48.0;
	float c0 = floor(cx); float fr = smoothstep(0.0, 1.0, fract(cx));
	float speed = 0.8 + mix(hash(c0), hash(c0 + 1.0), fr) * 0.9;
	float ph = mix(hash(c0 + 3.0), hash(c0 + 4.0), fr) * 6.28;
	float streak = smoothstep(0.3, 1.0, sin(UV.y * 11.0 - TIME * speed * 3.0 + ph) * 0.5 + 0.5);
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	float foam = smoothstep(0.84, 1.0, UV.y);
	float top = smoothstep(0.0, 0.1, UV.y);
	float a = (0.16 + 0.34 * streak + 0.5 * foam) * edge * top * fade;
	ALBEDO = mix(tint.rgb, vec3(1.0), foam * 0.8 + streak * 0.25);
	ALPHA = clamp(a, 0.0, 0.85);
}
