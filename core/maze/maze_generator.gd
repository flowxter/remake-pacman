class_name MazeGenerator
extends RefCounted

## Generador de laberintos estilo Pac-Man.
##
## Un generador clasico (DFS/Prim) produce un arbol: pasillos con callejones
## sin salida. Eso rompe Pac-Man -- los fantasmas se atascan y la persecucion
## pierde toda la tension. Aqui se generan laberintos que cumplen las
## invariantes del arcade:
##
##   1. Simetria espejo respecto al eje vertical.
##   2. Pasillos de 1 tile de ancho, paredes de 1 tile como minimo.
##   3. Ningun area abierta de 2x2 (garantizado por la rejilla impar).
##   4. Cero callejones sin salida: todo tile abierto tiene grado >= 2
##      (grafo "braided", lleno de ciclos).
##   5. Casa de fantasmas central con puerta unica hacia arriba.
##   6. Tunel lateral con warp.
##   7. 4 power pellets, uno por cuadrante, en pasillo real.
##   8. Conectividad total desde el spawn de Pac-Man.
##
## Todo depende de una semilla: un laberinto == un numero compartible.

const MAX_ATTEMPTS := 120

const PRESET_SMALL := {"cells_w": 10, "cells_h": 12}
const PRESET_CLASSIC := {"cells_w": 14, "cells_h": 16}
const PRESET_LARGE := {"cells_w": 18, "cells_h": 20}


static func preset(name: String) -> Dictionary:
	match name:
		"small":
			return PRESET_SMALL.duplicate()
		"large":
			return PRESET_LARGE.duplicate()
		_:
			return PRESET_CLASSIC.duplicate()


## cfg: cells_w, cells_h, block_ratio, loop_ratio, axis_ratio, seed
static func generate(cfg: Dictionary = {}) -> Maze:
	var cw: int = int(cfg.get("cells_w", 14))
	var ch: int = int(cfg.get("cells_h", 16))
	if cw % 2 == 1:
		cw += 1
	cw = maxi(cw, 8)
	ch = maxi(ch, 10)

	var base_seed: int = int(cfg.get("seed", 0))
	if base_seed == 0:
		base_seed = randi() | 1

	for attempt in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + attempt * 7919
		var m := _attempt(cw, ch, cfg, rng)
		if m != null:
			m.seed_used = base_seed
			return m
	return null


class _Grid:
	var cw: int
	var ch: int
	var hw: int                   ## columnas de la mitad izquierda (incluye el eje)
	var blocked: PackedByteArray  ## celdas que son masa de pared
	var eh: PackedByteArray       ## aristas horizontales (cw-1) x ch
	var ev: PackedByteArray       ## aristas verticales  cw x (ch-1)

	func _init(p_cw: int, p_ch: int) -> void:
		cw = p_cw
		ch = p_ch
		hw = int(p_cw / 2.0)
		blocked.resize(cw * ch)
		eh.resize((cw - 1) * ch)
		ev.resize(cw * (ch - 1))

	func ci(c: int, r: int) -> int:
		return r * cw + c

	func is_blocked(c: int, r: int) -> bool:
		if c < 0 or c >= cw or r < 0 or r >= ch:
			return true
		return blocked[ci(c, r)] == 1

	## Mantiene la simetria espejo.
	func set_blocked(c: int, r: int, v: bool) -> void:
		var b := 1 if v else 0
		blocked[ci(c, r)] = b
		blocked[ci(cw - 1 - c, r)] = b

	func hi(c: int, r: int) -> int:
		return r * (cw - 1) + c

	func vi(c: int, r: int) -> int:
		return r * cw + c

	func has_h(c: int, r: int) -> bool:
		if c < 0 or c >= cw - 1 or r < 0 or r >= ch:
			return false
		return eh[hi(c, r)] == 1

	func has_v(c: int, r: int) -> bool:
		if c < 0 or c >= cw or r < 0 or r >= ch - 1:
			return false
		return ev[vi(c, r)] == 1

	## El eje (c == hw-1) es su propio espejo, asi que queda igual.
	func carve_h(c: int, r: int) -> void:
		if c < 0 or c >= cw - 1 or r < 0 or r >= ch:
			return
		eh[hi(c, r)] = 1
		eh[hi(cw - 2 - c, r)] = 1

	func carve_v(c: int, r: int) -> void:
		if c < 0 or c >= cw or r < 0 or r >= ch - 1:
			return
		ev[vi(c, r)] = 1
		ev[vi(cw - 1 - c, r)] = 1

	func uncarve_h(c: int, r: int) -> void:
		if c < 0 or c >= cw - 1 or r < 0 or r >= ch:
			return
		eh[hi(c, r)] = 0
		eh[hi(cw - 2 - c, r)] = 0

	func uncarve_v(c: int, r: int) -> void:
		if c < 0 or c >= cw or r < 0 or r >= ch - 1:
			return
		ev[vi(c, r)] = 0
		ev[vi(cw - 1 - c, r)] = 0

	func cell_degree(c: int, r: int) -> int:
		var n := 0
		if has_h(c - 1, r):
			n += 1
		if has_h(c, r):
			n += 1
		if has_v(c, r - 1):
			n += 1
		if has_v(c, r):
			n += 1
		return n

	## Aristas aun sin tallar hacia vecinos no bloqueados: ["h"|"v", c, r].
	func free_edges(c: int, r: int) -> Array:
		var out: Array = []
		if c > 0 and not is_blocked(c - 1, r) and not has_h(c - 1, r):
			out.append(["h", c - 1, r])
		if c < cw - 1 and not is_blocked(c + 1, r) and not has_h(c, r):
			out.append(["h", c, r])
		if r > 0 and not is_blocked(c, r - 1) and not has_v(c, r - 1):
			out.append(["v", c, r - 1])
		if r < ch - 1 and not is_blocked(c, r + 1) and not has_v(c, r):
			out.append(["v", c, r])
		return out

	func carve_edge(e: Array) -> void:
		if e[0] == "h":
			carve_h(e[1], e[2])
		else:
			carve_v(e[1], e[2])


