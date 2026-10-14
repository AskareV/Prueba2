extends Control
## Exploración de una mazmorra (como en My Pet Protector, adaptada al celular):
## cada paso suma estrés y descubre las casillas de alrededor. Al pisar un
## enemigo empieza un combate; un cofre da botín; volver a pisar la H saca de la
## mazmorra. Con 70 de estrés el rey vuelve a casa. Al salir termina la semana
## y la mazmorra se reinicia.

const ESCENA_REINO := "res://escenas/reino.tscn"
const ESCENA_COMBATE := "res://escenas/combate.tscn"
const ESCENA_PROPIA := "res://escenas/mazmorra.tscn"
const DIRECCIONES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## La ayuda se muestra sola la primera vez que se entra a una mazmorra.
static var ayuda_vista := false

var _datos: Dictionary
var _tablero: TableroMazmorra
var _barra_estres: Barra
var _registro: Label
var _ayuda: Control
var _mensajes: PackedStringArray = []
var _saliendo := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Juego.mazmorra.is_empty():
		_volver_al_reino()
		return
	_datos = DatosAventura.MAZMORRAS[Juego.mazmorra["id"]]
	if not Juego.mazmorra.has("plano"):
		_preparar_mazmorra()
	UIReino.fondo(self)
	var area := UIReino.area_centrada(self)
	_crear_cabecera(area)
	_tablero = TableroMazmorra.new()
	_tablero.position = Vector2(20, 90)
	_tablero.size = Vector2(GeneradorMazmorra.ANCHO, GeneradorMazmorra.ALTO) * 62.0
	_tablero.mover.connect(_mover)
	area.add_child(_tablero)
	_crear_lateral(area)
	_crear_ayuda(area)
	_procesar_combate()
	# Una derrota (o el estrés) saca al rey de la mazmorra: no hay plano que mostrar.
	if _saliendo:
		return
	_actualizar()
	if not ayuda_vista:
		ayuda_vista = true
		_mostrar_ayuda()
	UIReino.bloquear_toques(self)


## Plano nuevo de esta semana, con el rey en la entrada.
func _preparar_mazmorra() -> void:
	var plano := GeneradorMazmorra.generar(Juego.mazmorra["id"], Juego.semana)
	Juego.mazmorra["plano"] = plano
	Juego.mazmorra["pos"] = plano["entrada"]
	Juego.mazmorra["anterior"] = plano["entrada"]
	Juego.mazmorra["visibles"] = {}
	Juego.mazmorra["salio"] = false
	_revelar(plano["entrada"])


func _crear_cabecera(area: Control) -> void:
	var fila := HBoxContainer.new()
	fila.position = Vector2(20, 18)
	fila.add_theme_constant_override("separation", 18)
	area.add_child(fila)
	var ayuda := UIReino.boton("?", _mostrar_ayuda, Vector2(60, 56), 30)
	ayuda.add_theme_color_override("font_color", Color("#7cb342"))
	fila.add_child(ayuda)
	var etiqueta := UIReino.etiqueta("Estrés", 22)
	etiqueta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(etiqueta)
	_barra_estres = UIReino.barra_estres()
	_barra_estres.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(_barra_estres)
	var titulo := UIReino.etiqueta("%s · %s" % [_datos["nombre"], _datos["dificultad"]], 28, UIReino.COLOR_TITULO)
	titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(titulo)


func _crear_lateral(area: Control) -> void:
	var panel := UIReino.panel()
	panel.position = Vector2(970, 90)
	panel.custom_minimum_size = Vector2(290, 250)
	area.add_child(panel)
	_registro = UIReino.parrafo("", 256, 17, Estilo.TEXTO)
	_registro.custom_minimum_size = Vector2(256, 230)
	panel.add_child(_registro)
	# Cruceta: sustituye a las flechas del teclado del juego original.
	var cruceta := GridContainer.new()
	cruceta.columns = 3
	cruceta.position = Vector2(978, 360)
	cruceta.add_theme_constant_override("h_separation", 6)
	cruceta.add_theme_constant_override("v_separation", 6)
	area.add_child(cruceta)
	var distribucion := [null, Vector2i.UP, null, Vector2i.LEFT, null, Vector2i.RIGHT, null, Vector2i.DOWN, null]
	for direccion in distribucion:
		if direccion == null:
			var hueco := Control.new()
			hueco.custom_minimum_size = Vector2(88, 88)
			cruceta.add_child(hueco)
			continue
		var boton := UIReino.boton("", _mover.bind(direccion), Vector2(88, 88))
		var flecha := Flecha.new()
		flecha.direccion = direccion
		flecha.set_anchors_preset(Control.PRESET_FULL_RECT)
		boton.add_child(flecha)
		cruceta.add_child(boton)


