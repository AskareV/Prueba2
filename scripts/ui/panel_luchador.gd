class_name PanelLuchador
extends PanelContainer
## Panel superior de un luchador: nombre, estados, arma, vida y funciones dañadas.

const COLORES_ESTADO := {
	"Inconsciente": Color("#757575"),
	"Aturdido": Color("#f9a825"),
	"Desarmado": Color("#e64a19"),
	"Mano torpe": Color("#8e24aa"),
	"En guardia": Color("#1e88e5"),
}
## Chip de la puntería ganada al fallar (ver MotorCombate.PUNTERIA_POR_FALLO).
const COLOR_PUNTERIA := Color("#00897b")

var _luchador: Luchador
var _titulo: String
var _nombre: Label
var _estados: HBoxContainer
var _subtitulo: Label
var _vida: Barra
var _alertas: Label


func configurar(luchador: Luchador, titulo: String) -> void:
	_luchador = luchador
	_titulo = titulo
	custom_minimum_size = Vector2(440, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 3)
	add_child(columna)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	columna.add_child(fila)
	_nombre = Label.new()
	_nombre.add_theme_font_size_override("font_size", 26)
	fila.add_child(_nombre)
	_estados = HBoxContainer.new()
	_estados.add_theme_constant_override("separation", 6)
	_estados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_estados.alignment = BoxContainer.ALIGNMENT_END
	fila.add_child(_estados)

	_subtitulo = Label.new()
	_subtitulo.add_theme_font_size_override("font_size", 17)
	_subtitulo.add_theme_color_override("font_color", Estilo.TEXTO_SUAVE)
	columna.add_child(_subtitulo)

	_vida = Barra.new()
	_vida.custom_minimum_size = Vector2(0, 28)
	columna.add_child(_vida)

	_alertas = Label.new()
	_alertas.add_theme_font_size_override("font_size", 15)
	_alertas.add_theme_color_override("font_color", Color("#ffb74d"))
	_alertas.custom_minimum_size = Vector2(0, 20)
	_alertas.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	columna.add_child(_alertas)
	actualizar()


func actualizar() -> void:
	if _luchador == null:
		return
	_nombre.text = _titulo
	_subtitulo.text = "%s · %s" % [_luchador.lateralidad(), DatosArmas.descripcion_corta(_luchador.arma_actual())]
	_vida.valor = float(_luchador.vida) / _luchador.vida_max
	_vida.texto = "%d / %d" % [_luchador.vida, _luchador.vida_max]
	for hijo in _estados.get_children():
		hijo.queue_free()
	for estado in _estados_activos():
		_estados.add_child(_chip(estado, COLORES_ESTADO[estado]))
	if _luchador.fallos_seguidos > 0 and not _luchador.fuera_de_combate():
		var extra := roundi(MotorCombate.PUNTERIA_POR_FALLO * _luchador.fallos_seguidos * 100.0)
		_estados.add_child(_chip("Puntería +%d%%" % extra, COLOR_PUNTERIA))
	_alertas.text = _texto_alertas()


func _estados_activos() -> Array[String]:
	var lista: Array[String] = []
	if _luchador.desmayado:
		lista.append("Inconsciente")
	if _luchador.aturdido:
		lista.append("Aturdido")
	if _luchador.desarmado:
		lista.append("Desarmado")
	elif _luchador.mano_torpe:
		lista.append("Mano torpe")
	if _luchador.defendiendo:
		lista.append("En guardia")
	return lista


## Funciones de supervivencia por debajo del 100 %, de la más dañada a la menos.
func _texto_alertas() -> String:
	var danadas: Array = []
	for funcion_id in DatosCuerpo.FUNCIONES:
		var valor := _luchador.funcion(funcion_id)
		if valor < 0.995:
			danadas.append([valor, funcion_id])
	danadas.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var textos: PackedStringArray = []
	for par in danadas.slice(0, 3):
		textos.append("%s %d%%" % [DatosCuerpo.NOMBRES_FUNCION[par[1]], roundi(par[0] * 100.0)])
	return " · ".join(textos)


func _chip(texto: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var caja := Estilo.caja(color, color.lightened(0.2), 10, 1)
	caja.content_margin_left = 8
	caja.content_margin_right = 8
	caja.content_margin_top = 1
	caja.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", caja)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", 15)
	chip.add_child(etiqueta)
	return chip
