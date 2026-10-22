class_name Palette
extends RefCounted

## Colores del arcade original.

const PACMAN := Color8(255, 255, 0)
const WALL := Color8(33, 33, 222)
const WALL_FLASH := Color8(255, 255, 255)
const GATE := Color8(255, 184, 255)
const PELLET := Color8(255, 184, 174)
const BG := Color8(0, 0, 0)

const GHOST_BODIES := [
	Color8(255, 0, 0),        ## Blinky
	Color8(255, 184, 255),    ## Pinky
	Color8(0, 255, 255),      ## Inky
	Color8(255, 184, 81),     ## Clyde
	Color8(166, 255, 120),    ## Randy  (extra)
	Color8(216, 160, 255),    ## Ambush (extra)
]

const FRIGHTENED := Color8(33, 33, 255)
const FRIGHTENED_FLASH := Color8(248, 248, 248)
const EYE_WHITE := Color8(248, 248, 248)
const EYE_PUPIL := Color8(33, 33, 222)

const TEXT := Color8(255, 255, 255)
const TEXT_DIM := Color8(150, 150, 160)
const TEXT_ACCENT := Color8(255, 255, 0)
const TEXT_WARN := Color8(255, 120, 120)

const FRUIT_COLORS := {
	"cherry": Color8(222, 0, 0),
	"strawberry": Color8(222, 48, 48),
	"orange": Color8(255, 150, 40),
	"apple": Color8(222, 0, 0),
	"melon": Color8(120, 222, 80),
	"galaxian": Color8(80, 180, 255),
	"bell": Color8(255, 222, 80),
	"key": Color8(180, 200, 255),
}


static func ghost_body(index: int) -> Color:
	return GHOST_BODIES[clampi(index, 0, GHOST_BODIES.size() - 1)]


static func fruit_color(name: String) -> Color:
	if FRUIT_COLORS.has(name):
		return FRUIT_COLORS[name]
	return Color8(255, 200, 200)
