# Mi Juego (nombre provisional)

Juego 2D horizontal para celular hecho con [Godot 4.7](https://godotengine.org/).

## Jugar

- **En el navegador del celular:** https://askarev.github.io/Prueba2/
- **APK para Android:** https://github.com/AskareV/Prueba2/releases/latest/download/mi-juego.apk

Al instalar el APK, Android pide permitir "instalar apps de fuentes desconocidas".
Cada APK nuevo se instala encima del anterior, sin desinstalar.

## Estructura

| Carpeta / archivo | Contenido |
|---|---|
| `project.godot` | Configuración del proyecto (horizontal, 1280×720, se adapta a cualquier pantalla) |
| `escenas/` | Escenas de Godot (`.tscn`) |
| `scripts/` | Código en GDScript (`.gd`). `orientacion.gd` es global: en el navegador pide girar el teléfono si está vertical |
| `assets/` | Imágenes, sonidos y fuentes |
| `export_presets.cfg` | Configuración para exportar a Android y Web |
| `ci/` | Llave de firma de pruebas del APK (ver `ci/LEEME.md`) |
| `.github/workflows/compilar.yml` | Compilación automática |

## Compilación automática

Cada `push` ejecuta GitHub Actions, que:

1. Descarga Godot y sus plantillas de exportación.
2. Exporta la versión web y la publica en la rama `gh-pages` (GitHub Pages).
3. Exporta el APK firmado y lo publica en *Releases* (se conservan las últimas 5 versiones).

El número de versión (`0.1.N`) aumenta solo en cada compilación y se ve en la esquina del juego.

### Activar GitHub Pages (una sola vez)

*Settings → Pages → Build and deployment → Source: Deploy from a branch → `gh-pages` / `(root)` → Save.*
