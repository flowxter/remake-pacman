class_name OptionsMenu
extends Control

## Menu previo a la partida, estilo arcade: flechas para navegar, izquierda
## y derecha para cambiar el valor, Enter para empezar.
##
## Cada fila es una palanca de dificultad real, no decoracion: todas se leen
## desde Difficulty y afectan a la simulacion.

signal play_requested(diff: Difficulty)

const ROWS := [
	{"id": "preset", "label": "AJUSTE"},
	{"id": "maze", "label": "LABERINTO"},
	{"id": "complexity", "label": "COMPLEJIDAD"},
	{"id": "ghosts", "label": "FANTASMAS"},
	{"id": "ghost_speed", "label": "VELOCIDAD"},
	{"id": "ai", "label": "IA"},
	{"id": "lives", "label": "VIDAS"},
	{"id": "power", "label": "POWER PELLET"},
	{"id": "tunnel", "label": "FRENAZO TUNEL"},
	{"id": "pinky", "label": "BUG DE PINKY"},
	{"id": "fruit", "label": "FRUTAS"},
	{"id": "fog", "label": "NIEBLA"},
	{"id": "level", "label": "NIVEL INICIAL"},
	{"id": "seed", "label": "SEMILLA"},
]

const MAZE_SIZES := ["small", "classic", "large"]
const AI_LABELS := ["CLASICA", "ELITE", "MIXTA"]

var diff := Difficulty.preset("classic")
var preset_index: int = 1
var cursor: int = 0
var asset_note: String = ""
var seed_digits: String = ""

var _font: Font
var _blink: float = 0.0


## Importa que sea set_anchors_AND_OFFSETS_preset: colgado de un CanvasLayer
## no hay padre que calcule el layout, y fijar solo los anclajes deja el
## size a cero.
func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	_blink += dt
	queue_redraw()


## El input lo reenvia main para que haya un unico camino.
func handle_key(event: InputEventKey) -> void:
	_handle(event)


