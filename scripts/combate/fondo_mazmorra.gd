class_name FondoMazmorra
extends Node2D
## Muro de piedra y suelo de la mazmorra. Solo se redibuja al cambiar el tamaño.

const ALTO_PIEDRA := 34.0
const ANCHO_PIEDRA := 74.0

var tamano := Vector2(1280, 720)
var suelo_y := 512.0
var _piedras: Array[Dictionary] = []


func ajustar(p_tamano: Vector2, p_suelo_y: float) -> void:
	tamano = p_tamano
	suelo_y = p_suelo_y
	_generar_piedras()
	queue_redraw()


func _generar_piedras() -> void:
	_piedras.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fila := 0
	var y := suelo_y - ALTO_PIEDRA
	while y > -ALTO_PIEDRA:
		var x := -ANCHO_PIEDRA / 2.0 if fila % 2 == 1 else 0.0
		while x < tamano.x:
			var ancho := ANCHO_PIEDRA * rng.randf_range(0.85, 1.15)
			_piedras.append({
				"rect": Rect2(x + 2, y + 2, ancho - 4, ALTO_PIEDRA - 4),
				"brillo": rng.randf_range(-0.03, 0.03),
			})
			x += ancho
		y -= ALTO_PIEDRA
		fila += 1


func _draw() -> void:
	draw_rect(Rect2(0, 0, tamano.x, suelo_y), Color("#10121e"))
	for piedra in _piedras:
		var rect: Rect2 = piedra["rect"]
		var brillo: float = piedra["brillo"]
		var altura := clampf(rect.position.y / suelo_y, 0.0, 1.0)
		var color := Color("#1a1d30").lerp(Color("#2b2f4b"), altura)
		color += Color(brillo, brillo, brillo, 0.0)
		draw_rect(rect, color)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(1, 1, 1, 0.04), 1.0)

	# Suelo con líneas de perspectiva hacia el centro.
	var fondo := Rect2(0, suelo_y, tamano.x, tamano.y - suelo_y)
	draw_rect(fondo, Color("#151726"))
	var fuga := Vector2(tamano.x / 2.0, suelo_y - 260.0)
	var pasos := 14
	for i in pasos + 1:
		var abajo := Vector2(lerpf(-tamano.x * 0.6, tamano.x * 1.6, float(i) / pasos), tamano.y)
		var t := (suelo_y - fuga.y) / (abajo.y - fuga.y)
		var arriba := fuga.lerp(abajo, t)
		draw_line(arriba, abajo, Color(1, 1, 1, 0.045), 2.0)
	var y := suelo_y + 18.0
	var separacion := 18.0
	while y < tamano.y:
		draw_line(Vector2(0, y), Vector2(tamano.x, y), Color(1, 1, 1, 0.035), 2.0)
		separacion *= 1.35
		y += separacion
	draw_line(Vector2(0, suelo_y), Vector2(tamano.x, suelo_y), Color("#3a3f63"), 3.0)