static func _attempt(cw: int, ch: int, cfg: Dictionary, rng: RandomNumberGenerator) -> Maze:
	var g := _Grid.new(cw, ch)
	var hw := g.hw

	# -- geometria fija: casa de fantasmas, filas de spawn y de tunel --------
	var house_c0 := hw - 2
	var house_c1 := hw + 1
	var house_r0: int = clampi(int(round(ch * 0.44)), 3, ch - 6)
	var house_r1 := house_r0 + 1
	var gate_row := house_r0 - 1
	var spawn_row: int = mini(house_r1 + 2, ch - 2)

	var tunnel_candidates: Array[int] = []
	if house_r1 + 1 < ch - 1 and house_r1 + 1 != spawn_row:
		tunnel_candidates.append(house_r1 + 1)
	if gate_row - 1 >= 1:
		tunnel_candidates.append(gate_row - 1)
	if tunnel_candidates.is_empty():
		tunnel_candidates.append(int(ch / 2.0))
	var tunnel_row_cell: int = tunnel_candidates[rng.randi_range(0, tunnel_candidates.size() - 1)]

	# Celdas protegidas: nunca se convierten en masa de pared.
	var protected := {}
	for r: int in [gate_row, spawn_row, tunnel_row_cell]:
		for c in range(cw):
			protected[g.ci(c, r)] = true
	for c in range(cw):
		protected[g.ci(c, 0)] = true
		protected[g.ci(c, ch - 1)] = true

	# La casa de fantasmas se bloquea antes de tallar y se estampa al final.
	for c in range(house_c0, house_c1 + 1):
		for r in range(house_r0, house_r1 + 1):
			if protected.has(g.ci(c, r)):
				return null
			g.blocked[g.ci(c, r)] = 1

	# -- masas de pared aleatorias (dan el aspecto chunky del arcade) --------
	var block_ratio: float = float(cfg.get("block_ratio", 0.12))
	for r in range(ch):
		for c in range(hw):
			if g.is_blocked(c, r) or protected.has(g.ci(c, r)):
				continue
			if rng.randf() < block_ratio:
				g.set_blocked(c, r, true)

	# -- la mitad izquierda tiene que ser conexa por si misma ---------------
	var left_cells: Array[Vector2i] = []
	for r in range(ch):
		for c in range(hw):
			if not g.is_blocked(c, r):
				left_cells.append(Vector2i(c, r))
	if left_cells.size() < 12:
		return null
	if not _left_half_connected(g, left_cells):
		return null

	# -- arbol de expansion con DFS aleatorio sobre la mitad izquierda ------
	_carve_spanning_tree(g, left_cells, rng)

	# -- aristas del eje: unen las dos mitades ------------------------------
	g.carve_h(hw - 1, gate_row)
	g.carve_h(hw - 1, spawn_row)
	var axis_ratio: float = float(cfg.get("axis_ratio", 0.35))
	for r in range(ch):
		if g.is_blocked(hw - 1, r) or g.is_blocked(hw, r):
			continue
		if rng.randf() < axis_ratio:
			g.carve_h(hw - 1, r)

	# -- ciclos extra: un Pac-Man sin bucles no es Pac-Man ------------------
	var loop_ratio: float = float(cfg.get("loop_ratio", 0.28))
	for r in range(ch):
		for c in range(hw):
			if g.is_blocked(c, r):
				continue
			for e: Array in g.free_edges(c, r):
				if rng.randf() < loop_ratio:
					g.carve_edge(e)

	# -- braiding: fuera todos los callejones sin salida --------------------
	if not _braid(g, rng, protected):
		return null

	# -- de celdas a tiles --------------------------------------------------
	var m := Maze.new()
	m.cells_w = cw
	m.cells_h = ch
	m.width = cw * 2 + 1
	m.height = ch * 2 + 1
	m.walls = PackedByteArray()
	m.walls.resize(m.width * m.height)
	m.walls.fill(1)
	m.pellets = PackedByteArray()
	m.pellets.resize(m.width * m.height)

	for r in range(ch):
		for c in range(cw):
			if not g.is_blocked(c, r):
				m.walls[m.idx(c * 2 + 1, r * 2 + 1)] = 0
	for r in range(ch):
		for c in range(cw - 1):
			if g.has_h(c, r):
				m.walls[m.idx(c * 2 + 2, r * 2 + 1)] = 0
	for r in range(ch - 1):
		for c in range(cw):
			if g.has_v(c, r):
				m.walls[m.idx(c * 2 + 1, r * 2 + 2)] = 0

	# -- casa de fantasmas, puerta, spawns ----------------------------------
	var hx0 := house_c0 * 2 + 1
	var hx1 := house_c1 * 2 + 1
	var hy0 := house_r0 * 2 + 1
	var hy1 := house_r1 * 2 + 1
	m.house = Rect2i(hx0, hy0, hx1 - hx0 + 1, hy1 - hy0 + 1)
	for y in range(hy0, hy1 + 1):
		for x in range(hx0, hx1 + 1):
			m.walls[m.idx(x, y)] = 0

	var cx := int((m.width - 1) / 2.0)
	m.gate = Vector2i(cx, hy0 - 1)
	m.gate_exit = Vector2i(cx, hy0 - 2)
	m.walls[m.idx(m.gate.x, m.gate.y)] = 0

	m.pacman_spawn = Vector2(cx, spawn_row * 2 + 1)

	var house_mid := Vector2(cx, (hy0 + hy1) * 0.5)
	m.ghost_starts = [
		Vector2(m.gate_exit),                         ## Blinky arranca fuera
		house_mid,                                     ## Pinky
		house_mid + Vector2(-2, 0),                    ## Inky
		house_mid + Vector2(2, 0),                     ## Clyde
		house_mid + Vector2(-1, 0),                    ## extras opcionales
		house_mid + Vector2(1, 0),
	]

	# -- tunel lateral con warp ---------------------------------------------
	m.tunnel_row = tunnel_row_cell * 2 + 1
	m.walls[m.idx(0, m.tunnel_row)] = 0
	m.walls[m.idx(m.width - 1, m.tunnel_row)] = 0

	# -- objetivos de scatter (esquinas fuera del tablero) ------------------
	m.scatter_targets = [
		Vector2i(m.width - 3, -3),
		Vector2i(2, -3),
		Vector2i(m.width - 1, m.height + 2),
		Vector2i(0, m.height + 2),
		Vector2i(m.width - 3, m.height + 2),
		Vector2i(2, -3),
	]

	# -- pellets ------------------------------------------------------------
	_place_pellets(m)
	if not _place_power_pellets(m, g, rng):
		return null

	if not MazeValidator.validate(m).ok:
		return null
	return m


