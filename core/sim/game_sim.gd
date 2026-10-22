class_name GameSim
extends RefCounted

## Simulacion del juego, con paso fijo y sin ninguna dependencia del render.
##
## Todo el estado autoritativo vive aqui: el laberinto, los actores, el reloj
## de scatter/chase, los contadores de salida de la casa, la puntuacion. La
## capa visual solo lee y dibuja. Eso permite testear el juego en headless y
## cambiar de motor sin reescribir las reglas.

signal pellet_eaten(tile: Vector2i)
signal power_eaten(tile: Vector2i)
signal ghost_eaten(ghost: Ghost, points: int)
signal pacman_died
signal level_started(level: int)
signal level_cleared
signal game_over
signal fruit_spawned(tile: Vector2i)
signal fruit_taken(points: int)
signal extra_life
signal score_changed(score: int)
signal mode_changed(chase: bool)
signal fright_started(duration: float)
signal fright_ended

enum Phase { READY, PLAY, DYING, CLEARED, OVER }

const TICK := 1.0 / 120.0        ## paso fijo, como el hardware original
const READY_TIME := 2.2
const DEATH_TIME := 1.9
const CLEARED_TIME := 1.6

var maze: Maze
var diff: Difficulty
var pacman: Pacman
var ghosts: Array[Ghost] = []

var level: int = 1
var score: int = 0
var lives: int = 3
var phase: Phase = Phase.READY
var phase_timer: float = 0.0

var pellets_total: int = 0
var pellets_left: int = 0
var pellets_eaten: int = 0

var schedule: Array[float] = []
var mode_index: int = 0
var mode_timer: float = 0.0
var in_chase: bool = false

var fright_timer: float = 0.0
var fright_total: float = 0.0
var ghost_chain: int = 0

var global_dots: int = -1        ## -1 = contadores individuales activos
var no_dot_timer: float = 0.0

var fruit_tile: Vector2i = Vector2i(-1, -1)
var fruit_timer: float = 0.0
var fruit_shown: int = 0

var level_row: Dictionary = {}
var next_extra_life: int = 0
var elapsed: float = 0.0
var generation_failed: bool = false

var rng := RandomNumberGenerator.new()
var _accum: float = 0.0
var _dist_cache: Dictionary = {}
var _last_pac_tile: Vector2i = Vector2i(-999, -999)
var _open_tiles: Array[Vector2i] = []


static func kind_for_index(i: int) -> Ghost.Kind:
	var order: Array[Ghost.Kind] = [
		Ghost.Kind.BLINKY, Ghost.Kind.PINKY, Ghost.Kind.INKY,
		Ghost.Kind.CLYDE, Ghost.Kind.RANDY, Ghost.Kind.AMBUSH,
	]
	return order[clampi(i, 0, order.size() - 1)]


# -- arranque ----------------------------------------------------------------

func start(d: Difficulty) -> bool:
	diff = d
	rng.seed = d.seed if d.seed != 0 else randi()
	level = maxi(d.start_level, 1)
	score = 0
	lives = maxi(d.lives, 1)
	next_extra_life = d.extra_life_score if d.extra_life_score > 0 else 1 << 60
	return build_level()


func build_level() -> bool:
	var cfg := diff.maze_config()
	if diff.seed != 0:
		cfg["seed"] = diff.seed + (level - 1) * 1013
	else:
		cfg["seed"] = 0
	var m := MazeGenerator.generate(cfg)
	if m == null:
		generation_failed = true
		return false
	maze = m
	level_row = LevelTable.row(level)
	schedule = LevelTable.mode_schedule(level)

	pellets_total = 0
	for i in range(maze.pellets.size()):
		if maze.pellets[i] != Maze.EMPTY:
			pellets_total += 1
	pellets_left = pellets_total
	pellets_eaten = 0

	_open_tiles.clear()
	for y in range(maze.height):
		for x in range(maze.width):
			var t := Vector2i(x, y)
			if maze.walls[maze.idx(x, y)] == 0 and not maze.is_house(t):
				_open_tiles.append(t)

	mode_index = 0
	mode_timer = 0.0
	in_chase = false
	fright_timer = 0.0
	ghost_chain = 0
	global_dots = -1
	no_dot_timer = 0.0
	fruit_tile = Vector2i(-1, -1)
	fruit_timer = 0.0
	fruit_shown = 0
	_dist_cache.clear()

	_build_actors()
	phase = Phase.READY
	phase_timer = READY_TIME
	return true


func _build_actors() -> void:
	pacman = Pacman.new()
	pacman.maze = maze
	ghosts.clear()
	for i in range(clampi(diff.ghost_count, 2, 6)):
		var g := Ghost.new()
		g.maze = maze
		g.rng = rng
		g.index = i
		g.kind = kind_for_index(i)
		g.dot_limit = _dot_limit(i)
		ghosts.append(g)
	_reset_actors()


