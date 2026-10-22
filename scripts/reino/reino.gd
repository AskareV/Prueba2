extends Control
## Pantalla principal del reino. Arriba, las pestañas (como en My Pet
## Protector) y una franja con la semana, el oro y el estrés; debajo, el
## contenido de la pestaña elegida. Todo es provisional.

const ESCENA_MENU := "res://escenas/menu_principal.tscn"
const ESCENA_MAZMORRA := "res://escenas/mazmorra.tscn"
const ESCENA_EXPEDICION := "res://escenas/expedicion.tscn"
const PESTANAS := ["rey", "inventario", "ciudad", "aventura", "trabajo", "salir"]
const NOMBRES_PESTANA := {
	"rey": "Rey", "inventario": "Inventario", "ciudad": "Ciudad", "aventura": "Aventura",
	"trabajo": "Trabajo", "salir": "Salir",
}
const COLORES_PESTANA := {
	"rey": Color("#ffd54f"), "inventario": Color("#8d6e63"), "ciudad": Color("#90a4ae"),
	"aventura": Color("#ef5350"), "trabajo": Color("#66bb6a"), "salir": Color("#9e9e9e"),
}
## Segundos entre los días al mostrar una semana de trabajo.
const PAUSA_DIA := 0.35

var _area: Control
var _contenido: Control
var _botones_pestana := {}
var _etiqueta_semana: Label
var _etiqueta_oro: Label
var _etiqueta_peligro: Label
var _barra_estres: Barra
var _aviso: Label
var _pestana := ""
## true mientras pasa una semana de trabajo: no se puede cambiar de pestaña.
var _ocupado := false
## Objeto elegido en el inventario: {"id": n} de la mochila o {"ranura": r} del equipo.
var _seleccion := {}
var _venta_pendiente := false
## Posición de la mochila, para no volver arriba al tocar un objeto.
var _scroll_mochila := 0
## Ventana del lugar elegido en el mapa, o null.
var _ventana_lugar: Control
var _oficio := "audiencias"
## Pestaña Rey: puntos repartidos sin confirmar y la característica o sub elegida.
var _pend_principal := {}
var _pend_sub := {}
var _elegida := ""
var _detalle_oficio: Control
## Ciudad: edificio con la ventana abierta y objeto del mercado tocado una vez
## (falta el segundo toque para comprarlo).
var _edificio_abierto := ""
var _compra_pendiente := -1


