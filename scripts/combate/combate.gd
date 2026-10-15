extends Control
## Escena de combate de la demo: el rey (izquierda) contra un rival (derecha).
## Ataque: Atacar -> zona (6) -> parte (21) -> se resuelve el golpe.
## Las reglas están en MotorCombate; aquí solo el flujo de turnos y la interfaz.

enum Estado { ESPERANDO, ACCIONES, ZONA, PARTE, ARMA, FIN, MAGIA }

const ESCENA_PREPARACION := "res://escenas/preparacion.tscn"
const COLOR_DANIO := Color("#ff6b6b")
const COLOR_FALLO := Color("#cfd8dc")
const COLOR_AVISO := Color("#ffd54f")
## Orden de los botones de zona: imita la silueta del rival, que mira a la cámara
## (su brazo derecho queda a la izquierda de la pantalla).
const ORDEN_BOTONES_ZONA := ["brazo_der", "cabeza", "brazo_izq", "pierna_der", "torso", "pierna_izq"]
const TAMANO_LUPA := Vector2(380, 330)
## Tras cambiar los botones se ignoran los toques un momento, para que un doble
## toque no pulse sin querer el botón que aparece bajo el dedo (por ejemplo, Huir).
const PAUSA_ENTRE_MENUS := 0.35
## Margen (en píxeles de pantalla) para acertar con el dedo a partes pequeñas.
const MARGEN_TOQUE := 14.0
## Líneas visibles del registro de mensajes.
const LINEAS_REGISTRO := 3
## Turnos que muestra la fila de próximos turnos.
const TURNOS_A_MOSTRAR := 6
const COLOR_JUGADOR := Color("#42a5f5")
const COLOR_RIVAL := Color("#ef5350")
const COLOR_CURA := Color("#81c784")

var _rng := RandomNumberGenerator.new()
var _jugador: Luchador
var _enemigo: Luchador
var _datos_rival: Dictionary
var _turno := 1
## Ya tuvo un turno el jugador (el número de turno sube con cada turno suyo).
var _ya_jugo := false
## Barra de turnos por velocidad (ver OrdenTurnos).
var _orden: OrdenTurnos
## Hechizo que se está apuntando ("" si es un ataque normal).
var _hechizo_id := ""
var _estado := Estado.ESPERANDO
var _zona := ""
var _mensajes: Array[String] = []
var _etiquetas_bbcode := RegEx.create_from_string("\\[[^\\]]*\\]")

var _fondo: FondoMazmorra
var _antorchas: Antorchas
var _vineta: Vineta
var _figura_jugador: Figura
var _figura_enemigo: Figura
var _panel_jugador: PanelLuchador
var _panel_enemigo: PanelLuchador
var _etiqueta_turno: Label
var _boton_estado: Button
var _boton_menu: Button
var _registro: RichTextLabel
var _acciones: HBoxContainer
var _boton_atacar: Button
var _boton_defender: Button
var _boton_arma: Button
var _boton_huir: Button
var _boton_magia: Button
var _fila_turnos: HBoxContainer
var _apuntar: VBoxContainer
var _titulo_apuntar: Label
var _opciones: GridContainer
var _boton_volver: Button
## Lupa: muestra ampliada la zona elegida para tocar sus partes con facilidad.
var _lupa: Panel
var _figura_lupa: Figura
var _capa_textos: Control
## Ventana abierta (estado o fin de combate), o null.
var _ventana: Control
var _ventana_es_estado := false
## Segundos que faltan para volver a aceptar toques (ver PAUSA_ENTRE_MENUS).
var _bloqueo := 0.0
## true si el combate viene de una mazmorra o zona del reino (ver Juego.combate):
## el rey pelea con su equipo y al terminar vuelve a ese lugar.
var _modo_reino := false
var _resultado := ""


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modo_reino = not Juego.combate.is_empty() and Juego.combate.get("resultado", "") == ""
	var rival_id: String = Juego.combate["rival"] if _modo_reino else Partida.rival
	if _modo_reino:
		_jugador = Juego.crear_rey()
	else:
		_jugador = DatosRivales.crear_rey(Partida.diestro, Partida.arma)
	_datos_rival = DatosRivales.rival(rival_id)
	_enemigo = DatosRivales.crear_rival(rival_id)
	_orden = OrdenTurnos.new(_jugador, _enemigo)
	_crear_escenario()
	_crear_interfaz()
	get_viewport().size_changed.connect(_reubicar)
	_reubicar()
	_agregar_mensaje("¡%s te desafía!" % _mayuscula(_enemigo.con_articulo()))
	if MotorCombate.puede_atemorizar(_jugador, _enemigo):
		_enemigo.atemorizado = true
		_agregar_mensaje("Tu presencia lo intimida: %s queda atemorizado." % _enemigo.con_articulo())
	_siguiente_turno()
	# Un doble toque en "¡Combatir!" no debe pulsar lo que quede debajo al entrar.
	_bloqueo = 0.5


func _process(delta: float) -> void:
	_bloqueo = maxf(_bloqueo - delta, 0.0)


# --- Construcción de la escena ---

func _crear_escenario() -> void:
	_fondo = FondoMazmorra.new()
	add_child(_fondo)
	_antorchas = Antorchas.new()
	add_child(_antorchas)
	_figura_jugador = Figura.new()
	add_child(_figura_jugador)
	_figura_jugador.configurar(_jugador, DatosRivales.ASPECTO_REY, true)
	_figura_enemigo = Figura.new()
	add_child(_figura_enemigo)
	_figura_enemigo.configurar(_enemigo, _datos_rival["aspecto"], false)
	_vineta = Vineta.new()
	add_child(_vineta)


