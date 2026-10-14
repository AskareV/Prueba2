extends Control
## Salida a una zona (banderín rojo del mapa): siete casillas, "Día 1" a
## "Día 7". Cada toque revela el suceso del día siguiente: combate, oro, un
## objeto, un día tranquilo, descanso o una trampa. Cada día suma estrés; con
## 70 el rey vuelve a casa. Al volver termina la semana.

const ESCENA_REINO := "res://escenas/reino.tscn"
const ESCENA_COMBATE := "res://escenas/combate.tscn"
const ESCENA_PROPIA := "res://escenas/expedicion.tscn"

var _datos: Dictionary
var _barra_estres: Barra
var _botones_dia: Array[Button] = []
var _descripcion: Label
var _boton_volver: Button
var _saliendo := false


func _ready() -> void:
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
	_actualizar()
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
	cabecera.add_child(UIReino.etiqueta("Salida a %s · %s" % [_datos["nombre"], _datos["dificultad"]], 28,
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _saliendo and not _datos.is_empty():
		_al_volver()


# --- Días ---

func _al_pulsar_dia(indice: int) -> void:
	var dias: Array = Juego.expedicion["dias"]
	if _saliendo or indice != dias.size() or _terminada():
		return
	Juego.sumar_estres(DatosAventura.ESTRES_POR_DIA)
	var nivel: int = _datos["nivel"]
	var suceso := DatosAventura.sortear_suceso(Juego.rng)
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
			var objeto := Juego.agregar(DatosBotin.generar(nivel, Juego.rng))
			_registrar(objeto["nombre"], "Encuentras %s (%s)." % [objeto["nombre"],
				DatosBotin.nombre_calidad(objeto["calidad"]).to_lower()])
		"descanso":
			Juego.sumar_estres(-10.0)
			_registrar("Descanso", "Acampas junto a un arroyo y descansas: −10 de estrés.")
		"trampa":
			Juego.sumar_estres(10.0)
			_registrar("Trampa", "Caes en una trampa de cazadores: +10 de estrés.")
		_:
			_registrar("Tranquilo", "Un día tranquilo de marcha. No pasa nada.")
	_comprobar_estres()
	_actualizar()


## Guarda el suceso del día: un texto corto para la casilla y uno largo.
func _registrar(corto: String, largo: String) -> void:
	Juego.expedicion["dias"].append({"corto": corto, "largo": largo})


func _terminada() -> bool:
	return Juego.expedicion["dias"].size() >= DatosAventura.DIAS_ZONA


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
			Juego.sumar_estres(DatosAventura.ESTRES_VICTORIA)
			var botin := Juego.recompensa_enemigo(combate["rival"], int(_datos["nivel"]))
			var texto := "Venciste al %s: %d de oro" % [nombre, botin["oro"]]
			var objeto: Dictionary = botin["objeto"]
			if not objeto.is_empty():
				texto += " y %s (%s)" % [objeto["nombre"], DatosBotin.nombre_calidad(objeto["calidad"]).to_lower()]
			_registrar("Victoria", texto + ".")
		"derrota":
			Juego.sumar_estres(DatosAventura.ESTRES_DERROTA)
			_registrar("Derrota", "El %s te venció." % nombre)
			Juego.expedicion["derrota"] = true
		_:
			_registrar("Huida", "Te cruzaste con un %s y huiste." % nombre)
	_comprobar_estres()


func _actualizar() -> void:
	UIReino.actualizar_estres(_barra_estres, Juego.estres)
	var dias: Array = Juego.expedicion["dias"]
	var cortado: bool = Juego.expedicion.get("derrota", false) or Juego.expedicion.get("agotado", false)
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