func _reset_actors() -> void:
	pacman.place(Vector2i(int(maze.pacman_spawn.x), int(maze.pacman_spawn.y)), Vector2i.LEFT)
	pacman.want_dir = Vector2i.ZERO
	pacman.mouth = 0.0
	for g in ghosts:
		var home: Vector2 = maze.ghost_starts[mini(g.index, maze.ghost_starts.size() - 1)]
		g.reset(home, g.index == 0, maze.gate_exit)
		g.dot_limit = _dot_limit(g.index)
	_update_elroy()


func _dot_limit(i: int) -> int:
	var base := LevelTable.house_dot_limits(level)
	if i < base.size():
		return base[i]
	## Los fantasmas 5 y 6 no existen en el arcade: son una opcion de
	## dificultad, asi que salen de inmediato. Si heredaran limites altos de
	## puntos casi nunca apareceran, que es justo lo contrario de lo que el
	## jugador pidio al subirlos.
	return 0


# -- bucle -------------------------------------------------------------------

func update(dt: float) -> void:
	_accum += minf(dt, 0.25)
	while _accum >= TICK:
		_accum -= TICK
		_tick(TICK)


func _tick(dt: float) -> void:
	elapsed += dt
	match phase:
		Phase.READY:
			phase_timer -= dt
			if phase_timer <= 0.0:
				phase = Phase.PLAY
				level_started.emit(level)
		Phase.PLAY:
			_tick_play(dt)
		Phase.DYING:
			phase_timer -= dt
			if phase_timer <= 0.0:
				if lives <= 0:
					phase = Phase.OVER
					game_over.emit()
				else:
					_reset_actors()
					global_dots = 0
					no_dot_timer = 0.0
					mode_index = 0
					mode_timer = 0.0
					in_chase = false
					fright_timer = 0.0
					phase = Phase.READY
					phase_timer = READY_TIME
		Phase.CLEARED:
			phase_timer -= dt
			if phase_timer <= 0.0:
				level += 1
				if not build_level():
					phase = Phase.OVER
					game_over.emit()
		Phase.OVER:
			pass


func _tick_play(dt: float) -> void:
	if pacman.tile != _last_pac_tile:
		_last_pac_tile = pacman.tile
		_dist_cache.clear()

	_tick_modes(dt)
	_tick_fright(dt)
	_tick_release(dt)

	var pac_speed := _pacman_speed()
	pacman.step(pac_speed * dt)
	pacman.animate(dt, pac_speed)
	for t in pacman.entered:
		_eat_at(t)

	_tick_ghosts(dt)
	_tick_fruit(dt)
	_check_collisions()

	if phase == Phase.PLAY and pellets_left <= 0:
		phase = Phase.CLEARED
		phase_timer = CLEARED_TIME
		level_cleared.emit()


func _tick_modes(dt: float) -> void:
	if fright_timer > 0.0:
		return     ## el reloj de scatter/chase se congela mientras huyen
	mode_timer += dt
	var dur: float = schedule[mode_index]
	if mode_timer < dur:
		return
	mode_timer = 0.0
	mode_index = mini(mode_index + 1, schedule.size() - 1)
	in_chase = (mode_index % 2) == 1
	for g in ghosts:
		if g.state == Ghost.State.HUNT:
			g.reverse_pending = true
	mode_changed.emit(in_chase)


func _tick_fright(dt: float) -> void:
	if fright_timer <= 0.0:
		return
	fright_timer -= dt
	if fright_timer > 0.0:
		return
	fright_timer = 0.0
	ghost_chain = 0
	for g in ghosts:
		if g.state == Ghost.State.FRIGHTENED:
			g.state = Ghost.State.HUNT
	fright_ended.emit()


func _tick_release(dt: float) -> void:
	no_dot_timer += dt
	var limit := 4.0 if level < 5 else 3.0
	if no_dot_timer >= limit:
		no_dot_timer = 0.0
		_release_next()
		return
	## Los fantasmas sin limite de puntos (Pinky y los extra) no hacen cola:
	## salen en cuanto pueden. Si no, los extra quedan atrapados detras de
	## Inky y Clyde y el jugador que subio a 6 fantasmas no los ve nunca.
	for g in ghosts:
		if g.state == Ghost.State.HOUSE and not g.released and g.dot_limit <= 0:
			g.start_leaving(maze.gate, maze.gate_exit)
			return
	if global_dots >= 0:
		return
	## El resto si hace cola, como en el arcade: solo el primero cuenta puntos.
	for g in ghosts:
		if g.state == Ghost.State.HOUSE and not g.released:
			if g.dot_counter >= g.dot_limit:
				g.start_leaving(maze.gate, maze.gate_exit)
			return


