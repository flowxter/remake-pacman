class_name Maze
extends RefCounted

## Datos de un laberinto ya generado y validado.
##
## El laberinto vive en una rejilla de tiles de `width` x `height`.
## Los tiles abiertos estan en posiciones (impar, impar) = "celdas" y
## (par, impar) / (impar, par) = "aristas" talladas entre celdas.
## Las posiciones (par, par) son siempre pared: eso garantiza por
## construccion que nunca aparece un area abierta de 2x2.

const TILE_PX := 8

enum { EMPTY = 0, PELLET = 1, POWER = 2 }

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]

var width: int
var height: int
var cells_w: int
var cells_h: int

var walls: PackedByteArray      ## 1 = pared, 0 = libre
var pellets: PackedByteArray    ## EMPTY / PELLET / POWER

var house: Rect2i               ## interior abierto de la casa de fantasmas
var gate: Vector2i              ## tile de la puerta (parte de la casa)
var gate_exit: Vector2i         ## primer tile del laberinto sobre la puerta
var tunnel_row: int             ## fila con warp lateral
var pacman_spawn: Vector2       ## en coordenadas de tile (centro = entero)
var ghost_starts: Array[Vector2] = []
var scatter_targets: Array[Vector2i] = []

var seed_used: int = 0
var pellet_total: int = 0
var power_tiles: Array[Vector2i] = []


func idx(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


## Aplica el warp del tunel: salir por un lado reaparece por el otro.
func wrap_tile(t: Vector2i) -> Vector2i:
	if t.y == tunnel_row and (t.x < 0 or t.x >= width):
		return Vector2i(posmod(t.x, width), t.y)
	return t


func is_open(t: Vector2i) -> bool:
	var w := wrap_tile(t)
	if not in_bounds(w.x, w.y):
		return false
	return walls[idx(w.x, w.y)] == 0


func is_wall(t: Vector2i) -> bool:
	return not is_open(t)


func is_house(t: Vector2i) -> bool:
	return house.has_point(t) or t == gate


## Numero de vecinos abiertos (cuenta el warp del tunel).
func degree(t: Vector2i) -> int:
	var n := 0
	for d in DIRS:
		if is_open(t + d):
			n += 1
	return n


func is_intersection(t: Vector2i) -> bool:
	return degree(t) >= 3


func pellet_at(t: Vector2i) -> int:
	var w := wrap_tile(t)
	if not in_bounds(w.x, w.y):
		return EMPTY
	return pellets[idx(w.x, w.y)]


func clear_pellet(t: Vector2i) -> void:
	var w := wrap_tile(t)
	if in_bounds(w.x, w.y):
		pellets[idx(w.x, w.y)] = EMPTY


## Distancia horizontal mas corta teniendo en cuenta el warp del tunel.
func dx_wrapped(a: int, b: int) -> int:
	var d := b - a
	if absi(d) > width / 2.0:
		d -= signi(d) * width
	return d


func duplicate_pellets() -> PackedByteArray:
	return pellets.duplicate()