func _ready() -> void:
	if not Juego.en_curso:
		Juego.nueva_partida(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIReino.fondo(self)
	_area = UIReino.area_centrada(self)
	_crear_pestanas()
	_crear_franja()
	_contenido = Control.new()
	_contenido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contenido.position = Vector2(0, 142)
	_contenido.size = Vector2(1280, 578)
	_area.add_child(_contenido)
	_mostrar_pestana(Juego.pestana)
	Juego.pestana = "rey"
	if Juego.aviso != "":
		_avisar(Juego.aviso)
		Juego.aviso = ""
	_mostrar_noticias()
	UIReino.bloquear_toques(self)


func _crear_pestanas() -> void:
	var fila := HBoxContainer.new()
	fila.position = Vector2(14, 10)
	fila.add_theme_constant_override("separation", 8)
	_area.add_child(fila)
	var grupo := ButtonGroup.new()
	for pestana in PESTANAS:
		var boton := UIReino.boton(NOMBRES_PESTANA[pestana], _al_pulsar_pestana.bind(pestana), Vector2(200, 76), 24)
		if pestana != "salir":
			boton.toggle_mode = true
			boton.button_group = grupo
		Estilo.con_franja(boton, COLORES_PESTANA[pestana])
		fila.add_child(boton)
		_botones_pestana[pestana] = boton


func _crear_franja() -> void:
	var franja := HBoxContainer.new()
	franja.position = Vector2(24, 96)
	franja.size = Vector2(1232, 40)
	franja.add_theme_constant_override("separation", 16)
	_area.add_child(franja)
	_etiqueta_semana = UIReino.etiqueta("", 22, UIReino.COLOR_TITULO)
	franja.add_child(_etiqueta_semana)
	_etiqueta_oro = UIReino.etiqueta("", 22, Color("#ffd54f"))
	franja.add_child(_etiqueta_oro)
	_etiqueta_peligro = UIReino.etiqueta("", 20)
	franja.add_child(_etiqueta_peligro)
	franja.add_child(UIReino.etiqueta("Estrés", 20, Estilo.TEXTO))
	_barra_estres = UIReino.barra_estres()
	_barra_estres.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	franja.add_child(_barra_estres)
	_aviso = UIReino.etiqueta("", 18, UIReino.COLOR_AVISO)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	franja.add_child(_aviso)
	_actualizar_franja()


func _actualizar_franja() -> void:
	_etiqueta_semana.text = "Semana %d" % Juego.semana
	# Aviso en la pestaña Rey cuando hay puntos por repartir.
	var por_repartir := Juego.puntos_principales + Juego.total_puntos_sub() > 0
	_botones_pestana["rey"].text = "Rey (+)" if por_repartir else String(NOMBRES_PESTANA["rey"])
	_etiqueta_oro.text = "Oro: %d" % Juego.oro
	_etiqueta_peligro.text = "Peligro %d%%" % roundi(Juego.peligro)
	_etiqueta_peligro.add_theme_color_override("font_color", _color_peligro(Juego.peligro))
	UIReino.actualizar_estres(_barra_estres, Juego.estres)


func _avisar(texto: String) -> void:
	_aviso.text = texto


# --- Pestañas ---

func _al_pulsar_pestana(pestana: String) -> void:
	if _ocupado:
		_botones_pestana[_pestana].button_pressed = true
		return
	if pestana == "salir":
		_salir()
		return
	if pestana != _pestana:
		_scroll_mochila = 0
	_mostrar_pestana(pestana)


## "noticias": si quedaron noticias de la ciudad sin ver, se muestran al cambiar
## de pestaña (así no se pierden aunque no se toque "Listo").
func _mostrar_pestana(pestana: String, noticias := true) -> void:
	_pestana = pestana
	_botones_pestana[pestana].button_pressed = true
	_ventana_lugar = null
	for hijo in _contenido.get_children():
		hijo.queue_free()
	match pestana:
		"rey":
			_crear_rey()
		"inventario":
			_crear_inventario()
		"ciudad":
			_crear_ciudad()
		"aventura":
			_crear_aventura()
		"trabajo":
			_crear_trabajo()
	_actualizar_franja()
	# Lo nuevo puede quedar justo bajo el dedo (ej. "Listo" sobre "Trabajar esta
	# semana", "Equipar" sobre "Quitar"): un doble toque no debe pulsarlo.
	UIReino.bloquear_toques(self, 0.35)
	if noticias and not _ocupado:
		_mostrar_noticias()


func _salir() -> void:
	get_tree().change_scene_to_file.call_deferred(ESCENA_MENU)


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _ocupado:
		return
	if _ventana_lugar != null:
		_cerrar_lugar()
	else:
		_salir()


# --- Rey ---

const ANCHO_TARJETA := 240.0
const ALTO_TARJETA := 280.0
const COLOR_PENDIENTE := Color("#81c784")


func _crear_rey() -> void:
	_crear_resumen_rey()
	# Siete tarjetas (una por característica) y la descripción en la octava casilla.
	for i in DatosEstadisticas.ORDEN.size():
		var tarjeta := _tarjeta_caracteristica(DatosEstadisticas.ORDEN[i])
		tarjeta.position = _posicion_tarjeta(i)
		_contenido.add_child(tarjeta)
	var descripcion := _tarjeta_descripcion()
	descripcion.position = _posicion_tarjeta(7)
	_contenido.add_child(descripcion)


func _posicion_tarjeta(indice: int) -> Vector2:
	return Vector2(280 + (indice % 4) * (ANCHO_TARJETA + 10), (indice / 4) * (ALTO_TARJETA + 10))


## Columna izquierda: nivel, experiencia, valores que salen de las
## características, puntos por repartir y confirmar o deshacer.
func _crear_resumen_rey() -> void:
	var panel := UIReino.panel()
	panel.position = Vector2(10, 0)
	panel.custom_minimum_size = Vector2(260, 0)
	_contenido.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	panel.add_child(columna)
	columna.add_child(UIReino.etiqueta("El Rey · %s" % ("Diestro" if Juego.diestro else "Zurdo"), 24, UIReino.COLOR_TITULO))
	columna.add_child(UIReino.etiqueta("Nivel %d" % Juego.nivel, 22))
	var barra := Barra.new()
	barra.custom_minimum_size = Vector2(228, 22)
	barra.tamano_fuente = 14
	barra.color_fijo = Color("#7e57c2")
	barra.valor = float(Juego.xp) / Juego.xp_para_subir()
	# Sin animación: al rehacer la pestaña la barra no debe vaciarse y volver a llenarse.
	barra._mostrado = barra.valor
	barra.texto = "Experiencia %d / %d" % [Juego.xp, Juego.xp_para_subir()]
	columna.add_child(barra)
	var rey := Juego.crear_rey()
	columna.add_child(UIReino.etiqueta("Vida %d / %d · Maná %d" % [rey.vida, rey.vida_max, roundi(rey.mana_max)], 17, Estilo.TEXTO_SUAVE))
	if Juego.esta_herido():
		columna.add_child(UIReino.parrafo(_texto_heridas(), 228, 15, UIReino.COLOR_AVISO))
	columna.add_child(UIReino.etiqueta("Rapidez %s" % _formato(rey.rapidez), 17, Estilo.TEXTO_SUAVE))
	var principales := _puntos_principales_libres()
	var de_partes := 0
	for car_id in DatosEstadisticas.ORDEN:
		de_partes += _puntos_sub_libres(car_id)
	columna.add_child(UIReino.etiqueta("Puntos principales: %d" % principales, 19,
		UIReino.COLOR_TITULO if principales > 0 else Estilo.TEXTO_SUAVE))
	columna.add_child(UIReino.etiqueta("Puntos de partes: %d" % de_partes, 19,
		UIReino.COLOR_TITULO if de_partes > 0 else Estilo.TEXTO_SUAVE))
	if principales > 0 or de_partes > 0:
		columna.add_child(UIReino.parrafo("+ en una característica: sube sus 3 partes y da %d puntos solo para ellas."
			% DatosEstadisticas.PUNTOS_SUB_POR_PRINCIPAL, 228, 15))
	if _hay_pendientes():
		var confirmar := UIReino.boton("Confirmar", _al_confirmar_puntos, Vector2(228, 54), 21)
		Estilo.con_franja(confirmar, COLOR_PENDIENTE)
		columna.add_child(confirmar)
		columna.add_child(UIReino.boton("Deshacer", _al_deshacer_puntos, Vector2(228, 48), 19))


func _tarjeta_caracteristica(car_id: String) -> PanelContainer:
	var datos: Dictionary = DatosEstadisticas.CARACTERISTICAS[car_id]
	var tarjeta := UIReino.panel()
	tarjeta.custom_minimum_size = Vector2(ANCHO_TARJETA, ALTO_TARJETA)
	tarjeta.size = tarjeta.custom_minimum_size
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	tarjeta.add_child(columna)
	var cabecera := HBoxContainer.new()
	columna.add_child(cabecera)
	var nombre := UIReino.boton(datos["nombre"], _al_elegir_estadistica.bind(car_id), Vector2(0, 44), 18)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Recortado: un nombre largo no debe ensanchar la tarjeta.
	nombre.clip_text = true
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_compactar(nombre)
	nombre.add_theme_color_override("font_color", datos["color"])
	cabecera.add_child(nombre)
	var cambiado := _pend_principal.has(car_id)
	cabecera.add_child(_etiqueta_valor(Juego.valor_principal(car_id, _pend_principal), cambiado, 21))
	if _puntos_principales_libres() > 0:
		cabecera.add_child(_compactar(UIReino.boton("+", _al_sumar_principal.bind(car_id), Vector2(44, 44), 24)))
	var libres := _puntos_sub_libres(car_id)
	for sub_id in datos["subs"]:
		var fila := HBoxContainer.new()
		columna.add_child(fila)
		var sub_nombre := UIReino.boton(DatosEstadisticas.SUBS[sub_id]["nombre"], _al_elegir_estadistica.bind(sub_id),
			Vector2(0, 46), 13)
		sub_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_nombre.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sub_nombre.clip_text = true
		sub_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_compactar(sub_nombre)
		if _elegida == sub_id:
			Estilo.con_franja(sub_nombre, datos["color"])
			# La franja de la elegida, angosta, para que el nombre siga cabiendo.
			for estado in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var caja := sub_nombre.get_theme_stylebox(estado) as StyleBoxFlat
				caja.border_width_left = 4
				caja.content_margin_left = 8
				caja.content_margin_right = 4
		fila.add_child(sub_nombre)
		var valor := Juego.valor_sub(sub_id, _pend_principal, _pend_sub)
		var sub_cambiada := not is_equal_approx(valor, Juego.valor_sub(sub_id))
		fila.add_child(_etiqueta_valor(valor, sub_cambiada, 17))
		if libres > 0:
			fila.add_child(_compactar(UIReino.boton("+", _al_sumar_sub.bind(sub_id), Vector2(44, 46), 22)))
	if libres > 0:
		var quedan := UIReino.etiqueta("%d %s para sus partes" % [libres, "punto" if libres == 1 else "puntos"],
			15, COLOR_PENDIENTE)
		# Recortado: con 3 cifras no debe ensanchar la tarjeta.
		quedan.clip_text = true
		quedan.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		columna.add_child(quedan)
	return tarjeta


## Octava casilla: qué hace la característica o sub elegida.
func _tarjeta_descripcion() -> PanelContainer:
	var tarjeta := UIReino.panel()
	tarjeta.custom_minimum_size = Vector2(ANCHO_TARJETA, ALTO_TARJETA)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 6)
	tarjeta.add_child(columna)
	if DatosEstadisticas.SUBS.has(_elegida):
		var sub: Dictionary = DatosEstadisticas.SUBS[_elegida]
		columna.add_child(UIReino.etiqueta(sub["nombre"], 21, UIReino.COLOR_TITULO))
		columna.add_child(UIReino.parrafo(sub["descripcion"], 208, 16, Estilo.TEXTO))
		if sub.get("sin_efecto", false):
			columna.add_child(UIReino.parrafo("Todavía sin efecto: falta el sistema del que depende.", 208, 15, Color("#ef9a9a")))
	elif DatosEstadisticas.CARACTERISTICAS.has(_elegida):
		var car: Dictionary = DatosEstadisticas.CARACTERISTICAS[_elegida]
		columna.add_child(UIReino.etiqueta(car["nombre"], 21, UIReino.COLOR_TITULO))
		columna.add_child(UIReino.parrafo("Un punto aquí sube +1 sus tres partes y da %d puntos para repartir solo entre ellas:"
			% DatosEstadisticas.PUNTOS_SUB_POR_PRINCIPAL, 208, 16, Estilo.TEXTO))
		for sub_id in car["subs"]:
			columna.add_child(UIReino.etiqueta("· " + String(DatosEstadisticas.SUBS[sub_id]["nombre"]), 16))
	else:
		columna.add_child(UIReino.etiqueta("Características", 21, UIReino.COLOR_TITULO))
		columna.add_child(UIReino.parrafo("Toca un nombre para ver qué hace. Todo empieza en 3; cada punto por encima mejora un poco.", 208, 16))
	return tarjeta


