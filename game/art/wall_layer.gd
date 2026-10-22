class_name WallLayer
extends Node2D

## Paredes del laberinto, en unidades de tile (1.0 = un tile).
##
## Las paredes del arcade son lineas dobles azules, no bloques macizos. Se
## consiguen gratis dibujando, por cada tile ABIERTO, una linea pegada a
## cada lado que da a pared: un muro de 1 tile de grosor queda con una linea
## a cada lado y el hueco en medio. Los extremos se recortan segun los
## vecinos para que las lineas se unan y las esquinas queden limpias.
##
## Se redibuja solo cuando cambia el laberinto, no cada fotograma.

const INSET := 0.26
const WIDTH := 0.13

var maze: Maze
var flash: bool = false


func set_maze(m: Maze) -> void:
	maze = m
	queue_redraw()


func set_flash(v: bool) -> void:
	if flash == v:
		return
	flash = v
	queue_redraw()


func _draw() -> void:
	if maze == null:
		return
	var col := Palette.WALL_FLASH if flash else Palette.WALL
	for y in range(maze.height):
		for x in range(maze.width):
			var t := Vector2i(x, y)
			if maze.is_wall(t) or maze.is_house(t):
				continue
			_tile_outline(t, col)
	_draw_house(col)


func _tile_outline(t: Vector2i, col: Color) -> void:
	var up := maze.is_wall(t + Vector2i.UP)
	var down := maze.is_wall(t + Vector2i.DOWN)
	var left := maze.is_wall(t + Vector2i.LEFT)
	var right := maze.is_wall(t + Vector2i.RIGHT)
	var x0 := float(t.x) - 0.5
	var x1 := float(t.x) + 0.5
	var y0 := float(t.y) - 0.5
	var y1 := float(t.y) + 0.5

	if up:
		var a := Vector2(x0 + (INSET if left else 0.0), y0 + INSET)
		var b := Vector2(x1 - (INSET if right else 0.0), y0 + INSET)
		draw_line(a, b, col, WIDTH)
	if down:
		var a2 := Vector2(x0 + (INSET if left else 0.0), y1 - INSET)
		var b2 := Vector2(x1 - (INSET if right else 0.0), y1 - INSET)
		draw_line(a2, b2, col, WIDTH)
	if left:
		var a3 := Vector2(x0 + INSET, y0 + (INSET if up else 0.0))
		var b3 := Vector2(x0 + INSET, y1 - (INSET if down else 0.0))
		draw_line(a3, b3, col, WIDTH)
	if right:
		var a4 := Vector2(x1 - INSET, y0 + (INSET if up else 0.0))
		var b4 := Vector2(x1 - INSET, y1 - (INSET if down else 0.0))
		draw_line(a4, b4, col, WIDTH)


## La casa de fantasmas es la unica zona abierta grande: se dibuja su
## contorno a mano y la puerta en rosa.
func _draw_house(col: Color) -> void:
	var r := maze.house
	var x0 := float(r.position.x) - 0.5
	var y0 := float(r.position.y) - 0.5
	var x1 := float(r.end.x) - 0.5
	var y1 := float(r.end.y) - 0.5
	var gx0 := float(maze.gate.x) - 0.5
	var gx1 := float(maze.gate.x) + 0.5

	draw_line(Vector2(x0, y0), Vector2(gx0, y0), col, WIDTH)
	draw_line(Vector2(gx1, y0), Vector2(x1, y0), col, WIDTH)
	draw_line(Vector2(x0, y1), Vector2(x1, y1), col, WIDTH)
	draw_line(Vector2(x0, y0), Vector2(x0, y1), col, WIDTH)
	draw_line(Vector2(x1, y0), Vector2(x1, y1), col, WIDTH)
	draw_line(Vector2(gx0, y0), Vector2(gx1, y0), Palette.GATE, WIDTH * 1.6)
