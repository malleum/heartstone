// Shaping a sourced face that has no shape keys: each feature is a soft region of
// the head, found on its rest pose (CUSTOM0, Hero._bake_rest) from the eyes, and
// moved a few millimetres. Shared by the head, eyes, brows and beard (Hero.FACE),
// so they all keep together. f_* run from -1 to 1; all zero leaves it as made.
uniform vec2 face_at = vec2(1.7, 0.0);   // eye height (x) and the head's middle front to back (y)
uniform float face_front = 0.07;         // the front of the eyes, front to back
uniform float f_width = 0.0;
uniform float f_jaw = 0.0;
uniform float f_chin = 0.0;
uniform float f_nose = 0.0;
uniform float f_cheek = 0.0;
uniform float f_brow = 0.0;

float sq(float x) { return x * x; }   // (pow of a negative number is undefined in GLSL)

vec3 face_shape(vec3 r) {
	float ey = face_at.x; float cz = face_at.y;
	float front = smoothstep(cz - 0.02, cz + 0.05, r.z);
	// The face from forehead to chin, not the neck or the crown.
	float band = smoothstep(ey + 0.09, ey + 0.03, r.y) * smoothstep(ey - 0.2, ey - 0.13, r.y);
	vec3 d = vec3(0.0);
	d.x += r.x * 0.14 * f_width * front * band;
	float jaw = smoothstep(ey - 0.05, ey - 0.11, r.y) * smoothstep(ey - 0.21, ey - 0.15, r.y) * smoothstep(cz - 0.07, cz + 0.02, r.z);
	d.x += r.x * 0.24 * f_jaw * jaw;
	float chin = exp(-(r.x * r.x) / 0.0012 - sq(r.y - (ey - 0.115)) / 0.0009) * front;
	d.z += 0.018 * f_chin * chin; d.y -= 0.008 * f_chin * chin;
	float nose = exp(-(r.x * r.x) / 0.00025 - sq(r.y - (ey - 0.032)) / 0.0008) * smoothstep(face_front - 0.03, face_front + 0.01, r.z);
	d.z += 0.016 * f_nose * nose; d.y -= 0.004 * f_nose * nose;
	float cheek = exp(-sq(abs(r.x) - 0.045) / 0.0006 - sq(r.y - (ey - 0.035)) / 0.001) * front;
	d.x += sign(r.x) * 0.011 * f_cheek * cheek; d.z += 0.005 * f_cheek * cheek;
	float brow = exp(-sq(r.y - (ey + 0.022)) / 0.0003) * smoothstep(face_front - 0.04, face_front, r.z) * smoothstep(0.07, 0.02, abs(r.x));
	d.z += 0.009 * f_brow * brow; d.y += 0.002 * f_brow * brow;
	return d;
}