## "Heridas en 3 partes (1 fractura)" o, sin partes heridas, "Te falta vida".
func _texto_heridas() -> String:
	var partes := Juego.integridad.size()
	if partes == 0:
		return "Te falta vida."
	var texto := "Heridas en %d %s" % [partes, "parte" if partes == 1 else "partes"]
	var fracturas := Juego.fracturas.size()
	if fracturas > 0:
		texto += " (%d %s)" % [fracturas, "fractura" if fracturas == 1 else "fracturas"]
	return texto + "."


## Botón con menos margen a los lados, para que quepa en una tarjeta.
func _compactar(boton: Button) -> Button:
	for estado in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		# Del tema del juego (el botón todavía no está en el árbol).
		var copia := Estilo.tema().get_stylebox(estado, "Button").duplicate() as StyleBox
		copia.content_margin_left = 4
		copia.content_margin_right = 4
		boton.add_theme_stylebox_override(estado, copia)
	return boton


func _etiqueta_valor(valor: float, cambiado: bool, tamano: int) -> Label:
	var etiqueta := UIReino.etiqueta(_formato(valor), tamano, COLOR_PENDIENTE if cambiado else Estilo.TEXTO)
	etiqueta.custom_minimum_size = Vector2(36, 0)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return etiqueta


## "5" o "5,3".
func _formato(valor: float) -> String:
	if absf(valor - roundf(valor)) < 0.05:
		return "%d" % roundi(valor)
	return String.num(snappedf(valor, 0.1)).replace(".", ",")


func _suma(diccionario: Dictionary) -> int:
	var total := 0
	for clave in diccionario:
		total += int(diccionario[clave])
	return total


func _puntos_principales_libres() -> int:
	return Juego.puntos_principales - _suma(_pend_principal)


## Puntos que quedan para las partes de una principal (los pendientes cuentan).
func _puntos_sub_libres(car_id: String) -> int:
	var libres := Juego.puntos_sub_de(car_id, _pend_principal)
	for sub_id in DatosEstadisticas.CARACTERISTICAS[car_id]["subs"]:
		libres -= int(_pend_sub.get(sub_id, 0))
	return libres


func _hay_pendientes() -> bool:
	return not _pend_principal.is_empty() or not _pend_sub.is_empty()


## Rehace la pestaña Rey sin bloquear los toques: un + repetido solo suma puntos
## sin confirmar, que se pueden deshacer.
func _redibujar_rey() -> void:
	for hijo in _contenido.get_children():
		hijo.queue_free()
	_crear_rey()
	_actualizar_franja()


func _al_sumar_principal(car_id: String) -> void:
	if _puntos_principales_libres() <= 0:
		return
	_pend_principal[car_id] = int(_pend_principal.get(car_id, 0)) + 1
	_elegida = car_id
	_redibujar_rey()


func _al_sumar_sub(sub_id: String) -> void:
	if _puntos_sub_libres(DatosEstadisticas.caracteristica_de(sub_id)) <= 0:
		return
	_pend_sub[sub_id] = int(_pend_sub.get(sub_id, 0)) + 1
	_elegida = sub_id
	_redibujar_rey()


func _al_elegir_estadistica(clave: String) -> void:
	_elegida = clave
	_redibujar_rey()


func _al_confirmar_puntos() -> void:
	if not Juego.aplicar_puntos(_pend_principal, _pend_sub):
		return
	_pend_principal = {}
	_pend_sub = {}
	_avisar("Puntos aplicados.")
	_mostrar_pestana("rey")


func _al_deshacer_puntos() -> void:
	_pend_principal = {}
	_pend_sub = {}
	_redibujar_rey()


# --- Inventario ---

func _crear_inventario() -> void:
	_venta_pendiente = false
	if not _seleccion_valida():
		_seleccion = {}
	_crear_equipo()
	_crear_mochila()
	_crear_detalle()


## Vuelve a dibujar el inventario sin cancelar una venta a medio confirmar.
func _redibujar_inventario() -> void:
	for hijo in _contenido.get_children():
		hijo.queue_free()
	_crear_equipo()
	_crear_mochila()
	_crear_detalle()


func _seleccion_valida() -> bool:
	if _seleccion.has("ranura"):
		return Juego.equipo.has(_seleccion["ranura"])
	if _seleccion.has("id"):
		return not _objeto_de_mochila(_seleccion["id"]).is_empty()
	return false


func _objeto_de_mochila(id: int) -> Dictionary:
	for objeto in Juego.inventario:
		if objeto["id"] == id:
			return objeto
	return {}


func _objeto_elegido() -> Dictionary:
	if _seleccion.has("ranura"):
		return Juego.equipo.get(_seleccion["ranura"], {})
	if _seleccion.has("id"):
		return _objeto_de_mochila(_seleccion["id"])
	return {}


func _crear_equipo() -> void:
	var columna := VBoxContainer.new()
	columna.position = Vector2(20, 0)
	columna.add_theme_constant_override("separation", 8)
	_contenido.add_child(columna)
	columna.add_child(UIReino.etiqueta("Equipo", 24, UIReino.COLOR_TITULO))
	for ranura in DatosBotin.ORDEN_RANURAS:
		var objeto: Dictionary = Juego.equipo.get(ranura, {})
		var nombre := "—" if objeto.is_empty() else String(objeto["nombre"])
		var boton := UIReino.boton("%s: %s" % [DatosBotin.RANURAS[ranura]["nombre"], nombre],
			_al_elegir_equipo.bind(ranura), Vector2(400, 60), 18)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.clip_text = true
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var color := Color("#3a3f5c") if objeto.is_empty() else DatosBotin.color_calidad(objeto["calidad"])
		Estilo.con_franja(boton, color)
		boton.disabled = objeto.is_empty()
		columna.add_child(boton)
	columna.add_child(UIReino.etiqueta("Protección (armadura · resistencia mágica)", 17, Estilo.TEXTO_SUAVE))
	var armadura := Juego.armadura_por_zona()
	for grupo in [["Cabeza", "cabeza"], ["Torso", "torso"], ["Brazos", "brazo_der"], ["Piernas", "pierna_der"]]:
		var valores: Dictionary = armadura.get(grupo[1], {"fisica": 0, "magica": 0})
		columna.add_child(UIReino.etiqueta("%s: %d (−%d%%) · %d (−%d%%)" % [grupo[0],
			valores["fisica"], DatosBotin.porcentaje_reduccion(valores["fisica"]),
			valores["magica"], DatosBotin.porcentaje_reduccion(valores["magica"])], 17))


