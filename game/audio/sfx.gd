class_name Sfx
extends RefCounted

## Sintesis de los efectos de sonido en tiempo de arranque.
##
## El hardware de Pac-Man generaba el audio con un sintetizador de 3 voces y
## formas de onda en una ROM, asi que recrearlo por sintesis es mas fiel que
## usar un sample cualquiera. Y como el juego no depende de ningun archivo,
## arranca con sonido desde el primer dia. Los .wav originales siguen
## pudiendo sustituir cualquiera de estos (ver AssetBank).

const RATE := 22050


static func build_all() -> Dictionary:
	return {
		"waka_a": _waka(440.0, 1050.0),
		"waka_b": _waka(1050.0, 440.0),
		"siren": _siren(),
		"fright": _fright(),
		"eat_ghost": _eat_ghost(),
		"death": _death(),
		"extra_life": _extra_life(),
		"fruit": _fruit(),
		"ready": _ready_jingle(),
	}


# -- utilidades --------------------------------------------------------------

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


static func _square(phase: float, duty: float = 0.5) -> float:
	return 1.0 if fposmod(phase, 1.0) < duty else -1.0


## Envolvente de ataque/caida corta: evita el "click" en los extremos.
static func _env(i: int, n: int, attack: float = 0.02, release: float = 0.25) -> float:
	var t := float(i) / float(maxi(n - 1, 1))
	var a := clampf(t / maxf(attack, 0.0001), 0.0, 1.0)
	var r := clampf((1.0 - t) / maxf(release, 0.0001), 0.0, 1.0)
	return a * r


# -- efectos -----------------------------------------------------------------

## El "wakka": un barrido corto de tono. El original alterna dos para que
## comer suene como una masticacion.
static func _waka(f0: float, f1: float) -> AudioStreamWAV:
	var n := int(RATE * 0.075)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		phase += f / float(RATE)
		out[i] = _square(phase, 0.5) * _env(i, n, 0.08, 0.35) * 0.30
	return _wav(out, false)


## Sirena de fondo: onda cuadrada con un LFO de tono. Se reproduce en bucle
## y la velocidad sube con el nivel via pitch_scale.
static func _siren() -> AudioStreamWAV:
	var dur := 0.52
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(RATE)
		var f := 310.0 + 130.0 * sin(TAU * t / dur)
		phase += f / float(RATE)
		out[i] = _square(phase, 0.35) * 0.14
	return _wav(out, true)


## Sirena de power pellet: mas rapida y mas grave.
static func _fright() -> AudioStreamWAV:
	var dur := 0.26
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(RATE)
		var f := 180.0 + 90.0 * sin(TAU * t / dur)
		phase += f / float(RATE)
		out[i] = _square(phase, 0.5) * 0.15
	return _wav(out, true)


static func _eat_ghost() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var f := lerpf(180.0, 1400.0, t * t)
		phase += f / float(RATE)
		out[i] = _square(phase, 0.5) * _env(i, n, 0.02, 0.2) * 0.26
	return _wav(out, false)


## Muerte: barrido descendente con tremolo.
static func _death() -> AudioStreamWAV:
	var n := int(RATE * 1.3)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var f := lerpf(900.0, 90.0, t) * (1.0 + 0.22 * sin(TAU * t * 14.0))
		phase += f / float(RATE)
		out[i] = _square(phase, 0.5) * _env(i, n, 0.01, 0.35) * 0.28
	return _wav(out, false)


static func _extra_life() -> AudioStreamWAV:
	var n := int(RATE * 0.36)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var f := 700.0 if t < 0.5 else 1050.0
		phase += f / float(RATE)
		out[i] = _square(phase, 0.5) * _env(i, n, 0.03, 0.2) * 0.24
	return _wav(out, false)


static func _fruit() -> AudioStreamWAV:
	var n := int(RATE * 0.3)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in range(n):
		var t := float(i) / float(n)
		var f := lerpf(500.0, 1200.0, t) + 200.0 * sin(TAU * t * 9.0)
		phase += f / float(RATE)
		out[i] = _square(phase, 0.4) * _env(i, n, 0.03, 0.3) * 0.22
	return _wav(out, false)


## Melodia de arranque. La del arcade es una composicion concreta de Namco,
## asi que esta es un arpegio propio con el mismo papel: avisar de que la
## ronda empieza. Se puede sustituir por el original en assets/sounds.
static func _ready_jingle() -> AudioStreamWAV:
	var notes := [392.0, 523.25, 659.25, 783.99]
	var note_len := 0.14
	var n := int(RATE * note_len * float(notes.size()))
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var per := int(RATE * note_len)
	for i in range(n):
		var ni := mini(int(i / per), notes.size() - 1)
		var f: float = notes[ni]
		phase += f / float(RATE)
		out[i] = _square(phase, 0.5) * _env(i % per, per, 0.06, 0.35) * 0.22
	return _wav(out, false)
