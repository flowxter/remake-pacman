class_name LevelTable
extends RefCounted

## Tablas de velocidad y temporizacion del arcade original.
##
## Las velocidades son fracciones de la velocidad base. En el hardware
## original la "velocidad plena" equivale a 75.7575 px/s con tiles de 8 px,
## es decir 9.4697 tiles por segundo. Todo lo demas es un porcentaje de eso:
## por eso Pac-Man en el nivel 1 (80%) cruza un laberinto de 28 tiles en
## unos 3.7 segundos.

const BASE_SPEED := 9.469696969

## Velocidad de los ojos volviendo a casa (no esta en la tabla original,
## el hardware los movia a tope).
const EYES_SPEED := 1.6


## Fila de la tabla para un nivel dado (1-indexado).
static func row(level: int) -> Dictionary:
	var l: int = maxi(level, 1)
	if l == 1:
		return _mk(0.80, 0.90, 0.75, 0.50, 0.40, 6.0, 20, 0.80, 10, 0.85)
	if l == 2:
		return _mk(0.90, 0.95, 0.85, 0.55, 0.45, 5.0, 30, 0.90, 15, 0.95)
	if l == 3:
		return _mk(0.90, 0.95, 0.85, 0.55, 0.45, 4.0, 40, 0.90, 20, 0.95)
	if l == 4:
		return _mk(0.90, 0.95, 0.85, 0.55, 0.45, 3.0, 40, 0.90, 20, 0.95)
	if l == 5:
		return _mk(1.00, 1.00, 0.95, 0.60, 0.50, 2.0, 40, 1.00, 20, 1.05)
	if l <= 8:
		return _mk(1.00, 1.00, 0.95, 0.60, 0.50, 2.0, 50, 1.00, 25, 1.05)
	if l <= 11:
		return _mk(1.00, 1.00, 0.95, 0.60, 0.50, 1.0, 60, 1.00, 30, 1.05)
	if l <= 14:
		return _mk(1.00, 1.00, 0.95, 0.60, 0.50, 3.0, 80, 1.00, 40, 1.05)
	if l <= 18:
		return _mk(1.00, 1.00, 0.95, 0.60, 0.50, 1.0, 100, 1.00, 50, 1.05)
	if l <= 20:
		return _mk(1.00, 1.00, 0.95, 0.60, 0.50, 1.0, 100, 1.00, 50, 1.05)
	# Nivel 21 y superiores: Pac-Man se frena y los power pellets dejan de
	# asustar a los fantasmas. El nivel 256 del arcade no se emula.
	return _mk(0.90, 0.90, 0.95, 0.60, 0.50, 0.0, 100, 1.00, 50, 1.05)


static func _mk(pac: float, pac_fright: float, ghost: float, ghost_fright: float,
		ghost_tunnel: float, fright_time: float, elroy1_dots: int,
		elroy1_speed: float, elroy2_dots: int, elroy2_speed: float) -> Dictionary:
	return {
		"pac": pac,
		"pac_fright": pac_fright,
		"ghost": ghost,
		"ghost_fright": ghost_fright,
		"ghost_tunnel": ghost_tunnel,
		"fright_time": fright_time,
		"elroy1_dots": elroy1_dots,
		"elroy1_speed": elroy1_speed,
		"elroy2_dots": elroy2_dots,
		"elroy2_speed": elroy2_speed,
	}


## Duraciones alternas scatter / chase / scatter / chase ... El ultimo tramo
## es infinito: a partir de ahi los fantasmas persiguen para siempre.
static func mode_schedule(level: int) -> Array[float]:
	if level <= 1:
		return [7.0, 20.0, 7.0, 20.0, 5.0, 20.0, 5.0, INF]
	if level <= 4:
		return [7.0, 20.0, 7.0, 20.0, 5.0, 1033.0 / 60.0, 1.0 / 60.0, INF]
	return [5.0, 20.0, 5.0, 20.0, 5.0, 1037.0 / 60.0, 1.0 / 60.0, INF]


## Puntos que tiene que comer Pac-Man antes de que cada fantasma salga de la
## casa, en el orden [Blinky, Pinky, Inky, Clyde].
static func house_dot_limits(level: int) -> Array[int]:
	if level <= 1:
		return [0, 0, 30, 60]
	if level == 2:
		return [0, 0, 0, 50]
	return [0, 0, 0, 0]


static func fruit_points(level: int) -> int:
	var table := [100, 300, 500, 500, 700, 700, 1000, 1000, 2000, 2000, 3000, 3000]
	if level - 1 < table.size():
		return int(table[level - 1])
	return 5000


static func fruit_name(level: int) -> String:
	var names := [
		"cherry", "strawberry", "orange", "orange", "apple", "apple",
		"melon", "melon", "galaxian", "galaxian", "bell", "bell",
	]
	if level - 1 < names.size():
		return String(names[level - 1])
	return "key"