func _crear_interfaz() -> void:
	_panel_jugador = PanelLuchador.new()
	add_child(_panel_jugador)
	_panel_jugador.configurar(_jugador, "Rey (tú)")
	_panel_jugador.position = Vector2(14, 12)

	_panel_enemigo = PanelLuchador.new()
	add_child(_panel_enemigo)
	_panel_enemigo.configurar(_enemigo, _enemigo.nombre)
	_panel_enemigo.anchor_left = 1.0
	_panel_enemigo.anchor_right = 1.0
	_panel_enemigo.offset_left = -454
	_panel_enemigo.offset_right = -14
	_panel_enemigo.offset_top = 12
	_panel_enemigo.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var centro := VBoxContainer.new()
	centro.alignment = BoxContainer.ALIGNMENT_BEGIN
	centro.add_theme_constant_override("separation", 6)
	_anclar(centro, 0.5, 0.0, Vector2(-180, 12), Vector2(180, 150))
	add_child(centro)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 10)
	centro.add_child(botones)
	_boton_estado = _boton("Estado", _al_pulsar_estado, Vector2(150, 54), 21)
	botones.add_child(_boton_estado)
	_boton_menu = _boton("Menú", _al_pulsar_menu, Vector2(120, 54), 21)
	botones.add_child(_boton_menu)
	# En el reino no se abandona un combate a la mitad (se puede intentar huir).
	_boton_menu.visible = not _modo_reino
	_etiqueta_turno = Label.new()
	_etiqueta_turno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta_turno.add_theme_font_size_override("font_size", 19)
	_etiqueta_turno.add_theme_color_override("font_color", Estilo.TEXTO_SUAVE)
	centro.add_child(_etiqueta_turno)
	# Próximos turnos según la velocidad de cada uno.
	_fila_turnos = HBoxContainer.new()
	_fila_turnos.alignment = BoxContainer.ALIGNMENT_CENTER
	_fila_turnos.add_theme_constant_override("separation", 4)
	_fila_turnos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_fila_turnos)

	_registro = RichTextLabel.new()
	_registro.bbcode_enabled = true
	_registro.scroll_active = false
	_registro.scroll_following = true
	_registro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_registro.add_theme_font_size_override("normal_font_size", 19)
	_anclar(_registro, 0.5, 1.0, Vector2(-520, -196), Vector2(520, -108))
	add_child(_registro)

	_acciones = HBoxContainer.new()
	_acciones.alignment = BoxContainer.ALIGNMENT_CENTER
	_acciones.add_theme_constant_override("separation", 12)
	_anclar(_acciones, 0.5, 1.0, Vector2(-560, -102), Vector2(560, -12))
	add_child(_acciones)
	_boton_atacar = _boton("Atacar", _al_pulsar_atacar, Vector2(200, 88), 26)
	_boton_defender = _boton("Defender", _al_pulsar_defender, Vector2(200, 88), 26)
	_boton_magia = _boton("Magia", _al_pulsar_magia, Vector2(200, 88), 24)
	_boton_arma = _boton("Cambiar arma", _al_pulsar_arma, Vector2(200, 88), 22)
	_boton_huir = _boton("Huir", _al_pulsar_huir, Vector2(200, 88), 22)
	Estilo.con_franja(_boton_atacar, Color("#ef5350"))
	Estilo.con_franja(_boton_defender, Color("#42a5f5"))
	Estilo.con_franja(_boton_magia, DatosArmas.COLORES_TIPO["arcano"])
	Estilo.con_franja(_boton_arma, Color("#ab47bc"))
	Estilo.con_franja(_boton_huir, Color("#9e9e9e"))
	_boton_magia.visible = _jugador.usa_mana
	for boton in [_boton_atacar, _boton_defender, _boton_magia, _boton_arma, _boton_huir]:
		_acciones.add_child(boton)

	_apuntar = VBoxContainer.new()
	_apuntar.alignment = BoxContainer.ALIGNMENT_END
	_apuntar.add_theme_constant_override("separation", 8)
	_anclar(_apuntar, 0.5, 1.0, Vector2(-620, -214), Vector2(620, -10))
	add_child(_apuntar)
	_titulo_apuntar = Label.new()
	_titulo_apuntar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo_apuntar.add_theme_font_size_override("font_size", 23)
	_titulo_apuntar.add_theme_color_override("font_color", Color("#ffe082"))
	_apuntar.add_child(_titulo_apuntar)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	_apuntar.add_child(fila)
	# "Volver" va a la izquierda: así no queda bajo el dedo nada peligroso (como Huir).
	_boton_volver = _boton("Volver", _al_pulsar_volver, Vector2(150, 70), 22)
	_boton_volver.size_flags_vertical = Control.SIZE_SHRINK_END
	fila.add_child(_boton_volver)
	_opciones = GridContainer.new()
	_opciones.add_theme_constant_override("h_separation", 10)
	_opciones.add_theme_constant_override("v_separation", 10)
	fila.add_child(_opciones)

	_lupa = Panel.new()
	_lupa.clip_contents = true
	_lupa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lupa.size = TAMANO_LUPA
	_lupa.visible = false
	add_child(_lupa)
	_figura_lupa = Figura.new()
	_lupa.add_child(_figura_lupa)
	_figura_lupa.configurar(_enemigo, _datos_rival["aspecto"], false)

	_capa_textos = Control.new()
	_capa_textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_textos.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_capa_textos)


## Ancla un control a un punto de la pantalla (fracciones) con márgenes en píxeles.
func _anclar(control: Control, ancla_x: float, ancla_y: float, desde: Vector2, hasta: Vector2) -> void:
	control.anchor_left = ancla_x
	control.anchor_right = ancla_x
	control.anchor_top = ancla_y
	control.anchor_bottom = ancla_y
	control.offset_left = desde.x
	control.offset_top = desde.y
	control.offset_right = hasta.x
	control.offset_bottom = hasta.y


func _boton(texto: String, al_pulsar: Callable, tamano: Vector2, fuente := 24) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = tamano
	boton.add_theme_font_size_override("font_size", fuente)
	boton.pressed.connect(al_pulsar)
	return boton


func _reubicar() -> void:
	var tamano := get_viewport_rect().size
	var suelo := tamano.y - 208.0
	# Cabe el personaje más alto (orco) entre los paneles superiores y el suelo.
	var escala := clampf((suelo - 142.0) / (PlantillaHumanoide.ALTURA * 1.13), 0.5, 1.0)
	_fondo.ajustar(tamano, suelo)
	_antorchas.ajustar(tamano, suelo)
	_vineta.ajustar(tamano)
	_figura_jugador.position = Vector2(tamano.x * 0.27, suelo)
	_figura_enemigo.position = Vector2(tamano.x * 0.73, suelo)
	_figura_jugador.escala_base = escala * float(DatosRivales.ASPECTO_REY["escala"])
	_figura_enemigo.escala_base = escala * float(_datos_rival["aspecto"]["escala"])
	_lupa.position = Vector2((tamano.x - TAMANO_LUPA.x) / 2.0, 150.0)