static func _left_half_connected(g: _Grid, left_cells: Array[Vector2i]) -> bool:
	var seen := {}
	var stack: Array[Vector2i] = [left_cells[0]]
	seen[g.ci(left_cells[0].x, left_cells[0].y)] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in Maze.DIRS:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= g.hw or n.y < 0 or n.y >= g.ch:
				continue
			if g.is_blocked(n.x, n.y):
				continue
			var k := g.ci(n.x, n.y)
			if seen.has(k):
				continue
			seen[k] = true
			stack.append(n)
	return seen.size() == left_cells.size()


static func _carve_spanning_tree(g: _Grid, left_cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var start: Vector2i = left_cells[rng.randi_range(0, left_cells.size() - 1)]
	var seen := {g.ci(start.x, start.y): true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack[-1]
		var cands: Array[Vector2i] = []
		for d in Maze.DIRS:
			var n: Vector2i = cur + d
			if n.x < 0 or n.x >= g.hw or n.y < 0 or n.y >= g.ch:
				continue
			if g.is_blocked(n.x, n.y):
				continue
			if seen.has(g.ci(n.x, n.y)):
				continue
			cands.append(n)
		if cands.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = cands[rng.randi_range(0, cands.size() - 1)]
		if nxt.y == cur.y:
			g.carve_h(mini(cur.x, nxt.x), cur.y)
		else:
			g.carve_v(cur.x, mini(cur.y, nxt.y))
		seen[g.ci(nxt.x, nxt.y)] = true
		stack.append(nxt)


## Elimina callejones sin salida. Una celda con grado 1 abre otra arista; si
## no tiene ninguna disponible se convierte en masa de pared.
static func _braid(g: _Grid, rng: RandomNumberGenerator, protected: Dictionary) -> bool:
	for _pass in range(400):
		var changed := false
		for r in range(g.ch):
			for c in range(g.hw):
				if g.is_blocked(c, r):
					continue
				if g.cell_degree(c, r) >= 2:
					continue
				var cands := g.free_edges(c, r)
				if cands.is_empty():
					if protected.has(g.ci(c, r)):
						return false
					g.uncarve_h(c - 1, r)
					g.uncarve_h(c, r)
					g.uncarve_v(c, r - 1)
					g.uncarve_v(c, r)
					g.set_blocked(c, r, true)
				else:
					g.carve_edge(cands[rng.randi_range(0, cands.size() - 1)])
				changed = true
		if not changed:
			return true
	return false


static func _place_pellets(m: Maze) -> void:
	var spawn_tile := Vector2i(int(m.pacman_spawn.x), int(m.pacman_spawn.y))
	var total := 0
	for y in range(m.height):
		for x in range(m.width):
			var t := Vector2i(x, y)
			if m.walls[m.idx(x, y)] == 1:
				continue
			if m.is_house(t):
				continue
			if x == 0 or x == m.width - 1:
				continue          ## sin puntos dentro del tunel
			if t == spawn_tile or t == m.gate_exit:
				continue
			m.pellets[m.idx(x, y)] = Maze.PELLET
			total += 1
	m.pellet_total = total


static func _place_power_pellets(m: Maze, g: _Grid, rng: RandomNumberGenerator) -> bool:
	var band_h: int = maxi(2, int(m.cells_h / 4.0))
	var bands: Array[Vector2i] = [
		Vector2i(1, band_h),
		Vector2i(m.cells_h - 1 - band_h, m.cells_h - 2),
	]
	m.power_tiles.clear()
	for band: Vector2i in bands:
		var picked := false
		for max_c: int in [1, 2, 3, int(g.hw / 2.0)]:
			var cands: Array[Vector2i] = []
			for r in range(band.x, band.y + 1):
				for c in range(mini(max_c + 1, g.hw)):
					if g.is_blocked(c, r):
						continue
					var t := Vector2i(c * 2 + 1, r * 2 + 1)
					if m.pellets[m.idx(t.x, t.y)] != Maze.PELLET:
						continue
					if g.cell_degree(c, r) == 2:
						cands.append(t)
			if cands.is_empty():
				continue
			var t: Vector2i = cands[rng.randi_range(0, cands.size() - 1)]
			var mt := Vector2i(m.width - 1 - t.x, t.y)
			m.pellets[m.idx(t.x, t.y)] = Maze.POWER
			m.power_tiles.append(t)
			m.pellet_total -= 1
			if mt != t and m.pellets[m.idx(mt.x, mt.y)] == Maze.PELLET:
				m.pellets[m.idx(mt.x, mt.y)] = Maze.POWER
				m.power_tiles.append(mt)
				m.pellet_total -= 1
			picked = true
			break
		if not picked:
			return false
	return m.power_tiles.size() >= 4
