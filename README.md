# Pac-Man Remake

Pac-Man de escritorio con **laberintos generados aleatoriamente** en cada nivel y
opciones de dificultad que se eligen antes de jugar.

Hecho en **Godot 4.7** (GDScript). Arranca y es jugable sin descargar nada: los
sprites se dibujan por codigo y los sonidos se sintetizan al arrancar. Si quieres
los originales, se copian en `assets/` y sustituyen a los procedurales.

---

## Arrancar

```powershell
.\run.ps1
```

O desde el editor de Godot: abre la carpeta como proyecto y pulsa F5.

## Controles

| Tecla | Accion |
|---|---|
| Flechas / WASD | Mover |
| ENTER | Empezar partida (en el menu) |
| P | Pausa |
| M | Silenciar |
| N | Generar un laberinto nuevo en el mismo nivel |
| R | Reiniciar la partida con las mismas opciones |
| ESC | Volver al menu |

En el menu: flechas para navegar y cambiar valores. En la fila **SEMILLA** puedes
teclear numeros (una semilla fija da siempre los mismos laberintos, util para
compartir una partida o para depurar), `R` para una aleatoria y RETROCESO para borrar.

---

## Que tiene de distinto

### Laberintos aleatorios que se sienten Pac-Man

Un generador clasico (DFS, Prim, Kruskal) produce un arbol: pasillos con callejones
sin salida. Eso rompe el juego -- los fantasmas se atascan y la persecucion pierde
toda la tension. `core/maze/maze_generator.gd` genera laberintos que cumplen las
invariantes del arcade, y `core/maze/maze_validator.gd` los verifica uno a uno
(si alguno falla, se descarta y se reintenta con otra semilla derivada):

1. Simetria espejo respecto al eje vertical.
2. Pasillos de 1 tile de ancho, paredes de 1 tile como minimo.
3. Ningun area abierta de 2x2 — gratis, por usar una rejilla impar donde las
   posiciones (par, par) son siempre pared.
4. **Cero callejones sin salida**: todo tile abierto tiene grado >= 2. El grafo se
   "trenza" (braiding) hasta que no queda ninguno.
5. Casa de fantasmas central con una unica puerta hacia arriba.
6. Tunel lateral con warp.
7. Cuatro power pellets, uno por cuadrante, en pasillo real.
8. Conectividad total verificada desde el spawn de Pac-Man.

Todo depende de una semilla: **un laberinto == un numero compartible**.

### IA de fantasmas fiel al original

Los fantasmas del arcade **no usan pathfinding**. En cada centro de tile eligen la
direccion que minimiza la distancia euclidea a un tile objetivo, sin poder invertir
el sentido y rompiendo empates en el orden arriba / izquierda / abajo / derecha. Eso
produce su comportamiento caracteristico: torpe, acorralable, pero amenazante. Lo
unico que cambia entre ellos es el objetivo:

- **Blinky** (rojo): el tile de Pac-Man. Acelera ("Cruise Elroy") cuando quedan pocos pellets.
- **Pinky** (rosa): 4 tiles por delante de Pac-Man — incluido el bug de desbordamiento
  del original cuando Pac-Man mira hacia arriba, que puedes desactivar en el menu.
- **Inky** (cian): el vector de Blinky al punto 2 tiles delante de Pac-Man, duplicado.
- **Clyde** (naranja): persigue si esta a mas de 8 tiles, si no huye a su esquina.
- **Randy** y **Ambush** (extra): objetivo aleatorio y campeo de power pellets.

Tambien estan los ciclos scatter/chase por nivel, las tablas de velocidad del
arcade, el frenazo del tunel, los contadores de puntos para salir de la casa, la
inversion forzada al cambiar de modo y la cadena 200/400/800/1600 al comer fantasmas.

La IA **elite** (A* via BFS) existe como opcion de dificultad, no por defecto: con
pathfinding real los fantasmas se vuelven implacables y el juego deja de ser Pac-Man.

### Opciones de dificultad

Todas afectan a la simulacion de verdad: tamano y complejidad del laberinto, numero
de fantasmas (2-6), multiplicador de velocidad, tipo de IA, vidas, duracion de los
power pellets (hasta dejarlos sin efecto), frenazo del tunel, bug de Pinky, frutas,
niebla de guerra y nivel inicial.

---

## Arquitectura

```
core/                 simulacion pura, sin dependencias del motor
  maze/               generador, validador y datos del laberinto
  sim/                reglas del juego: actores, IA, tablas, puntuacion
game/                 presentacion: dibujo, audio, menu, HUD
assets/               sprites y sonidos propios (opcional)
tests/                tests headless
```

El nucleo corre a **paso fijo de 120 Hz** y no sabe nada de Godot mas alla de los
tipos basicos. La capa visual solo lee y dibuja. Por eso el juego se puede testear
entero sin abrir una ventana.

## Tests

```powershell
.\test.ps1
```

- `tests/test_maze.gd` genera 200 laberintos de cada tamano y exige que **todos**
  pasen el validador, mas una comprobacion de determinismo por semilla.
- `tests/test_sim.gd` pone un piloto automatico a jugar y verifica las invariantes
  en cada tick: nadie dentro de una pared, los fantasmas salen y persiguen, las
  colisiones matan, un nivel se completa y se pasa al siguiente con laberinto nuevo,
  los power pellets asustan e invierten el sentido, y la reversa conserva la posicion.
- `tests/shot.tscn` arranca el juego de verdad y guarda capturas, para revisar el
  aspecto sin jugar a mano:
  `godot --path . res://tests/shot.tscn -- C:\ruta\de\salida`

## Sustituir sprites y sonidos

Ver [`assets/README.md`](assets/README.md). Resumen: copia los archivos con los
nombres indicados y vuelve a lanzar el juego. No hace falta pasar por el editor ni
reimportar nada.