func _crear_ayuda(area: Control) -> void:
	_ayuda = ColorRect.new()
	(_ayuda as ColorRect).color = Color(0, 0, 0, 0.6)
	_ayuda.position = Vector2.ZERO
	_ayuda.size = Vector2(1280, 720)
	_ayuda.mouse_filter = Control.MOUSE_FILTER_STOP
	_ayuda.visible = false
	area.add_child(_ayuda)
	var panel := UIReino.panel()
	panel.position = Vector2(300, 170)
	panel.custom_minimum_size = Vector2(680, 0)
	_ayuda.add_child(panel)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel.add_child(columna)
	columna.add_child(UIReino.parrafo("Usa la cruceta o toca una casilla vecina para moverte. Cada paso suma estrés; con %d es hora de volver a casa." % roundi(DatosAventura.ESTRES_MAXIMO), 640, 21, Color("#ffb74d")))
	var leyenda := Leyenda.new()
	leyenda.custom_minimum_size = Vector2(640, 64)
	columna.add_child(leyenda)
	columna.add_child(UIReino.parrafo("Lo que sigue negro al lado tuyo es un muro. Para salir, vuelve a pisar la H. La mazmorra se reinicia cada semana.", 640, 18))
	var listo := UIReino.boton("Entendido", _ocultar_ayuda, Vector2(240, 64), 22)
	listo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	columna.add_child(listo)


func _mostrar_ayuda() -> void:
	_ayuda.visible = true
	UIReino.bloquear_toques(self, 0.35)


func _ocultar_ayuda() -> void:
	_ayuda.visible = false
	UIReino.bloquear_toques(self, 0.35)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _ayuda != null and _ayuda.visible:
		_ocultar_ayuda()


func _unhandled_input(event: InputEvent) -> void:
	# Con teclado (en la computadora) también sirven las flechas.
	if _saliendo or _ayuda == null or _ayuda.visible:
		return
	for accion in [["ui_up", Vector2i.UP], ["ui_down", Vector2i.DOWN], ["ui_left", Vector2i.LEFT], ["ui_right", Vector2i.RIGHT]]:
		if event.is_action_pressed(accion[0]):
			get_viewport().set_input_as_handled()
			_mover(accion[1])
			return


# --- Movimiento ---

func _mover(direccion: Vector2i) -> void:
	if _saliendo or _ayuda.visible:
		return
	var plano: Dictionary = Juego.mazmorra["plano"]
	var origen: Vector2i = Juego.mazmorra["pos"]
	var destino: Vector2i = origen + direccion
	if not GeneradorMazmorra.es_suelo(plano["celdas"], destino):
		return
	Juego.sumar_estres(_datos["estres_por_paso"])
	Juego.mazmorra["anterior"] = origen
	Juego.mazmorra["pos"] = destino
	_revelar(destino)
	if destino != plano["entrada"]:
		Juego.mazmorra["salio"] = true
	if plano["enemigos"].has(destino):
		_iniciar_combate(destino)
		return
	if plano["cofres"].has(destino):
		_abrir_cofre(destino)
	if destino == plano["entrada"] and Juego.mazmorra["salio"]:
		_salir("Saliste de %s." % _datos["nombre"])
		return
	if Juego.estres >= DatosAventura.ESTRES_MAXIMO:
		_salir("El estrés llegó a %d: es hora de volver a casa." % roundi(DatosAventura.ESTRES_MAXIMO))
		return
	_actualizar()


## Descubre la casilla y sus cuatro vecinas.
func _revelar(celda: Vector2i) -> void:
	var visibles: Dictionary = Juego.mazmorra["visibles"]
	visibles[celda] = true
	for d in DIRECCIONES:
		visibles[celda + d] = true


func _abrir_cofre(celda: Vector2i) -> void:
	Juego.mazmorra["plano"]["cofres"].erase(celda)
	var botin := Juego.abrir_cofre(int(_datos["nivel"]))
	var objeto: Dictionary = botin["objeto"]
	_mensaje("Abres un cofre: %d de oro y %s (%s)." % [botin["oro"], objeto["nombre"],
		DatosBotin.nombre_calidad(objeto["calidad"]).to_lower()])


