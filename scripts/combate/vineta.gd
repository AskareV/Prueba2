class_name Vineta
extends Node2D
## Oscurece los bordes de la pantalla para centrar la atención en el combate.

var tamano := Vector2(1280, 720)
var _textura: GradientTexture2D


func _init() -> void:
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(0, 0, 0, 0))
	gradiente.set_color(1, Color(0, 0, 0, 0.6))
	gradiente.add_point(0.55, Color(0, 0, 0, 0))
	_textura = GradientTexture2D.new()
	_textura.gradient = gradiente
	_textura.fill = GradientTexture2D.FILL_RADIAL
	_textura.fill_from = Vector2(0.5, 0.5)
	_textura.fill_to = Vector2(1.0, 1.0)
	_textura.width = 256
	_textura.height = 256


func ajustar(p_tamano: Vector2) -> void:
	tamano = p_tamano
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_textura, Rect2(Vector2.ZERO, tamano), false)