func _crear_mochila() -> void:
	var titulo := UIReino.etiqueta("Mochila (%d)" % Juego.inventario.size(), 24, UIReino.COLOR_TITULO)
	titulo.position = Vector2(440, 0)
	_contenido.add_child(titulo)
	var desplazable := ScrollContainer.new()
	desplazable.position = Vector2(440, 40)
	desplazable.size = Vector2(440, 530)
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_contenido.add_child(desplazable)
	desplazable.get_v_scroll_bar().value_changed.connect(func(valor: float) -> void: _scroll_mochila = int(valor))
	desplazable.set_deferred("scroll_vertical", _scroll_mochila)
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 8)
	rejilla.add_theme_constant_override("v_separation", 8)
	desplazable.add_child(rejilla)
	if Juego.inventario.is_empty():
		rejilla.add_child(UIReino.parrafo("Vacía. El botín de mazmorras y zonas aparece aquí.", 400, 18))
	for objeto in Juego.inventario:
		var boton := UIReino.boton_objeto(objeto, _al_elegir_mochila.bind(objeto["id"]), Vector2(212, 74))
		# Deja pasar el arrastre: así la mochila se desliza con el dedo sobre los objetos.
		boton.mouse_filter = Control.MOUSE_FILTER_PASS
		rejilla.add_child(boton)


func _crear_detalle() -> void:
	var panel := UIReino.panel()
	panel.position = Vector2(900, 0)
	panel.custom_minimum_size = Vector2(364, 300)
	_contenido.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	panel.add_child(columna)
	var objeto := _objeto_elegido()
	if objeto.is_empty():
		columna.add_child(UIReino.parrafo("Toca un objeto para ver sus datos, equiparlo o venderlo.", 330, 19))
		return
	columna.add_child(UIReino.parrafo(objeto["nombre"], 330, 24, DatosBotin.color_calidad(objeto["calidad"])))
	for linea in DatosBotin.describir(objeto, Juego.precio_venta(objeto)):
		columna.add_child(UIReino.parrafo(linea, 330, 18, Estilo.TEXTO))
	if _seleccion.has("ranura"):
		var quitar := UIReino.boton("Quitar", _al_quitar, Vector2(330, 62), 22)
		quitar.disabled = _seleccion["ranura"] == "arma"
		columna.add_child(quitar)
		if quitar.disabled:
			columna.add_child(UIReino.parrafo("El arma se cambia equipando otra.", 330, 16))
		return
	var es_pocion := DatosBotin.es_pocion(objeto)
	if es_pocion:
		columna.add_child(UIReino.parrafo("Tu vida: %d / %d.%s" % [Juego.vida_actual(), Juego.vida_maxima(),
			"" if Juego.esta_herido() else " Estás sano."], 330, 17, Estilo.TEXTO))
		var tomar := UIReino.boton("Tomar una", _al_tomar_pocion, Vector2(330, 62), 22)
		tomar.disabled = not Juego.esta_herido()
		Estilo.con_franja(tomar, Color("#ec407a"))
		columna.add_child(tomar)
	else:
		columna.add_child(UIReino.boton("Equipar", _al_equipar, Vector2(330, 62), 22))
	var texto_venta := ("Vender una por %d de oro" if es_pocion else "Vender por %d de oro") % Juego.precio_venta(objeto)
	if _venta_pendiente:
		texto_venta = "¿Seguro? Toca para vender"
	var vender := UIReino.boton(texto_venta, _al_vender, Vector2(330, 62), 20)
	Estilo.con_franja(vender, Color("#ffd54f"))
	columna.add_child(vender)


func _al_elegir_equipo(ranura: String) -> void:
	_seleccion = {"ranura": ranura}
	_mostrar_pestana("inventario")


func _al_elegir_mochila(id: int) -> void:
	_seleccion = {"id": id}
	_mostrar_pestana("inventario")


func _al_equipar() -> void:
	var objeto := _objeto_elegido()
	if objeto.is_empty() or not Juego.equipar(objeto["id"]):
		return
	_seleccion = {"ranura": objeto["ranura"]}
	_avisar("Equipaste: %s." % objeto["nombre"])
	_mostrar_pestana("inventario")


func _al_quitar() -> void:
	var objeto := _objeto_elegido()
	if objeto.is_empty() or not Juego.quitar(_seleccion["ranura"]):
		return
	_seleccion = {"id": objeto["id"]}
	_avisar("Guardaste: %s." % objeto["nombre"])
	_mostrar_pestana("inventario")


## Vender pide un segundo toque para confirmar.
func _al_vender() -> void:
	var objeto := _objeto_elegido()
	if objeto.is_empty() or _seleccion.has("ranura"):
		return
	if not _venta_pendiente:
		_venta_pendiente = true
		_redibujar_inventario()
		# Un doble toque no debe confirmar la venta sin querer.
		UIReino.bloquear_toques(self, 0.35)
		return
	var oro := Juego.vender(objeto["id"])
	# De las pociones se vende una: si quedan, siguen elegidas.
	if _objeto_de_mochila(objeto["id"]).is_empty():
		_seleccion = {}
	_avisar("Vendiste %s por %d de oro." % ["una poción" if DatosBotin.es_pocion(objeto) else String(objeto["nombre"]), oro])
	_mostrar_pestana("inventario")


func _al_tomar_pocion() -> void:
	if not Juego.usar_pocion():
		return
	_avisar("Tomaste una poción: vida %d / %d." % [Juego.vida_actual(), Juego.vida_maxima()])
	if not _seleccion_valida():
		_seleccion = {}
	_mostrar_pestana("inventario")


# --- Ciudad ---

func _crear_ciudad() -> void:
	var fila := HBoxContainer.new()
	fila.position = Vector2(24, 4)
	fila.add_theme_constant_override("separation", 26)
	_contenido.add_child(fila)
	var cambio := Juego.cambio_peligro_previsto()
	fila.add_child(UIReino.etiqueta("Peligro %d%% (%s por semana)" % [roundi(Juego.peligro), _con_signo(cambio)], 20,
		_color_peligro(Juego.peligro)))
	fila.add_child(UIReino.etiqueta("Defensa %s" % _decimal(Juego.defensa_ciudad()), 20))
	fila.add_child(UIReino.etiqueta("Soldados %d/%d" % [Juego.soldados, Juego.soldados_maximos()], 20))
	fila.add_child(UIReino.etiqueta("Comida %d (%s por semana)" % [
		Juego.comida, _con_signo(Juego.produccion_comida() - Juego.consumo_comida())], 20))
	fila.add_child(UIReino.etiqueta("Impuestos +%d por semana" % Juego.impuestos(), 20))
	var vista := VistaCiudad.new()
	vista.position = Vector2(20, 40)
	vista.size = Vector2(1240, 532)
	vista.edificio_elegido.connect(_abrir_edificio)
	_contenido.add_child(vista)


