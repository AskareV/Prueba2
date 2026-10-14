extends Control
## Pantalla de preparación de la demo: mano dominante del rey, arma y rival.
## El contenido se diseña en un área de 1280×720 centrada, que siempre cabe.

const ESCENA_COMBATE := "res://escenas/combate.tscn"
const ESCENA_MENU := "res://escenas/menu_principal.tscn"
const DIFICULTAD := {"bandido": "Fácil", "lancero": "Medio", "orco": "Difícil"}

var _fondo: FondoMazmorra
var _antorchas: Antorchas
var _vineta: Vineta
var _contenido: Control
var _figura_rey: Figura
var _descripcion_arma: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo = FondoMazmorra.new()
	add_child(_fondo)
	_antorchas = Antorchas.new()
	add_child(_antorchas)
	_vineta = Vineta.new()
	add_child(_vineta)

	_contenido = Control.new()
	_contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenido.set_anchors_preset(Control.PRESET_CENTER)
	_contenido.offset_left = -640
	_contenido.offset_right = 640
	_contenido.offset_top = -360
	_contenido.offset_bottom = 360
	add_child(_contenido)

	_crear_titulo()
	_crear_rey()
	_crear_opciones_rey()
	_crear_rivales()
	_crear_pie()
	get_viewport().size_changed.connect(_reubicar)
	_reubicar()
	_actualizar_rey()
	_bloquear_toques(0.45)