func _handle(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_UP, KEY_W:
			cursor = posmod(cursor - 1, ROWS.size())
		KEY_DOWN, KEY_S:
			cursor = posmod(cursor + 1, ROWS.size())
		KEY_LEFT, KEY_A:
			_change(-1)
		KEY_RIGHT, KEY_D:
			_change(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_commit_seed()
			play_requested.emit(diff.duplicate_cfg())
		KEY_BACKSPACE:
			if _row_id() == "seed" and not seed_digits.is_empty():
				seed_digits = seed_digits.substr(0, seed_digits.length() - 1)
				_commit_seed()
		KEY_R:
			if _row_id() == "seed":
				seed_digits = str(randi() % 1000000)
				_commit_seed()
		_:
			if _row_id() == "seed":
				var ch := char(k.unicode)
				if ch.is_valid_int() and seed_digits.length() < 9:
					seed_digits += ch
					_commit_seed()


func _row_id() -> String:
	return String(ROWS[cursor]["id"])


func _commit_seed() -> void:
	diff.seed = int(seed_digits) if not seed_digits.is_empty() else 0


func _change(step: int) -> void:
	match _row_id():
		"preset":
			var names := Difficulty.preset_names()
			preset_index = posmod(preset_index + step, names.size())
			var keep_seed := diff.seed
			diff = Difficulty.preset(names[preset_index])
			diff.seed = keep_seed
		"maze":
			var i := MAZE_SIZES.find(diff.maze_size)
			diff.maze_size = MAZE_SIZES[posmod(i + step, MAZE_SIZES.size())]
		"complexity":
			diff.block_ratio = clampf(diff.block_ratio + 0.02 * float(step), 0.04, 0.24)
			# mas masas de pared -> menos ciclos, para que no quede laberintico
			diff.loop_ratio = clampf(0.40 - diff.block_ratio, 0.16, 0.42)
		"ghosts":
			diff.ghost_count = clampi(diff.ghost_count + step, 2, 6)
		"ghost_speed":
			diff.ghost_speed = clampf(diff.ghost_speed + 0.05 * float(step), 0.60, 1.60)
		"ai":
			var order: Array[Difficulty.AI] = [
				Difficulty.AI.CLASSIC, Difficulty.AI.ELITE, Difficulty.AI.MIXED,
			]
			var ai_i := order.find(diff.ai)
			diff.ai = order[posmod(maxi(ai_i, 0) + step, order.size())]
		"lives":
			diff.lives = clampi(diff.lives + step, 1, 5)
		"power":
			diff.power_duration = clampf(diff.power_duration + 0.25 * float(step), 0.0, 2.5)
		"tunnel":
			diff.tunnel_slowdown = not diff.tunnel_slowdown
		"pinky":
			diff.pinky_overflow_bug = not diff.pinky_overflow_bug
		"fruit":
			diff.fruit_enabled = not diff.fruit_enabled
		"fog":
			var fogs := [0.0, 12.0, 9.0, 6.0]
			var fi := fogs.find(diff.vision_radius)
			if fi < 0:
				fi = 0
			diff.vision_radius = float(fogs[posmod(fi + step, fogs.size())])
		"level":
			diff.start_level = clampi(diff.start_level + step, 1, 20)
		"seed":
			var s := int(seed_digits) if not seed_digits.is_empty() else 0
			s = maxi(s + step, 0)
			seed_digits = "" if s == 0 else str(s)
			_commit_seed()


func _value_text(id: String) -> String:
	match id:
		"preset":
			return Difficulty.preset_label(Difficulty.preset_names()[preset_index])
		"maze":
			var labels := {"small": "PEQUENO", "classic": "CLASICO", "large": "GRANDE"}
			return String(labels[diff.maze_size])
		"complexity":
			return "%d%%" % int(round(diff.block_ratio * 100.0))
		"ghosts":
			return str(diff.ghost_count)
		"ghost_speed":
			return "x%.2f" % diff.ghost_speed
		"ai":
			return String(AI_LABELS[int(diff.ai)])
		"lives":
			return str(diff.lives)
		"power":
			return "SIN EFECTO" if diff.power_duration <= 0.0 else "x%.2f" % diff.power_duration
		"tunnel":
			return "SI" if diff.tunnel_slowdown else "NO"
		"pinky":
			return "SI" if diff.pinky_overflow_bug else "NO"
		"fruit":
			return "SI" if diff.fruit_enabled else "NO"
		"fog":
			return "NO" if diff.vision_radius <= 0.0 else "%d TILES" % int(diff.vision_radius)
		"level":
			return str(diff.start_level)
		"seed":
			return "ALEATORIA" if diff.seed == 0 else str(diff.seed)
	return ""


func _draw() -> void:
	if _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG)

	var cx := size.x * 0.5
	_centered("PAC-MAN", Vector2(cx, 46), 34, Palette.TEXT_ACCENT)
	_centered("R E M A K E", Vector2(cx, 68), 13, Palette.GATE)
	_centered("laberintos aleatorios", Vector2(cx, 88), 11, Palette.TEXT_DIM)

	# Pac-Man y un fantasma de adorno, con la animacion viva
	Painter.pacman(self, Vector2(cx - 74, 40), 13.0, Vector2i.RIGHT, _blink * 7.0)
	Painter.ghost(self, Vector2(cx + 74, 40), 13.0, Vector2i.LEFT, Palette.ghost_body(0), _blink * 6.0)

	var y := 120.0
	var row_h := 26.0
	for i in range(ROWS.size()):
		var id := String(ROWS[i]["id"])
		var selected := i == cursor
		var col := Palette.TEXT_ACCENT if selected else Palette.TEXT
		if selected:
			draw_rect(Rect2(Vector2(28, y - 13), Vector2(size.x - 56, row_h - 4)), Color(1, 1, 1, 0.07))
			_text(">", Vector2(34, y + 4), 13, Palette.GATE)
		_text(String(ROWS[i]["label"]), Vector2(52, y + 4), 13, col)
		var val := _value_text(id)
		if selected and id == "seed" and fmod(_blink, 1.0) < 0.5:
			val += "_"
		_right(val, Vector2(size.x - 48, y + 4), 13, Palette.GATE if selected else Palette.TEXT_DIM)
		y += row_h

	y += 6.0
	_centered("ENTER  JUGAR          FLECHAS  CAMBIAR", Vector2(cx, y), 11, Palette.TEXT_DIM)
	_centered("en SEMILLA: teclea numeros, R aleatoria, RETROCESO borra", Vector2(cx, y + 16), 10, Palette.TEXT_DIM)
	_centered("en partida: P pausa   M silencio   N nuevo laberinto   ESC menu", Vector2(cx, y + 32), 10, Palette.TEXT_DIM)
	if not asset_note.is_empty():
		_centered(asset_note, Vector2(cx, y + 52), 10, Palette.TEXT_DIM)


func _text(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _centered(s: String, at: Vector2, px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, at - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _right(s: String, at: Vector2, px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, at - Vector2(w, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