# --- Flujo de turnos ---

## Le da el turno a quien llega primero en la barra, salvo que termine el combate.
func _siguiente_turno() -> void:
	if await _comprobar_fin():
		return
	var actor := _orden.siguiente()
	_actualizar_fila_turnos()
	if actor == _jugador:
		_iniciar_turno_jugador()
	else:
		await _turno_del_rival()


func _iniciar_turno_jugador() -> void:
	if _ya_jugo:
		_turno += 1
	_ya_jugo = true
	# La guardia dura hasta el comienzo de su propio turno, aunque lo pierda aturdido.
	_jugador.defendiendo = false
	_jugador.regenerar_mana()
	if _jugador.aturdido:
		_jugador.aturdido = false
		_estado = Estado.ESPERANDO
		_etiqueta_turno.text = "Turno %d · Aturdido" % _turno
		_agregar_mensaje("Estás aturdido y pierdes el turno.")
		_texto_flotante(_figura_jugador, "craneo", "Aturdido", COLOR_AVISO)
		_actualizar_paneles()
		await _pausa(1.0)
		await _siguiente_turno()
		return
	_actualizar_paneles()
	_mostrar_acciones()


## Turno del rival; después sigue quien toque en la barra.
func _turno_del_rival() -> void:
	_estado = Estado.ESPERANDO
	_ocultar_controles()
	_etiqueta_turno.text = "Turno %d · %s" % [_turno, _enemigo.nombre]
	await _pausa(0.45)
	await _actuar_rival()
	_actualizar_paneles()
	await _siguiente_turno()


## Fila con los próximos turnos: "Tú" o "Rival", según la barra de velocidad.
func _actualizar_fila_turnos() -> void:
	for hijo in _fila_turnos.get_children():
		_fila_turnos.remove_child(hijo)
		hijo.queue_free()
	var siguen := _etiqueta_simple("Siguen:", 15, Estilo.TEXTO_SUAVE)
	_fila_turnos.add_child(siguen)
	for luchador in _orden.vista_previa(TURNOS_A_MOSTRAR):
		var es_jugador := luchador == _jugador
		_fila_turnos.add_child(_ficha_turno("Tú" if es_jugador else "Rival",
			COLOR_JUGADOR if es_jugador else COLOR_RIVAL))


func _ficha_turno(texto: String, color: Color) -> PanelContainer:
	var ficha := PanelContainer.new()
	ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caja := Estilo.caja(color.darkened(0.35), color, 8, 1)
	caja.content_margin_left = 6
	caja.content_margin_right = 6
	caja.content_margin_top = 0
	caja.content_margin_bottom = 0
	ficha.add_theme_stylebox_override("panel", caja)
	ficha.add_child(_etiqueta_simple(texto, 15, Color.WHITE))
	return ficha


func _actuar_rival() -> void:
	var nombre := _mayuscula(_enemigo.con_articulo())
	_enemigo.defendiendo = false
	if _enemigo.aturdido:
		_enemigo.aturdido = false
		_agregar_mensaje("%s está aturdido y pierde el turno." % nombre)
		_texto_flotante(_figura_enemigo, "craneo", "Aturdido", COLOR_AVISO)
		await _pausa(0.9)
		return
	var decision := IAEnemigo.decidir(_enemigo, _jugador, _rng)
	match decision["accion"]:
		"recoger":
			_enemigo.empunar()
			var texto := "%s recoge su %s" % [nombre, _nombre_arma(_enemigo.arma)]
			if _enemigo.mano_torpe:
				texto += " con la otra mano"
			_agregar_mensaje(texto + ".")
			_actualizar_paneles()
			await _pausa(0.8)
		"defender":
			_enemigo.defendiendo = true
			_agregar_mensaje("%s se pone en guardia." % nombre)
			_actualizar_paneles()
			await _pausa(0.8)
		"atacar":
			var parte_id: String = decision["parte"]
			_figura_jugador.marcar_objetivo(parte_id)
			await _pausa(0.5)
			_figura_jugador.marcar_objetivo("")
			await _atacar(_enemigo, _jugador, parte_id)


func _atacar(atacante: Luchador, defensor: Luchador, parte_id: String) -> void:
	var figura_atacante := _figura_de(atacante)
	var figura_defensor := _figura_de(defensor)
	var embestida := figura_atacante.embestir()
	await _pausa(0.13)
	var resultado := MotorCombate.resolver_ataque(atacante, defensor, parte_id, _rng, _turno)
	if resultado["empujon"]:
		_orden.retrasar(defensor, DatosHechizos.RETRASO_EMPUJON)
		_actualizar_fila_turnos()
	if resultado["acierto"]:
		figura_defensor.recibir_impacto(parte_id)
		_texto_flotante(figura_defensor, parte_id, "-%d" % resultado["danio"], COLOR_DANIO)
		var avisos := _avisos(resultado)
		for i in avisos.size():
			_texto_flotante(figura_defensor, parte_id, avisos[i], COLOR_AVISO, i + 1)
		Input.vibrate_handheld(45 if defensor.es_jugador else 20)
	else:
		_texto_flotante(figura_defensor, parte_id, "Falla", COLOR_FALLO)
	_agregar_mensaje(_narrar(atacante, defensor, resultado))
	_actualizar_paneles()
	if embestida.is_running():
		await embestida.finished
	if defensor.fuera_de_combate():
		figura_defensor.caer()
	await _pausa(0.45)


## Si alguien quedó fuera de combate, muestra el resultado y devuelve true.
func _comprobar_fin() -> bool:
	if not (_jugador.fuera_de_combate() or _enemigo.fuera_de_combate()):
		return false
	_estado = Estado.FIN
	_cerrar_ventana()
	_ocultar_controles()
	# Hasta que aparezca el resultado no se puede salir ni abrir el estado.
	_boton_menu.disabled = true
	_boton_estado.disabled = true
	await _pausa(1.1)
	_mostrar_fin("victoria" if _enemigo.fuera_de_combate() else "derrota")
	return true