## "+6,8" o "−3".
func _con_signo(valor: float) -> String:
	return ("+" if valor >= 0.0 else "−") + _decimal(absf(valor))


func _decimal(valor: float) -> String:
	return _formato(valor)


## Un multiplicador con hasta dos decimales ("1,25", "1,5", "1").
func _multiplicador(valor: float) -> String:
	return String.num(snappedf(valor, 0.01)).replace(".", ",")


func _color_peligro(valor: float) -> Color:
	if valor < 25.0:
		return Color("#a5d6a7")
	if valor < 50.0:
		return Color("#ffe082")
	return Color("#ef9a9a")


## Ventana de un edificio: a la izquierda qué es y su mejora; a la derecha lo
## que se hace en él.
func _abrir_edificio(edificio_id: String) -> void:
	if _ventana_lugar != null:
		return
	_edificio_abierto = edificio_id
	_compra_pendiente = -1
	_dibujar_edificio()
	UIReino.bloquear_toques(self, 0.35)


func _dibujar_edificio() -> void:
	if _ventana_lugar != null:
		_ventana_lugar.queue_free()
	var capa := ColorRect.new()
	capa.color = Color(0, 0, 0, 0.6)
	capa.position = Vector2(0, 0)
	capa.size = Vector2(1280, 578)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	_contenido.add_child(capa)
	_ventana_lugar = capa
	var panel := UIReino.panel()
	panel.position = Vector2(70, 4)
	panel.custom_minimum_size = Vector2(1140, 0)
	capa.add_child(panel)
	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 30)
	panel.add_child(columnas)
	var izquierda := VBoxContainer.new()
	izquierda.add_theme_constant_override("separation", 10)
	izquierda.custom_minimum_size = Vector2(500, 0)
	columnas.add_child(izquierda)
	var derecha := VBoxContainer.new()
	derecha.add_theme_constant_override("separation", 8)
	derecha.custom_minimum_size = Vector2(560, 0)
	columnas.add_child(derecha)
	var edificio_id := _edificio_abierto
	var datos := DatosCiudad.edificio(edificio_id)
	var nivel := Juego.nivel_edificio(edificio_id)
	izquierda.add_child(UIReino.etiqueta(datos["nombre"], 32, UIReino.COLOR_TITULO))
	var estado := "En ruinas" if nivel <= 0 else "Nivel %d de %d" % [nivel, DatosCiudad.NIVEL_MAXIMO]
	izquierda.add_child(UIReino.etiqueta(estado, 20, UIReino.COLOR_AVISO if nivel <= 0 else Estilo.TEXTO))
	izquierda.add_child(UIReino.parrafo(datos["descripcion"], 480, 18, Estilo.TEXTO))
	izquierda.add_child(UIReino.parrafo("Ahora: " + DatosCiudad.efecto(edificio_id, nivel), 480, 17))
	if nivel < DatosCiudad.NIVEL_MAXIMO:
		izquierda.add_child(UIReino.parrafo("Con nivel %d: %s" % [nivel + 1, DatosCiudad.efecto(edificio_id, nivel + 1)], 480, 17))
		var costo := DatosCiudad.costo_mejora(edificio_id, nivel)
		var texto := "Reconstruir (%d de oro)" % costo if nivel <= 0 else "Mejorar a nivel %d (%d de oro)" % [nivel + 1, costo]
		var mejorar := UIReino.boton(texto, _al_mejorar_edificio, Vector2(480, 64), 22)
		var motivo := Juego.motivo_sin_mejora(edificio_id)
		mejorar.disabled = motivo != ""
		Estilo.con_franja(mejorar, datos["color"])
		izquierda.add_child(mejorar)
		if motivo != "":
			izquierda.add_child(UIReino.parrafo(motivo, 480, 17, Color("#ef9a9a")))
	izquierda.add_child(UIReino.boton("Cerrar", _cerrar_lugar, Vector2(480, 56), 21))
	match edificio_id:
		"castillo":
			_detalle_castillo(derecha)
		"herreria":
			_detalle_herreria(derecha, nivel)
		"granja":
			_detalle_granja(derecha)
		"mercado":
			_detalle_mercado(derecha, nivel)
		"barracas":
			_detalle_barracas(derecha, nivel)
		"enfermeria":
			_detalle_enfermeria(derecha, nivel)


func _detalle_castillo(columna: VBoxContainer) -> void:
	columna.add_child(UIReino.etiqueta("Estado de la ciudad", 24, UIReino.COLOR_TITULO))
	var cambio := Juego.cambio_peligro_previsto()
	var texto_peligro := "Peligro: %d%%. Cambia %s por semana: al terminar esta semana será de %d%%, y esa es la probabilidad de un ataque." % [
		roundi(Juego.peligro), _con_signo(cambio), roundi(Juego.peligro_previsto())]
	var desertores := Juego.desertores_previstos()
	if desertores > 0:
		texto_peligro += " (Cuenta que, sin comida, se irán %d.)" % desertores
	columna.add_child(UIReino.parrafo(texto_peligro, 540, 18, _color_peligro(Juego.peligro)))
	var por_soldado: float = DatosCiudad.EQUIPO_SOLDADOS[Juego.nivel_edificio("herreria")] * Juego.moral()
	columna.add_child(UIReino.parrafo("Defensa %s: %d %s × %s (equipo y moral) + %d de murallas. Cada punto de defensa baja %s el peligro por semana." % [
		_decimal(Juego.defensa_ciudad()), Juego.soldados, "soldado" if Juego.soldados == 1 else "soldados", _multiplicador(por_soldado),
		DatosCiudad.MURALLAS[Juego.nivel_edificio("castillo")], _decimal(DatosCiudad.PELIGRO_POR_DEFENSA)], 540, 17))
	var fuerza := DatosCiudad.FUERZA_BASE + DatosCiudad.FUERZA_POR_SEMANA * Juego.semana
	columna.add_child(UIReino.parrafo("Un ataque al terminar esta semana tendría unos %d a %d de fuerza. Si tu defensa es menor, saquean la ciudad: oro, comida, soldados y un edificio dañado." % [
		roundi(fuerza * DatosCiudad.AZAR_ATAQUE.x), roundi(fuerza * DatosCiudad.AZAR_ATAQUE.y)], 540, 17))
	if not Juego.informe_ciudad.is_empty():
		columna.add_child(UIReino.etiqueta("Semana %d" % Juego.informe_ciudad["semana"], 20, UIReino.COLOR_TITULO))
		columna.add_child(UIReino.parrafo(_resumen_semana(Juego.informe_ciudad), 540, 17))
	var descansar := UIReino.boton("Descansar una semana\n−%d de estrés · cura el %d%% de tus heridas" % [
		roundi(EstadoReino.ESTRES_DESCANSO), _porcentaje_descanso()], _al_descansar, Vector2(540, 74), 20)
	columna.add_child(descansar)


