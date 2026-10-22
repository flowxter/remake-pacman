class_name Pacman
extends GridActor

## Pac-Man. Lo unico que lo distingue de un fantasma es el input buffer:
## la ultima tecla pulsada se guarda y se aplica en el primer centro de tile
## donde sea legal. Sin eso el juego se siente resbaladizo y es imposible
## trazar un giro limpio en una interseccion.

var want_dir: Vector2i = Vector2i.ZERO
var mouth: float = 0.0        ## fase de la animacion de la boca


func _can_enter(t: Vector2i) -> bool:
	return maze.is_open(t) and not maze.is_house(t)


func _at_center() -> void:
	if want_dir == Vector2i.ZERO:
		return
	if _can_enter(maze.wrap_tile(tile + want_dir)):
		dir = want_dir


## Guarda la intencion del jugador. La reversa se aplica al instante porque
## el arcade tambien la permite a mitad de pasillo.
func request(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	want_dir = d
	if dir != Vector2i.ZERO and d == -dir and frac > 0.0:
		reverse()
		want_dir = d


func animate(dt: float, speed_tiles: float) -> void:
	if is_blocked or dir == Vector2i.ZERO:
		return
	mouth += dt * speed_tiles * 1.6
