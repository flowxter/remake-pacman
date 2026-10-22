# Sustituir sprites y sonidos

El juego funciona sin nada de esto: los sprites se dibujan por codigo y los
sonidos se sintetizan al arrancar. Lo que pongas aqui **sustituye** al
procedural, archivo a archivo. Puedes reemplazar solo lo que quieras.

Se cargan en tiempo de ejecucion, asi que basta con copiar los archivos y
volver a lanzar el juego: no hay que abrir el editor ni reimportar.

## Sprites -> `assets/sprites/` (PNG, WEBP o JPG)

El nombre define que sustituye. Un sufijo `_1`, `_2`, ... son fotogramas de
animacion del mismo sprite.

```
pacman_right_1.png   pacman_right_2.png
pacman_left_1.png    pacman_up_1.png     pacman_down_1.png
blinky_left_1.png    blinky_left_2.png   blinky_up_1.png  ...
pinky_*  inky_*  clyde_*  randy_*  ambush_*
frightened_1.png     frightened_2.png
frightened_flash_1.png
eyes_up.png  eyes_down.png  eyes_left.png  eyes_right.png
pellet.png   power.png
cherry.png  strawberry.png  orange.png  apple.png  melon.png
galaxian.png  bell.png  key.png
```

Direcciones validas: `left`, `right`, `up`, `down`.
Cualquier sprite que falte se sigue dibujando por codigo, asi que puedes ir
sustituyendolos poco a poco.

Los sprites se dibujan centrados en el tile. Lo mas fiel es recortarlos
cuadrados (los del arcade son de 16x16 px con Pac-Man ocupando unos 14).

## Sonidos -> `assets/sounds/` (WAV o OGG)

```
waka_a      comer pellet (se alterna con waka_b)
waka_b
siren       bucle de fondo; se acelera segun avanza el nivel
fright      bucle mientras los fantasmas huyen
eat_ghost   comerse un fantasma
death       morir
extra_life  vida extra
fruit       comerse la fruta
ready       melodia de inicio de ronda
```

`siren` y `fright` se ponen en bucle automaticamente.

Los WAV se leen con un lector propio (PCM de 8, 16, 24 bits y float de 32),
asi que los `.wav` originales funcionan tal cual.

## De donde sacarlos

- Sprites: The Spriters Resource, seccion Arcade / Pac-Man.
- Sonidos: The Sounds Resource, misma seccion.
- Alternativa libre: OpenGameArt.org (retro / 8-bit).

Nota: los sprites y sonidos originales son propiedad de Bandai Namco. Para uso
personal y aprendizaje no hay problema; si alguna vez quieres **distribuir** un
ejecutable, deja esta carpeta vacia y se usaran los procedurales, que son
propios y se pueden repartir sin pedir permiso a nadie.
