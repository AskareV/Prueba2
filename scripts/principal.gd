extends Control
## Pantalla de prueba: confirma que el proyecto compila y que el toque funciona.
## Se reemplazará cuando empecemos el juego.

const DURACION_ONDA := 0.6
const RADIO_MAX := 90.0

var _ondas: Array = []
var _toques := 0

@onready var _etiqueta_toques: Label = $Toques
@onready var _etiqueta_version: Label = $Version


func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_etiqueta_version.text = "v%s · %s" % [version, OS.get_name()]


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var local := make_input_local(event) as InputEventScreenTouch
		_toques += 1
		_etiqueta_toques.text = "Toques: %d" % _toques
		_ondas.append({"pos": local.position, "t": 0.0})


func _process(delta: float) -> void:
	for onda in _ondas:
		onda["t"] += delta
	_ondas = _ondas.filter(func(onda): return onda["t"] < DURACION_ONDA)
	queue_redraw()


func _draw() -> void:
	for onda in _ondas:
		var avance: float = onda["t"] / DURACION_ONDA
		draw_circle(onda["pos"], RADIO_MAX * avance, Color(1, 1, 1, 0.35 * (1.0 - avance)))
