shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, specular_schlick_ggx;
// Torrent's wave: a sheet of water rising off the ground to a curling crest. UV.x
// runs across the wave, UV.y up its face from the foot to the lip. Clear and dark
// low down, breaking white at the lip and in streaks thrown up its face; glossy so
// firelight runs on it. The scene behind is bent through it.
uniform vec4 body : source_color = vec4(0.06, 0.2, 0.24, 1.0);
uniform vec4 foam_col : source_color = vec4(0.85, 0.93, 0.95, 1.0);
uniform float fade = 1.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float n = noise(vec2(UV.x * 18.0, UV.y * 6.0 - TIME * 4.0)) * 0.6 + noise(vec2(UV.x * 40.0, UV.y * 14.0 - TIME * 7.0)) * 0.4;
	float lip = smoothstep(0.42, 0.8, UV.y + n * 0.35);
	float streak = smoothstep(0.55, 0.85, n) * smoothstep(0.1, 0.5, UV.y);
	float foam = clamp(lip + streak * 0.7, 0.0, 1.0);
	vec2 bend = vec2(n - 0.5, n - 0.5) * 0.015;
	vec3 behind = textureLod(screen_tex, SCREEN_UV + bend, 0.0).rgb;
	float ends = smoothstep(0.0, 0.25, UV.x + (n - 0.5) * 0.1) * smoothstep(1.0, 0.75, UV.x - (n - 0.5) * 0.1);
	ALBEDO = mix(mix(behind * 0.4, body.rgb, 0.75), foam_col.rgb, foam);
	EMISSION = foam_col.rgb * foam * 0.08 + body.rgb * 0.05;
	ROUGHNESS = mix(0.3, 0.8, foam);
	SPECULAR = 0.35;
	ALPHA = clamp((0.7 + foam * 0.3) * ends * fade * smoothstep(0.0, 0.08, UV.y), 0.0, 1.0);
}
