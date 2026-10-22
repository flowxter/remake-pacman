class_name OptionsMenu
extends Control

## Menu previo a la partida, estilo arcade: flechas para navegar, izquierda
## y derecha para cambiar el valor, Enter para empezar.
##
## Cada fila es una palanca de dificultad real, no decoracion: todas se leen
## desde Difficulty y afectan a la simulacion. La fila seleccionada muestra
## triangulos a los lados del valor para que se vea que se cambia deslizando,
## y una linea de ayuda abajo explica que hace.

signal play_requested(diff: Difficulty)
signal ui_sound(sound_name: String)

const ROWS := [
	{"id": "preset", "label": "AJUSTE RAPIDO", "section": "",
		"help": "Carga una combinacion lista. Luego puedes retocar cualquier fila."},

	{"id": "maze", "label": "TAMANO", "section": "LABERINTO",
		"help": "Grande = mas pellets y mas sitio donde esconderse."},
	{"id": "complexity", "label": "COMPLEJIDAD", "section": "",
		"help": "Cuanta masa de pared. Mas alto = pasillos mas cerrados."},
	{"id": "seed", "label": "SEMILLA", "section": "",
		"help": "Fija el numero y saldran siempre los mismos laberintos."},

	{"id": "ghosts", "label": "CUANTOS", "section": "FANTASMAS",
		"help": "Los dos ultimos no son del arcade: objetivo aleatorio y campeo."},
	{"id": "ghost_speed", "label": "VELOCIDAD", "section": "",
		"help": "Multiplica la tabla del arcade. x1.00 es la velocidad original."},
	{"id": "ai", "label": "INTELIGENCIA", "section": "",
		"help": "CLASICA es la del arcade. ELITE usa pathfinding y no perdona."},
	{"id": "tunnel", "label": "FRENAZO TUNEL", "section": "",
		"help": "En el arcade frenan al cruzar el tunel. Quitarlo te deja sin escape."},
	{"id": "pinky", "label": "BUG DE PINKY", "section": "",
		"help": "El fallo de calculo original cuando Pac-Man mira hacia arriba."},

	{"id": "lives", "label": "VIDAS", "section": "PARTIDA",
		"help": "Con cuantas empiezas. Ganas una al llegar a 10000 puntos."},
	{"id": "power", "label": "POWER PELLET", "section": "",
		"help": "Cuanto duran. SIN EFECTO los vuelve puntos de 50 y nada mas."},
	{"id": "fruit", "label": "FRUTAS", "section": "",
		"help": "Aparecen dos por nivel y dan puntos extra."},
	{"id": "fog", "label": "NIEBLA", "section": "",
		"help": "Solo ves el laberinto alrededor de Pac-Man. Brutal."},
	{"id": "level", "label": "NIVEL INICIAL", "section": "",
		"help": "Empezar alto = fantasmas rapidos desde el primer momento."},
]

const MAZE_SIZES := ["small", "classic", "large"]
const AI_LABELS := ["CLASICA", "ELITE", "MIXTA"]

const TOP := 98.0
const ROW_H := 23.0
const SECTION_H := 18.0

var diff := Difficulty.preset("classic")
var preset_index: int = 1
var cursor: int = 0
var asset_note: String = ""
var seed_digits: String = ""

var _font: Font
var _blink: float = 0.0
var _row_y: PackedFloat32Array = PackedFloat32Array()


## Importa que sea set_anchors_AND_OFFSETS_preset: colgado de un CanvasLayer
## no hay padre que calcule el layout, y fijar solo los anclajes deja el
## size a cero.
func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_rows()


func _layout_rows() -> void:
	_row_y.resize(ROWS.size())
	var y := TOP
	for i in range(ROWS.size()):
		if not String(ROWS[i]["section"]).is_empty():
			y += SECTION_H
		_row_y[i] = y
		y += ROW_H


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
			ui_sound.emit("menu_move")
		KEY_DOWN, KEY_S:
			cursor = posmod(cursor + 1, ROWS.size())
			ui_sound.emit("menu_move")
		KEY_LEFT, KEY_A:
			_change(-1)
			ui_sound.emit("menu_change")
		KEY_RIGHT, KEY_D:
			_change(1)
			ui_sound.emit("menu_change")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_commit_seed()
			ui_sound.emit("menu_select")
			play_requested.emit(diff.duplicate_cfg())
		KEY_BACKSPACE:
			if _row_id() == "seed" and not seed_digits.is_empty():
				seed_digits = seed_digits.substr(0, seed_digits.length() - 1)
				_commit_seed()
				ui_sound.emit("menu_change")
		KEY_R:
			if _row_id() == "seed":
				seed_digits = str(randi() % 1000000)
				_commit_seed()
				ui_sound.emit("menu_change")
		_:
			if _row_id() == "seed":
				var ch := char(k.unicode)
				if ch.is_valid_int() and seed_digits.length() < 9:
					seed_digits += ch
					_commit_seed()
					ui_sound.emit("menu_change")


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