## Parte de la vida y de cada parte herida que cura descansar ahora (en %).
func _porcentaje_descanso() -> int:
	return mini(roundi(Juego.cura_al_descansar() * Juego.multiplicador_curacion() * 100.0), 100)


func _detalle_enfermeria(columna: VBoxContainer, nivel: int) -> void:
	columna.add_child(UIReino.etiqueta("Salud del rey", 24, UIReino.COLOR_TITULO))
	var estado := _texto_heridas() if Juego.esta_herido() else "Estás sano."
	columna.add_child(UIReino.parrafo("Vida %d / %d. %s" % [Juego.vida_actual(), Juego.vida_maxima(), estado], 540, 18, Estilo.TEXTO))
	columna.add_child(UIReino.parrafo("Descansar una semana en el castillo cura el %d%% de la vida y de cada parte herida (Recuperación ×%s)." % [
		_porcentaje_descanso(), _multiplicador(Juego.multiplicador_curacion())], 540, 17))
	if nivel <= 0:
		columna.add_child(UIReino.parrafo("Reconstrúyela para que descansar cure más.", 540, 17))
	columna.add_child(UIReino.parrafo("Al caminar por una mazmorra o una zona también te curas poco a poco. Las pociones curan en el momento (se compran en el mercado).", 540, 17))


## Todo lo que pasó en la ciudad esa semana, en un párrafo.
func _resumen_semana(informe: Dictionary) -> String:
	var texto := "Comida +%d −%d. Impuestos +%d de oro. Peligro de %d%% a %d%%." % [
		informe["comida_producida"], informe["comida_consumida"], informe["impuestos"],
		roundi(informe["peligro_antes"]), roundi(informe["peligro_final"])]
	var grave := Juego.texto_informe(informe)
	if grave != "":
		texto += " " + grave
	elif not informe.has("ataque"):
		texto += " Sin ataques."
	return texto


func _detalle_herreria(columna: VBoxContainer, nivel: int) -> void:
	columna.add_child(UIReino.etiqueta("Mejorar tu equipo", 24, UIReino.COLOR_TITULO))
	if nivel <= 0:
		columna.add_child(UIReino.parrafo("Reconstrúyela para mejorar la calidad de tus armas y armaduras.", 540, 18))
		return
	columna.add_child(UIReino.parrafo("Sube una calidad lo que llevas puesto (hasta calidad %s)." % DatosCiudad.CALIDAD_FEMENINA[
		DatosCiudad.CALIDAD_MAXIMA_HERRERIA[nivel]], 540, 17))
	for ranura in DatosBotin.ORDEN_RANURAS:
		if not Juego.equipo.has(ranura):
			continue
		var objeto: Dictionary = Juego.equipo[ranura]
		var costo := Juego.costo_herreria(objeto)
		var texto: String = "%s (%s)" % [objeto["nombre"], DatosBotin.nombre_calidad(objeto["calidad"]).to_lower()]
		texto += "\nYa no se puede mejorar aquí" if costo < 0 else "\nA calidad %s: %d de oro" % [
			DatosCiudad.CALIDAD_FEMENINA[Juego.calidad_siguiente(objeto)], costo]
		var boton := UIReino.boton(texto, _al_mejorar_objeto.bind(ranura), Vector2(540, 62), 17)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.clip_text = true
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		boton.disabled = costo < 0 or Juego.oro < costo
		Estilo.con_franja(boton, DatosBotin.color_calidad(objeto["calidad"]))
		columna.add_child(boton)


func _detalle_granja(columna: VBoxContainer) -> void:
	columna.add_child(UIReino.etiqueta("Comida", 24, UIReino.COLOR_TITULO))
	var producida := Juego.produccion_comida()
	var consumida := Juego.consumo_comida()
	columna.add_child(UIReino.parrafo("En el almacén: %d de comida." % Juego.comida, 540, 18, Estilo.TEXTO))
	columna.add_child(UIReino.parrafo("Cada semana la granja produce %d y los soldados comen %d (%d cada uno)." % [
		producida, consumida, DatosCiudad.COMIDA_POR_SOLDADO], 540, 18))
	var balance := producida - consumida
	if balance >= 0:
		columna.add_child(UIReino.parrafo("Sobra comida: +%d por semana." % balance, 540, 18, Color("#a5d6a7")))
	else:
		var semanas := floori(Juego.comida / float(-balance))
		columna.add_child(UIReino.parrafo("Falta comida: %d por semana. Alcanza para %d %s; después se irán soldados." % [
			balance, semanas, "semana" if semanas == 1 else "semanas"], 540, 18, Color("#ef9a9a")))


func _detalle_mercado(columna: VBoxContainer, nivel: int) -> void:
	columna.add_child(UIReino.etiqueta("A la venta esta semana", 24, UIReino.COLOR_TITULO))
	if nivel <= 0:
		columna.add_child(UIReino.parrafo("Reconstrúyelo para cobrar impuestos y comprar objetos.", 540, 18))
		return
	columna.add_child(UIReino.parrafo("Cobra %d de oro de impuestos por semana. Lo que vende cambia cada semana. Lo que compras va al Inventario, y ahí también se vende." % Juego.impuestos(), 540, 17))
	if Juego.mercado.is_empty():
		columna.add_child(UIReino.parrafo("Ya compraste todo lo de esta semana.", 540, 18))
	for i in Juego.mercado.size():
		var objeto: Dictionary = Juego.mercado[i]
		var precio := Juego.precio_compra(objeto)
		var es_pocion := DatosBotin.es_pocion(objeto)
		var texto: String = String(objeto["nombre"]) + "\n" if es_pocion else "%s (%s, nivel %d)\n" % [
			objeto["nombre"], DatosBotin.nombre_calidad(objeto["calidad"]).to_lower(), objeto["nivel"]]
		# El dato principal: lo que cura una poción, el daño de un arma, o la
		# armadura y la resistencia mágica de una pieza.
		var dato: String
		if es_pocion:
			dato = "Cura %d de vida · quedan %d" % [DatosBotin.POCION_VIDA, int(objeto.get("cantidad", 1))]
		elif objeto["ranura"] == "arma":
			dato = DatosBotin.describir(objeto)[1]
		else:
			dato = "Arm. %d · Res. mág. %d" % [objeto["armadura"], objeto["resistencia_magica"]]
		texto += "Toca otra vez para comprar por %d de oro" % precio if i == _compra_pendiente else "%s · %d de oro" % [dato, precio]
		var boton := UIReino.boton(texto, _al_comprar.bind(i), Vector2(540, 62), 17)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.clip_text = true
		boton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		boton.disabled = Juego.oro < precio
		Estilo.con_franja(boton, DatosBotin.color_calidad(objeto["calidad"]))
		columna.add_child(boton)


