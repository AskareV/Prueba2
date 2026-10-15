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
	franja.add_theme_constant_override("separation", 22)
	_area.add_child(franja)
	_etiqueta_semana = UIReino.etiqueta("", 22, UIReino.COLOR_TITULO)
	franja.add_child(_etiqueta_semana)
	_etiqueta_oro = UIReino.etiqueta("", 22, Color("#ffd54f"))
	franja.add_child(_etiqueta_oro)
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
	var por_repartir := Juego.puntos_principales + Juego.puntos_sub > 0
	_botones_pestana["rey"].text = "Rey (+)" if por_repartir else String(NOMBRES_PESTANA["rey"])
	_etiqueta_oro.text = "Oro: %d" % Juego.oro
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


func _mostrar_pestana(pestana: String) -> void:
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
	barra.custom_minimum_size = Vector2(230, 22)
	barra.tamano_fuente = 14
	barra.color_fijo = Color("#7e57c2")
	barra.valor = float(Juego.xp) / Juego.xp_para_subir()
	barra.texto = "Experiencia %d / %d" % [Juego.xp, Juego.xp_para_subir()]
	columna.add_child(barra)
	var rey := Juego.crear_rey()
	columna.add_child(UIReino.etiqueta("Vida %d · Maná %d" % [rey.vida_max, roundi(rey.mana_max)], 17, Estilo.TEXTO_SUAVE))
	columna.add_child(UIReino.etiqueta("Rapidez %s" % _formato(rey.rapidez), 17, Estilo.TEXTO_SUAVE))
	var principales := _puntos_principales_libres()
	var sueltos := _puntos_sub_libres()
	columna.add_child(UIReino.etiqueta("Puntos principales: %d" % principales, 19,
		UIReino.COLOR_TITULO if principales > 0 else Estilo.TEXTO_SUAVE))
	columna.add_child(UIReino.etiqueta("Puntos sueltos: %d" % sueltos, 19,
		UIReino.COLOR_TITULO if sueltos > 0 else Estilo.TEXTO_SUAVE))
	if principales > 0 or sueltos > 0:
		columna.add_child(UIReino.parrafo("Toca + en una característica (sube sus 3 partes) o en una de sus partes.", 240, 15))
	if _hay_pendientes():
		var confirmar := UIReino.boton("Confirmar", _al_confirmar_puntos, Vector2(240, 54), 21)
		Estilo.con_franja(confirmar, COLOR_PENDIENTE)
		columna.add_child(confirmar)
		columna.add_child(UIReino.boton("Deshacer", _al_deshacer_puntos, Vector2(240, 48), 19))


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
	for sub_id in datos["subs"]:
		var fila := HBoxContainer.new()
		columna.add_child(fila)
		var sub_nombre := UIReino.boton(DatosEstadisticas.SUBS[sub_id]["nombre"], _al_elegir_estadistica.bind(sub_id),
			Vector2(0, 46), 15)
		sub_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_nombre.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sub_nombre.clip_text = true
		sub_nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_compactar(sub_nombre)
		if _elegida == sub_id:
			Estilo.con_franja(sub_nombre, datos["color"])
		fila.add_child(sub_nombre)
		var valor := Juego.valor_sub(sub_id, _pend_principal, _pend_sub)
		var sub_cambiada := not is_equal_approx(valor, Juego.valor_sub(sub_id))
		fila.add_child(_etiqueta_valor(valor, sub_cambiada, 17))
		if _puntos_sub_libres() > 0:
			fila.add_child(_compactar(UIReino.boton("+", _al_sumar_sub.bind(sub_id), Vector2(44, 46), 22)))
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
		columna.add_child(UIReino.parrafo(sub["descripcion"], 220, 16, Estilo.TEXTO))
		if sub.get("sin_efecto", false):
			columna.add_child(UIReino.parrafo("Todavía sin efecto: falta el sistema del que depende.", 220, 15, Color("#ef9a9a")))
	elif DatosEstadisticas.CARACTERISTICAS.has(_elegida):
		var car: Dictionary = DatosEstadisticas.CARACTERISTICAS[_elegida]
		columna.add_child(UIReino.etiqueta(car["nombre"], 21, UIReino.COLOR_TITULO))
		columna.add_child(UIReino.parrafo("Un punto aquí sube +1 sus tres partes:", 220, 16, Estilo.TEXTO))
		for sub_id in car["subs"]:
			columna.add_child(UIReino.etiqueta("· " + String(DatosEstadisticas.SUBS[sub_id]["nombre"]), 16))
	else:
		columna.add_child(UIReino.etiqueta("Características", 21, UIReino.COLOR_TITULO))
		columna.add_child(UIReino.parrafo("Toca un nombre para ver qué hace. Todo empieza en 3; cada punto por encima mejora un poco.", 220, 16))
	return tarjeta


## Botón con menos margen a los lados, para que quepa en una tarjeta.
func _compactar(boton: Button) -> Button:
	for estado in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		# Del tema del juego (el botón todavía no está en el árbol).
		var copia := Estilo.tema().get_stylebox(estado, "Button").duplicate() as StyleBox
		copia.content_margin_left = 8
		copia.content_margin_right = 8
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


func _puntos_sub_libres() -> int:
	return Juego.puntos_sub - _suma(_pend_sub)


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
	if _puntos_sub_libres() <= 0:
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
	columna.add_child(UIReino.boton("Equipar", _al_equipar, Vector2(330, 62), 22))
	var texto_venta := "Vender por %d de oro" % Juego.precio_venta(objeto)
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
	_seleccion = {}
	_avisar("Vendiste %s por %d de oro." % [objeto["nombre"], oro])
	_mostrar_pestana("inventario")


# --- Ciudad ---

func _crear_ciudad() -> void:
	var panel := UIReino.panel()
	panel.position = Vector2(290, 60)
	panel.custom_minimum_size = Vector2(700, 0)
	_contenido.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 14)
	panel.add_child(columna)
	columna.add_child(UIReino.etiqueta("Ciudad", 34, UIReino.COLOR_TITULO))
	columna.add_child(UIReino.parrafo("En construcción. Aquí irán el descanso, la escuela y lo demás de la ciudad.", 660, 20))
	columna.add_child(UIReino.parrafo("Provisional, para no quedar trabado con mucho estrés: descansar una semana baja %d de estrés." % roundi(EstadoReino.ESTRES_DESCANSO), 660, 18))
	var descansar := UIReino.boton("Descansar una semana (provisional)", _al_descansar, Vector2(520, 70), 22)
	descansar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	columna.add_child(descansar)


func _al_descansar() -> void:
	Juego.descansar()
	_avisar("Descansaste. Empieza la semana %d." % Juego.semana)
	_actualizar_franja()
	# Un doble toque no debe descansar dos semanas.
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
	var puede := Juego.estres < DatosAventura.ESTRES_MAXIMO
	if not puede:
		columna.add_child(UIReino.parrafo("Estás demasiado estresado para salir. Descansa primero (en la Ciudad).", 680, 18, Color("#ef9a9a")))
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


func _al_terminar_trabajo() -> void:
	_mostrar_pestana("trabajo")
