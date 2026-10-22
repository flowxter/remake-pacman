extends Node2D

## Arranque y pegamento: menu -> partida -> menu.
##
## Toda la logica del juego vive en core/. Aqui solo se traduce input a
## intenciones, se dibuja lo que dice la simulacion y se disparan sonidos a
## partir de sus senales.

const VIEW_W := 480.0
const VIEW_H := 600.0
const HUD_TOP := 46.0
const HUD_BOTTOM := 30.0
const SAVE_PATH := "user://pacman_remake.cfg"

enum State { MENU, PLAYING, PAUSED }

var bank: AssetBank
var audio: AudioBank
var sim: GameSim
var view: GameView
var hud: Hud
var menu: OptionsMenu
var diff: Difficulty

var state: State = State.MENU
var high_score: int = 0
var _flash_t: float = 0.0


func _ready() -> void:
	bank = AssetBank.new()
	bank.load_all()

	audio = AudioBank.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup(bank)

	view = GameView.new()
	view.name = "View"
	view.visible = false
	add_child(view)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	hud = Hud.new()
	hud.name = "Hud"
	hud.visible = false
	ui.add_child(hud)

	menu = OptionsMenu.new()
	menu.name = "Menu"
	menu.asset_note = bank.report()
	menu.play_requested.connect(_on_play)
	ui.add_child(menu)

	_load_high_score()
	hud.high_score = high_score
	print(bank.report())


# -- menu / partida ----------------------------------------------------------

func _on_play(d: Difficulty) -> void:
	diff = d
	_start_game()


func _start_game() -> void:
	sim = GameSim.new()
	if not sim.start(diff):
		menu.asset_note = "no se pudo generar un laberinto con esas opciones"
		return
	_connect_sim()
	view.setup(sim, bank)
	view.walls.show_behind_parent = true
	view.fog_radius = diff.vision_radius
	hud.sim = sim
	hud.high_score = high_score
	_layout()
	audio.play("ready")
	menu.visible = false
	view.visible = true
	hud.visible = true
	state = State.PLAYING


func _back_to_menu() -> void:
	audio.stop_ambient()
	state = State.MENU
	menu.visible = true
	view.visible = false
	hud.visible = false
	hud.message = ""
	menu.asset_note = bank.report()


func _connect_sim() -> void:
	sim.pellet_eaten.connect(func(_t: Vector2i) -> void: audio.waka())
	sim.power_eaten.connect(func(_t: Vector2i) -> void: audio.waka())
	sim.ghost_eaten.connect(_on_ghost_eaten)
	sim.fruit_taken.connect(_on_fruit_taken)
	sim.pacman_died.connect(_on_pacman_died)
	sim.extra_life.connect(func() -> void: audio.play("extra_life"))
	sim.level_cleared.connect(func() -> void: audio.stop_ambient())
	sim.game_over.connect(_on_game_over)
	sim.score_changed.connect(_on_score_changed)


func _on_ghost_eaten(g: Ghost, points: int) -> void:
	audio.play("eat_ghost")
	view.add_popup(g.world_pos(), str(points))


func _on_fruit_taken(points: int) -> void:
	audio.play("fruit")
	view.add_popup(Vector2(sim.pacman.tile), str(points))


func _on_pacman_died() -> void:
	audio.stop_ambient()
	audio.play("death")


func _on_game_over() -> void:
	audio.stop_ambient()
	_save_high_score()


func _on_score_changed(score: int) -> void:
	if score > high_score:
		high_score = score
		hud.high_score = high_score


