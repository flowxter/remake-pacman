class_name Painter
extends RefCounted

## Dibujo procedural de los sprites.
##
## OJO: todo se dibuja en unidades de tile (1.0 = un tile), no en pixeles.
## Los grosores de linea son fracciones de `r`, nunca valores absolutos.
##
## Pac-Man y los fantasmas del arcade son formas geometricas simples, asi que
## se dibujan por codigo en vez de depender de un spritesheet. Ventajas: el
## juego es jugable desde el primer arranque sin descargar nada, escala a
## cualquier resolucion sin perder nitidez, y los sprites originales siguen
## pudiendo sustituirlos (ver AssetBank).

const ARC_STEPS := 20


## Pac-Man: un circulo al que se le quita una cuna animada.
static func pacman(c: CanvasItem, center: Vector2, r: float, dir: Vector2i,
		phase: float, color: Color = Palette.PACMAN) -> void:
	var open := absf(sin(phase)) * 0.46
	if open < 0.02:
		c.draw_circle(center, r, color)
		return
	var base := 0.0
	if dir != Vector2i.ZERO:
		base = atan2(float(dir.y), float(dir.x))
	var pts := PackedVector2Array([center])
	for i in range(ARC_STEPS + 1):
		var a := lerpf(base + open, base + TAU - open, float(i) / float(ARC_STEPS))
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, color)


## Pac-Man muriendo: el circulo se cierra como un abanico hasta desaparecer.
static func pacman_dying(c: CanvasItem, center: Vector2, r: float, t: float,
		color: Color = Palette.PACMAN) -> void:
	var k := clampf(t, 0.0, 1.0)
	var open := lerpf(0.0, PI, k)
	if open >= PI - 0.02:
		return
	var pts := PackedVector2Array([center])
	for i in range(ARC_STEPS + 1):
		var a := lerpf(-PI * 0.5 + open, -PI * 0.5 + TAU - open, float(i) / float(ARC_STEPS))
		pts.append(center + Vector2(cos(a), sin(a)) * r * (1.0 - k * 0.25))
	c.draw_colored_polygon(pts, color)


## Fantasma: cupula semicircular, cuerpo recto y tres ondas abajo.
static func ghost(c: CanvasItem, center: Vector2, r: float, look: Vector2i,
		body: Color, wave_phase: float) -> void:
	var pts := PackedVector2Array()
	for i in range(ARC_STEPS + 1):
		var a := lerpf(PI, TAU, float(i) / float(ARC_STEPS))
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	var shoulder := center.y + r * 0.55
	var deep := center.y + r * 1.05
	var shallow := center.y + r * 0.6
	pts.append(Vector2(center.x + r, shoulder))
	var waves := 3
	var w := r * 2.0 / float(waves)
	var flip := int(wave_phase) % 2 == 0
	for i in range(waves):
		var x0 := center.x + r - w * float(i)
		pts.append(Vector2(x0 - w * 0.5, deep if (i % 2 == 0) == flip else shallow))
		pts.append(Vector2(x0 - w, shoulder))
	pts.append(Vector2(center.x - r, shoulder))
	c.draw_colored_polygon(pts, body)
	_eyes(c, center, r, look)


## Fantasma asustado: cuerpo azul (o blanco al parpadear), ojos fijos y boca
## en zigzag.
static func ghost_frightened(c: CanvasItem, center: Vector2, r: float,
		blinking: bool, wave_phase: float) -> void:
	var body := Palette.FRIGHTENED_FLASH if blinking else Palette.FRIGHTENED
	var pts := PackedVector2Array()
	for i in range(ARC_STEPS + 1):
		var a := lerpf(PI, TAU, float(i) / float(ARC_STEPS))
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	var shoulder := center.y + r * 0.55
	var deep := center.y + r * 1.05
	var shallow := center.y + r * 0.6
	pts.append(Vector2(center.x + r, shoulder))
	var waves := 3
	var w := r * 2.0 / float(waves)
	var flip := int(wave_phase) % 2 == 0
	for i in range(waves):
		var x0 := center.x + r - w * float(i)
		pts.append(Vector2(x0 - w * 0.5, deep if (i % 2 == 0) == flip else shallow))
		pts.append(Vector2(x0 - w, shoulder))
	pts.append(Vector2(center.x - r, shoulder))
	c.draw_colored_polygon(pts, body)

	var ink := Palette.FRIGHTENED if blinking else Palette.EYE_WHITE
	var er := r * 0.17
	c.draw_circle(center + Vector2(-r * 0.36, -r * 0.18), er, ink)
	c.draw_circle(center + Vector2(r * 0.36, -r * 0.18), er, ink)
	# boca en zigzag
	var y := center.y + r * 0.28
	var steps := 6
	var pw := r * 1.5 / float(steps)
	var prev := Vector2(center.x - r * 0.75, y)
	for i in range(1, steps + 1):
		var nx := center.x - r * 0.75 + pw * float(i)
		var ny := y + (r * 0.16 if i % 2 == 1 else -r * 0.16)
		c.draw_line(prev, Vector2(nx, ny), ink, r * 0.12)
		prev = Vector2(nx, ny)


