extends Control
## Salida a una zona (banderín rojo del mapa): siete casillas, "Día 1" a
## "Día 7". Cada toque revela el suceso del día siguiente: combate, oro, un
## objeto, un día tranquilo, descanso o una trampa. Cada día de marcha suma
## estrés (Cardio lo baja); con 70 el rey vuelve a casa, aunque ese día tocara
## un combate. Al volver termina la semana.

const ESCENA_REINO := "res://escenas/reino.tscn"
const ESCENA_COMBATE := "res://escenas/combate.tscn"
const ESCENA_PROPIA := "res://escenas/expedicion.tscn"
## Milisegundos tras abrir la pantalla en que "atrás" se ignora: un doble
## "atrás" en el resultado de un combate no debe terminar la salida.
const ESPERA_ATRAS_MS := 800

var _datos: Dictionary
var _barra_estres: Barra
var _barra_vida: Barra
var _boton_objetos: Button
var _lista_objetos: PanelContainer
var _salud: Label
var _botones_dia: Array[Button] = []
var _descripcion: Label
var _boton_volver: Button
var _saliendo := false
var _abierto_en := 0


func _ready() -> void:
	_abierto_en = Time.get_ticks_msec()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Juego.expedicion.is_empty():
		_volver_al_reino()
		return
	_datos = DatosAventura.ZONAS[Juego.expedicion["id"]]
	if not Juego.expedicion.has("dias"):
		Juego.expedicion["dias"] = []
	UIReino.fondo(self)
	var area := UIReino.area_centrada(self)
	_crear_interfaz(area)
	_procesar_combate()
	_actualizar(true)
	UIReino.bloquear_toques(self)


func _crear_interfaz(area: Control) -> void:
	var cabecera := HBoxContainer.new()
	cabecera.position = Vector2(30, 20)
	cabecera.add_theme_constant_override("separation", 18)
	area.add_child(cabecera)
	cabecera.add_child(UIReino.etiqueta("Estrés", 22))
	_barra_estres = UIReino.barra_estres()
	_barra_estres.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(_barra_estres)
	cabecera.add_child(UIReino.etiqueta("Vida", 22))
	_barra_vida = UIReino.barra_vida()
	_barra_vida.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(_barra_vida)
	cabecera.add_child(UIReino.etiqueta("%s · %s" % [_datos["nombre"], _datos["dificultad"]], 28,
		UIReino.COLOR_TITULO))
	# Siete días: cinco arriba y dos abajo, como en el juego original.
	for i in DatosAventura.DIAS_ZONA:
		var fila := i / 5
		var columna := i % 5
		var boton := UIReino.boton("Día %d" % (i + 1), _al_pulsar_dia.bind(i), Vector2(220, 150), 22)
		boton.position = Vector2(30 + columna * 240, 90 + fila * 170)
		boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		area.add_child(boton)
		_botones_dia.append(boton)
	var panel := UIReino.panel()
	panel.position = Vector2(510, 260)
	panel.custom_minimum_size = Vector2(740, 200)
	area.add_child(panel)
	_descripcion = UIReino.parrafo("", 700, 20, Estilo.TEXTO)
	panel.add_child(_descripcion)
	_boton_volver = UIReino.boton("Volver a casa", _al_volver, Vector2(320, 76), 24)
	_boton_volver.position = Vector2(930, 600)
	area.add_child(_boton_volver)
	# Los objetos van a la izquierda, lejos de "Volver a casa" (que termina la semana).
	_boton_objetos = UIReino.boton("", _al_pulsar_objetos, Vector2(320, 76), 22)
	_boton_objetos.position = Vector2(30, 600)
	Estilo.con_franja(_boton_objetos, Color("#ec407a"))
	area.add_child(_boton_objetos)
	_lista_objetos = UIReino.panel()
	_lista_objetos.position = Vector2(30, 474)
	_lista_objetos.visible = false
	area.add_child(_lista_objetos)
	# Sangre, sangrados e infecciones, al lado de los objetos.
	_salud = UIReino.parrafo("", 540, 17, UIReino.COLOR_AVISO)
	_salud.position = Vector2(370, 614)
	area.add_child(_salud)


