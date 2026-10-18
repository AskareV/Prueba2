class_name VistaCiudad
extends Control
## La ciudad dibujada con código (provisional): suelo, caminos y los cinco
## edificios fijos de DatosCiudad. Tocar un edificio emite edificio_elegido. Los
## que están en ruinas se dibujan derrumbados.

signal edificio_elegido(edificio_id: String)

const COLOR_SUELO := Color("#4a5a3a")
const COLOR_PLAZA := Color("#7a6f5d")
const COLOR_CAMINO := Color("#8c7d64")
const COLOR_TINTA := Color("#231c14")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_reconstruir)
	_reconstruir()


func _reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	for edificio_id in DatosCiudad.ORDEN:
		var edificio := EdificioCiudad.new()
		edificio.edificio_id = edificio_id
		var centro: Vector2 = DatosCiudad.edificio(edificio_id)["posicion"]
		edificio.position = centro * size - EdificioCiudad.TAMANO / 2.0
		edificio.pulsado.connect(func(id: String) -> void: edificio_elegido.emit(id))
		add_child(edificio)
	queue_redraw()


func _draw() -> void:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = COLOR_SUELO
	fondo.set_corner_radius_all(10)
	draw_style_box(fondo, Rect2(Vector2.ZERO, size))
	# Caminos del castillo a cada edificio, y la plaza del castillo.
	var castillo: Vector2 = DatosCiudad.edificio("castillo")["posicion"] * size
	for edificio_id in DatosCiudad.ORDEN:
		if edificio_id != "castillo":
			draw_line(castillo + Vector2(0, 40), DatosCiudad.edificio(edificio_id)["posicion"] * size + Vector2(0, 40),
				COLOR_CAMINO, 22.0, true)
	draw_circle(castillo + Vector2(0, 40), 110.0, COLOR_PLAZA)
	var borde := StyleBoxFlat.new()
	borde.draw_center = false
	borde.border_color = COLOR_TINTA
	borde.set_border_width_all(4)
	borde.set_corner_radius_all(10)
	draw_style_box(borde, Rect2(Vector2.ZERO, size))


