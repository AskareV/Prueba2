class_name MapaReino
extends Control
## Mapa de aventura (provisional, dibujado con código): un pergamino con
## banderines. Los rojos son zonas de siete días; los oscuros, mazmorras.

signal lugar_elegido(lugar_id: String)

const COLOR_PERGAMINO := Color("#d8c49a")
const COLOR_TIERRA := Color("#b89f6e")
const COLOR_TINTA := Color("#4a3b26")
const COLOR_ZONA := Color("#c62828")
const COLOR_MAZMORRA := Color("#37323e")

var _manchas: Array[PackedVector2Array] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Las islas que se salen del pergamino se recortan.
	clip_contents = true
	resized.connect(_reconstruir)
	_reconstruir()


func _reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_crear_tierras()
	for lugar_id in DatosAventura.ORDEN_ZONAS + DatosAventura.ORDEN_MAZMORRAS:
		var banderin := Banderin.new()
		banderin.lugar_id = lugar_id
		banderin.es_mazmorra = DatosAventura.es_mazmorra(lugar_id)
		var datos := DatosAventura.lugar(lugar_id)
		banderin.position = Vector2(datos["posicion"]) * size - Vector2(Banderin.ANCHO / 2.0, Banderin.ALTO)
		banderin.pulsado.connect(func(id: String) -> void: lugar_elegido.emit(id))
		add_child(banderin)
	queue_redraw()


## Islas y costas al azar (siempre las mismas).
func _crear_tierras() -> void:
	_manchas.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for centro in [Vector2(0.25, 0.55), Vector2(0.55, 0.45), Vector2(0.8, 0.55), Vector2(0.62, 0.15), Vector2(0.12, 0.2)]:
		var puntos := PackedVector2Array()
		var radio := Vector2(size.x * rng.randf_range(0.12, 0.2), size.y * rng.randf_range(0.18, 0.3))
		var ruido: Array[float] = []
		for i in 28:
			ruido.append(rng.randf_range(0.75, 1.2))
		for i in 28:
			var angulo := TAU * i / 28.0
			# Promedio con los vecinos: costas más suaves, sin picos.
			var suave := (ruido[i - 1] + 2.0 * ruido[i] + ruido[(i + 1) % 28]) / 4.0
			puntos.append(Vector2(centro) * size + Vector2(cos(angulo) * radio.x, sin(angulo) * radio.y) * suave)
		_manchas.append(puntos)


func _draw() -> void:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = COLOR_PERGAMINO
	fondo.set_corner_radius_all(10)
	draw_style_box(fondo, Rect2(Vector2.ZERO, size))
	for mancha in _manchas:
		draw_colored_polygon(mancha, COLOR_TIERRA)
		var cerrada := mancha.duplicate()
		cerrada.append(mancha[0])
		draw_polyline(cerrada, COLOR_TINTA, 2.0, true)
	# El borde va encima de las islas.
	var borde := StyleBoxFlat.new()
	borde.draw_center = false
	borde.border_color = COLOR_TINTA
	borde.set_border_width_all(4)
	borde.set_corner_radius_all(10)
	draw_style_box(borde, Rect2(Vector2.ZERO, size))
	# Rosa de los vientos sencilla.
	var rosa := Vector2(size.x - 60, size.y - 60)
	draw_line(rosa + Vector2(0, -30), rosa + Vector2(0, 30), COLOR_TINTA, 2.0)
	draw_line(rosa + Vector2(-30, 0), rosa + Vector2(30, 0), COLOR_TINTA, 2.0)
	draw_string(get_theme_default_font(), rosa + Vector2(-6, -36), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COLOR_TINTA)


## Banderín tocable sobre el mapa, con el nombre del lugar debajo.
class Banderin:
	extends Control

	signal pulsado(lugar_id: String)

	const ANCHO := 150.0
	const ALTO := 92.0

	var lugar_id := ""
	var es_mazmorra := false

	func _ready() -> void:
		size = Vector2(ANCHO, ALTO + 26)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		var suelto := false
		if event is InputEventMouseButton:
			var boton := event as InputEventMouseButton
			suelto = boton.button_index == MOUSE_BUTTON_LEFT and not boton.pressed
		if suelto:
			accept_event()
			pulsado.emit(lugar_id)

	func _draw() -> void:
		var base := Vector2(ANCHO / 2.0, ALTO)
		draw_line(base, base + Vector2(0, -78), Color("#3e2723"), 4.0)
		var color := MapaReino.COLOR_MAZMORRA if es_mazmorra else MapaReino.COLOR_ZONA
		var bandera := PackedVector2Array([
			base + Vector2(2, -78), base + Vector2(46, -66), base + Vector2(2, -52)])
		draw_colored_polygon(bandera, color)
		draw_polyline(PackedVector2Array([bandera[0], bandera[1], bandera[2]]), MapaReino.COLOR_TINTA, 2.0)
		draw_circle(base, 6.0, MapaReino.COLOR_TINTA)
		var fuente := get_theme_default_font()
		var nombre: String = DatosAventura.lugar(lugar_id)["nombre"]
		var medida := fuente.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var posicion := Vector2((ANCHO - medida.x) / 2.0, ALTO + 20)
		draw_string_outline(fuente, posicion, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("#f3e7c9"))
		draw_string(fuente, posicion, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MapaReino.COLOR_TINTA)
