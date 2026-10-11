class_name Antorchas
extends Node2D
## Dos antorchas en el muro con llama y luz que parpadean.

var tamano := Vector2(1280, 720)
var suelo_y := 512.0
var _tiempo := 0.0


func ajustar(p_tamano: Vector2, p_suelo_y: float) -> void:
	tamano = p_tamano
	suelo_y = p_suelo_y


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


func _draw() -> void:
	var altura := suelo_y - minf(250.0, suelo_y * 0.5)
	for i in 2:
		var x := tamano.x * (0.08 if i == 0 else 0.92)
		_dibujar_antorcha(Vector2(x, altura), i * 1.7)


func _dibujar_antorcha(posicion: Vector2, desfase: float) -> void:
	var parpadeo := 0.85 + 0.1 * sin(_tiempo * 9.0 + desfase) + 0.05 * sin(_tiempo * 23.0 + desfase * 2.0)
	# Luz sobre el muro.
	for capa in 7:
		var radio := (190.0 - capa * 24.0) * parpadeo
		draw_circle(posicion + Vector2(0, -10), radio, Color(1.0, 0.62, 0.25, 0.035))
	# Soporte y palo.
	draw_rect(Rect2(posicion.x - 14, posicion.y + 22, 28, 8), Color("#3b3024"))
	var palo := PackedVector2Array([
		posicion + Vector2(-6, 0), posicion + Vector2(6, 0), posicion + Vector2(3, 34), posicion + Vector2(-3, 34)])
	draw_colored_polygon(palo, Color("#5d4037"))
	# Llama en tres capas.
	var colores := [Color("#ff7043"), Color("#ffb74d"), Color("#fff3c4")]
	for capa in 3:
		var escala := (1.0 - capa * 0.28) * parpadeo
		var punta := posicion + Vector2(sin(_tiempo * 7.0 + desfase + capa) * 2.5, -34.0 * escala)
		var llama := PackedVector2Array([
			posicion + Vector2(-10 * escala, 0), punta, posicion + Vector2(10 * escala, 0),
			posicion + Vector2(5 * escala, 6), posicion + Vector2(-5 * escala, 6)])
		draw_colored_polygon(llama, colores[capa])