func _detalle_barracas(columna: VBoxContainer, nivel: int) -> void:
	columna.add_child(UIReino.etiqueta("Soldados", 24, UIReino.COLOR_TITULO))
	if nivel <= 0:
		columna.add_child(UIReino.parrafo("Reconstrúyelas para reclutar soldados que cuiden la ciudad.", 540, 18))
		return
	var por_soldado: float = DatosCiudad.EQUIPO_SOLDADOS[Juego.nivel_edificio("herreria")] * Juego.moral()
	columna.add_child(UIReino.parrafo("Tienes %d de %d soldados. Cada uno da %s de defensa (equipo de la herrería ×%s, moral ×%s por Liderazgo) y come %d de comida por semana." % [
		Juego.soldados, Juego.soldados_maximos(), _multiplicador(por_soldado),
		_multiplicador(DatosCiudad.EQUIPO_SOLDADOS[Juego.nivel_edificio("herreria")]), _multiplicador(Juego.moral()),
		DatosCiudad.COMIDA_POR_SOLDADO], 540, 18))
	var reclutar := UIReino.boton("Reclutar un soldado (%d de oro)" % DatosCiudad.COSTO_SOLDADO, _al_reclutar, Vector2(540, 64), 21)
	reclutar.disabled = not Juego.puede_reclutar()
	Estilo.con_franja(reclutar, DatosCiudad.edificio("barracas")["color"])
	columna.add_child(reclutar)
	if Juego.soldados >= Juego.soldados_maximos():
		columna.add_child(UIReino.parrafo("No caben más: mejora las barracas.", 540, 17, Color("#ef9a9a")))
	elif Juego.oro < DatosCiudad.COSTO_SOLDADO:
		columna.add_child(UIReino.parrafo("No te alcanza el oro.", 540, 17, Color("#ef9a9a")))


## Rehace la ventana del edificio (y lo de detrás) tras un cambio.
func _actualizar_ciudad() -> void:
	var abierto := _edificio_abierto
	var pendiente := _compra_pendiente
	_mostrar_pestana("ciudad", false)
	_edificio_abierto = abierto
	_compra_pendiente = pendiente
	_dibujar_edificio()


func _al_mejorar_edificio() -> void:
	var articulo: String = DatosCiudad.edificio(_edificio_abierto)["articulo"]
	var nivel := Juego.nivel_edificio(_edificio_abierto)
	if not Juego.mejorar_edificio(_edificio_abierto):
		return
	_avisar("Reconstruiste %s." % articulo if nivel <= 0 else "Mejoraste %s a nivel %d." % [articulo, nivel + 1])
	_compra_pendiente = -1
	_actualizar_ciudad()


func _al_mejorar_objeto(ranura: String) -> void:
	if not Juego.mejorar_en_herreria(ranura):
		return
	var objeto: Dictionary = Juego.equipo[ranura]
	_avisar("%s: ahora de calidad %s." % [objeto["nombre"], DatosCiudad.CALIDAD_FEMENINA[objeto["calidad"]]])
	_actualizar_ciudad()


## Comprar pide un segundo toque sobre el mismo objeto.
func _al_comprar(indice: int) -> void:
	if indice != _compra_pendiente:
		_compra_pendiente = indice
		_actualizar_ciudad()
		UIReino.bloquear_toques(self, 0.35)
		return
	var objeto: Dictionary = Juego.mercado[indice]
	var precio := Juego.precio_compra(objeto)
	if not Juego.comprar(indice):
		return
	_compra_pendiente = -1
	_avisar("Compraste %s por %d de oro." % ["una poción" if DatosBotin.es_pocion(objeto) else String(objeto["nombre"]), precio])
	_actualizar_ciudad()


func _al_reclutar() -> void:
	if not Juego.reclutar():
		return
	_avisar("Reclutaste un soldado (%d en total)." % Juego.soldados)
	_actualizar_ciudad()


func _al_descansar() -> void:
	var herido := Juego.esta_herido()
	Juego.descansar()
	_avisar("Descansaste%s. Empieza la semana %d." % [" y te curaste" if herido else "", Juego.semana])
	_mostrar_pestana("ciudad")
	_mostrar_noticias()


## Si en la última semana atacaron la ciudad o se fueron soldados, lo cuenta en
## una ventana (una sola vez).
func _mostrar_noticias() -> void:
	var informe := Juego.informe_ciudad
	if not informe.get("nuevo", false):
		return
	informe["nuevo"] = false
	var texto := Juego.texto_informe(informe)
	if texto == "" or _ventana_lugar != null:
		return
	var capa := ColorRect.new()
	capa.color = Color(0, 0, 0, 0.6)
	capa.size = Vector2(1280, 578)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	_contenido.add_child(capa)
	_ventana_lugar = capa
	var panel := UIReino.panel()
	panel.position = Vector2(320, 120)
	panel.custom_minimum_size = Vector2(640, 0)
	capa.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)
	columna.add_child(UIReino.etiqueta("Noticias de la ciudad · semana %d" % informe["semana"], 26, UIReino.COLOR_TITULO))
	columna.add_child(UIReino.parrafo(texto, 600, 19, Estilo.TEXTO))
	columna.add_child(UIReino.parrafo("Peligro ahora: %d%%. Mira el castillo para ver cómo protegerla." % roundi(Juego.peligro), 600, 17))
	var listo := UIReino.boton("Listo", _cerrar_lugar, Vector2(600, 60), 22)
	columna.add_child(listo)
	UIReino.bloquear_toques(self, 0.35)


# --- Aventura ---

func _crear_aventura() -> void:
	var mapa := MapaReino.new()
	mapa.position = Vector2(20, 0)
	mapa.size = Vector2(1240, 570)
	mapa.lugar_elegido.connect(_al_elegir_lugar)
	_contenido.add_child(mapa)


func _al_elegir_lugar(lugar_id: String) -> void:
	if _ventana_lugar != null:
		return
	var datos := DatosAventura.lugar(lugar_id)
	var es_mazmorra := DatosAventura.es_mazmorra(lugar_id)
	var capa := ColorRect.new()
	capa.color = Color(0, 0, 0, 0.55)
	capa.position = Vector2(20, 0)
	capa.size = Vector2(1240, 570)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	_contenido.add_child(capa)
	_ventana_lugar = capa
	var panel := UIReino.panel()
	panel.position = Vector2(260, 60)
	panel.custom_minimum_size = Vector2(720, 0)
	capa.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)
	columna.add_child(UIReino.etiqueta(datos["nombre"], 32, UIReino.COLOR_TITULO))
	var tipo := "Mazmorra" if es_mazmorra else "Zona: siete días de sucesos al azar"
	columna.add_child(UIReino.etiqueta("%s · %s" % [tipo, datos["dificultad"]], 20, UIReino.COLOR_AVISO))
	columna.add_child(UIReino.parrafo(datos["descripcion"], 680, 19, Estilo.TEXTO))
	columna.add_child(UIReino.parrafo("Enemigos: %s." % DatosAventura.nombres_enemigos(lugar_id), 680, 18))
	if es_mazmorra:
		columna.add_child(UIReino.parrafo("Cada paso suma estrés; con %d vuelves a casa. La mazmorra se reinicia cada semana." % roundi(DatosAventura.ESTRES_MAXIMO), 680, 17))
	var vida := "Tu vida: %d / %d." % [Juego.vida_actual(), Juego.vida_maxima()]
	if Juego.vida_actual() < Juego.vida_maxima() / 2:
		vida += " Estás herido: descansa en el castillo o toma una poción antes de salir."
	columna.add_child(UIReino.parrafo(vida, 680, 18, UIReino.COLOR_AVISO if Juego.esta_herido() else Estilo.TEXTO_SUAVE))
	var puede := Juego.estres < DatosAventura.ESTRES_MAXIMO
	if not puede:
		columna.add_child(UIReino.parrafo("Estás demasiado estresado para salir. Descansa primero (en el castillo, en la Ciudad).", 680, 18, Color("#ef9a9a")))
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 20)
	columna.add_child(fila)
	var explorar := UIReino.boton("Explorar", _al_explorar.bind(lugar_id), Vector2(240, 70), 24)
	explorar.disabled = not puede
	fila.add_child(explorar)
	fila.add_child(UIReino.boton("Cancelar", _cerrar_lugar, Vector2(240, 70), 24))
	UIReino.bloquear_toques(self, 0.35)