# --- Combate ---

func _iniciar_combate(celda: Vector2i) -> void:
	Juego.combate = {
		"origen": "mazmorra", "escena": ESCENA_PROPIA, "rival": Juego.mazmorra["plano"]["enemigos"][celda],
		"celda": celda, "resultado": "",
	}
	_saliendo = true
	get_tree().change_scene_to_file.call_deferred(ESCENA_COMBATE)


## Aplica el resultado de un combate recién terminado en esta mazmorra.
func _procesar_combate() -> void:
	if Juego.combate.get("origen", "") != "mazmorra" or Juego.combate.get("resultado", "") == "":
		return
	var combate := Juego.combate
	Juego.combate = {}
	var nombre: String = DatosRivales.rival(combate["rival"])["nombre"]
	match String(combate["resultado"]):
		"victoria":
			Juego.mazmorra["plano"]["enemigos"].erase(combate["celda"])
			Juego.sumar_estres(DatosAventura.ESTRES_VICTORIA)
			var botin := Juego.recompensa_enemigo(combate["rival"])
			var texto := "Venciste al %s: %d de oro" % [nombre, botin["oro"]]
			var objeto: Dictionary = botin["objeto"]
			if not objeto.is_empty():
				texto += " y %s (%s)" % [objeto["nombre"], DatosBotin.nombre_calidad(objeto["calidad"]).to_lower()]
			_mensaje(texto + ".")
			if Juego.estres >= DatosAventura.ESTRES_MAXIMO:
				_salir("El estrés llegó a %d: es hora de volver a casa." % roundi(DatosAventura.ESTRES_MAXIMO))
		"derrota":
			Juego.sumar_estres(DatosAventura.ESTRES_DERROTA)
			_salir("El %s te venció. Te llevan de vuelta al castillo." % nombre)
		_:
			Juego.mazmorra["pos"] = Juego.mazmorra["anterior"]
			_mensaje("Huiste del %s." % nombre)


# --- Salida ---

## Sale de la mazmorra: termina la semana y vuelve al mapa.
func _salir(motivo: String) -> void:
	if _saliendo:
		return
	_saliendo = true
	var semana := Juego.semana
	Juego.pasar_semana()
	var extra := ""
	if not _mensajes.is_empty():
		extra = " " + _mensajes[-1]
	Juego.aviso = "%s%s Terminó la semana %d." % [motivo, extra, semana]
	_volver_al_reino()


func _volver_al_reino() -> void:
	_saliendo = true
	# Al volver, el reino abre la pestaña de Aventura.
	Juego.pestana = "aventura"
	get_tree().change_scene_to_file.call_deferred(ESCENA_REINO)


func _mensaje(texto: String) -> void:
	_mensajes.append(texto)
	if _registro != null:
		_registro.text = "\n".join(_mensajes.slice(maxi(_mensajes.size() - 4, 0)))


func _actualizar() -> void:
	UIReino.actualizar_estres(_barra_estres, Juego.estres)
	_tablero.actualizar(Juego.mazmorra["plano"], Juego.mazmorra["visibles"], Juego.mazmorra["pos"])
	if _mensajes.is_empty():
		_mensaje("Entras a %s." % _datos["nombre"])


## Triángulo de un botón de la cruceta.
class Flecha:
	extends Control

	var direccion := Vector2i.UP

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centro := size / 2.0
		var d := Vector2(direccion)
		var lateral := d.orthogonal()
		var puntos := PackedVector2Array([
			centro + d * 24.0, centro - d * 14.0 + lateral * 22.0, centro - d * 14.0 - lateral * 22.0])
		draw_colored_polygon(puntos, Color("#eef0ff"))


## Leyenda de la ayuda: enemigo, tesoro y salida.
class Leyenda:
	extends Control

	func _draw() -> void:
		var fuente := get_theme_default_font()
		var y := size.y / 2.0
		TableroMazmorra.dibujar_espadas(self, Vector2(40, y), 20.0)
		draw_string(fuente, Vector2(72, y + 8), "Enemigo", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffb74d"))
		TableroMazmorra.dibujar_cofre(self, Vector2(260, y), 20.0)
		draw_string(fuente, Vector2(292, y + 8), "Tesoro", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffb74d"))
		draw_string(fuente, Vector2(452, y + 12), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, TableroMazmorra.COLOR_SALIDA)
		draw_string(fuente, Vector2(482, y + 8), "Salida", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffb74d"))
