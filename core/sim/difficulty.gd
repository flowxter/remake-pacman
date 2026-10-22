class_name Difficulty
extends RefCounted

## Opciones que se eligen antes de jugar. Todo lo que mueve la aguja de la
## dificultad vive aqui: el resto del codigo solo lee estos valores.

enum AI { CLASSIC, ELITE, MIXED }

# -- laberinto ---------------------------------------------------------------
var maze_size: String = "classic"   ## small | classic | large
var block_ratio: float = 0.12       ## masas de pared: mas alto = mas cerrado
var loop_ratio: float = 0.28        ## ciclos extra: mas alto = mas abierto
var seed: int = 0                   ## 0 = aleatoria

# -- fantasmas ---------------------------------------------------------------
var ghost_count: int = 4            ## 2..6
var ghost_speed: float = 1.0        ## multiplicador sobre la tabla original
var ai: AI = AI.CLASSIC
var tunnel_slowdown: bool = true    ## el frenazo del tunel es una via de escape
var pinky_overflow_bug: bool = true ## el bug de Pinky mirando hacia arriba

# -- Pac-Man -----------------------------------------------------------------
var lives: int = 3
var pacman_speed: float = 1.0
var power_duration: float = 1.0     ## 0 = los power pellets no asustan
var start_level: int = 1
var fruit_enabled: bool = true
var vision_radius: float = 0.0      ## 0 = sin niebla; si no, radio en tiles
var extra_life_score: int = 10000


func maze_config() -> Dictionary:
	var cfg := MazeGenerator.preset(maze_size)
	cfg["block_ratio"] = block_ratio
	cfg["loop_ratio"] = loop_ratio
	cfg["seed"] = seed
	return cfg


func describe() -> String:
	var ai_names := ["clasica", "elite", "mixta"]
	return "%s | %d fantasmas x%.2f | IA %s | %d vidas | power x%.1f%s" % [
		maze_size, ghost_count, ghost_speed, ai_names[ai], lives, power_duration,
		"" if tunnel_slowdown else " | sin frenazo de tunel",
	]


func duplicate_cfg() -> Difficulty:
	var d := Difficulty.new()
	d.maze_size = maze_size
	d.block_ratio = block_ratio
	d.loop_ratio = loop_ratio
	d.seed = seed
	d.ghost_count = ghost_count
	d.ghost_speed = ghost_speed
	d.ai = ai
	d.tunnel_slowdown = tunnel_slowdown
	d.pinky_overflow_bug = pinky_overflow_bug
	d.lives = lives
	d.pacman_speed = pacman_speed
	d.power_duration = power_duration
	d.start_level = start_level
	d.fruit_enabled = fruit_enabled
	d.vision_radius = vision_radius
	d.extra_life_score = extra_life_score
	return d


# -- presets -----------------------------------------------------------------

static func preset(name: String) -> Difficulty:
	var d := Difficulty.new()
	match name:
		"zen":
			d.ghost_count = 3
			d.ghost_speed = 0.80
			d.lives = 5
			d.power_duration = 1.6
			d.block_ratio = 0.08
			d.loop_ratio = 0.40
		"classic":
			pass
		"hard":
			d.ghost_count = 5
			d.ghost_speed = 1.15
			d.ai = AI.MIXED
			d.lives = 3
			d.power_duration = 0.75
			d.block_ratio = 0.16
			d.loop_ratio = 0.22
		"nightmare":
			d.maze_size = "large"
			d.ghost_count = 6
			d.ghost_speed = 1.30
			d.ai = AI.ELITE
			d.lives = 1
			d.power_duration = 0.5
			d.tunnel_slowdown = false
			d.block_ratio = 0.18
			d.loop_ratio = 0.18
			d.vision_radius = 9.0
	return d


static func preset_names() -> Array[String]:
	return ["zen", "classic", "hard", "nightmare"]


static func preset_label(name: String) -> String:
	match name:
		"zen":
			return "ZEN"
		"classic":
			return "CLASICO"
		"hard":
			return "DIFICIL"
		"nightmare":
			return "PESADILLA"
	return name.to_upper()