## Ignora los toques un momento al entrar: un doble toque en la pantalla anterior
## (por ejemplo en "Preparación") no debe elegir sin querer lo que quede debajo.
func _bloquear_toques(segundos: float) -> void:
	var escudo := Control.new()
	escudo.set_anchors_preset(Control.PRESET_FULL_RECT)
	escudo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(escudo)
	get_tree().create_timer(segundos).timeout.connect(escudo.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_al_volver_al_menu()


func _reubicar() -> void:
	var tamano := get_viewport_rect().size
	var suelo := (tamano.y - 720.0) / 2.0 + 590.0
	_fondo.ajustar(tamano, suelo)
	_antorchas.ajustar(tamano, suelo)
	_vineta.ajustar(tamano)


# --- Construcción ---

func _crear_titulo() -> void:
	var titulo := _etiqueta("Demo de combate", 46, Vector2(40, 18))
	titulo.add_theme_color_override("font_color", Color("#ffe082"))
	var subtitulo := _etiqueta("Prototipo del sistema de cuerpo: 21 partes en 6 zonas · reglas provisionales",
		19, Vector2(42, 80))
	subtitulo.add_theme_color_override("font_color", Estilo.TEXTO_SUAVE)
	# En el navegador no hay botón "atrás" de Android: este vuelve al menú.
	var menu := Button.new()
	menu.text = "Menú principal"
	menu.add_theme_font_size_override("font_size", 20)
	menu.position = Vector2(1050, 24)
	menu.custom_minimum_size = Vector2(200, 60)
	menu.pressed.connect(_al_volver_al_menu)
	_contenido.add_child(menu)


func _crear_rey() -> void:
	_etiqueta("Tu rey", 26, Vector2(40, 130))
	_figura_rey = Figura.new()
	_figura_rey.position = Vector2(180, 590)
	_figura_rey.escala_base = 1.0
	_contenido.add_child(_figura_rey)


func _crear_opciones_rey() -> void:
	_panel(Rect2(340, 118, 370, 480))
	_etiqueta("Mano dominante", 22, Vector2(362, 130))
	var grupo_mano := ButtonGroup.new()
	var fila := HBoxContainer.new()
	fila.position = Vector2(362, 166)
	fila.add_theme_constant_override("separation", 12)
	_contenido.add_child(fila)
	for diestro in [true, false]:
		var boton := Button.new()
		boton.text = "Diestro" if diestro else "Zurdo"
		boton.custom_minimum_size = Vector2(158, 62)
		boton.toggle_mode = true
		boton.button_group = grupo_mano
		boton.button_pressed = Partida.diestro == diestro
		boton.pressed.connect(_al_elegir_mano.bind(diestro))
		fila.add_child(boton)

	_etiqueta("Arma", 22, Vector2(362, 248))
	var grupo_arma := ButtonGroup.new()
	var columna := VBoxContainer.new()
	columna.position = Vector2(362, 284)
	columna.add_theme_constant_override("separation", 10)
	_contenido.add_child(columna)
	for arma_id in DatosArmas.ELEGIBLES:
		var arma: Dictionary = DatosArmas.ARMAS[arma_id]
		var boton := Button.new()
		boton.text = "%s · %s" % [arma["nombre"], String(DatosArmas.tipo(arma["tipo"])["nombre"]).to_lower()]
		boton.custom_minimum_size = Vector2(328, 62)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.toggle_mode = true
		boton.button_group = grupo_arma
		boton.button_pressed = Partida.arma == arma_id
		boton.pressed.connect(_al_elegir_arma.bind(arma_id))
		Estilo.con_franja(boton, DatosArmas.COLORES_TIPO[arma["tipo"]])
		columna.add_child(boton)

	_descripcion_arma = _etiqueta("", 17, Vector2(362, 506))
	_descripcion_arma.size = Vector2(328, 80)
	_descripcion_arma.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_descripcion_arma.add_theme_color_override("font_color", Estilo.TEXTO_SUAVE)


func _crear_rivales() -> void:
	_panel(Rect2(728, 118, 528, 480))
	_etiqueta("Rival", 22, Vector2(748, 130))
	var grupo := ButtonGroup.new()
	var columna := VBoxContainer.new()
	columna.position = Vector2(748, 166)
	columna.add_theme_constant_override("separation", 10)
	_contenido.add_child(columna)
	for rival_id in DatosRivales.ORDEN:
		columna.add_child(_tarjeta_rival(rival_id, grupo))


func _tarjeta_rival(rival_id: String, grupo: ButtonGroup) -> Button:
	var datos := DatosRivales.rival(rival_id)
	var luchador := DatosRivales.crear_rival(rival_id)
	var tarjeta := Button.new()
	tarjeta.custom_minimum_size = Vector2(488, 132)
	tarjeta.toggle_mode = true
	tarjeta.button_group = grupo
	tarjeta.button_pressed = Partida.rival == rival_id
	tarjeta.pressed.connect(_al_elegir_rival.bind(rival_id))

	var figura := Figura.new()
	figura.configurar(luchador, datos["aspecto"], false)
	figura.escala_base = 0.3 * float(datos["aspecto"]["escala"])
	figura.position = Vector2(64, 124)
	tarjeta.add_child(figura)

	var nombre := _etiqueta_en(tarjeta, String(datos["nombre"]), 26, Vector2(128, 8))
	nombre.add_theme_color_override("font_color", Color.WHITE)
	var dificultad := _etiqueta_en(tarjeta, DIFICULTAD[rival_id], 16, Vector2(400, 14))
	dificultad.add_theme_color_override("font_color", Color("#ffcc80"))
	_etiqueta_en(tarjeta, "%s · %s · %d de vida" % [luchador.lateralidad(),
		DatosArmas.descripcion_corta(luchador.arma), luchador.vida_max], 17, Vector2(128, 46))
	var personalidad := _etiqueta_en(tarjeta, DatosRivales.PERSONALIDADES[datos["personalidad"]], 16, Vector2(128, 74))
	personalidad.add_theme_color_override("font_color", Estilo.TEXTO_SUAVE)
	return tarjeta


func _crear_pie() -> void:
	var combatir := Button.new()
	combatir.text = "¡Combatir!"
	combatir.add_theme_font_size_override("font_size", 32)
	combatir.position = Vector2(956, 618)
	combatir.custom_minimum_size = Vector2(300, 82)
	combatir.pressed.connect(_al_combatir)
	Estilo.con_franja(combatir, Color("#ffd54f"))
	_contenido.add_child(combatir)
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var texto := _etiqueta("v%s · Toca un botón para elegir; el rey se actualiza al instante." % version,
		15, Vector2(40, 676))
	texto.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))


func _panel(rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenido.add_child(panel)


func _etiqueta(texto: String, tamano: int, posicion: Vector2) -> Label:
	return _etiqueta_en(_contenido, texto, tamano, posicion)


func _etiqueta_en(padre: Control, texto: String, tamano: int, posicion: Vector2) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = posicion
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", tamano)
	padre.add_child(etiqueta)
	return etiqueta


# --- Elecciones ---

func _al_elegir_mano(diestro: bool) -> void:
	Partida.diestro = diestro
	_actualizar_rey()


func _al_elegir_arma(arma_id: String) -> void:
	Partida.arma = arma_id
	_actualizar_rey()


func _al_elegir_rival(rival_id: String) -> void:
	Partida.rival = rival_id


func _actualizar_rey() -> void:
	_figura_rey.configurar(DatosRivales.crear_rey(Partida.diestro, Partida.arma), DatosRivales.ASPECTO_REY, true)
	_descripcion_arma.text = DatosArmas.tipo_de(Partida.arma)["descripcion"]


func _al_combatir() -> void:
	get_tree().change_scene_to_file.call_deferred(ESCENA_COMBATE)


func _al_volver_al_menu() -> void:
	get_tree().change_scene_to_file.call_deferred(ESCENA_MENU)