# -- dibujo ------------------------------------------------------------------

func _draw() -> void:
	if _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG)
	var cx := size.x * 0.5

	_centered("PAC-MAN", Vector2(cx, 44), 32, Palette.TEXT_ACCENT)
	_centered("R E M A K E", Vector2(cx, 64), 12, Palette.GATE)
	_centered("un laberinto nuevo en cada nivel", Vector2(cx, 84), 10, Palette.TEXT_DIM)
	Painter.pacman(self, Vector2(cx - 92, 38), 12.0, Vector2i.RIGHT, _blink * 7.0)
	Painter.ghost(self, Vector2(cx + 92, 38), 12.0, Vector2i.LEFT, Palette.ghost_body(0), _blink * 6.0)

	for i in range(ROWS.size()):
		_draw_row(i)

	# Ayuda de la fila seleccionada: evita tener que adivinar que hace cada cosa.
	var help := String(ROWS[cursor]["help"])
	_centered(help, Vector2(cx, size.y - 76), 11, Palette.GATE)

	var pulse := 0.65 + 0.35 * sin(_blink * 4.0)
	var play_col := Palette.TEXT_ACCENT
	play_col.a = pulse
	_centered("ENTER  -  JUGAR", Vector2(cx, size.y - 50), 15, play_col)
	_centered("flechas: moverse y cambiar     en SEMILLA: teclea, R aleatoria",
		Vector2(cx, size.y - 30), 9, Palette.TEXT_DIM)
	_centered("en partida:  P pausa    M silencio    N otro laberinto    ESC menu",
		Vector2(cx, size.y - 17), 9, Palette.TEXT_DIM)
	if not asset_note.is_empty():
		_centered(asset_note, Vector2(cx, size.y - 4), 9, Palette.TEXT_DIM)


func _draw_row(i: int) -> void:
	var y: float = _row_y[i]
	var section := String(ROWS[i]["section"])
	if not section.is_empty():
		_text(section, Vector2(34, y - 6), 10, Palette.GATE)
		draw_line(Vector2(34 + _width(section, 10) + 8, y - 10),
			Vector2(size.x - 34, y - 10), Color(1, 1, 1, 0.12), 1.0)

	var selected := i == cursor
	var col := Palette.TEXT_ACCENT if selected else Palette.TEXT
	if selected:
		draw_rect(Rect2(Vector2(26, y - 1), Vector2(size.x - 52, ROW_H - 3)), Color(1, 1, 1, 0.08))

	_text(String(ROWS[i]["label"]), Vector2(48, y + 15), 13, col)

	var val := _value_text(String(ROWS[i]["id"]))
	if selected and String(ROWS[i]["id"]) == "seed" and fmod(_blink, 1.0) < 0.5:
		val += "_"
	var right := size.x - 60.0
	var vw := _width(val, 13)
	_right(val, Vector2(right, y + 15), 13, Palette.GATE if selected else Palette.TEXT_DIM)

	# Triangulos a los lados del valor: dicen "esto se cambia deslizando".
	if selected:
		var mid := y + 10.0
		_arrow(Vector2(right - vw - 14, mid), -1.0, Palette.TEXT_ACCENT)
		_arrow(Vector2(right + 14, mid), 1.0, Palette.TEXT_ACCENT)


func _arrow(at: Vector2, dir: float, col: Color) -> void:
	var w := 5.0
	var h := 6.0
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(w * dir, 0.0),
		at + Vector2(-w * dir, -h * 0.5),
		at + Vector2(-w * dir, h * 0.5),
	]), col)


func _width(s: String, px: int) -> float:
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


func _text(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _centered(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font, at - Vector2(_width(s, px) * 0.5, 0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _right(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font, at - Vector2(_width(s, px), 0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
