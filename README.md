# Mi Juego (nombre provisional)

Juego 2D horizontal para celular hecho con [Godot 4.7](https://godotengine.org/).
Por ahora contiene una **versión preliminar del reino** (mazmorras, zonas, botín,
inventario y trabajos) y una **demo de combate por turnos** con el sistema de
cuerpo de 21 partes. El diseño acordado está en [`docs/diseno.md`](docs/diseno.md).

## Jugar

- **En el navegador del celular:** https://askarev.github.io/Prueba2/
- **APK para Android:** https://github.com/AskareV/Prueba2/releases/latest/download/mi-juego.apk

Al instalar el APK, Android pide permitir "instalar apps de fuentes desconocidas".
Cada APK nuevo se instala encima del anterior, sin desinstalar.

## El reino (preliminar)

Desde el menú principal: *Nueva partida* (eliges si el rey es diestro o zurdo)
o *Continuar*. Arriba están las pestañas:

- **Rey:** la ficha del rey (sus características están por definir).
- **Inventario:** el botín. Tocas un objeto para equiparlo o venderlo (calidad
  normal, rara, épica o legendaria; vale más cuanto mejor es).
- **Ciudad:** en construcción.
- **Aventura:** mapa con 4 mazmorras (banderín oscuro) y 3 zonas de siete días
  (banderín rojo). En la mazmorra te mueves con la cruceta o tocando una casilla
  vecina; cada paso suma estrés, las espadas son enemigos, los cofres dan botín
  y la **H** es la salida. Las mazmorras se reinician cada semana.
- **Trabajo:** trabajos del rey que dan oro a cambio de estrés.
- **Salir:** vuelve al menú principal.

La armadura reduce el daño como en *League of Legends*: daño × 100 / (100 + armadura).
Los detalles están en la sección 7 de [`docs/diseno.md`](docs/diseno.md).

## La demo de combate

1. **Preparación:** eliges si tu rey es diestro o zurdo, su arma (espada cortante,
   maza contundente o lanza punzante) y el rival (bandido, orco o lancero).
2. **Combate:** tu rey a la izquierda y el rival a la derecha. En tu turno:
   - **Atacar:** eliges una de las 6 zonas y luego una de sus partes; la lupa
     amplía la zona para tocar partes pequeñas. Cada botón muestra la
     probabilidad de acierto y el daño posible; en brazos y piernas, también
     cuántos golpes faltan para inutilizarlos.
   - **Defender:** te defiendes mejor y recibes la mitad de daño hasta tu próximo turno.
   - **Cambiar o recoger el arma**, y **Huir**.
   - **Estado:** funciones de supervivencia, cobertura y partes heridas de ambos.
3. **Táctica:** los brazos son fáciles de acertar pero quitan poca vida; la
   cabeza y el torso quitan más, pero los cubren los brazos y las piernas. Cada
   brazo o pierna que inutilizas deja más expuestos la cabeza y el torso.
4. Las heridas cambian el color de cada parte (sin gore) y afectan sus funciones:
   sin ojos se apunta peor, con la mano del arma herida se puede soltar, un golpe
   en el cráneo puede aturdir o desmayar, etc. Las reglas son **provisionales**.

## Estructura

| Carpeta / archivo | Contenido |
|---|---|
| `project.godot` | Configuración del proyecto (horizontal, 1280×720, se adapta a cualquier pantalla) |
| `escenas/` | `menu_principal.tscn` (pantalla inicial), `reino.tscn`, `mazmorra.tscn`, `expedicion.tscn`, `preparacion.tscn` (demo) y `combate.tscn` |
| `scripts/reino/` | Reino: estado de la partida (`Juego`), botín, mazmorras, zonas, trabajos y sus pantallas |
| `scripts/combate/` | Reglas del combate y dibujo de los luchadores |
| `scripts/ui/` | Barras y paneles de la interfaz |
| `scripts/` | Globales: `estilo.gd` (tema), `partida.gd` (elecciones de la demo), `orientacion.gd` (aviso para girar el teléfono en el navegador) |
| `pruebas/` | Pruebas automáticas, partida automática y simulador de equilibrio |
| `docs/diseno.md` | Documento de diseño |
| `assets/` | Imágenes, sonidos y fuentes (por ahora todo se dibuja con código) |
| `export_presets.cfg` | Configuración para exportar a Android y Web |
| `ci/` | Llave de firma de pruebas del APK (ver `ci/LEEME.md`) |
| `.github/workflows/compilar.yml` | Compilación automática |

### Archivos principales del combate

| Archivo | Qué hace |
|---|---|
| `datos_cuerpo.gd` | Las 21 partes, las 6 zonas y las funciones de supervivencia |
| `datos_armas.gd` | Las armas (espada, maza, lanza y bastón mágico) y sus números provisionales |
| `datos_rivales.gd` | Rivales de la demo, enemigos del reino y aspecto del rey |
| `luchador.gd` | Estado de un combatiente: vida, integridad de cada parte, lateralidad |
| `motor_combate.gd` | Reglas: acierto, daño, armadura, fracturas, desarme, aturdimiento, desmayo |
| `ia_enemigo.gd` | Cómo deciden los rivales: el plan de su personalidad, y a veces improvisan |
| `figura.gd` / `plantilla_humanoide.gd` | Dibujo del cuerpo por partes, heridas y animaciones |
| `combate.gd` | Flujo de turnos e interfaz del combate |

### Archivos principales del reino

| Archivo | Qué hace |
|---|---|
| `estado_reino.gd` | La partida (global `Juego`): semana, oro, estrés, inventario, equipo |
| `datos_botin.gd` | Calidades, armas y armaduras de botín, precios de venta |
| `datos_aventura.gd` | Mazmorras, zonas, sucesos de los siete días |
| `generador_mazmorra.gd` | Crea el plano de cada mazmorra según la semana |
| `datos_trabajos.gd` | Trabajos del rey |
| `reino.gd`, `mazmorra.gd`, `expedicion.gd`, `menu_principal.gd` | Pantallas |

## Pruebas

```sh
godot --headless --import
godot --headless --script res://pruebas/ejecutar.gd            # pruebas de las reglas y del equilibrio
godot --headless --script res://pruebas/partida_automatica.gd  # combates completos pulsando botones
godot --headless --script res://pruebas/recorrido_reino.gd     # recorre el reino: mazmorra, zona, inventario y trabajo
godot --headless --script res://pruebas/simular.gd             # equilibrio: miles de combates por estrategia
```

El simulador compara estrategias del rey (por ejemplo, ir directo al abdomen o
inutilizar primero el brazo del arma) contra cada rival. Se pueden elegir algunas:
`godot --headless --script res://pruebas/simular.gd -- brazo_arma abdomen arma=maza combates=200`.

## Compilación automática

Cada `push` ejecuta GitHub Actions, que:

1. Descarga Godot y sus plantillas de exportación.
2. Ejecuta las pruebas, una partida automática y un recorrido del reino.
3. Exporta la versión web y la publica en la rama `gh-pages` (GitHub Pages).
4. Exporta el APK firmado y lo publica en *Releases* (se conservan las últimas 5 versiones).

El número de versión (`0.2.N`) aumenta solo en cada compilación y se ve en la pantalla
de preparación de la demo.

### Activar GitHub Pages (una sola vez)

*Settings → Pages → Build and deployment → Source: Deploy from a branch → `gh-pages` / `(root)` → Save.*
