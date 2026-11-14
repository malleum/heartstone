class_name Sfx
## Synthesized sound: every effect is a few lines of maths rendered once at startup.
## No audio files, in keeping with the generated creatures. Nobody has listened to
## these yet (see docs/PLAYTEST.md), so treat the recipes as first guesses.

const RATE := 22050
static var bank := {}

static func _render(secs: float, f: Callable) -> AudioStreamWAV:
	var n := int(secs * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(f.call(float(i) / RATE), -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = data
	return w

## White noise through a one-pole low-pass; `cut` 0..1 (1 = unfiltered).
static func _noise(state: Array, cut: float) -> float:
	state[0] = lerpf(state[0], randf_range(-1.0, 1.0), cut)
	return state[0]

static func build() -> void:
	if not bank.is_empty():
		return
	seed(7)
	var a := [0.0]; var b := [0.0]
	bank.boom = _render(1.3, func(t: float) -> float:
		return sin(TAU * (62.0 * t - 18.0 * t * t)) * exp(-t * 4.0) * 0.9 + _noise(a, 0.12) * exp(-t * 6.0) * 1.6 + _noise(b, 0.9) * exp(-t * 40.0) * 0.5)
	bank.whoosh = _render(0.5, func(t: float) -> float:
		var e := pow(sin(PI * t / 0.5), 2.0)
		return _noise(a, 0.05 + 0.5 * t) * e * 1.4)
	bank.crack = _render(1.6, func(t: float) -> float:
		return _noise(a, 1.0) * exp(-t * 28.0) + _noise(b, 0.06) * exp(-t * 2.6) * 2.4 * minf(t * 30.0, 1.0))
	bank.thud = _render(0.3, func(t: float) -> float:
		return sin(TAU * 85.0 * t) * exp(-t * 20.0) + _noise(a, 0.5) * exp(-t * 60.0) * 0.6)
	bank.rumble = _render(1.4, func(t: float) -> float:
		return _noise(a, 0.04) * exp(-t * 2.8) * 3.0 * minf(t * 20.0, 1.0) + _noise(b, 0.6) * exp(-t * 9.0) * 0.35)
	bank.hum = _render(0.7, func(t: float) -> float:
		var e := sin(PI * t / 0.7)
		return (sin(TAU * 196.0 * t) + 0.6 * sin(TAU * 294.0 * t) + 0.3 * sin(TAU * 588.0 * t + sin(TAU * 5.0 * t))) * e * 0.28)
	bank.chime = _render(0.9, func(t: float) -> float:
		return (sin(TAU * 660.0 * t) + 0.5 * sin(TAU * 990.0 * t)) * exp(-t * 4.0) * 0.4)
	# Steel on steel: a few inharmonic partials ringing down, with a click at the front.
	bank.clang = _render(0.8, func(t: float) -> float:
		return (sin(TAU * 1730.0 * t) + 0.7 * sin(TAU * 2610.0 * t) + 0.5 * sin(TAU * 4120.0 * t) + 0.4 * sin(TAU * 5870.0 * t)) * exp(-t * 7.0) * 0.22 + _noise(a, 1.0) * exp(-t * 90.0) * 0.7)
	# A bowstring: a low pluck that drops in pitch, and the slap of the string.
	bank.twang = _render(0.35, func(t: float) -> float:
		return sin(TAU * (210.0 * t - 160.0 * t * t)) * exp(-t * 14.0) * 0.7 + _noise(b, 0.7) * exp(-t * 70.0) * 0.5)
	randomize()

static func play(g: Node3D, name: String, at: Vector3, db := 0.0, pitch := 1.0) -> void:
	build()
	var p := AudioStreamPlayer3D.new()
	p.stream = bank[name]; p.volume_db = db; p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.unit_size = 14.0; p.max_distance = 160.0
	g.add_child(p); p.position = at
	p.finished.connect(p.queue_free)
	p.play()
