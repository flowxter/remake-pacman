class_name AssetBank
extends RefCounted

## Capa de assets intercambiable.
##
## El juego arranca y es jugable sin ningun archivo: los sprites se dibujan
## por codigo y los sonidos se sintetizan. Si existen archivos en la carpeta
## assets/, sustituyen a los procedurales uno por uno.
##
## Se cargan en tiempo de ejecucion (no como recursos importados) para que
## baste con copiar los archivos y volver a lanzar el juego, sin pasar por
## el editor.
##
## Convencion de nombres en assets/sprites (PNG):
##   pacman_right_1.png  pacman_right_2.png   -> fotogramas de animacion
##   pacman_up_1.png     ...                     (left / right / up / down)
##   blinky_left_1.png   pinky_up_2.png       -> idem por fantasma
##   frightened_1.png    frightened_flash_1.png
##   eyes_up.png  eyes_down.png  eyes_left.png  eyes_right.png
##   pellet.png  power.png  cherry.png  strawberry.png  ...
##
## En assets/sounds (WAV o OGG), con el nombre del efecto:
##   waka_a  waka_b  siren  fright  eat_ghost  death  extra_life  fruit  ready

var frames: Dictionary = {}      ## nombre -> Array[Texture2D]
var sounds: Dictionary = {}      ## nombre -> AudioStream
var sprite_files: int = 0
var sound_files: int = 0
var root: String = ""


func load_all() -> void:
	frames.clear()
	sounds.clear()
	sprite_files = 0
	sound_files = 0
	root = _find_root()
	if root.is_empty():
		return
	_load_sprites(root.path_join("sprites"))
	_load_sounds(root.path_join("sounds"))


func _find_root() -> String:
	var candidates := [
		ProjectSettings.globalize_path("res://assets"),
		OS.get_executable_path().get_base_dir().path_join("assets"),
	]
	for c in candidates:
		if DirAccess.dir_exists_absolute(c):
			return c
	return ""


func _load_sprites(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	var names := d.get_files()
	names.sort()
	for file_name in names:
		if file_name.get_extension().to_lower() not in ["png", "webp", "jpg", "jpeg"]:
			continue
		var img := Image.load_from_file(dir_path.path_join(file_name))
		if img == null:
			push_warning("no se pudo leer el sprite %s" % file_name)
			continue
		var tex := ImageTexture.create_from_image(img)
		var key := file_name.get_basename()
		# "pacman_right_2" -> grupo "pacman_right", fotograma 2
		var parts := key.split("_")
		if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
			parts.remove_at(parts.size() - 1)
			key = "_".join(parts)
		if not frames.has(key):
			frames[key] = [] as Array[Texture2D]
		var arr: Array = frames[key]
		arr.append(tex)
		sprite_files += 1


func _load_sounds(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for file_name in d.get_files():
		var ext := file_name.get_extension().to_lower()
		var full := dir_path.path_join(file_name)
		var stream: AudioStream = null
		if ext == "ogg":
			stream = AudioStreamOggVorbis.load_from_file(full)
		elif ext == "wav":
			stream = load_wav(full)
		if stream == null:
			continue
		var key := file_name.get_basename()
		if key in ["siren", "fright"] and stream is AudioStreamWAV:
			var w: AudioStreamWAV = stream
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.data.size() / (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1))
		sounds[key] = stream
		sound_files += 1


# -- consulta ----------------------------------------------------------------

func has_frames(key: String) -> bool:
	return frames.has(key) and not (frames[key] as Array).is_empty()


## Fotograma `i` del grupo `key`, ciclando. null si no hay override.
func frame(key: String, i: int) -> Texture2D:
	if not has_frames(key):
		return null
	var arr: Array = frames[key]
	return arr[posmod(i, arr.size())]


func sound(key: String) -> AudioStream:
	return sounds.get(key, null)


func report() -> String:
	if root.is_empty() or (sprite_files == 0 and sound_files == 0):
		return "assets: sprites y sonidos procedurales (copia los tuyos en assets/)"
	return "assets: %d sprites y %d sonidos propios cargados" % [sprite_files, sound_files]


# -- lector de WAV en tiempo de ejecucion ------------------------------------

## Godot solo carga .wav como recurso importado. Este lector permite copiar
## los .wav originales en assets/sounds y que funcionen sin reimportar.
static func load_wav(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if bytes.size() < 44:
		return null
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	if bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null

	var pos := 12
	var channels := 1
	var rate := 22050
	var bits := 16
	var fmt_code := 1
	var data := PackedByteArray()
	while pos + 8 <= bytes.size():
		var cid := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var csize := int(bytes.decode_u32(pos + 4))
		var cstart := pos + 8
		if cid == "fmt " and cstart + 16 <= bytes.size():
			fmt_code = bytes.decode_u16(cstart)
			channels = maxi(int(bytes.decode_u16(cstart + 2)), 1)
			rate = int(bytes.decode_u32(cstart + 4))
			bits = int(bytes.decode_u16(cstart + 14))
		elif cid == "data":
			data = bytes.slice(cstart, mini(cstart + csize, bytes.size()))
		pos = cstart + csize + (csize & 1)
		if csize <= 0:
			break
	if data.is_empty():
		return null

	# Normalizar a PCM 16 bits, que es lo que espera AudioStreamWAV.
	var out := PackedByteArray()
	if fmt_code == 1 and bits == 16:
		out = data
	elif fmt_code == 1 and bits == 8:
		out.resize((data.size()) * 2)
		for i in range(data.size()):
			out.encode_s16(i * 2, (int(data[i]) - 128) * 256)
	elif fmt_code == 1 and bits == 24:
		var n24 := int(data.size() / 3)
		out.resize(n24 * 2)
		for i in range(n24):
			var v := data.decode_s16(i * 3 + 1)
			out.encode_s16(i * 2, v)
	elif fmt_code == 3 and bits == 32:
		var n32 := int(data.size() / 4)
		out.resize(n32 * 2)
		for i in range(n32):
			out.encode_s16(i * 2, int(clampf(data.decode_float(i * 4), -1.0, 1.0) * 32000.0))
	else:
		push_warning("WAV no soportado (%s): fmt=%d bits=%d" % [path.get_file(), fmt_code, bits])
		return null

	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = channels >= 2
	s.data = out
	return s
