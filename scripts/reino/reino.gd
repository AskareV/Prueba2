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
## Ventana del lugar elegido en el mapa, o null.
var _ventana_lugar: Control
var _oficio := "audiencias"
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
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_aviso.clip_text = true
	franja.add_child(_aviso)
	_actualizar_franja()


func _actualizar_franja() -> void:
	_etiqueta_semana.text = "Semana %d" % Juego.semana
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

func _crear_rey() -> void:
	var figura := Figura.new()
	figura.configurar(Juego.crear_rey(), DatosRivales.ASPECTO_REY, true)
	figura.escala_base = 1.0
	figura.position = Vector2(300, 520)
	_contenido.add_child(figura)
	var panel := UIReino.panel()
	panel.position = Vector2(560, 40)
	panel.custom_minimum_size = Vector2(660, 0)
	_contenido.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	panel.add_child(columna)
	columna.add_child(UIReino.etiqueta("El Rey", 34, UIReino.COLOR_TITULO))
	columna.add_child(UIReino.etiqueta("Diestro" if Juego.diestro else "Zurdo", 22))
	columna.add_child(UIReino.parrafo("Características: por definir. Aquí irán las del rey.", 620, 20))


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
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 8)
	rejilla.add_theme_constant_override("v_separation", 8)
	desplazable.add_child(rejilla)
	if Juego.inventario.is_empty():
		rejilla.add_child(UIReino.parrafo("Vacía. El botín de mazmorras y zonas aparece aquí.", 400, 18))
	for objeto in Juego.inventario:
		rejilla.add_child(UIReino.boton_objeto(objeto, _al_elegir_mochila.bind(objeto["id"]), Vector2(212, 74)))


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
	for linea in DatosBotin.describir(objeto):
		columna.add_child(UIReino.parrafo(linea, 330, 18, Estilo.TEXTO))
	if _seleccion.has("ranura"):
		var quitar := UIReino.boton("Quitar", _al_quitar, Vector2(330, 62), 22)
		quitar.disabled = _seleccion["ranura"] == "arma"
		columna.add_child(quitar)
		if quitar.disabled:
			columna.add_child(UIReino.parrafo("El arma se cambia equipando otra.", 330, 16))
		return
	columna.add_child(UIReino.boton("Equipar", _al_equipar, Vector2(330, 62), 22))
	var texto_venta := "Vender por %d de oro" % objeto["precio"]
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
		var boton := UIReino.boton("%s\n%d oro por día · dominio %d%%" % [oficio["nombre"], oficio["pago"], roundi(dominio)],
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
	columna.add_child(UIReino.parrafo("Pago por cada día que sale bien: %d de oro." % oficio["pago"], 530, 18))
	columna.add_child(UIReino.parrafo("Probabilidad de que un día salga bien: %d%% (sube con el dominio, ahora %d de 100)." % [
		roundi(DatosTrabajos.prob_exito(dominio) * 100.0), roundi(dominio)], 530, 18))
	columna.add_child(UIReino.parrafo("Estrés de la semana: +%d. Si los siete días salen bien, cobras %d de oro extra." % [
		roundi(float(oficio["estres"]) * DatosTrabajos.DIAS), int(oficio["pago"]) * DatosTrabajos.BONO_SEMANA_PERFECTA], 530, 18))
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
		var texto := "Día %d: salió bien (+%d de oro)" % [i + 1, oficio["pago"]] if dias[i] \
			else "Día %d: salió mal (sin pago)" % (i + 1)
		columna.add_child(UIReino.etiqueta(texto, 19, Color("#a5d6a7") if dias[i] else Color("#ef9a9a")))
	await get_tree().create_timer(PAUSA_DIA).timeout
	var resumen := "Ganaste %d de oro" % resultado["oro"]
	if int(resultado["bono"]) > 0:
		resumen += " (incluye %d por la semana perfecta)" % resultado["bono"]
	columna.add_child(UIReino.parrafo("%s. Estrés +%d." % [resumen, roundi(resultado["estres"])], 530, 19, Estilo.TEXTO))
	columna.add_child(UIReino.boton("Listo", _al_terminar_trabajo, Vector2(530, 64), 22))
	_actualizar_franja()
	_avisar("Terminó la semana %d. Empieza la semana %d." % [semana, Juego.semana])
	_ocupado = false


func _al_terminar_trabajo() -> void:
	_mostrar_pestana("trabajo")