## "Atrás" solo termina una salida que ya terminó (como la mazmorra, una salida
## en curso se deja con "Volver a casa", para no perder la semana sin querer).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _saliendo or _datos.is_empty():
		return
	if _cortada() or _terminada():
		if Time.get_ticks_msec() - _abierto_en >= ESPERA_ATRAS_MS:
			_al_volver()


# --- Días ---

func _al_pulsar_dia(indice: int) -> void:
	var dias: Array = Juego.expedicion["dias"]
	if _saliendo or indice != dias.size() or _terminada():
		return
	Juego.sumar_estres(Juego.estres_de_paso(DatosAventura.ESTRES_POR_DIA))
	_lista_objetos.visible = false
	if Juego.curar_al_caminar(DatosAventura.PASOS_POR_DIA):
		_registrar("Desangrado", "Te desangras por el camino.")
		Juego.expedicion["derrota"] = true
		_actualizar()
		return
	var salud := Juego.pasar_dia()
	if salud["muerte"]:
		_registrar("Infección", salud["texto"])
		Juego.expedicion["derrota"] = true
		_actualizar()
		return
	# Lo que pasó con las infecciones se cuenta junto con el suceso del día.
	Juego.expedicion["noticia_salud"] = salud["texto"]
	# Con el estrés al máximo se vuelve a casa: ese día ya no pasa nada (ni un combate).
	if Juego.estres >= DatosAventura.ESTRES_MAXIMO:
		_registrar("Agotado", "Un día entero de marcha te deja agotado.")
		_comprobar_estres()
		_actualizar()
		return
	var nivel: int = _datos["nivel"]
	var suceso := DatosAventura.sortear_suceso(Juego.rng, Juego.puntos_de("amuleto"))
	match suceso:
		"combate":
			var posibles: Array = _datos["enemigos"]
			var enemigo_id: String = posibles[Juego.rng.randi() % posibles.size()]
			Juego.combate = {"origen": "expedicion", "escena": ESCENA_PROPIA, "rival": enemigo_id, "resultado": ""}
			_saliendo = true
			get_tree().change_scene_to_file.call_deferred(ESCENA_COMBATE)
			return
		"oro":
			var oro := Juego.rng.randi_range(5, 15) * nivel
			Juego.oro += oro
			_registrar("+%d de oro" % oro, "Encuentras una bolsa olvidada con %d de oro." % oro)
		"objeto":
			var objeto := Juego.agregar(DatosBotin.generar_botin(nivel, Juego.rng))
			_registrar(String(objeto["nombre"]).get_slice(" ", 0) if DatosBotin.es_consumible(objeto) else String(objeto["nombre"]),
				"Encuentras %s." % DatosBotin.texto_hallazgo(objeto))
		"descanso":
			Juego.sumar_estres(-10.0)
			_registrar("Descanso", "Acampas junto a un arroyo y descansas: −10 de estrés.")
		"trampa":
			var estres := Juego.estres_mental(10.0)
			Juego.sumar_estres(estres)
			_registrar("Trampa", "Caes en una trampa de cazadores: +%s de estrés." % String.num(snappedf(estres, 0.1)))
		_:
			_registrar("Tranquilo", "Un día tranquilo de marcha. No pasa nada.")
	_comprobar_estres()
	_actualizar()


## Abre o cierra la lista de objetos para usar entre combates.
func _al_pulsar_objetos() -> void:
	if _saliendo:
		return
	_lista_objetos.visible = not _lista_objetos.visible
	_actualizar()
	UIReino.bloquear_toques(self, 0.35)


func _al_usar_objeto(tipo: String) -> void:
	if _saliendo:
		return
	var texto := Juego.usar(tipo)
	if texto == "":
		return
	_lista_objetos.visible = false
	_actualizar()
	_descripcion.text = texto
	# Un doble toque no debe gastar otro.
	UIReino.bloquear_toques(self, 0.35)


## Guarda el suceso del día: un texto corto para la casilla y uno largo (con lo
## que pasó con las infecciones ese día, si pasó algo).
func _registrar(corto: String, largo: String) -> void:
	var noticia := String(Juego.expedicion.get("noticia_salud", ""))
	Juego.expedicion.erase("noticia_salud")
	if noticia != "":
		largo += " " + noticia
	Juego.expedicion["dias"].append({"corto": corto, "largo": largo})


func _terminada() -> bool:
	return Juego.expedicion["dias"].size() >= DatosAventura.DIAS_ZONA


