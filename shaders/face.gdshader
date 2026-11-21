shader_type spatial;
// A face that can be shaped (face_deform.gdshaderinc): the head, eyes and brows,
// drawn as the pack's material had them, tinted as chosen.
#include "res://shaders/face_deform.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float rough = 0.7;
uniform bool cutout = false;

void vertex() { VERTEX += face_shape(CUSTOM0.xyz); }

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (cutout && c.a < 0.5) { discard; }
	ALBEDO = c.rgb * tint.rgb;
	ROUGHNESS = rough;
	if (has_normal) { NORMAL_MAP = texture(normal_tex, UV).rgb; }
}
