class_name GridActor
extends RefCounted

## Movimiento por casillas al estilo arcade.
##
## La posicion es (centro de `tile`) + dir * frac, con frac en [0,1). Las
## decisiones de giro ocurren exactamente en el centro de cada tile, que es
## lo que hace que el juego se sienta como el original: no hay giros a mitad
## de pasillo y los fantasmas y Pac-Man comparten la misma rejilla.

var maze: Maze
var tile: Vector2i
var prev_tile: Vector2i
var dir: Vector2i = Vector2i.ZERO
var frac: float = 0.0

## Tiles cuyo centro se cruzo en el ultimo step (para comer pellets sin
## saltarse ninguno si el paso fuese grande).
var entered: Array[Vector2i] = []
var is_blocked: bool = false


func world_pos() -> Vector2:
	return Vector2(tile) + Vector2(dir) * frac


func place(t: Vector2i, d: Vector2i) -> void:
	tile = t
	prev_tile = t
	dir = d
	frac = 0.0
	is_blocked = false


func step(dist: float) -> void:
	entered.clear()
	is_blocked = false
	prev_tile = tile
	var guard := 0
	while guard < 128:
		guard += 1
		if is_zero_approx(frac):
			_at_center()
		if dir == Vector2i.ZERO:
			is_blocked = true
			return
		var nxt := maze.wrap_tile(tile + dir)
		if not _can_enter(nxt):
			frac = 0.0
			is_blocked = true
			return
		var room := 1.0 - frac
		if dist < room:
			frac += dist
			return
		dist -= room
		tile = nxt
		frac = 0.0
		entered.append(tile)


## Reversa instantanea en mitad de pasillo, conservando la posicion exacta.
func reverse() -> void:
	if dir == Vector2i.ZERO:
		return
	if frac > 0.0:
		tile = maze.wrap_tile(tile + dir)
		frac = 1.0 - frac
	dir = -dir


func dirs_available(exclude_reverse: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in Maze.DIRS:
		if exclude_reverse and d == -dir and dir != Vector2i.ZERO:
			continue
		if _can_enter(maze.wrap_tile(tile + d)):
			out.append(d)
	return out


# -- para sobrescribir -------------------------------------------------------

func _at_center() -> void:
	pass


func _can_enter(_t: Vector2i) -> bool:
	return true
