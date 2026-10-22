class_name MazeValidator
extends RefCounted

## Verifica que un laberinto generado sea jugable y "se sienta" Pac-Man.
## El generador llama a esto en cada intento: si algo falla, descarta y
## reintenta con otra semilla derivada.

static func validate(m: Maze) -> Dictionary:
	var errors: PackedStringArray = []

	if m == null:
		return {"ok": false, "errors": ["laberinto nulo"], "stats": {}}

	_check_symmetry(m, errors)
	_check_no_open_squares(m, errors)
	_check_no_dead_ends(m, errors)
	_check_house(m, errors)
	_check_tunnel(m, errors)
	var reach := _check_connectivity(m, errors)
	_check_pellets(m, reach, errors)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"stats": _stats(m, reach),
	}


static func _check_symmetry(m: Maze, errors: PackedStringArray) -> void:
	for y in range(m.height):
		for x in range(m.width):
			if m.walls[m.idx(x, y)] != m.walls[m.idx(m.width - 1 - x, y)]:
				errors.append("simetria rota en (%d,%d)" % [x, y])
				return


## Con la rejilla impar los tiles (par,par) son siempre pared, asi que esto
## no deberia fallar nunca. Se verifica igual: si un dia se cambia la
## rejilla, este test avisa antes de que el juego se vea raro.
static func _check_no_open_squares(m: Maze, errors: PackedStringArray) -> void:
	for y in range(m.height - 1):
		for x in range(m.width - 1):
			var quad: Array[Vector2i] = [
				Vector2i(x, y), Vector2i(x + 1, y),
				Vector2i(x, y + 1), Vector2i(x + 1, y + 1),
			]
			var all_open := true
			var any_house := false
			for t: Vector2i in quad:
				if m.walls[m.idx(t.x, t.y)] == 1:
					all_open = false
					break
				if m.is_house(t):
					any_house = true
			if all_open and not any_house:
				errors.append("area abierta 2x2 en (%d,%d)" % [x, y])
				return


static func _check_no_dead_ends(m: Maze, errors: PackedStringArray) -> void:
	for y in range(m.height):
		for x in range(m.width):
			var t := Vector2i(x, y)
			if m.walls[m.idx(x, y)] == 1 or m.is_house(t):
				continue
			if m.degree(t) < 2:
				errors.append("callejon sin salida en (%d,%d)" % [x, y])
				return


static func _check_house(m: Maze, errors: PackedStringArray) -> void:
	if m.walls[m.idx(m.gate.x, m.gate.y)] == 1:
		errors.append("la puerta de la casa esta cerrada")
		return
	if not m.is_open(m.gate_exit):
		errors.append("la salida sobre la puerta esta cerrada")
		return
	# La casa solo puede tener una abertura: la puerta.
	for y in range(m.house.position.y, m.house.end.y):
		for x in range(m.house.position.x, m.house.end.x):
			for d in Maze.DIRS:
				var n := Vector2i(x, y) + d
				if m.is_house(n):
					continue
				if m.is_open(n):
					errors.append("fuga en la casa de fantasmas en (%d,%d)" % [n.x, n.y])
					return


static func _check_tunnel(m: Maze, errors: PackedStringArray) -> void:
	if not m.is_open(Vector2i(0, m.tunnel_row)):
		errors.append("tunel izquierdo cerrado")
	if not m.is_open(Vector2i(m.width - 1, m.tunnel_row)):
		errors.append("tunel derecho cerrado")


static func _check_connectivity(m: Maze, errors: PackedStringArray) -> Dictionary:
	var start := Vector2i(int(m.pacman_spawn.x), int(m.pacman_spawn.y))
	if not m.is_open(start):
		errors.append("el spawn de Pac-Man cae en pared")
		return {}
	var seen := {m.idx(start.x, start.y): true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in Maze.DIRS:
			var n := m.wrap_tile(cur + d)
			if not m.in_bounds(n.x, n.y) or m.walls[m.idx(n.x, n.y)] == 1:
				continue
			var k := m.idx(n.x, n.y)
			if seen.has(k):
				continue
			seen[k] = true
			stack.append(n)

	var open_count := 0
	for i in range(m.walls.size()):
		if m.walls[i] == 0:
			open_count += 1
	if seen.size() != open_count:
		errors.append("laberinto no conexo: %d de %d tiles alcanzables" % [seen.size(), open_count])
	return seen


static func _check_pellets(m: Maze, reach: Dictionary, errors: PackedStringArray) -> void:
	var powers := 0
	for y in range(m.height):
		for x in range(m.width):
			var p := m.pellets[m.idx(x, y)]
			if p == Maze.EMPTY:
				continue
			if p == Maze.POWER:
				powers += 1
			if not reach.is_empty() and not reach.has(m.idx(x, y)):
				errors.append("pellet inalcanzable en (%d,%d)" % [x, y])
				return
	if powers != 4:
		errors.append("se esperaban 4 power pellets, hay %d" % powers)
	if m.pellet_total < 40:
		errors.append("muy pocos pellets: %d" % m.pellet_total)


static func _stats(m: Maze, reach: Dictionary) -> Dictionary:
	var open_tiles := 0
	var intersections := 0
	for y in range(m.height):
		for x in range(m.width):
			var t := Vector2i(x, y)
			if m.walls[m.idx(x, y)] == 1:
				continue
			open_tiles += 1
			if m.degree(t) >= 3:
				intersections += 1
	return {
		"width": m.width,
		"height": m.height,
		"open_tiles": open_tiles,
		"intersections": intersections,
		"pellets": m.pellet_total,
		"reachable": reach.size(),
		"seed": m.seed_used,
		"tunnel_row": m.tunnel_row,
	}


## Volcado ASCII para depurar en consola.
static func to_ascii(m: Maze) -> String:
	var out := ""
	var spawn := Vector2i(int(m.pacman_spawn.x), int(m.pacman_spawn.y))
	for y in range(m.height):
		for x in range(m.width):
			var t := Vector2i(x, y)
			if m.walls[m.idx(x, y)] == 1:
				out += "#"
			elif t == spawn:
				out += "C"
			elif t == m.gate:
				out += "-"
			elif m.is_house(t):
				out += " "
			elif m.pellets[m.idx(x, y)] == Maze.POWER:
				out += "O"
			elif m.pellets[m.idx(x, y)] == Maze.PELLET:
				out += "."
			else:
				out += " "
		out += "\n"
	return out
