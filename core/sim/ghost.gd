class_name Ghost
extends GridActor

## Los fantasmas del arcade NO usan pathfinding.
##
## En cada centro de tile eligen la direccion que minimiza la distancia
## euclidea a un tile objetivo, con dos reglas: no pueden invertir el sentido
## y los empates se rompen en el orden arriba, izquierda, abajo, derecha. Eso
## es lo que produce su comportamiento caracteristico: torpe, acorralable,
## pero amenazante. Si se les pone A* se vuelven implacables y el juego deja
## de ser Pac-Man -- por eso la IA "elite" existe solo como opcion.
##
## Lo que cambia entre los cuatro es unicamente el tile objetivo.

enum Kind { BLINKY, PINKY, INKY, CLYDE, RANDY, AMBUSH }
enum State { HOUSE, LEAVING, HUNT, FRIGHTENED, EYES, ENTERING }

const KIND_NAMES := ["blinky", "pinky", "inky", "clyde", "randy", "ambush"]

var kind: Kind = Kind.BLINKY
var index: int = 0
var state: State = State.HOUSE

## Objetivo y campo de distancias los calcula la simulacion antes de mover:
## asi el fantasma no necesita conocer el resto del juego.
var target: Vector2i = Vector2i.ZERO
var dist_field: PackedInt32Array = PackedInt32Array()
var rng: RandomNumberGenerator

## Casa de fantasmas: en HOUSE / LEAVING / ENTERING el movimiento es libre,
## porque el interior de la casa no es un pasillo de 1 tile.
var home_pos: Vector2 = Vector2.ZERO
var free_pos: Vector2 = Vector2.ZERO
var path: Array[Vector2] = []
var bob_t: float = 0.0

var elroy: int = 0              ## 0, 1 o 2; solo Blinky
var dot_counter: int = 0
var dot_limit: int = 0
var released: bool = false
var reverse_pending: bool = false
var random_target_timer: float = 0.0


func world_pos() -> Vector2:
	if state == State.HOUSE or state == State.LEAVING or state == State.ENTERING:
		return free_pos
	return super()


func in_house_states() -> bool:
	return state == State.HOUSE or state == State.LEAVING or state == State.ENTERING


func is_edible() -> bool:
	return state == State.FRIGHTENED


func is_dangerous() -> bool:
	return state == State.HUNT or state == State.LEAVING


func reset(p_home: Vector2, start_outside: bool, gate_exit: Vector2i) -> void:
	home_pos = p_home
	free_pos = p_home
	path.clear()
	elroy = 0
	dot_counter = 0
	released = false
	reverse_pending = false
	bob_t = 0.0
	dist_field = PackedInt32Array()
	if start_outside:
		state = State.HUNT
		released = true
		place(gate_exit, Vector2i.LEFT)
	else:
		state = State.HOUSE
		dir = Vector2i.UP
		place(Vector2i(int(round(p_home.x)), int(round(p_home.y))), Vector2i.UP)


# -- movimiento --------------------------------------------------------------

func update(dist: float, gate: Vector2i, gate_exit: Vector2i, fright_active: bool) -> void:
	match state:
		State.HOUSE:
			bob_t += dist
			free_pos = home_pos + Vector2(0, sin(bob_t * 3.2) * 0.35)
			dir = Vector2i.UP if sin(bob_t * 3.2) >= 0.0 else Vector2i.DOWN
		State.LEAVING:
			if path.is_empty():
				_build_exit_path(gate, gate_exit)
			_set_dir_from(path[0] if not path.is_empty() else free_pos)
			if _follow_path(dist):
				place(gate_exit, Vector2i.LEFT)
				state = State.FRIGHTENED if fright_active else State.HUNT
				if state == State.FRIGHTENED:
					reverse_pending = false
		State.ENTERING:
			if path.is_empty():
				_build_enter_path(gate)
			_set_dir_from(path[0] if not path.is_empty() else free_pos)
			if _follow_path(dist):
				state = State.HOUSE
				released = false
				bob_t = 0.0
		_:
			if reverse_pending:
				reverse_pending = false
				reverse()
			step(dist)
			if state == State.EYES and tile == gate_exit and is_zero_approx(frac):
				state = State.ENTERING
				free_pos = Vector2(gate_exit)
				path.clear()


func start_leaving(gate: Vector2i, gate_exit: Vector2i) -> void:
	if state != State.HOUSE:
		return
	state = State.LEAVING
	released = true
	_build_exit_path(gate, gate_exit)


func get_eaten() -> void:
	state = State.EYES
	dist_field = PackedInt32Array()


func _build_exit_path(gate: Vector2i, gate_exit: Vector2i) -> void:
	path = [Vector2(gate.x, free_pos.y), Vector2(gate.x, gate_exit.y)]


func _build_enter_path(gate: Vector2i) -> void:
	path = [Vector2(gate.x, gate.y), Vector2(gate.x, home_pos.y), home_pos]


func _follow_path(dist: float) -> bool:
	var guard := 0
	while dist > 0.0 and not path.is_empty() and guard < 16:
		guard += 1
		var tgt: Vector2 = path[0]
		var to := tgt - free_pos
		var d := to.length()
		if d <= dist:
			free_pos = tgt
			path.remove_at(0)
			dist -= d
		else:
			free_pos += to / d * dist
			dist = 0.0
	return path.is_empty()


func _set_dir_from(tgt: Vector2) -> void:
	var to := tgt - free_pos
	if to.length_squared() < 0.0001:
		return
	if absf(to.x) > absf(to.y):
		dir = Vector2i.RIGHT if to.x > 0.0 else Vector2i.LEFT
	else:
		dir = Vector2i.DOWN if to.y > 0.0 else Vector2i.UP


func _can_enter(t: Vector2i) -> bool:
	if not maze.is_open(t):
		return false
	if maze.is_house(t):
		return false      ## entrar y salir de la casa es movimiento libre
	return true


## La decision del arcade: greedy sobre la distancia euclidea al objetivo,
## sin invertir el sentido, empates en orden arriba/izquierda/abajo/derecha.
func _at_center() -> void:
	var cands := dirs_available(true)
	if cands.is_empty():
		cands = dirs_available(false)
		if cands.is_empty():
			dir = Vector2i.ZERO
			return

	if state == State.FRIGHTENED:
		dir = cands[rng.randi_range(0, cands.size() - 1)]
		return

	var best: Vector2i = cands[0]
	var best_score := INF
	for d in cands:
		var n := maze.wrap_tile(tile + d)
		var score: float
		if dist_field.is_empty():
			score = Vector2(target - n).length_squared()
		else:
			var v := dist_field[maze.idx(n.x, n.y)]
			score = INF if v < 0 else float(v)
		if score < best_score:
			best_score = score
			best = d
	dir = best


func kind_name() -> String:
	return String(KIND_NAMES[kind])