## Un edificio tocable: su dibujo (según el nivel), el nombre y el nivel.
class EdificioCiudad:
	extends Control

	signal pulsado(edificio_id: String)

	const TAMANO := Vector2(230, 190)

	var edificio_id := ""

	func _ready() -> void:
		size = TAMANO
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var boton := event as InputEventMouseButton
			if boton.button_index == MOUSE_BUTTON_LEFT and not boton.pressed:
				accept_event()
				pulsado.emit(edificio_id)

	func _draw() -> void:
		var nivel := Juego.nivel_edificio(edificio_id)
		var base := Vector2(TAMANO.x / 2.0, 132)
		if nivel <= 0:
			_ruinas(base)
		else:
			match edificio_id:
				"castillo":
					_castillo(base)
				"herreria":
					_herreria(base)
				"granja":
					_granja(base)
				"mercado":
					_mercado(base)
				"barracas":
					_barracas(base)
		var datos := DatosCiudad.edificio(edificio_id)
		var fuente := get_theme_default_font()
		var nombre: String = datos["nombre"]
		var detalle := "En ruinas" if nivel <= 0 else "Nivel %d" % nivel
		_texto(fuente, nombre, 152, 20, Color("#fff3d6"))
		_texto(fuente, detalle, 176, 16, Color("#ffcc80") if nivel <= 0 else Color("#e0e0e0"))

	func _texto(fuente: Font, texto: String, y: float, tamano: int, color: Color) -> void:
		var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano).x
		var posicion := Vector2((TAMANO.x - ancho) / 2.0, y)
		draw_string_outline(fuente, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, 5, Color("#1a140e"))
		draw_string(fuente, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano, color)

	func _caja(rect: Rect2, color: Color) -> void:
		draw_rect(rect, color)
		draw_rect(rect, VistaCiudad.COLOR_TINTA, false, 2.0)

	func _tejado(izq: Vector2, der: Vector2, alto: float, color: Color) -> void:
		var punta := Vector2((izq.x + der.x) / 2.0, izq.y - alto)
		var tejado := PackedVector2Array([izq, punta, der])
		draw_colored_polygon(tejado, color)
		draw_polyline(PackedVector2Array([izq, punta, der, izq]), VistaCiudad.COLOR_TINTA, 2.0)

	func _almenas(x: float, y: float, ancho: float, color: Color) -> void:
		var paso := ancho / 5.0
		for i in 3:
			_caja(Rect2(x + paso * (2 * i), y - 10, paso, 10), color)

	func _castillo(base: Vector2) -> void:
		var piedra := Color("#9e9aa8")
		var oscura := Color("#7c7886")
		_caja(Rect2(base.x - 92, base.y - 70, 40, 70), oscura)
		_tejado(Vector2(base.x - 98, base.y - 70), Vector2(base.x - 46, base.y - 70), 30, Color("#5c6bc0"))
		_caja(Rect2(base.x + 52, base.y - 70, 40, 70), oscura)
		_tejado(Vector2(base.x + 46, base.y - 70), Vector2(base.x + 98, base.y - 70), 30, Color("#5c6bc0"))
		_caja(Rect2(base.x - 54, base.y - 96, 108, 96), piedra)
		_almenas(base.x - 54, base.y - 96, 108, piedra)
		# Puerta en arco.
		draw_rect(Rect2(base.x - 15, base.y - 34, 30, 34), Color("#3e2723"))
		draw_circle(Vector2(base.x, base.y - 34), 15.0, Color("#3e2723"))
		draw_line(Vector2(base.x, base.y - 106), Vector2(base.x, base.y - 132), VistaCiudad.COLOR_TINTA, 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x, base.y - 132), Vector2(base.x + 26, base.y - 124), Vector2(base.x, base.y - 116)]), Color("#ffd54f"))

	func _herreria(base: Vector2) -> void:
		_caja(Rect2(base.x - 60, base.y - 58, 120, 58), Color("#8d6e63"))
		_tejado(Vector2(base.x - 70, base.y - 58), Vector2(base.x + 70, base.y - 58), 34, Color("#4e342e"))
		_caja(Rect2(base.x + 28, base.y - 100, 18, 34), Color("#616161"))
		for i in 3:
			draw_circle(Vector2(base.x + 40 + i * 9, base.y - 110 - i * 12), 7.0 + i * 2, Color(0.75, 0.75, 0.75, 0.6))
		draw_rect(Rect2(base.x - 40, base.y - 34, 26, 34), Color("#3e2723"))
		# Yunque y fuego de la fragua.
		draw_rect(Rect2(base.x - 6, base.y - 20, 30, 10), Color("#424242"))
		draw_rect(Rect2(base.x + 4, base.y - 10, 10, 10), Color("#424242"))
		draw_circle(Vector2(base.x + 46, base.y - 14), 8.0, Color("#ff7043"))

	func _granja(base: Vector2) -> void:
		# Campos sembrados a la izquierda y el granero a la derecha.
		for i in 4:
			draw_rect(Rect2(base.x - 104, base.y - 60 + i * 15, 70, 11), Color("#c5e1a5") if i % 2 == 0 else Color("#fdd835"))
		draw_rect(Rect2(base.x - 104, base.y - 60, 70, 56), VistaCiudad.COLOR_TINTA, false, 2.0)
		_caja(Rect2(base.x - 24, base.y - 62, 104, 62), Color("#b23b2e"))
		_tejado(Vector2(base.x - 32, base.y - 62), Vector2(base.x + 88, base.y - 62), 36, Color("#6d2a20"))
		draw_rect(Rect2(base.x + 12, base.y - 40, 32, 40), Color("#f5e6c8"))
		draw_line(Vector2(base.x + 12, base.y - 40), Vector2(base.x + 44, base.y), Color("#b23b2e"), 3.0)
		draw_line(Vector2(base.x + 44, base.y - 40), Vector2(base.x + 12, base.y), Color("#b23b2e"), 3.0)

	func _mercado(base: Vector2) -> void:
		for puesto: float in [-52.0, 52.0]:
			var x := base.x + puesto
			draw_line(Vector2(x - 40, base.y), Vector2(x - 40, base.y - 62), VistaCiudad.COLOR_TINTA, 3.0)
			draw_line(Vector2(x + 40, base.y), Vector2(x + 40, base.y - 62), VistaCiudad.COLOR_TINTA, 3.0)
			# Toldo a rayas.
			for i in 4:
				var color := Color("#4fc3f7") if i % 2 == 0 else Color("#fafafa")
				draw_rect(Rect2(x - 44 + i * 22, base.y - 78, 22, 18), color)
			draw_rect(Rect2(x - 44, base.y - 78, 88, 18), VistaCiudad.COLOR_TINTA, false, 2.0)
			_caja(Rect2(x - 36, base.y - 26, 72, 26), Color("#a1887f"))
			draw_circle(Vector2(x - 16, base.y - 32), 7.0, Color("#ef5350"))
			draw_circle(Vector2(x + 2, base.y - 32), 7.0, Color("#ffca28"))
			draw_circle(Vector2(x + 20, base.y - 32), 7.0, Color("#9ccc65"))

	func _barracas(base: Vector2) -> void:
		_caja(Rect2(base.x - 90, base.y - 54, 180, 54), Color("#8d8170"))
		_caja(Rect2(base.x - 96, base.y - 66, 192, 12), Color("#5d4037"))
		for i in 4:
			draw_rect(Rect2(base.x - 70 + i * 40, base.y - 40, 16, 16), Color("#3e2723"))
		draw_line(Vector2(base.x + 70, base.y - 66), Vector2(base.x + 70, base.y - 116), VistaCiudad.COLOR_TINTA, 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x + 70, base.y - 116), Vector2(base.x + 104, base.y - 106), Vector2(base.x + 70, base.y - 96)]), Color("#ef5350"))
		# Lanzas apoyadas en la pared.
		for i in 3:
			var x := base.x - 82 + i * 10
			draw_line(Vector2(x, base.y), Vector2(x + 6, base.y - 72), Color("#6d4c41"), 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x + 3, base.y - 72), Vector2(x + 9, base.y - 72), Vector2(x + 7, base.y - 84)]), Color("#cfd8dc"))

	func _ruinas(base: Vector2) -> void:
		var piedra := Color("#6e6a72")
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - 70, base.y), Vector2(base.x - 70, base.y - 52), Vector2(base.x - 52, base.y - 40),
			Vector2(base.x - 40, base.y - 64), Vector2(base.x - 26, base.y - 30), Vector2(base.x - 26, base.y)]), piedra)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x + 18, base.y), Vector2(base.x + 18, base.y - 36), Vector2(base.x + 34, base.y - 48),
			Vector2(base.x + 46, base.y - 28), Vector2(base.x + 62, base.y - 40), Vector2(base.x + 62, base.y)]), piedra)
		for punto in [Vector2(-10, -6), Vector2(4, -10), Vector2(-2, -18), Vector2(76, -6), Vector2(-84, -6)]:
			draw_circle(base + punto, 7.0, Color("#57525c"))
		# Viga quemada cruzada.
		draw_line(Vector2(base.x - 44, base.y - 6), Vector2(base.x + 36, base.y - 30), Color("#3b2a1e"), 6.0)