## La salida se cortó por una derrota o por llegar al estrés máximo.
func _cortada() -> bool:
	return Juego.expedicion.get("derrota", false) or Juego.expedicion.get("agotado", false)


func _comprobar_estres() -> void:
	if Juego.estres >= DatosAventura.ESTRES_MAXIMO and not _terminada():
		Juego.expedicion["agotado"] = true


## Aplica el resultado de un combate de esta salida.
func _procesar_combate() -> void:
	if Juego.combate.get("origen", "") != "expedicion" or Juego.combate.get("resultado", "") == "":
		return
	var combate := Juego.combate
	Juego.combate = {}
	var nombre: String = DatosRivales.rival(combate["rival"])["nombre"]
	match String(combate["resultado"]):
		"victoria":
			Juego.sumar_estres(Juego.estres_mental(DatosAventura.ESTRES_VICTORIA))
			var botin := Juego.recompensa_enemigo(combate["rival"], int(_datos["nivel"]))
			var texto := "Venciste al %s: %d de oro" % [nombre, botin["oro"]]
			var objeto: Dictionary = botin["objeto"]
			if not objeto.is_empty():
				texto += " y %s" % DatosBotin.texto_hallazgo(objeto)
			_registrar("Victoria", "%s. %s." % [texto, Juego.texto_xp(botin)])
		"derrota":
			Juego.sumar_estres(Juego.estres_mental(DatosAventura.ESTRES_DERROTA))
			_registrar("Derrota", "El %s te venció." % nombre)
			Juego.expedicion["derrota"] = true
		_:
			_registrar("Huida", "Te cruzaste con un %s y huiste." % nombre)
	_comprobar_estres()


## "inmediato": al abrir la pantalla las barras no se animan desde llenas.
func _actualizar(inmediato := false) -> void:
	UIReino.actualizar_estres(_barra_estres, Juego.estres, inmediato)
	UIReino.actualizar_vida(_barra_vida, inmediato)
	_boton_objetos.text = "Cerrar objetos" if _lista_objetos.visible else "Objetos (%d)" % UIReino.total_objetos()
	_boton_objetos.disabled = UIReino.total_objetos() == 0 and not _lista_objetos.visible
	for hijo in _lista_objetos.get_children():
		_lista_objetos.remove_child(hijo)
		hijo.queue_free()
	_lista_objetos.add_child(UIReino.lista_objetos(_al_usar_objeto, 150, 2))
	_salud.text = UIReino.texto_salud()
	var dias: Array = Juego.expedicion["dias"]
	var cortado := _cortada()
	for i in _botones_dia.size():
		var boton := _botones_dia[i]
		if i < dias.size():
			boton.text = "Día %d\n%s" % [i + 1, dias[i]["corto"]]
			boton.disabled = true
			boton.modulate = Color.WHITE
		else:
			boton.text = "Día %d" % (i + 1)
			var siguiente: bool = i == dias.size() and not cortado
			boton.disabled = not siguiente
			# Los días que aún no llegan se ven apagados.
			boton.modulate = Color.WHITE if siguiente else Color(1, 1, 1, 0.35)
	var texto := "Toca el Día 1 para empezar." if dias.is_empty() else String(dias[-1]["largo"])
	if Juego.expedicion.get("derrota", false):
		texto += "\nTe llevan de vuelta al castillo."
	elif Juego.expedicion.get("agotado", false):
		texto += "\nEl estrés llegó a %d: es hora de volver a casa." % roundi(DatosAventura.ESTRES_MAXIMO)
	elif _terminada():
		texto += "\nTerminaron los siete días."
	_descripcion.text = texto
	_boton_volver.text = "Volver a casa" if not (cortado or _terminada()) else "Terminar la salida"


func _al_volver() -> void:
	if _saliendo:
		return
	_saliendo = true
	var semana := Juego.semana
	var dias: int = Juego.expedicion["dias"].size()
	Juego.pasar_semana()
	Juego.aviso = "Volviste de %s tras %d %s. Terminó la semana %d." % [_datos["nombre"], dias,
		"día" if dias == 1 else "días", semana]
	_volver_al_reino()


func _volver_al_reino() -> void:
	_saliendo = true
	Juego.pestana = "aventura"
	get_tree().change_scene_to_file.call_deferred(ESCENA_REINO)
