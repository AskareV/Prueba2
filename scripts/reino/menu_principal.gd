extends Control
## Menú principal: seguir la partida del reino, empezar una nueva o abrir la
## demo de combate.

const ESCENA_REINO := "res://escenas/reino.tscn"
const ESCENA_DEMO := "res://escenas/preparacion.tscn"

var _fondo: FondoMazmorra
var _antorchas: Antorchas
var _vineta: Vineta
var _botones: VBoxContainer
var _eleccion: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fondo = FondoMazmorra.new()
	add_child(_fondo)
	_antorchas = Antorchas.new()
	add_child(_antorchas)
	_vineta = Vineta.new()
	add_child(_vineta)
	var area := UIReino.area_centrada(self)

	var titulo := UIReino.etiqueta("Mi Juego", 64, UIReino.COLOR_TITULO)
	titulo.position = Vector2(0, 90)
	titulo.size = Vector2(1280, 80)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area.add_child(titulo)
	var subtitulo := UIReino.etiqueta("Nombre provisional · prototipo", 20, Estilo.TEXTO_SUAVE)
	subtitulo.position = Vector2(0, 172)
	subtitulo.size = Vector2(1280, 30)
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area.add_child(subtitulo)

	_botones = VBoxContainer.new()
	_botones.add_theme_constant_override("separation", 16)
	_botones.position = Vector2(470, 250)
	area.add_child(_botones)
	if Juego.en_curso:
		_agregar_boton("Continuar (semana %d)" % Juego.semana, _al_continuar, Color("#ffd54f"))
	_agregar_boton("Nueva partida", _al_pulsar_nueva, Color("#66bb6a"))
	_agregar_boton("Demo de combate", _al_pulsar_demo, Color("#42a5f5"))

	_crear_eleccion(area)
	get_viewport().size_changed.connect(_reubicar)
	_reubicar()
	UIReino.bloquear_toques(self)


func _agregar_boton(texto: String, al_pulsar: Callable, color: Color) -> void:
	var boton := UIReino.boton(texto, al_pulsar, Vector2(340, 78), 26)
	Estilo.con_franja(boton, color)
	_botones.add_child(boton)


## Ventana para elegir si el rey es diestro o zurdo antes de empezar.
func _crear_eleccion(area: Control) -> void:
	_eleccion = UIReino.panel()
	_eleccion.position = Vector2(390, 240)
	_eleccion.custom_minimum_size = Vector2(500, 0)
	_eleccion.visible = false
	area.add_child(_eleccion)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 14)
	_eleccion.add_child(columna)
	var pregunta := UIReino.etiqueta("¿Tu rey es diestro o zurdo?", 26, UIReino.COLOR_TITULO)
	pregunta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(pregunta)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 14)
	columna.add_child(fila)
	fila.add_child(UIReino.boton("Diestro", _al_elegir_mano.bind(true), Vector2(200, 72), 24))
	fila.add_child(UIReino.boton("Zurdo", _al_elegir_mano.bind(false), Vector2(200, 72), 24))
	var aviso := UIReino.parrafo("Si ya tienes una partida, se pierde.", 460, 17)
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.visible = Juego.en_curso
	columna.add_child(aviso)
	var cancelar := UIReino.boton("Cancelar", _al_cancelar, Vector2(200, 60), 22)
	cancelar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	columna.add_child(cancelar)


func _reubicar() -> void:
	var tamano := get_viewport_rect().size
	var suelo := (tamano.y - 720.0) / 2.0 + 620.0
	_fondo.ajustar(tamano, suelo)
	_antorchas.ajustar(tamano, suelo)
	_vineta.ajustar(tamano)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _eleccion.visible:
			_al_cancelar()
		else:
			get_tree().quit()


func _al_continuar() -> void:
	get_tree().change_scene_to_file.call_deferred(ESCENA_REINO)


func _al_pulsar_nueva() -> void:
	_botones.visible = false
	_eleccion.visible = true
	UIReino.bloquear_toques(self, 0.35)


func _al_cancelar() -> void:
	_eleccion.visible = false
	_botones.visible = true
	UIReino.bloquear_toques(self, 0.35)


func _al_elegir_mano(diestro: bool) -> void:
	Juego.nueva_partida(diestro)
	get_tree().change_scene_to_file.call_deferred(ESCENA_REINO)


func _al_pulsar_demo() -> void:
	get_tree().change_scene_to_file.call_deferred(ESCENA_DEMO)
