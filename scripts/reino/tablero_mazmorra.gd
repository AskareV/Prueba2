class_name TableroMazmorra
extends Control
## Dibuja la cuadrícula de la mazmorra (como en My Pet Protector): lo no
## descubierto es negro y un muro sigue negro aunque esté al lado; el suelo
## descubierto es piedra clara. Espadas cruzadas = enemigo, cofre = tesoro,
## H = salida. Tocar una casilla vecina pide moverse hacia ella.

signal mover(direccion: Vector2i)

const COLOR_OSCURO := Color("#151a17")
const COLOR_JUNTA := Color("#0c0f0d")
const COLOR_SUELO := Color("#cfc6b0")
const COLOR_SUELO_BORDE := Color("#a99f87")
const COLOR_SALIDA := Color("#43a047")

var plano: Dictionary = {}
var visibles: Dictionary = {}
var posicion_rey := Vector2i.ZERO
var lado := 62.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func actualizar(p_plano: Dictionary, p_visibles: Dictionary, p_posicion: Vector2i) -> void:
	plano = p_plano
	visibles = p_visibles
	posicion_rey = p_posicion
	lado = minf(size.x / GeneradorMazmorra.ANCHO, size.y / GeneradorMazmorra.ALTO)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var boton := event as InputEventMouseButton
	if boton.button_index != MOUSE_BUTTON_LEFT or boton.pressed:
		return
	var celda := Vector2i(floori(boton.position.x / lado), floori(boton.position.y / lado))
	var diferencia := celda - posicion_rey
	if absi(diferencia.x) + absi(diferencia.y) == 1:
		accept_event()
		mover.emit(diferencia)


func _draw() -> void:
	if plano.is_empty():
		return
	var celdas: Array = plano["celdas"]
	for y in GeneradorMazmorra.ALTO:
		for x in GeneradorMazmorra.ANCHO:
			var celda := Vector2i(x, y)
			var rect := Rect2(Vector2(x, y) * lado, Vector2(lado, lado))
			if visibles.has(celda) and celdas[y][x] == GeneradorMazmorra.Celda.SUELO:
				draw_rect(rect, COLOR_SUELO)
				draw_rect(rect.grow(-1.0), COLOR_SUELO_BORDE, false, 2.0)
				_dibujar_contenido(celda, rect)
			else:
				draw_rect(rect, COLOR_OSCURO)
				draw_rect(rect, COLOR_JUNTA, false, 1.0)
	_dibujar_rey(Rect2(Vector2(posicion_rey) * lado, Vector2(lado, lado)))


func _dibujar_contenido(celda: Vector2i, rect: Rect2) -> void:
	var centro := rect.get_center()
	if celda == plano["entrada"]:
		var fuente := get_theme_default_font()
		var tamano := int(lado * 0.6)
		var medida := fuente.get_string_size("H", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano)
		draw_string(fuente, centro + Vector2(-medida.x / 2.0, tamano * 0.35), "H", HORIZONTAL_ALIGNMENT_LEFT, -1,
			tamano, COLOR_SALIDA)
	elif plano["enemigos"].has(celda):
		dibujar_espadas(self, centro, lado * 0.32)
	elif plano["cofres"].has(celda):
		dibujar_cofre(self, centro, lado * 0.3)


func _dibujar_rey(rect: Rect2) -> void:
	var centro := rect.get_center()
	var radio := lado * 0.3
	draw_circle(centro + Vector2(0, radio * 0.25), radio, Color("#2f5fb3"))
	draw_arc(centro + Vector2(0, radio * 0.25), radio, 0.0, TAU, 20, Color("#141726"), 2.0, true)
	var corona := PackedVector2Array([
		centro + Vector2(-radio * 0.7, -radio * 0.35), centro + Vector2(-radio * 0.7, -radio * 0.95),
		centro + Vector2(-radio * 0.35, -radio * 0.6), centro + Vector2(0, -radio * 1.1),
		centro + Vector2(radio * 0.35, -radio * 0.6), centro + Vector2(radio * 0.7, -radio * 0.95),
		centro + Vector2(radio * 0.7, -radio * 0.35)])
	draw_colored_polygon(corona, Color("#ffcc33"))


## Espadas cruzadas (enemigo). Estática para usarla también en la leyenda.
static func dibujar_espadas(lienzo: CanvasItem, centro: Vector2, radio: float) -> void:
	for lado_x in [-1.0, 1.0]:
		var punta := centro + Vector2(radio * lado_x, -radio)
		var mango := centro + Vector2(-radio * lado_x, radio)
		lienzo.draw_line(mango, punta, Color("#eceff1"), 4.0, true)
		lienzo.draw_line(mango, punta, Color("#37474f"), 1.5, true)
		var guarda := mango.lerp(punta, 0.28)
		var normal := (punta - mango).normalized().orthogonal() * radio * 0.35
		lienzo.draw_line(guarda - normal, guarda + normal, Color("#5d4037"), 4.0, true)


## Cofre (tesoro). Estática para usarla también en la leyenda.
static func dibujar_cofre(lienzo: CanvasItem, centro: Vector2, radio: float) -> void:
	var caja := Rect2(centro + Vector2(-radio, -radio * 0.55), Vector2(radio * 2.0, radio * 1.4))
	lienzo.draw_rect(caja, Color("#8d6e63"))
	lienzo.draw_rect(Rect2(caja.position, Vector2(caja.size.x, radio * 0.45)), Color("#6d4c41"))
	lienzo.draw_rect(caja, Color("#3e2723"), false, 2.0)
	lienzo.draw_rect(Rect2(centro + Vector2(-radio * 0.18, -radio * 0.2), Vector2(radio * 0.36, radio * 0.4)),
		Color("#ffcc33"))
