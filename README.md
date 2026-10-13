# Mi Juego (nombre provisional)

Juego 2D horizontal para celular hecho con [Godot 4.7](https://godotengine.org/).
Por ahora contiene una **demo de combate por turnos** con el sistema de cuerpo de
21 partes. El diseño acordado está en [`docs/diseno.md`](docs/diseno.md).

## Jugar

- **En el navegador del celular:** https://askarev.github.io/Prueba2/
- **APK para Android:** https://github.com/AskareV/Prueba2/releases/latest/download/mi-juego.apk

Al instalar el APK, Android pide permitir "instalar apps de fuentes desconocidas".
Cada APK nuevo se instala encima del anterior, sin desinstalar.

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
   brazo o pierna que inutilizas deja más expuestos la cabeza y el torso. Cada
   fallo seguido da +10% de puntería al siguiente ataque, para que no haya
   rachas largas de mala suerte.
4. Las heridas cambian el color de cada parte (sin gore) y afectan sus funciones:
   sin ojos se apunta peor, con la mano del arma herida se puede soltar, un golpe
   en el cráneo puede aturdir o desmayar, etc. Las reglas son **provisionales**.

## Estructura

| Carpeta / archivo | Contenido |
|---|---|
| `project.godot` | Configuración del proyecto (horizontal, 1280×720, se adapta a cualquier pantalla) |
| `escenas/` | `preparacion.tscn` (pantalla inicial) y `combate.tscn` |
| `scripts/combate/` | Reglas del combate y dibujo de los luchadores |
| `scripts/ui/` | Barras y paneles de la interfaz |
| `scripts/` | Globales: `estilo.gd` (tema), `partida.gd` (elecciones), `orientacion.gd` (aviso para girar el teléfono en el navegador) |
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
| `datos_armas.gd` | Los tres tipos de arma y sus números provisionales |
| `datos_rivales.gd` | Rivales de la demo y aspecto del rey |
| `luchador.gd` | Estado de un combatiente: vida, integridad de cada parte, lateralidad |
| `motor_combate.gd` | Reglas: acierto, daño, fracturas, desarme, aturdimiento, desmayo |
| `ia_enemigo.gd` | Cómo deciden los rivales: el plan de su personalidad, y a veces improvisan |
| `figura.gd` / `plantilla_humanoide.gd` | Dibujo del cuerpo por partes, heridas y animaciones |
| `combate.gd` | Flujo de turnos e interfaz del combate |

## Pruebas

```sh
godot --headless --import
godot --headless --script res://pruebas/ejecutar.gd            # pruebas de las reglas y del equilibrio
godot --headless --script res://pruebas/partida_automatica.gd  # combates completos pulsando botones
godot --headless --script res://pruebas/simular.gd             # equilibrio: miles de combates por estrategia
```

El simulador compara estrategias del rey (por ejemplo, ir directo al abdomen o
inutilizar primero el brazo del arma) contra cada rival. Se pueden elegir algunas:
`godot --headless --script res://pruebas/simular.gd -- brazo_arma abdomen arma=maza combates=200`.

## Compilación automática

Cada `push` ejecuta GitHub Actions, que:

1. Descarga Godot y sus plantillas de exportación.
2. Ejecuta las pruebas y una partida automática.
3. Exporta la versión web y la publica en la rama `gh-pages` (GitHub Pages).
4. Exporta el APK firmado y lo publica en *Releases* (se conservan las últimas 5 versiones).

El número de versión (`0.2.N`) aumenta solo en cada compilación y se ve en la pantalla
de preparación.

### Activar GitHub Pages (una sola vez)

*Settings → Pages → Build and deployment → Source: Deploy from a branch → `gh-pages` / `(root)` → Save.*