## Solo los ojos: el fantasma comido volviendo a casa.
static func ghost_eyes(c: CanvasItem, center: Vector2, r: float, look: Vector2i) -> void:
	_eyes(c, center, r, look)


static func _eyes(c: CanvasItem, center: Vector2, r: float, look: Vector2i) -> void:
	var off := Vector2(float(look.x), float(look.y)) * r * 0.22
	var er := r * 0.3
	var pr := r * 0.15
	var l := center + Vector2(-r * 0.36, -r * 0.2)
	var right := center + Vector2(r * 0.36, -r * 0.2)
	c.draw_circle(l, er, Palette.EYE_WHITE)
	c.draw_circle(right, er, Palette.EYE_WHITE)
	c.draw_circle(l + off, pr, Palette.EYE_PUPIL)
	c.draw_circle(right + off, pr, Palette.EYE_PUPIL)


static func pellet(c: CanvasItem, center: Vector2, r: float) -> void:
	c.draw_circle(center, r, Palette.PELLET)


static func power_pellet(c: CanvasItem, center: Vector2, r: float, on: bool) -> void:
	if on:
		c.draw_circle(center, r, Palette.PELLET)


static func fruit(c: CanvasItem, center: Vector2, r: float, name: String) -> void:
	var col := Palette.fruit_color(name)
	var stem := Color8(0, 200, 80)
	match name:
		"cherry":
			c.draw_circle(center + Vector2(-r * 0.4, r * 0.25), r * 0.5, col)
			c.draw_circle(center + Vector2(r * 0.4, r * 0.3), r * 0.45, col)
			c.draw_line(center + Vector2(-r * 0.4, r * 0.2), center + Vector2(r * 0.2, -r * 0.8), stem, r * 0.14)
			c.draw_line(center + Vector2(r * 0.4, r * 0.25), center + Vector2(r * 0.2, -r * 0.8), stem, r * 0.14)
		"strawberry":
			var pts := PackedVector2Array([
				center + Vector2(-r * 0.7, -r * 0.25),
				center + Vector2(r * 0.7, -r * 0.25),
				center + Vector2(0, r * 0.9),
			])
			c.draw_colored_polygon(pts, col)
			c.draw_rect(Rect2(center + Vector2(-r * 0.6, -r * 0.55), Vector2(r * 1.2, r * 0.3)), stem)
		"bell":
			var pts2 := PackedVector2Array([
				center + Vector2(-r * 0.7, r * 0.6),
				center + Vector2(-r * 0.45, -r * 0.5),
				center + Vector2(r * 0.45, -r * 0.5),
				center + Vector2(r * 0.7, r * 0.6),
			])
			c.draw_colored_polygon(pts2, col)
			c.draw_rect(Rect2(center + Vector2(-r * 0.2, r * 0.6), Vector2(r * 0.4, r * 0.25)), col)
		"key":
			c.draw_circle(center + Vector2(0, -r * 0.4), r * 0.35, col)
			c.draw_rect(Rect2(center + Vector2(-r * 0.12, -r * 0.1), Vector2(r * 0.24, r * 0.95)), col)
			c.draw_rect(Rect2(center + Vector2(0, r * 0.45), Vector2(r * 0.45, r * 0.18)), col)
		"galaxian":
			var pts3 := PackedVector2Array([
				center + Vector2(0, -r * 0.8),
				center + Vector2(r * 0.75, r * 0.7),
				center + Vector2(0, r * 0.3),
				center + Vector2(-r * 0.75, r * 0.7),
			])
			c.draw_colored_polygon(pts3, col)
		_:
			c.draw_circle(center + Vector2(0, r * 0.15), r * 0.72, col)
			c.draw_line(center + Vector2(0, -r * 0.5), center + Vector2(r * 0.25, -r * 0.95), stem, r * 0.16)


## Icono de vida: Pac-Man con la boca abierta mirando a la derecha.
static func life_icon(c: CanvasItem, center: Vector2, r: float) -> void:
	pacman(c, center, r, Vector2i.RIGHT, PI * 0.5)
