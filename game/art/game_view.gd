class_name GameView
extends Node2D

## Dibuja el tablero. Todo el dibujo esta en unidades de tile (1.0 = un
## tile) y el escalado a pixeles lo hace la transformacion del nodo, asi que
## el mismo codigo sirve para cualquier tamano de laberinto y de ventana.

const PACMAN_R := 0.46
const GHOST_R := 0.46
const PELLET_R := 0.09
const POWER_R := 0.3

var sim: GameSim
var bank: AssetBank
var walls: WallLayer

var anim: float = 0.0
var hide_actors: bool = false
var fog_radius: float = 0.0     ## 0 = sin niebla
var _popups: Array = []      ## [{pos: Vector2, text: String, t: float}]


func _ready() -> void:
	walls = WallLayer.new()
	walls.name = "WallLayer"
	add_child(walls)


func setup(p_sim: GameSim, p_bank: AssetBank) -> void:
	sim = p_sim
	bank = p_bank
	walls.set_maze(p_sim.maze)


func on_new_maze() -> void:
	_popups.clear()
	walls.set_maze(sim.maze)


func add_popup(at: Vector2, text: String) -> void:
	_popups.append({"pos": at, "text": text, "t": 0.0})


func _process(dt: float) -> void:
	anim += dt
	var keep: Array = []
	for p in _popups:
		p["t"] = float(p["t"]) + dt
		if float(p["t"]) < 1.0:
			keep.append(p)
	_popups = keep
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.maze == null:
		return
	_draw_pellets()
	_draw_fruit()
	if not hide_actors:
		_draw_ghosts()
		_draw_pacman()
	_draw_fog()
	_draw_popups()


## Niebla: oscurece todo lo que queda fuera de un radio alrededor de
## Pac-Man. Se dibuja como un anillo de cuadrilateros porque el canvas 2D no
## sabe recortar agujeros en un poligono.
func _draw_fog() -> void:
	if fog_radius <= 0.0 or sim.phase == GameSim.Phase.CLEARED:
		return
	var c := sim.pacman.world_pos()
	var far := float(maxi(sim.maze.width, sim.maze.height)) * 1.6
	var radii := [fog_radius, fog_radius * 1.2, fog_radius * 1.45, far]
	var shades := [Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.82), Color(0, 0, 0, 1.0)]
	var seg := 40
	for ring in range(3):
		var r0 := float(radii[ring])
		var r1 := float(radii[ring + 1])
		for i in range(seg):
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			draw_colored_polygon(PackedVector2Array([
				c + d0 * r0, c + d1 * r0, c + d1 * r1, c + d0 * r1,
			]), shades[ring])


func _draw_pellets() -> void:
	var m := sim.maze
	var blink := fmod(anim * 5.0, 2.0) < 1.0
	for y in range(m.height):
		for x in range(m.width):
			var p := m.pellets[m.idx(x, y)]
			if p == Maze.EMPTY:
				continue
			var c := Vector2(x, y)
			if p == Maze.POWER:
				if not _sprite("power", c, 0):
					Painter.power_pellet(self, c, POWER_R, blink)
			else:
				if not _sprite("pellet", c, 0):
					draw_rect(Rect2(c - Vector2(PELLET_R, PELLET_R), Vector2(PELLET_R * 2.0, PELLET_R * 2.0)), Palette.PELLET)


func _draw_fruit() -> void:
	if sim.fruit_tile.x < 0:
		return
	var name := LevelTable.fruit_name(sim.level)
	var c := Vector2(sim.fruit_tile)
	if not _sprite(name, c, 0):
		Painter.fruit(self, c, 0.5, name)


func _draw_pacman() -> void:
	var pac := sim.pacman
	var c := pac.world_pos()
	if sim.phase == GameSim.Phase.DYING:
		var t := 1.0 - clampf(sim.phase_timer / GameSim.DEATH_TIME, 0.0, 1.0)
		var n := bank.frame_count("pacman_death") if bank != null else 0
		if n > 0 and _sprite("pacman_death", c, mini(int(t * float(n)), n - 1)):
			return
		Painter.pacman_dying(self, c, PACMAN_R, t)
		return
	var key := "pacman_" + _dir_name(pac.dir)
	if _sprite(key, c, int(pac.mouth * 2.0)):
		return
	Painter.pacman(self, c, PACMAN_R, pac.dir, pac.mouth)


func _draw_ghosts() -> void:
	var wave := anim * 6.0
	for g in sim.ghosts:
		var c := g.world_pos()
		match g.state:
			Ghost.State.FRIGHTENED:
				var blinking := sim.fright_blinking() and fmod(anim * 6.0, 2.0) < 1.0
				var key := "frightened_flash" if blinking else "frightened"
				if not _sprite(key, c, int(wave)):
					Painter.ghost_frightened(self, c, GHOST_R, blinking, wave)
			Ghost.State.EYES, Ghost.State.ENTERING:
				if not _sprite("eyes_" + _dir_name(g.dir), c, 0):
					Painter.ghost_eyes(self, c, GHOST_R, g.dir)
			_:
				var key2 := "%s_%s" % [g.kind_name(), _dir_name(g.dir)]
				if not _sprite(key2, c, int(wave)):
					Painter.ghost(self, c, GHOST_R, g.dir, Palette.ghost_body(g.index), wave)


func _draw_popups() -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	for p in _popups:
		var t := float(p["t"])
		var pos: Vector2 = p["pos"] + Vector2(0, -t * 0.8)
		var col := Palette.GATE
		col.a = clampf(1.0 - t, 0.0, 1.0)
		# El texto se dibuja sin el escalado del nodo para que no se deforme.
		draw_set_transform(pos, 0.0, Vector2(0.06, 0.06))
		draw_string(font, Vector2(-26, 0), String(p["text"]), HORIZONTAL_ALIGNMENT_CENTER, 52, 40, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Dibuja un sprite de assets/ si existe. Devuelve false si hay que recurrir
## al dibujo procedural.
func _sprite(key: String, center: Vector2, frame_i: int) -> bool:
	if bank == null:
		return false
	var tex := bank.frame(key, frame_i)
	if tex == null:
		return false
	# Los sprites del arcade estan hechos para tiles de 8 px: uno de 16x16
	# ocupa 2 tiles y el punto de 2x2 ocupa un cuarto. Sacando el tamano del
	# propio archivo salen a su escala real sin ajustarlo a mano.
	var sz := Vector2(tex.get_width(), tex.get_height()) / float(Maze.TILE_PX)
	draw_texture_rect(tex, Rect2(center - sz * 0.5, sz), false)
	return true


func _dir_name(d: Vector2i) -> String:
	if d == Vector2i.UP:
		return "up"
	if d == Vector2i.DOWN:
		return "down"
	if d == Vector2i.RIGHT:
		return "right"
	return "left"