# --- Acciones del jugador ---

func _al_pulsar_atacar() -> void:
	if _estado == Estado.ACCIONES and _entrada_libre():
		_mostrar_zonas()


func _mostrar_zonas() -> void:
	_estado = Estado.ZONA
	_zona = ""
	_lupa.visible = false
	_figura_enemigo.modo = Figura.Modo.ZONAS
	_figura_enemigo.zona_activa = ""
	_titulo_apuntar.text = "Elige una zona %s (o tócala en su cuerpo)" % _enemigo.de_nombre()
	if _hechizo_id != "":
		_titulo_apuntar.text = "%s: elige una zona %s" % [DatosHechizos.hechizo(_hechizo_id)["nombre"], _enemigo.de_nombre()]
	_limpiar_opciones()
	_opciones.columns = 3
	for zona_id in ORDEN_BOTONES_ZONA:
		var prob := MotorCombate.prob_acierto_zona(_jugador, _enemigo, zona_id)
		var texto := "%s\n%d%% de acierto" % [DatosCuerpo.ZONAS[zona_id]["nombre"], roundi(prob * 100.0)]
		var boton := _boton(texto, _al_elegir_zona.bind(zona_id), Vector2(236, 72), 20)
		Estilo.con_franja(boton, Figura.COLORES_ZONA[zona_id])
		boton.mouse_entered.connect(_resaltar_zona.bind(zona_id))
		_opciones.add_child(boton)
	_boton_volver.text = "Cancelar"
	_mostrar_panel_apuntar()
	_bloquear_entrada()


func _al_elegir_zona(zona_id: String) -> void:
	if (_estado != Estado.ZONA and _estado != Estado.PARTE) or not _entrada_libre():
		return
	_estado = Estado.PARTE
	_zona = zona_id
	_figura_enemigo.modo = Figura.Modo.PARTES
	_figura_enemigo.zona_activa = zona_id
	_figura_enemigo.parte_activa = ""
	_titulo_apuntar.text = "%s: elige una parte" % DatosCuerpo.ZONAS[zona_id]["nombre"]
	_limpiar_opciones()
	var partes := DatosCuerpo.partes_de(zona_id)
	_opciones.columns = partes.size()
	for i in partes.size():
		var parte_id: String = partes[i]
		var prob := MotorCombate.prob_acierto(_jugador, _enemigo, parte_id)
		var rango := MotorCombate.rango_danio(_jugador, _enemigo, parte_id)
		var nombre: String = DatosCuerpo.PARTES[parte_id]["corto"]
		if _enemigo.nivel(parte_id) >= 3:
			nombre += " (%s)" % _enemigo.estado(parte_id).to_lower()
		var danio := "%d" % rango.x if rango.x == rango.y else "%d–%d" % [rango.x, rango.y]
		var texto := "%s\n%d%% · %s de daño" % [nombre, roundi(prob * 100.0), danio]
		var tactica := _texto_tactico(parte_id)
		if tactica != "":
			texto += "\n" + tactica
		var boton := _boton(texto, _al_elegir_parte.bind(parte_id), Vector2(222, 96), 19)
		Estilo.con_franja(boton, Figura.COLORES_PARTE[i % Figura.COLORES_PARTE.size()])
		boton.mouse_entered.connect(_resaltar_parte.bind(parte_id))
		_opciones.add_child(boton)
	_boton_volver.text = "Volver"
	_mostrar_panel_apuntar()
	_mostrar_lupa(zona_id)
	_bloquear_entrada()


## En brazos y piernas: cuántos golpes faltan para inutilizarlos (así se ve para
## qué sirve atacarlos aunque quiten poca vida).
func _texto_tactico(parte_id: String) -> String:
	var zona_id := DatosCuerpo.zona_de(parte_id)
	if DatosCuerpo.ZONAS[zona_id]["defensa"] == "cubierta":
		return ""
	if not _enemigo.extremidad_util(zona_id):
		return "Pierna ya inutilizada" if zona_id.begins_with("pierna_") else "Brazo ya inutilizado"
	var golpes := MotorCombate.golpes_para_inutilizar(_jugador, _enemigo, parte_id)
	if golpes.x == golpes.y:
		return "Inutilizar: %d %s" % [golpes.x, "golpe" if golpes.x == 1 else "golpes"]
	return "Inutilizar: %d–%d golpes" % [golpes.x, golpes.y]


## Amplía la zona en la lupa, centrada y tan grande como quepa.
func _mostrar_lupa(zona_id: String) -> void:
	var caja := _figura_lupa.caja_zona(zona_id)
	var escala := clampf(minf(TAMANO_LUPA.x * 0.8 / maxf(caja.size.x, 1.0),
		TAMANO_LUPA.y * 0.8 / maxf(caja.size.y, 1.0)), 1.2, 3.2)
	_figura_lupa.escala_base = escala
	_figura_lupa.position = TAMANO_LUPA / 2.0 - caja.get_center() * escala
	_figura_lupa.modo = Figura.Modo.PARTES
	_figura_lupa.zona_activa = zona_id
	_figura_lupa.parte_activa = ""
	_lupa.visible = true


func _al_elegir_parte(parte_id: String) -> void:
	if _estado != Estado.PARTE or not _entrada_libre():
		return
	_estado = Estado.ESPERANDO
	_figura_enemigo.modo = Figura.Modo.NORMAL
	_ocultar_controles()
	if _hechizo_id != "":
		_jugador.mana -= float(DatosHechizos.hechizo(_hechizo_id)["coste"])
	await _atacar(_jugador, _enemigo, parte_id)
	_dejar_hechizo()
	await _siguiente_turno()


func _resaltar_zona(zona_id: String) -> void:
	if _estado == Estado.ZONA:
		_figura_enemigo.zona_activa = zona_id


func _resaltar_parte(parte_id: String) -> void:
	if _estado == Estado.PARTE:
		_figura_enemigo.parte_activa = parte_id
		_figura_lupa.parte_activa = parte_id


