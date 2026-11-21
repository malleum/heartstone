shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// A Wall of Water: a standing sheet falling without end. UV.y is 0 at the top, 1 at
// the foot. `u0` and `ulen` give this stretch's place along the whole wall in
// metres, so the falling threads are the same size on every stretch. The scene
// behind is bent through it; threads of white run down, it boils white at the foot,
// and the top edge is ragged. `fade` takes it away when the weave is let go.
uniform vec4 tint : source_color = vec4(0.35, 0.62, 0.75, 1.0);
uniform float fade = 1.0;
uniform float u0 = 0.0;
uniform float ulen = 1.0;
uniform float height = 3.6;
uniform float total = 8.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

float hash(float n) { return fract(sin(n) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float s = u0 + UV.x * ulen;               // metres along the wall
	float y = UV.y * height;                  // metres down from the top
	// Falling threads: noise stretched tall, scrolling down at slightly different speeds.
	float th = noise(vec2(s * 11.0, y * 1.1 - TIME * 3.2)) * 0.5 + noise(vec2(s * 29.0 + 9.0, y * 2.0 - TIME * 4.6)) * 0.3 + noise(vec2(s * 4.0, y * 0.5 - TIME * 2.4)) * 0.2;
	float thread = smoothstep(0.55, 0.85, th) * 0.7;
	float foot = smoothstep(height - 0.9, height, y + noise(vec2(s * 3.0, TIME * 2.0)) * 0.4);
	float top = smoothstep(0.0, 0.35, y - noise(vec2(s * 2.5, TIME * 1.5)) * 0.3);
	float ends = smoothstep(0.0, 0.35, s) * smoothstep(total, total - 0.35, s);
	vec2 bend = vec2((th - 0.5) * 0.025, (noise(vec2(s * 5.0, y * 3.0 - TIME * 5.0)) - 0.5) * 0.012);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + bend, 0.0).rgb;
	vec3 water = mix(behind * 0.55 + tint.rgb * 0.3, vec3(0.8, 0.9, 0.95), thread * 0.4 + foot * 0.5);
	ALBEDO = water;
	ALPHA = clamp((0.7 + thread * 0.2 + foot * 0.2) * top * ends * fade, 0.0, 0.92);
}
