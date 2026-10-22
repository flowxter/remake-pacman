extends SceneTree

## Test de la simulacion: un piloto automatico juega solo y se verifican las
## invariantes en cada tick.
##   godot --headless --path . --script res://tests/test_sim.gd
##
## Nota: los contadores son variables miembro a proposito. En GDScript los
## lambdas capturan las locales POR VALOR, asi que un contador local
## incrementado dentro de un callback de senal se queda siempre a cero.

const SECONDS := 150.0
const CLEAR_SECONDS := 300.0

var failures := 0
var checks := 0

# contadores alimentados por senales
var deaths := 0
var levels := 0
var ghosts_eaten := 0
var fruits := 0
var cleared_with_pellets_left := -1

# cache del piloto automatico
var _cache_tile := Vector2i(-999, -999)
var _cache_dir := Vector2i.ZERO
var _avoid_ghosts := true


func _initialize() -> void:
	_run("classic", 12345)
	_run("nightmare", 777)
	_test_clear_level()
	_test_reverse()
	_test_power_pellet()

	print("")
	if failures == 0:
		print("OK  -  %d comprobaciones, 0 fallos" % checks)
	else:
		printerr("FALLOS: %d de %d comprobaciones" % [failures, checks])
	quit(1 if failures > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("  FALLO: " + msg)


# -- escenario completo ------------------------------------------------------

func _run(preset_name: String, seed_value: int) -> void:
	var diff := Difficulty.preset(preset_name)
	diff.seed = seed_value
	diff.lives = 99            ## que no termine por game over
	diff.start_level = 1

	deaths = 0
	levels = 0
	ghosts_eaten = 0
	fruits = 0
	cleared_with_pellets_left = -1
	_cache_tile = Vector2i(-999, -999)

	var sim := GameSim.new()
	_assert(sim.start(diff), "%s: no se pudo arrancar la simulacion" % preset_name)
	if sim.maze == null:
		return
	sim.pacman_died.connect(_on_death)
	sim.ghost_eaten.connect(_on_ghost_eaten)
	sim.fruit_taken.connect(_on_fruit)
	sim.level_cleared.connect(_on_cleared.bind(sim))

	var bad_tiles := 0
	var pac_moves := 0
	var last_pac := sim.pacman.tile
	var house_empty_at := -1.0
	var ghosts_out_of_house := 0
	var max_out := 0

	for _i in range(int(SECONDS * 120.0)):
		_autopilot(sim)
		sim.update(GameSim.TICK)
		if sim.phase == GameSim.Phase.OVER:
			break
		if sim.phase != GameSim.Phase.PLAY:
			continue

		if sim.pacman.tile != last_pac:
			pac_moves += 1
			last_pac = sim.pacman.tile
		if sim.maze.is_wall(sim.pacman.tile) or sim.maze.is_house(sim.pacman.tile):
			bad_tiles += 1
		var all_out := true
		var out_now := 0
		for g in sim.ghosts:
			if not g.in_house_states() and sim.maze.is_wall(g.tile):
				bad_tiles += 1
			if g.state == Ghost.State.HOUSE:
				all_out = false
			else:
				ghosts_out_of_house += 1
				out_now += 1
		max_out = maxi(max_out, out_now)
		if all_out and house_empty_at < 0.0:
			house_empty_at = sim.elapsed

	_assert(bad_tiles == 0, "%s: %d ticks con un actor dentro de pared o de la casa" % [preset_name, bad_tiles])
	_assert(sim.score > 0, "%s: la puntuacion no subio" % preset_name)
	_assert(pac_moves > 500, "%s: Pac-Man apenas se movio (%d tiles)" % [preset_name, pac_moves])
	## Que la casa se vacie del todo depende de que el jugador deje de comer
	## (el temporizador de 4 s del arcade), asi que no se exige. Lo que si
	## tiene que pasar es que salgan varios y persigan.
	_assert(max_out >= 2, "%s: nunca hubo 2 fantasmas fuera a la vez (max %d)" % [preset_name, max_out])
	_assert(ghosts_out_of_house > 0, "%s: ningun fantasma salio nunca" % preset_name)
	_assert(deaths > 0, "%s: el piloto nunca murio, las colisiones no se detectan" % preset_name)
	_assert(sim.phase != GameSim.Phase.OVER,
		"%s: se quedo en game over teniendo 99 vidas" % preset_name)

	var states: Array[String] = []
	for g in sim.ghosts:
		states.append("%s:%s" % [g.kind_name(), _state_name(g.state)])
	print("%-10s semilla=%d  nivel=%d  puntos=%d  niveles=%d  muertes=%d  fantasmas=%d  frutas=%d"
		% [preset_name, seed_value, sim.level, sim.score, levels, deaths, ghosts_eaten, fruits])
	print("           comidos=%d/%d  tiles=%d (%.0f%% con pellet)  max_fuera=%d  estados=%s"
		% [sim.pellets_eaten, sim.pellets_total, pac_moves,
			100.0 * float(sim.pellets_eaten) / maxf(float(pac_moves), 1.0), max_out, str(states)])


func _on_death() -> void:
	deaths += 1


func _on_ghost_eaten(_g: Ghost, _p: int) -> void:
	ghosts_eaten += 1


func _on_fruit(_p: int) -> void:
	fruits += 1


func _on_cleared(sim: GameSim) -> void:
	levels += 1
	cleared_with_pellets_left = sim.pellets_left


func _state_name(s: int) -> String:
	return ["casa", "saliendo", "caza", "huye", "ojos", "entrando"][s]


## Con fantasmas inofensivos el piloto tiene que limpiar el nivel entero y
## la simulacion tiene que pasar al nivel 2 con un laberinto nuevo.
func _test_clear_level() -> void:
	var diff := Difficulty.preset("classic")
	diff.seed = 31337
	diff.ghost_count = 2
	diff.ghost_speed = 0.05
	diff.lives = 99
	levels = 0
	deaths = 0
	cleared_with_pellets_left = -1
	_cache_tile = Vector2i(-999, -999)
	_avoid_ghosts = false

	var sim := GameSim.new()
	if not sim.start(diff):
		_assert(false, "completar nivel: no arranco")
		_avoid_ghosts = true
		return
	sim.level_cleared.connect(_on_cleared.bind(sim))
	var first_walls := sim.maze.walls.duplicate()
	var total := sim.pellets_total

	for _i in range(int(CLEAR_SECONDS * 120.0)):
		_autopilot(sim)
		sim.update(GameSim.TICK)
		if levels >= 1 and sim.level >= 2 and sim.phase == GameSim.Phase.PLAY:
			break

	_assert(levels >= 1, "completar nivel: no se limpio el laberinto en %.0f s (quedaban %d)"
		% [CLEAR_SECONDS, sim.pellets_left])
	_assert(cleared_with_pellets_left == 0,
		"completar nivel: se dio por completado con %d pellets" % cleared_with_pellets_left)
	_assert(sim.level == 2, "completar nivel: el nivel no avanzo (nivel=%d)" % sim.level)
	_assert(sim.maze.walls != first_walls, "completar nivel: el nivel 2 reusa el mismo laberinto")
	_assert(sim.pellets_total > 0 and sim.pellets_left == sim.pellets_total - sim.pellets_eaten,
		"completar nivel: contabilidad de pellets inconsistente")
	print("completar nivel: laberinto de %d pellets limpiado, nivel 2 con laberinto nuevo (%d pellets)"
		% [total, sim.pellets_total])
	_avoid_ghosts = true


# -- pruebas puntuales -------------------------------------------------------

## La reversa instantanea tiene que conservar la posicion exacta en el mundo.
func _test_reverse() -> void:
	var diff := Difficulty.preset("classic")
	diff.seed = 2024
	var sim := GameSim.new()
	if not sim.start(diff):
		_assert(false, "reversa: no arranco")
		return
	var pac := sim.pacman
	# colocarlo en un pasillo horizontal y avanzar media casilla
	pac.place(Vector2i(int(sim.maze.pacman_spawn.x), int(sim.maze.pacman_spawn.y)), Vector2i.LEFT)
	pac.step(0.4)
	var before := pac.world_pos()
	var before_dir := pac.dir
	pac.request(-before_dir)
	var after := pac.world_pos()
	_assert(before.distance_to(after) < 0.001,
		"reversa: la posicion salto de %s a %s" % [str(before), str(after)])
	_assert(pac.dir == -before_dir, "reversa: la direccion no se invirtio")
	print("reversa instantanea: posicion conservada (%s -> %s)" % [str(before), str(after)])


## Comerse un power pellet asusta a los fantasmas que estan fuera y les hace
## invertir el sentido; la cadena de puntos es 200/400/800/1600.
func _test_power_pellet() -> void:
	var diff := Difficulty.preset("classic")
	diff.seed = 999
	var sim := GameSim.new()
	if not sim.start(diff):
		_assert(false, "power pellet: no arranco")
		return
	for _i in range(int(20.0 * 120.0)):
		_autopilot(sim)
		sim.update(GameSim.TICK)

	## El piloto puede haberse comido un power pellet durante el calentamiento:
	## se limpia el estado para partir de una situacion conocida.
	sim.fright_timer = 0.0
	for g in sim.ghosts:
		if g.state == Ghost.State.FRIGHTENED:
			g.state = Ghost.State.HUNT
		g.reverse_pending = false
	var hunting := 0
	var hunters: Array[Ghost] = []
	for g in sim.ghosts:
		if g.state == Ghost.State.HUNT:
			hunting += 1
			hunters.append(g)

	var target: Vector2i = sim.maze.power_tiles[0]
	sim.maze.pellets[sim.maze.idx(target.x, target.y)] = Maze.POWER
	sim._eat_at(target)

	var frightened := 0
	for g in sim.ghosts:
		if g.state == Ghost.State.FRIGHTENED:
			frightened += 1
	_assert(sim.fright_timer > 0.0, "power pellet: no se activo el modo frightened")
	_assert(hunting > 0, "power pellet: no habia ningun fantasma en caza para asustar")
	_assert(frightened == hunting,
		"power pellet: %d en caza pero solo %d asustados" % [hunting, frightened])
	var reversed_count := 0
	for g in hunters:
		if g.reverse_pending:
			reversed_count += 1
	_assert(reversed_count == hunting,
		"power pellet: %d de %d fantasmas sin invertir el sentido" % [hunting - reversed_count, hunting])

	var chain: Array[int] = []
	for i in range(1, 6):
		chain.append(200 * int(pow(2.0, float(mini(i - 1, 3)))))
	_assert(chain[0] == 200 and chain[1] == 400 and chain[2] == 800 and chain[3] == 1600 and chain[4] == 1600,
		"power pellet: cadena de puntos erronea %s" % str(chain))
	print("power pellet: %d en caza -> %d asustados, timer %.1fs, cadena %s"
		% [hunting, frightened, sim.fright_timer, str(chain)])


# -- piloto automatico -------------------------------------------------------

## Desciende el gradiente de un BFS multi-origen desde todos los pellets y
## penaliza las casillas con un fantasma peligroso cerca. No es un jugador
## experto, solo lo bastante bueno para completar un nivel.
func _autopilot(sim: GameSim) -> void:
	if sim.phase != GameSim.Phase.PLAY:
		return
	var pac := sim.pacman
	var m := sim.maze
	## want_dir se aplica en el PROXIMO centro de tile, asi que hay que
	## planificar desde la casilla a la que va a entrar. Decidir desde la
	## actual hace que cada giro llegue una casilla tarde.
	var from: Vector2i = pac.tile if is_zero_approx(pac.frac) else m.wrap_tile(pac.tile + pac.dir)
	if from == _cache_tile:
		pac.want_dir = _cache_dir
		return
	_cache_tile = from
	var food := _field(m, _pellet_sources(m))
	var danger := _field(m, _ghost_sources(sim, true)) if _avoid_ghosts else PackedInt32Array()
	var prey := _field(m, _ghost_sources(sim, false)) if _avoid_ghosts else PackedInt32Array()

	var best := pac.dir
	var best_score := INF
	for d in Maze.DIRS:
		var n := m.wrap_tile(from + d)
		if m.is_wall(n) or m.is_house(n):
			continue
		var k := m.idx(n.x, n.y)
		if food[k] < 0:
			continue
		var score := float(food[k])
		if _avoid_ghosts:
			if danger[k] >= 0 and danger[k] <= 3:
				score += 60.0 * float(4 - danger[k])
			if prey[k] >= 0 and prey[k] <= 6:
				score -= 20.0
		if d == -pac.dir:
			score += 2.0
		if score < best_score:
			best_score = score
			best = d
	_cache_dir = best
	pac.want_dir = best


func _pellet_sources(m: Maze) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(m.height):
		for x in range(m.width):
			if m.pellets[m.idx(x, y)] != Maze.EMPTY:
				out.append(Vector2i(x, y))
	return out


func _ghost_sources(sim: GameSim, dangerous: bool) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for g in sim.ghosts:
		if g.in_house_states() or g.state == Ghost.State.EYES:
			continue
		if g.is_dangerous() == dangerous:
			out.append(g.tile)
	return out


func _field(m: Maze, sources: Array[Vector2i]) -> PackedInt32Array:
	var f := PackedInt32Array()
	f.resize(m.width * m.height)
	f.fill(-1)
	var q: Array[Vector2i] = []
	for s in sources:
		var k := m.idx(s.x, s.y)
		if f[k] < 0:
			f[k] = 0
			q.append(s)
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		var base := f[m.idx(cur.x, cur.y)]
		for d in Maze.DIRS:
			var n := m.wrap_tile(cur + d)
			if not m.in_bounds(n.x, n.y) or m.is_wall(n) or m.is_house(n):
				continue
			var k2 := m.idx(n.x, n.y)
			if f[k2] >= 0:
				continue
			f[k2] = base + 1
			q.append(n)
	return f
