extends SceneTree

## Test del generador de laberintos.
##   godot --headless --path . --script res://tests/test_maze.gd
## Genera N laberintos de cada tamano y exige que TODOS pasen el validador.

const N := 200

var failures := 0
var checks := 0


func _initialize() -> void:
	for preset_name: String in ["small", "classic", "large"]:
		_run_preset(preset_name)
	_run_determinism()
	_dump_sample()

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


func _run_preset(preset_name: String) -> void:
	var cfg := MazeGenerator.preset(preset_name)
	var t0 := Time.get_ticks_msec()
	var worst_intersections := 1 << 30
	var min_pellets := 1 << 30
	var nulls := 0

	for i in range(N):
		cfg["seed"] = 1000 + i
		var m := MazeGenerator.generate(cfg)
		if m == null:
			nulls += 1
			_assert(false, "%s semilla %d: no se pudo generar" % [preset_name, cfg["seed"]])
			continue
		var res := MazeValidator.validate(m)
		_assert(res.ok, "%s semilla %d: %s" % [preset_name, cfg["seed"], str(res.errors)])
		worst_intersections = mini(worst_intersections, int(res.stats.intersections))
		min_pellets = mini(min_pellets, int(res.stats.pellets))

	var ms := Time.get_ticks_msec() - t0
	print("%-8s  %d laberintos  %d ms (%.1f ms/laberinto)  nulos=%d  min_intersecciones=%d  min_pellets=%d"
		% [preset_name, N, ms, float(ms) / N, nulls, worst_intersections, min_pellets])


func _run_determinism() -> void:
	var cfg := MazeGenerator.preset("classic")
	cfg["seed"] = 424242
	var a := MazeGenerator.generate(cfg)
	var b := MazeGenerator.generate(cfg)
	_assert(a != null and b != null, "determinismo: generacion nula")
	if a != null and b != null:
		_assert(a.walls == b.walls, "la misma semilla debe dar el mismo laberinto")
		_assert(a.pellets == b.pellets, "la misma semilla debe dar los mismos pellets")
	print("determinismo: misma semilla -> mismo laberinto")


func _dump_sample() -> void:
	var cfg := MazeGenerator.preset("classic")
	cfg["seed"] = 7
	var m := MazeGenerator.generate(cfg)
	if m == null:
		return
	var res := MazeValidator.validate(m)
	print("\nmuestra (semilla 7)  %s" % str(res.stats))
	print(MazeValidator.to_ascii(m))