func _cerrar_lugar() -> void:
	if _ventana_lugar != null:
		_ventana_lugar.queue_free()
		_ventana_lugar = null
		UIReino.bloquear_toques(self, 0.35)


func _al_explorar(lugar_id: String) -> void:
	if Juego.estres >= DatosAventura.ESTRES_MAXIMO:
		return
	if DatosAventura.es_mazmorra(lugar_id):
		Juego.mazmorra = {"id": lugar_id}
		get_tree().change_scene_to_file.call_deferred(ESCENA_MAZMORRA)
	else:
		Juego.expedicion = {"id": lugar_id}
		get_tree().change_scene_to_file.call_deferred(ESCENA_EXPEDICION)


# --- Trabajo ---

func _crear_trabajo() -> void:
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.position = Vector2(20, 0)
	rejilla.add_theme_constant_override("h_separation", 10)
	rejilla.add_theme_constant_override("v_separation", 10)
	_contenido.add_child(rejilla)
	var grupo := ButtonGroup.new()
	for oficio_id in DatosTrabajos.ORDEN:
		var oficio: Dictionary = DatosTrabajos.OFICIOS[oficio_id]
		var dominio: float = Juego.dominio.get(oficio_id, 0.0)
		var pago := DatosTrabajos.pago_dia(oficio_id, Juego.multiplicador_pago())
		var boton := UIReino.boton("%s\n%d oro por día · dominio %d%%" % [oficio["nombre"], pago, roundi(dominio)],
			_al_elegir_oficio.bind(oficio_id), Vector2(320, 92), 19)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.toggle_mode = true
		boton.button_group = grupo
		boton.button_pressed = oficio_id == _oficio
		Estilo.con_franja(boton, Color("#66bb6a"))
		rejilla.add_child(boton)
	_crear_detalle_oficio()


func _crear_detalle_oficio() -> void:
	var panel := UIReino.panel()
	panel.position = Vector2(690, 0)
	panel.custom_minimum_size = Vector2(570, 0)
	_contenido.add_child(panel)
	_detalle_oficio = panel
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	panel.add_child(columna)
	var oficio: Dictionary = DatosTrabajos.OFICIOS[_oficio]
	var dominio: float = Juego.dominio.get(_oficio, 0.0)
	columna.add_child(UIReino.etiqueta(oficio["nombre"], 28, UIReino.COLOR_TITULO))
	columna.add_child(UIReino.parrafo(oficio["descripcion"], 530, 19, Estilo.TEXTO))
	var pago := DatosTrabajos.pago_dia(_oficio, Juego.multiplicador_pago())
	columna.add_child(UIReino.parrafo("Pago por cada día que sale bien: %d de oro." % pago, 530, 18))
	columna.add_child(UIReino.parrafo("Probabilidad de que un día salga bien: %d%% (sube con el dominio, ahora %d de 100)." % [
		roundi(DatosTrabajos.prob_exito(dominio) * 100.0), roundi(dominio)], 530, 18))
	columna.add_child(UIReino.parrafo("Estrés de la semana: +%s. Si los siete días salen bien, cobras %d de oro extra." % [
		String.num(snappedf(Juego.estres_mental(float(oficio["estres"]) * DatosTrabajos.DIAS), 0.1)),
		pago * DatosTrabajos.BONO_SEMANA_PERFECTA], 530, 18))
	var boton := UIReino.boton("Trabajar esta semana", _al_trabajar, Vector2(530, 70), 24)
	if not Juego.puede_trabajar():
		boton.disabled = true
		columna.add_child(UIReino.parrafo("Demasiado estresado para trabajar (máximo %d). Descansa primero." % roundi(DatosTrabajos.ESTRES_MAXIMO), 530, 18, Color("#ef9a9a")))
	columna.add_child(boton)


func _al_elegir_oficio(oficio_id: String) -> void:
	if _ocupado:
		return
	_oficio = oficio_id
	_quitar_detalle_oficio()
	_crear_detalle_oficio()


## Quita el panel del oficio (al final del cuadro: puede estar en medio de un toque).
func _quitar_detalle_oficio() -> void:
	if is_instance_valid(_detalle_oficio):
		_detalle_oficio.queue_free()
	_detalle_oficio = null


## Pasa la semana trabajando y muestra día por día cómo fue.
func _al_trabajar() -> void:
	if _ocupado or not Juego.puede_trabajar():
		return
	_ocupado = true
	var oficio: Dictionary = DatosTrabajos.OFICIOS[_oficio]
	var semana := Juego.semana
	var resultado := Juego.trabajar(_oficio)
	_quitar_detalle_oficio()
	var panel := UIReino.panel()
	panel.position = Vector2(690, 0)
	panel.custom_minimum_size = Vector2(570, 0)
	_contenido.add_child(panel)
	_detalle_oficio = panel
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	panel.add_child(columna)
	columna.add_child(UIReino.etiqueta("%s · semana %d" % [oficio["nombre"], semana], 24, UIReino.COLOR_TITULO))
	var dias: Array = resultado["dias"]
	for i in dias.size():
		await get_tree().create_timer(PAUSA_DIA).timeout
		var texto := "Día %d: salió bien (+%d de oro)" % [i + 1, resultado["pago_dia"]] if dias[i] \
			else "Día %d: salió mal (sin pago)" % (i + 1)
		columna.add_child(UIReino.etiqueta(texto, 19, Color("#a5d6a7") if dias[i] else Color("#ef9a9a")))
	await get_tree().create_timer(PAUSA_DIA).timeout
	var resumen := "Ganaste %d de oro" % resultado["oro"]
	if int(resultado["bono"]) > 0:
		resumen += " (incluye %d por la semana perfecta)" % resultado["bono"]
	columna.add_child(UIReino.parrafo("%s. Estrés +%s." % [resumen, String.num(snappedf(resultado["estres"], 0.1))], 530, 19, Estilo.TEXTO))
	columna.add_child(UIReino.boton("Listo", _al_terminar_trabajo, Vector2(530, 64), 22))
	_actualizar_franja()
	_avisar("Terminó la semana %d. Empieza la semana %d." % [semana, Juego.semana])
	_ocupado = false
	_mostrar_noticias()


func _al_terminar_trabajo() -> void:
	_mostrar_pestana("trabajo")
	_mostrar_noticias()