func _al_pulsar_defender() -> void:
	if _estado != Estado.ACCIONES or not _entrada_libre():
		return
	_estado = Estado.ESPERANDO
	_ocultar_controles()
	_jugador.defendiendo = true
	var recibe := roundi(MotorCombate.factor_guardia(_enemigo, _jugador) * 100.0)
	_agregar_mensaje("Te pones en guardia: te defiendes mejor y recibes el %d%% del daño." % recibe)
	_actualizar_paneles()
	await _pausa(0.6)
	await _siguiente_turno()


func _al_pulsar_arma() -> void:
	if _estado != Estado.ACCIONES or not _entrada_libre():
		return
	if not _jugador.desarmado:
		_mostrar_armas()
		return
	_estado = Estado.ESPERANDO
	_ocultar_controles()
	if _jugador.empunar():
		var texto := "Recoges tu %s" % _nombre_arma(_jugador.arma)
		if _jugador.mano_torpe:
			texto += " con la otra mano (mano torpe: menos precisión y daño)"
		_agregar_mensaje(texto + ".")
	_actualizar_paneles()
	await _pausa(0.7)
	await _siguiente_turno()


func _mostrar_armas() -> void:
	_estado = Estado.ARMA
	_titulo_apuntar.text = "Cambiar de arma (usa tu turno)"
	_limpiar_opciones()
	_opciones.columns = DatosArmas.ELEGIBLES.size()
	for arma_id in DatosArmas.ELEGIBLES:
		var arma: Dictionary = DatosArmas.ARMAS[arma_id]
		var texto := "%s\n%s" % [arma["nombre"], DatosArmas.tipo(arma["tipo"])["nombre"]]
		var boton := _boton(texto, _al_elegir_arma.bind(arma_id), Vector2(236, 72), 20)
		boton.disabled = arma_id == _jugador.arma
		Estilo.con_franja(boton, DatosArmas.COLORES_TIPO[arma["tipo"]])
		_opciones.add_child(boton)
	_boton_volver.text = "Volver"
	_mostrar_panel_apuntar()
	_bloquear_entrada()


func _al_elegir_arma(arma_id: String) -> void:
	if _estado != Estado.ARMA or not _entrada_libre():
		return
	_estado = Estado.ESPERANDO
	_ocultar_controles()
	_jugador.arma = arma_id
	var texto := "Cambias a la %s" % _nombre_arma(arma_id)
	if not _jugador.empunar():
		_jugador.desarmado = true
		texto = "No puedes sostener la %s" % _nombre_arma(arma_id)
	elif _jugador.mano_torpe:
		texto += " con la otra mano"
	_agregar_mensaje(texto + ".")
	_actualizar_paneles()
	await _pausa(0.7)
	await _siguiente_turno()


func _al_pulsar_huir() -> void:
	if _estado != Estado.ACCIONES or not _entrada_libre():
		return
	_estado = Estado.ESPERANDO
	_ocultar_controles()
	if _rng.randf() < MotorCombate.prob_huir(_jugador, _enemigo):
		_agregar_mensaje("¡Logras escapar!")
		var tween := create_tween()
		tween.tween_property(_figura_jugador, "position:x", -200.0, 0.8).set_ease(Tween.EASE_IN)
		await tween.finished
		_figura_jugador.visible = false
		_mostrar_fin("huida")
	else:
		_agregar_mensaje("Intentas huir, pero %s te corta el paso." % _enemigo.con_articulo())
		await _pausa(0.7)
		await _siguiente_turno()


# --- Magia ---

func _al_pulsar_magia() -> void:
	if _estado == Estado.ACCIONES and _entrada_libre():
		_mostrar_hechizos()


func _mostrar_hechizos() -> void:
	_estado = Estado.MAGIA
	_dejar_hechizo()
	_titulo_apuntar.text = "Magia · tienes %d de maná" % floori(_jugador.mana)
	_limpiar_opciones()
	_opciones.columns = DatosHechizos.ORDEN.size()
	for hechizo_id in DatosHechizos.ORDEN:
		var datos := DatosHechizos.hechizo(hechizo_id)
		var detalle: String = datos["descripcion"]
		if hechizo_id == "curacion":
			detalle = "Recuperas %d de vida." % DatosHechizos.cura(_jugador)
		var texto := "%s · %d de maná\n%s" % [datos["nombre"], roundi(float(datos["coste"])), detalle]
		var boton := _boton(texto, _al_elegir_hechizo.bind(hechizo_id), Vector2(300, 96), 18)
		boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boton.disabled = not DatosHechizos.puede_lanzar(_jugador, hechizo_id)
		Estilo.con_franja(boton, DatosArmas.COLORES_TIPO["arcano"])
		_opciones.add_child(boton)
	_boton_volver.text = "Volver"
	_mostrar_panel_apuntar()
	_bloquear_entrada()


func _al_elegir_hechizo(hechizo_id: String) -> void:
	if _estado != Estado.MAGIA or not _entrada_libre() or not DatosHechizos.puede_lanzar(_jugador, hechizo_id):
		return
	var datos := DatosHechizos.hechizo(hechizo_id)
	if datos["objetivo"] == "parte":
		# Se apunta como un ataque, pero con los datos del hechizo.
		_hechizo_id = hechizo_id
		_jugador.hechizo = DatosHechizos.como_arma(hechizo_id)
		_mostrar_zonas()
		return
	_estado = Estado.ESPERANDO
	_ocultar_controles()
	_jugador.mana -= float(datos["coste"])
	match String(datos["objetivo"]):
		"propio":
			var cura := mini(DatosHechizos.cura(_jugador), _jugador.vida_max - _jugador.vida)
			_jugador.vida += cura
			_agregar_mensaje("Lanzas %s: recuperas %d de vida." % [datos["nombre"], cura])
			_texto_flotante(_figura_jugador, "torax_der", "+%d" % cura, COLOR_CURA)
		"rival":
			_orden.retrasar(_enemigo, DatosHechizos.RETRASO_RALENTIZAR)
			_actualizar_fila_turnos()
			_agregar_mensaje("Lanzas %s: %s pierde tiempo." % [datos["nombre"], _enemigo.con_articulo()])
			_texto_flotante(_figura_enemigo, "craneo", "Ralentizado", COLOR_AVISO)
	_actualizar_paneles()
	await _pausa(0.8)
	await _siguiente_turno()


