class_name Hud
extends Control

## Marcador, vidas, nivel y mensajes centrados sobre el tablero.

var sim: GameSim
var board_rect: Rect2 = Rect2()
var high_score: int = 0
var message: String = ""
var message_color: Color = Palette.TEXT_ACCENT
var sub_message: String = ""
var seed_text: String = ""

var _font: Font


## Importa que sea set_anchors_AND_OFFSETS_preset: colgado de un CanvasLayer
## no hay padre que calcule el layout, y fijar solo los anclajes deja el
## size a cero.
func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var w := size.x
	_text("1UP", Vector2(14, 16), 11, Palette.TEXT_DIM)
	_text("%d" % (sim.score if sim != null else 0), Vector2(14, 32), 15, Palette.TEXT)

	_text("HIGH SCORE", Vector2(w * 0.5 - 38, 16), 11, Palette.TEXT_DIM)
	_text("%d" % high_score, Vector2(w * 0.5 - 38, 32), 15, Palette.TEXT)

	if sim != null:
		_text("NIVEL %d" % sim.level, Vector2(w - 86, 16), 11, Palette.TEXT_DIM)
		var mode := "CAZA" if sim.in_chase else "DISPERSION"
		if sim.fright_timer > 0.0:
			mode = "HUIDA %.1f" % sim.fright_timer
		_text(mode, Vector2(w - 86, 32), 11, Palette.TEXT_ACCENT)

	# vidas y semilla abajo
	if sim != null:
		var y := size.y - 14.0
		for i in range(mini(sim.lives, 8)):
			Painter.life_icon(self, Vector2(18 + i * 20, y), 7.0)
		_text(seed_text, Vector2(size.x - 150, y + 4), 10, Palette.TEXT_DIM)

	if not message.is_empty():
		# Justo debajo de la casa de fantasmas, donde lo pone el arcade, para
		# no taparla.
		var center := Vector2(board_rect.get_center().x,
			board_rect.position.y + board_rect.size.y * 0.60)
		_centered(message, center + Vector2(0, -6), 22, message_color)
		if not sub_message.is_empty():
			_centered(sub_message, center + Vector2(0, 22), 12, Palette.TEXT_DIM)


func _text(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _centered(s: String, at: Vector2, px: int, col: Color) -> void:
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(_font, at - Vector2(w * 0.5, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
