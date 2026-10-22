class_name AudioBank
extends Node

## Reproduccion de efectos. Los sonidos sintetizados son la base y los
## archivos de assets/sounds los sustituyen por nombre.

const VOICES := 6

var streams: Dictionary = {}
var muted: bool = false

var _voices: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _ambient_name: String = ""
var _next: int = 0
var _waka_flip: bool = false


func setup(bank: AssetBank) -> void:
	streams = Sfx.build_all()
	if bank != null:
		for k in bank.sounds.keys():
			streams[k] = bank.sounds[k]
	for _i in range(VOICES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = -4.0
	add_child(_ambient)


func play(sound_name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if muted:
		return
	var s: AudioStream = streams.get(sound_name, null)
	if s == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()


## Comer alterna dos sonidos para que suene a masticacion, como el arcade.
func waka() -> void:
	play("waka_b" if _waka_flip else "waka_a", 1.0, -3.0)
	_waka_flip = not _waka_flip


## Bucle de fondo: "siren" o "fright". Solo reinicia si cambia.
func set_ambient(sound_name: String, pitch: float = 1.0) -> void:
	if muted:
		stop_ambient()
		return
	if sound_name.is_empty():
		stop_ambient()
		return
	var s: AudioStream = streams.get(sound_name, null)
	if s == null:
		return
	_ambient.pitch_scale = pitch
	if _ambient_name == sound_name and _ambient.playing:
		return
	_ambient_name = sound_name
	_ambient.stream = s
	_ambient.play()


func stop_ambient() -> void:
	_ambient_name = ""
	if _ambient != null and _ambient.playing:
		_ambient.stop()


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		stop_ambient()
		for p in _voices:
			p.stop()
	return muted