## Deja de apuntar un hechizo: el rey vuelve a pelear con su arma.
func _dejar_hechizo() -> void:
	_hechizo_id = ""
	_jugador.hechizo = {}


# --- Entrada: tocar el cuerpo del rival y botón "atrás" ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_volver_atras()
		return
	if not (event is InputEventScreenTouch):
		return
	var toque := event as InputEventScreenTouch
	# Solo el primer dedo, al levantarlo, y nunca un toque cancelado por el sistema.
	if toque.pressed or toque.index != 0 or toque.canceled:
		return
	if _estado != Estado.ZONA and _estado != Estado.PARTE:
		return
	var punto := toque.position
	if _apuntar.get_global_rect().has_point(punto):
		return
	if _lupa.visible and _lupa.get_global_rect().has_point(punto):
		var en_lupa := _figura_lupa.parte_cercana(punto, _zona, MARGEN_TOQUE)
		if en_lupa != "":
			get_viewport().set_input_as_handled()
			_al_elegir_parte(en_lupa)
		return
	if _estado == Estado.PARTE:
		var cercana := _figura_enemigo.parte_cercana(punto, _zona, MARGEN_TOQUE)
		if cercana != "":
			get_viewport().set_input_as_handled()
			_al_elegir_parte(cercana)
			return
	var parte_id := _figura_enemigo.parte_en(punto)
	if parte_id == "":
		return
	get_viewport().set_input_as_handled()
	_al_elegir_zona(DatosCuerpo.zona_de(parte_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_volver_atras()


func _volver_atras() -> void:
	if not _entrada_libre():
		return
	if _ventana != null:
		if _estado == Estado.FIN:
			_ir_a_preparacion()
		else:
			_cerrar_ventana()
		return
	match _estado:
		Estado.PARTE:
			_mostrar_zonas()
		Estado.ZONA:
			if _hechizo_id != "":
				_mostrar_hechizos()
			else:
				_mostrar_acciones()
		Estado.ARMA, Estado.MAGIA:
			_mostrar_acciones()
		Estado.ACCIONES:
			_ir_a_preparacion()


func _ir_a_preparacion() -> void:
	# Durante las animaciones no se sale, para no cortar un turno a la mitad.
	if _estado == Estado.ESPERANDO:
		return
	if _modo_reino:
		# En el reino solo se sale al terminar, de vuelta al lugar del combate.
		if _estado == Estado.FIN and _resultado != "":
			_volver_al_reino()
		return
	get_tree().change_scene_to_file.call_deferred(ESCENA_PREPARACION)


## Deja el resultado en Juego.combate y vuelve a la mazmorra o zona.
func _volver_al_reino() -> void:
	Juego.combate["resultado"] = _resultado
	get_tree().change_scene_to_file.call_deferred(Juego.combate["escena"])


# --- Botones con pausa entre menús ---

func _bloquear_entrada() -> void:
	_bloqueo = PAUSA_ENTRE_MENUS


func _entrada_libre() -> bool:
	return _bloqueo <= 0.0


func _al_pulsar_volver() -> void:
	_volver_atras()


func _al_pulsar_menu() -> void:
	if _entrada_libre():
		_ir_a_preparacion()


func _al_pulsar_estado() -> void:
	if _estado != Estado.FIN and _entrada_libre():
		_mostrar_estado()


func _al_pulsar_cerrar() -> void:
	if _entrada_libre():
		_cerrar_ventana()


func _al_pulsar_revancha() -> void:
	if _entrada_libre():
		get_tree().reload_current_scene.call_deferred()


# --- Interfaz ---

func _mostrar_acciones() -> void:
	_estado = Estado.ACCIONES
	_dejar_hechizo()
	_figura_enemigo.modo = Figura.Modo.NORMAL
	_apuntar.visible = false
	_lupa.visible = false
	_registro.visible = true
	_acciones.visible = true
	_boton_atacar.text = "Atacar" if not _jugador.desarmado \
		else "Atacar\n(%s)" % _nombre_arma(_jugador.arma_actual())
	if _jugador.sin_mana_para_baston():
		_boton_atacar.text = "Atacar\n(sin maná)"
	if _jugador.desarmado:
		_boton_arma.text = "Recoger arma"
		_boton_arma.disabled = not (_jugador.puede_empunar("der") or _jugador.puede_empunar("izq"))
	else:
		_boton_arma.text = "Cambiar arma"
		# En el reino el rey pelea con el arma equipada (se cambia en el Inventario).
		_boton_arma.disabled = _modo_reino
	_boton_huir.text = "Huir\n%d%%" % roundi(MotorCombate.prob_huir(_jugador, _enemigo) * 100.0)
	_etiqueta_turno.text = "Turno %d · Te toca" % _turno
	_boton_menu.disabled = false
	_boton_estado.disabled = false
	_bloquear_entrada()


func _mostrar_panel_apuntar() -> void:
	_acciones.visible = false
	_registro.visible = false
	_apuntar.visible = true


func _ocultar_controles() -> void:
	_acciones.visible = false
	_apuntar.visible = false
	_lupa.visible = false
	_registro.visible = true
	_boton_menu.disabled = _estado == Estado.ESPERANDO
	_figura_enemigo.modo = Figura.Modo.NORMAL


func _limpiar_opciones() -> void:
	for hijo in _opciones.get_children():
		_opciones.remove_child(hijo)
		hijo.queue_free()


func _actualizar_paneles() -> void:
	_panel_jugador.actualizar()
	_panel_enemigo.actualizar()
	# Si la ventana de estado está abierta, se rehace para que no muestre datos viejos.
	if _ventana_es_estado:
		_mostrar_estado()


func _figura_de(luchador: Luchador) -> Figura:
	return _figura_jugador if luchador == _jugador else _figura_enemigo


func _agregar_mensaje(texto: String) -> void:
	_mensajes.append(texto)
	# Salen los más viejos hasta que quepan: un mensaje largo ocupa dos líneas.
	while _mensajes.size() > 1 and _lineas_del_registro() > LINEAS_REGISTRO:
		_mensajes.pop_front()
	var lineas: PackedStringArray = []
	for i in _mensajes.size():
		var reciente := i == _mensajes.size() - 1
		lineas.append("[color=%s]%s[/color]" % ["#ffffff" if reciente else "#8f97bd", _mensajes[i]])
	_registro.text = "[center]%s[/center]" % "\n".join(lineas)


## Líneas que ocupan los mensajes en el registro, según su ancho.
func _lineas_del_registro() -> int:
	var fuente := _registro.get_theme_font("normal_font")
	var tamano := _registro.get_theme_font_size("normal_font_size")
	# Un poco menos que el ancho real: el ajuste por palabras deja huecos al final.
	var ancho := maxf(_registro.size.x, 1.0) * 0.92
	var lineas := 0
	for mensaje in _mensajes:
		var plano := _etiquetas_bbcode.sub(mensaje, "", true)
		lineas += maxi(1, ceili(fuente.get_string_size(plano, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x / ancho))
	return lineas


## Texto que sube y se desvanece sobre una parte del cuerpo ("-12", "Falla"...).
func _texto_flotante(figura: Figura, parte_id: String, texto: String, color: Color, fila := 0) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_size_override("font_size", 34 if fila == 0 else 26)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	etiqueta.add_theme_constant_override("outline_size", 8)
	_capa_textos.add_child(etiqueta)
	var ancho := etiqueta.get_minimum_size().x
	var inicio := figura.posicion_global_de(parte_id) - Vector2(ancho / 2.0, 24.0 + fila * 32.0)
	etiqueta.position = inicio
	var tween := etiqueta.create_tween()
	tween.set_parallel(true)
	tween.tween_property(etiqueta, "position:y", inicio.y - 70.0, 1.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(etiqueta, "modulate:a", 0.0, 0.5).set_delay(0.7)
	tween.chain().tween_callback(etiqueta.queue_free)


func _pausa(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


# --- Narración ---

func _narrar(atacante: Luchador, defensor: Luchador, r: Dictionary) -> String:
	var parte_id: String = r["parte"]
	var arma_id: String = r["arma"]
	var texto := ""
	if atacante.es_jugador:
		if not r["acierto"]:
			return "Fallas tu ataque %s %s." % [DatosCuerpo.a_parte(parte_id), defensor.de_nombre()]
		texto = "Golpeas %s en %s %s: %s %s." % [defensor.a_nombre(), DatosCuerpo.con_articulo(parte_id),
			_con_arma(arma_id, "tu"), String(r["herida"]).to_lower(), _danio(r["danio"])]
	else:
		var nombre := _mayuscula(atacante.con_articulo())
		if not r["acierto"]:
			return "%s falla su ataque a %s." % [nombre, DatosCuerpo.posesivo(parte_id, "tu")]
		texto = "%s te golpea en %s %s: %s %s." % [nombre, DatosCuerpo.con_articulo(parte_id),
			_con_arma(arma_id, "su"), String(r["herida"]).to_lower(), _danio(r["danio"])]
	var tu := defensor.es_jugador
	if r["inutilizada"]:
		var genero := "inutilizada" if DatosCuerpo.PARTES[parte_id]["articulo"] == "la" else "inutilizado"
		texto += " %s queda %s." % [_mayuscula(DatosCuerpo.posesivo(parte_id, "tu" if tu else "su")), genero]
	if r["desarme"]:
		texto += " ¡Sueltas tu %s!" % _nombre_arma(defensor.arma) if tu \
			else " ¡Suelta su %s!" % _nombre_arma(defensor.arma)
	if r["expuesto"]:
		texto += " Ahora tu cabeza y tu torso están más expuestos." if tu \
			else " Ahora su cabeza y su torso están más expuestos."
	if r["critico"]:
		texto += " ¡Golpe crítico!"
	if r["empujon"]:
		texto += " El golpe te hace retroceder: pierdes tiempo." if tu \
			else " El golpe lo hace retroceder: pierde tiempo."
	if r["aturdido"]:
		texto += " ¡Quedas aturdido!" if tu else " ¡Queda aturdido!"
	if r["desmayo"]:
		texto += " ¡Pierdes el conocimiento!" if tu else " ¡Se desploma inconsciente!"
	elif defensor.vida <= 0:
		texto += " Caes derrotado." if tu else " Cae derrotado."
	return texto


func _avisos(r: Dictionary) -> Array[String]:
	var avisos: Array[String] = []
	if r["critico"]:
		avisos.append("¡Crítico!")
	if r["empujon"]:
		avisos.append("¡Empujado!")
	if r["fractura"]:
		avisos.append("¡Fractura!")
	if r["inutilizada"]:
		var femenino: bool = DatosCuerpo.PARTES[r["parte"]]["articulo"] == "la"
		avisos.append("¡Inutilizada!" if femenino else "¡Inutilizado!")
	if r["desarme"]:
		avisos.append("¡Desarmado!")
	if r["aturdido"]:
		avisos.append("¡Aturdido!")
	if r["desmayo"]:
		avisos.append("¡Inconsciente!")
	return avisos


func _con_arma(arma_id: String, posesivo: String) -> String:
	if arma_id == "punos":
		return "con los puños"
	if arma_id == "patadas":
		return "a patadas"
	return "con %s %s" % [posesivo, _nombre_arma(arma_id)]


func _nombre_arma(arma_id: String) -> String:
	if DatosHechizos.HECHIZOS.has(arma_id):
		return String(DatosHechizos.HECHIZOS[arma_id]["nombre"]).to_lower()
	return String(DatosArmas.ARMAS[arma_id]["nombre"]).to_lower()


func _danio(cantidad: int) -> String:
	return "[color=#ff8a80](−%d)[/color]" % cantidad


func _mayuscula(texto: String) -> String:
	if texto.is_empty():
		return texto
	return texto[0].to_upper() + texto.substr(1)


# --- Ventanas: estado y fin del combate ---

## Crea una ventana centrada sobre un fondo oscuro. Devuelve su columna de contenido.
func _abrir_ventana(tamano: Vector2) -> VBoxContainer:
	_cerrar_ventana()
	var capa := ColorRect.new()
	capa.color = Color(0, 0, 0, 0.6)
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(capa)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Estilo.caja(Color("#0c0e1c"), Color(1, 1, 1, 0.18), 18))
	_anclar(panel, 0.5, 0.5, -tamano / 2.0, tamano / 2.0)
	capa.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)
	_ventana = capa
	_bloquear_entrada()
	return columna


func _cerrar_ventana() -> void:
	_ventana_es_estado = false
	if _ventana != null:
		_ventana.queue_free()
		_ventana = null
		_bloquear_entrada()


func _mostrar_estado() -> void:
	if _estado == Estado.FIN:
		return
	var columna := _abrir_ventana(Vector2(1180, 640))
	_ventana_es_estado = true
	var titulo := _etiqueta_simple("Estado de los combatientes", 30, Color("#ffe082"))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(titulo)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 30)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(fila)
	fila.add_child(_columna_estado(_jugador, "Rey (tú)"))
	fila.add_child(_columna_estado(_enemigo, _enemigo.nombre))
	var reglas := _etiqueta_simple("Reglas provisionales: cada brazo y pierna útil cubre la cabeza y el torso "
		+ "(cobertura); al inutilizarlo es más fácil acertarles. Brazos y piernas quitan poca vida pero se "
		+ "inutilizan rápido; sin brazos útiles se pelea a patadas. La visión afecta la precisión; las piernas, "
		+ "la esquiva y la huida; el brazo del arma, el daño. La mano del arma puede soltarla; el cráneo puede "
		+ "aturdir o desmayar. La velocidad decide quién actúa: arriba se ven los próximos turnos, y el más "
		+ "rápido puede actuar dos veces seguidas. El sangrado, el dolor y las infecciones vendrán después.", 16, Estilo.TEXTO_SUAVE)
	reglas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reglas.custom_minimum_size = Vector2(1100, 0)
	columna.add_child(reglas)
	var cerrar := _boton("Cerrar", _al_pulsar_cerrar, Vector2(200, 62), 22)
	cerrar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	columna.add_child(cerrar)


## Fila "nombre ▬▬▬ 80%" de la ventana de estado.
func _fila_barra(texto: String, valor: float) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	var nombre := _etiqueta_simple(texto, 18, Estilo.TEXTO)
	nombre.custom_minimum_size = Vector2(140, 0)
	fila.add_child(nombre)
	var barra := Barra.new()
	barra.custom_minimum_size = Vector2(250, 16)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.valor = valor
	fila.add_child(barra)
	fila.add_child(_etiqueta_simple("%d%%" % roundi(valor * 100.0), 18, Barra.color_para(valor)))
	return fila


func _columna_estado(luchador: Luchador, titulo: String) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 5)
	columna.add_child(_etiqueta_simple("%s · %d / %d de vida" % [titulo, luchador.vida, luchador.vida_max], 24, Color.WHITE))
	for funcion_id in DatosCuerpo.FUNCIONES:
		columna.add_child(_fila_barra(DatosCuerpo.NOMBRES_FUNCION[funcion_id], luchador.funcion(funcion_id)))
	columna.add_child(_fila_barra("Cobertura", luchador.cobertura() / Luchador.cobertura_maxima()))
	columna.add_child(_etiqueta_simple("Partes heridas", 20, Color("#ffe082")))
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	var desplazable := ScrollContainer.new()
	desplazable.custom_minimum_size = Vector2(0, 140)
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.add_child(lista)
	columna.add_child(desplazable)
	var alguna := false
	for parte_id in PlantillaHumanoide.ORDEN:
		var nivel := luchador.nivel(parte_id)
		if nivel == 0:
			continue
		alguna = true
		var tipos: PackedStringArray = []
		var conteo := luchador.heridas_de(parte_id)
		for tipo in conteo:
			tipos.append("%s ×%d" % [tipo, conteo[tipo]] if conteo[tipo] > 1 else String(tipo))
		if luchador.fracturas.has(parte_id) and not conteo.has("Fractura"):
			tipos.append("Fractura")
		var texto := "• %s: %s (%s)" % [DatosCuerpo.PARTES[parte_id]["nombre"], luchador.estado(parte_id).to_lower(), ", ".join(tipos)]
		lista.add_child(_etiqueta_simple(texto, 17, Barra.color_para(1.0 - nivel / 4.0)))
	if not alguna:
		lista.add_child(_etiqueta_simple("Sin heridas.", 17, Estilo.TEXTO_SUAVE))
	return columna


func _mostrar_fin(resultado: String) -> void:
	_estado = Estado.FIN
	_resultado = resultado
	_ocultar_controles()
	_boton_menu.disabled = false
	var titulo := ""
	var color := Color.WHITE
	var motivo := ""
	match resultado:
		"victoria":
			titulo = "¡Victoria!"
			color = Color("#ffd54f")
			motivo = "%s quedó inconsciente." if _enemigo.desmayado else "%s ya no puede seguir."
			motivo = motivo % _mayuscula(_enemigo.con_articulo())
		"derrota":
			titulo = "Derrota"
			color = Color("#ef5350")
			motivo = "Perdiste el conocimiento." if _jugador.desmayado else "Te quedaste sin vida."
		_:
			titulo = "Escapaste"
			color = Color("#90caf9")
			motivo = "Huiste del combate."
	_etiqueta_turno.text = titulo
	var columna := _abrir_ventana(Vector2(660, 430))
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	for linea in [[titulo, 56, color], [motivo, 24, Estilo.TEXTO]]:
		var etiqueta := _etiqueta_simple(linea[0], linea[1], linea[2])
		etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columna.add_child(etiqueta)
	var precision := 0 if _jugador.ataques == 0 else roundi(100.0 * _jugador.aciertos / _jugador.ataques)
	var resumen := _etiqueta_simple("Turnos: %d   ·   Daño causado: %d   ·   Daño recibido: %d\nAciertos: %d de %d (%d%%)" % [
		_turno, _jugador.danio_causado, _jugador.danio_recibido, _jugador.aciertos, _jugador.ataques, precision],
		19, Estilo.TEXTO_SUAVE)
	resumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(resumen)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 16)
	columna.add_child(botones)
	if _modo_reino:
		botones.add_child(_boton("Continuar", _al_pulsar_menu, Vector2(260, 72), 24))
		return
	botones.add_child(_boton("Revancha", _al_pulsar_revancha, Vector2(230, 72), 24))
	botones.add_child(_boton("Preparación", _al_pulsar_menu, Vector2(230, 72), 24))


func _etiqueta_simple(texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta
