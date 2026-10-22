extends Node

## Arranca el juego de verdad, avanza unos segundos y guarda capturas.
##   godot --path . res://tests/shot.tscn -- <carpeta_de_salida>
## Sirve para revisar el aspecto sin tener que jugar a mano.

var out_dir := "."
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	main = load("res://game/main.tscn").instantiate()
	add_child(main)
	await _wait(10)
	print("viewport=", get_viewport().get_visible_rect().size,
		" menu=", main.menu.size, " anchors=", main.menu.anchor_right,
		" hud=", main.hud.size, " content_scale=", get_window().content_scale_size)
	await _shot("01_menu")

	var d := Difficulty.preset("classic")
	d.seed = 7
	main._on_play(d)
	await _wait(150)
	await _shot("02_listo")
	await _wait(420)
	await _shot("03_partida")

	# un power pellet para ver los fantasmas asustados
	var sim: GameSim = main.sim
	if sim != null and not sim.maze.power_tiles.is_empty():
		sim._eat_at(sim.maze.power_tiles[0])
		await _wait(40)
		await _shot("04_asustados")

	var d2 := Difficulty.preset("nightmare")
	d2.seed = 4242
	main._on_play(d2)
	await _wait(400)
	await _shot("05_pesadilla_niebla")

	print("capturas en ", out_dir)
	get_tree().quit()


func _wait(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(shot_name + ".png")
	var err := img.save_png(path)
	if err != OK:
		printerr("no se pudo guardar ", path, " err=", err)