func _release_next() -> void:
	for g in ghosts:
		if g.state == Ghost.State.HOUSE and not g.released:
			g.start_leaving(maze.gate, maze.gate_exit)
			return


func _tick_ghosts(dt: float) -> void:
	for g in ghosts:
		if g.kind == Ghost.Kind.RANDY:
			g.random_target_timer -= dt
			if g.random_target_timer <= 0.0:
				g.random_target_timer = 3.0
				g.target = _random_open_tile()
		else:
			g.target = _ghost_target(g)
		if _use_elite(g) and is_zero_approx(g.frac):
			g.dist_field = _dist_field(g.target)
		elif not _use_elite(g):
			g.dist_field = PackedInt32Array()
		g.update(_ghost_speed(g) * dt, maze.gate, maze.gate_exit, fright_timer > 0.0)


func _tick_fruit(dt: float) -> void:
	if not diff.fruit_enabled:
		return
	if fruit_timer > 0.0:
		fruit_timer -= dt
		if fruit_timer <= 0.0:
			fruit_tile = Vector2i(-1, -1)
	var frac := float(pellets_eaten) / maxf(float(pellets_total), 1.0)
	if fruit_shown == 0 and frac >= 0.29:
		_spawn_fruit()
	elif fruit_shown == 1 and frac >= 0.71:
		_spawn_fruit()
	if fruit_tile.x >= 0 and pacman.tile == fruit_tile:
		var pts := LevelTable.fruit_points(level)
		add_score(pts)
		fruit_tile = Vector2i(-1, -1)
		fruit_timer = 0.0
		fruit_taken.emit(pts)


func _spawn_fruit() -> void:
	fruit_shown += 1
	fruit_tile = _nearest_open(Vector2i(int(maze.pacman_spawn.x), maze.house.end.y + 1))
	fruit_timer = 9.0 + rng.randf() * 1.5
	fruit_spawned.emit(fruit_tile)


# -- comer -------------------------------------------------------------------

func _eat_at(t: Vector2i) -> void:
	var kind := maze.pellet_at(t)
	if kind == Maze.EMPTY:
		return
	maze.clear_pellet(t)
	pellets_eaten += 1
	pellets_left -= 1
	_house_dot_eaten()
	_update_elroy()
	if kind == Maze.POWER:
		add_score(50)
		_start_fright()
		power_eaten.emit(t)
	else:
		add_score(10)
		pellet_eaten.emit(t)


func _start_fright() -> void:
	var base := float(level_row.fright_time) * diff.power_duration
	if base <= 0.0:
		return     ## nivel 21+ o power pellets desactivados: no asustan
	fright_timer = base
	fright_total = base
	ghost_chain = 0
	for g in ghosts:
		if g.state == Ghost.State.HUNT:
			g.state = Ghost.State.FRIGHTENED
			g.reverse_pending = true
	fright_started.emit(base)


func _house_dot_eaten() -> void:
	no_dot_timer = 0.0
	if global_dots >= 0:
		global_dots += 1
		var th := [0, 7, 17, 32, 50, 70]
		for g in ghosts:
			if g.state == Ghost.State.HOUSE and not g.released:
				if global_dots >= int(th[mini(g.index, th.size() - 1)]):
					g.start_leaving(maze.gate, maze.gate_exit)
				return
		return
	for g in ghosts:
		if g.state == Ghost.State.HOUSE and not g.released:
			g.dot_counter += 1
			return


func add_score(p: int) -> void:
	score += p
	if score >= next_extra_life:
		lives += 1
		next_extra_life += maxi(diff.extra_life_score, 1)
		extra_life.emit()
	score_changed.emit(score)


func _check_collisions() -> void:
	for g in ghosts:
		if g.in_house_states() or g.state == Ghost.State.EYES:
			continue
		var hit := g.tile == pacman.tile
		if not hit and g.tile == pacman.prev_tile and pacman.tile == g.prev_tile:
			hit = true
		if not hit:
			continue
		if g.is_edible():
			ghost_chain += 1
			var pts := 200 * int(pow(2.0, float(mini(ghost_chain - 1, 3))))
			add_score(pts)
			g.get_eaten()
			ghost_eaten.emit(g, pts)
		else:
			lives -= 1
			phase = Phase.DYING
			phase_timer = DEATH_TIME
			pacman_died.emit()
			return


# -- velocidades -------------------------------------------------------------

func _pacman_speed() -> float:
	var pct := float(level_row.pac_fright) if fright_timer > 0.0 else float(level_row.pac)
	return LevelTable.BASE_SPEED * pct * diff.pacman_speed