## Coloca el tablero centrado entre las dos franjas del HUD. El dibujo esta
## en unidades de tile, asi que basta con escalar el nodo.
func _layout() -> void:
	var m := sim.maze
	var avail := Vector2(VIEW_W - 16.0, VIEW_H - HUD_TOP - HUD_BOTTOM)
	var px := minf(avail.x / float(m.width), avail.y / float(m.height))
	px = floorf(px * 4.0) / 4.0
	var board := Vector2(float(m.width), float(m.height)) * px
	var origin := Vector2((VIEW_W - board.x) * 0.5, HUD_TOP + (avail.y - board.y) * 0.5)
	view.scale = Vector2(px, px)
	view.position = origin + Vector2(px, px) * 0.5
	hud.board_rect = Rect2(origin, board)


# -- bucle -------------------------------------------------------------------

func _process(dt: float) -> void:
	if state != State.PLAYING or sim == null:
		return
	sim.update(dt)
	_update_audio()
	_update_hud()
	view.hide_actors = sim.phase == GameSim.Phase.CLEARED

	if sim.phase == GameSim.Phase.CLEARED:
		_flash_t += dt
		view.walls.set_flash(fmod(_flash_t, 0.26) < 0.13)
	else:
		_flash_t = 0.0
		view.walls.set_flash(false)

	if sim.maze != view.walls.maze:
		view.on_new_maze()
		view.fog_radius = diff.vision_radius
		_layout()


func _update_audio() -> void:
	if sim.phase != GameSim.Phase.PLAY:
		audio.stop_ambient()
		return
	if sim.fright_timer > 0.0:
		audio.set_ambient("fright", 1.0)
		return
	# La sirena se acelera a medida que se vacia el laberinto, como el arcade.
	var progress := float(sim.pellets_eaten) / maxf(float(sim.pellets_total), 1.0)
	var pitch := 1.0 + progress * 0.45 + float(sim.level - 1) * 0.04
	audio.set_ambient("siren", clampf(pitch, 0.8, 2.2))


func _update_hud() -> void:
	hud.seed_text = "SEMILLA %d" % sim.maze.seed_used
	match sim.phase:
		GameSim.Phase.READY:
			hud.message = "LISTO!"
			hud.message_color = Palette.TEXT_ACCENT
			hud.sub_message = ""
		GameSim.Phase.CLEARED:
			hud.message = "NIVEL %d SUPERADO" % sim.level
			hud.message_color = Palette.GATE
			hud.sub_message = "laberinto nuevo en camino"
		GameSim.Phase.OVER:
			hud.message = "GAME OVER"
			hud.message_color = Palette.TEXT_WARN
			hud.sub_message = "ENTER para volver al menu"
		_:
			hud.message = ""
			hud.sub_message = ""
	if state == State.PAUSED:
		hud.message = "PAUSA"
		hud.message_color = Palette.TEXT
		hud.sub_message = "P para seguir"


# -- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return

	if state == State.MENU:
		menu.handle_key(k)
		return

	match k.keycode:
		KEY_ESCAPE:
			_back_to_menu()
			return
		KEY_M:
			audio.toggle_mute()
			return
		KEY_P:
			if sim.phase != GameSim.Phase.OVER:
				state = State.PAUSED if state == State.PLAYING else State.PLAYING
				if state == State.PAUSED:
					audio.stop_ambient()
			return
		KEY_R:
			_start_game()
			return
		KEY_N:
			# Mismo nivel, laberinto nuevo: para probar el generador en vivo.
			diff.seed = 0
			sim.diff.seed = 0
			if sim.build_level():
				view.on_new_maze()
				_layout()
			return
		KEY_ENTER, KEY_KP_ENTER:
			if sim.phase == GameSim.Phase.OVER:
				_back_to_menu()
			return

	if state != State.PLAYING:
		return
	match k.keycode:
		KEY_UP, KEY_W:
			sim.input_dir(Vector2i.UP)
		KEY_DOWN, KEY_S:
			sim.input_dir(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			sim.input_dir(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			sim.input_dir(Vector2i.RIGHT)


# -- persistencia ------------------------------------------------------------

func _load_high_score() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("score", "high", 0))


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("score", "high", high_score)
	cfg.save(SAVE_PATH)