func _ghost_speed(g: Ghost) -> float:
	var pct := 1.0
	match g.state:
		Ghost.State.EYES:
			pct = LevelTable.EYES_SPEED
		Ghost.State.HOUSE, Ghost.State.LEAVING, Ghost.State.ENTERING:
			pct = 0.55
		Ghost.State.FRIGHTENED:
			pct = float(level_row.ghost_fright)
		_:
			pct = float(level_row.ghost)
			if g.kind == Ghost.Kind.BLINKY and g.elroy > 0:
				pct = float(level_row.elroy2_speed) if g.elroy == 2 else float(level_row.elroy1_speed)
			if diff.tunnel_slowdown and _in_tunnel(g.tile):
				pct = float(level_row.ghost_tunnel)
	return LevelTable.BASE_SPEED * pct * diff.ghost_speed


func _in_tunnel(t: Vector2i) -> bool:
	return t.y == maze.tunnel_row and (t.x <= 2 or t.x >= maze.width - 3)


func _update_elroy() -> void:
	if ghosts.is_empty():
		return
	var b: Ghost = ghosts[0]
	if b.kind != Ghost.Kind.BLINKY:
		return
	if pellets_left <= int(level_row.elroy2_dots):
		b.elroy = 2
	elif pellets_left <= int(level_row.elroy1_dots):
		b.elroy = 1
	else:
		b.elroy = 0


# -- objetivos ---------------------------------------------------------------

func _ghost_target(g: Ghost) -> Vector2i:
	if g.state == Ghost.State.EYES:
		return maze.gate_exit
	var scatter: Vector2i = maze.scatter_targets[g.index % maze.scatter_targets.size()]
	if not in_chase and g.elroy == 0:
		return scatter

	match g.kind:
		Ghost.Kind.BLINKY:
			return pacman.tile
		Ghost.Kind.PINKY:
			var t := pacman.tile + pacman.dir * 4
			if diff.pinky_overflow_bug and pacman.dir == Vector2i.UP:
				t += Vector2i(-4, 0)     ## el overflow del original
			return t
		Ghost.Kind.INKY:
			var p := pacman.tile + pacman.dir * 2
			if diff.pinky_overflow_bug and pacman.dir == Vector2i.UP:
				p += Vector2i(-2, 0)
			var b: Vector2i = ghosts[0].tile
			return p + (p - b)
		Ghost.Kind.CLYDE:
			if Vector2(pacman.tile - g.tile).length() > 8.0:
				return pacman.tile
			return scatter
		Ghost.Kind.AMBUSH:
			return _nearest_power_to_pacman()
	return pacman.tile


func _nearest_power_to_pacman() -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for t in maze.power_tiles:
		if maze.pellet_at(t) != Maze.POWER:
			continue
		var d := Vector2(t - pacman.tile).length_squared()
		if d < bd:
			bd = d
			best = t
	if best.x < 0:
		return pacman.tile + pacman.dir * 8
	return best


func _random_open_tile() -> Vector2i:
	if _open_tiles.is_empty():
		return pacman.tile
	return _open_tiles[rng.randi_range(0, _open_tiles.size() - 1)]


# -- IA elite: campo de distancias por BFS -----------------------------------

func _use_elite(g: Ghost) -> bool:
	if g.state != Ghost.State.HUNT:
		return false
	match diff.ai:
		Difficulty.AI.ELITE:
			return true
		Difficulty.AI.MIXED:
			return g.index % 2 == 1
	return false


func _nearest_open(t: Vector2i) -> Vector2i:
	if maze.in_bounds(t.x, t.y) and maze.walls[maze.idx(t.x, t.y)] == 0 and not maze.is_house(t):
		return t
	var best := _open_tiles[0] if not _open_tiles.is_empty() else Vector2i.ZERO
	var bd := INF
	for o in _open_tiles:
		var d := Vector2(o - t).length_squared()
		if d < bd:
			bd = d
			best = o
	return best


func _dist_field(target: Vector2i) -> PackedInt32Array:
	var t := _nearest_open(target)
	var key := maze.idx(t.x, t.y)
	if _dist_cache.has(key):
		return _dist_cache[key]
	var f := PackedInt32Array()
	f.resize(maze.width * maze.height)
	f.fill(-1)
	f[key] = 0
	var q: Array[Vector2i] = [t]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		var base := f[maze.idx(cur.x, cur.y)]
		for d in Maze.DIRS:
			var n := maze.wrap_tile(cur + d)
			if not maze.in_bounds(n.x, n.y):
				continue
			if maze.walls[maze.idx(n.x, n.y)] == 1 or maze.is_house(n):
				continue
			var k := maze.idx(n.x, n.y)
			if f[k] >= 0:
				continue
			f[k] = base + 1
			q.append(n)
	_dist_cache[key] = f
	return f


# -- input -------------------------------------------------------------------

func input_dir(d: Vector2i) -> void:
	if phase == Phase.PLAY or phase == Phase.READY:
		pacman.request(d)


func fright_blinking() -> bool:
	return fright_timer > 0.0 and fright_timer < minf(2.0, fright_total * 0.4)
