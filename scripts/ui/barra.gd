class_name Barra
extends Control
## Barra de valor de 0 a 1 (vida o funciones) que se anima al cambiar.

## Valor de 0 a 1.
var valor := 1.0:
	set(nuevo):
		valor = clampf(nuevo, 0.0, 1.0)
		queue_redraw()
## Texto centrado sobre la barra (opcional).
var texto := "":
	set(nuevo):
		texto = nuevo
		queue_redraw()
var tamano_fuente := 18
## Si tiene alfa > 0, se usa este color; si no, verde, amarillo o rojo según el valor.
var color_fijo := Color(0, 0, 0, 0)
var _mostrado := 1.0


static func color_para(fraccion: float) -> Color:
	if fraccion > 0.6:
		return Color("#66bb6a")
	if fraccion > 0.3:
		return Color("#ffca28")
	return Color("#ef5350")


func _process(delta: float) -> void:
	if not is_equal_approx(_mostrado, valor):
		_mostrado = move_toward(_mostrado, valor, delta * 1.2)
		queue_redraw()


func _draw() -> void:
	var radio := int(minf(size.y / 2.0, 8.0))
	draw_style_box(_caja(Color(0, 0, 0, 0.5), radio), Rect2(Vector2.ZERO, size))
	if _mostrado > 0.001:
		var ancho := maxf(size.x * _mostrado, radio * 2.0)
		var color := color_fijo if color_fijo.a > 0.0 else color_para(_mostrado)
		draw_style_box(_caja(color, radio), Rect2(0, 0, ancho, size.y))
	if texto != "":
		var fuente := get_theme_default_font()
		var medida := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente)
		var alto_texto := fuente.get_ascent(tamano_fuente) + fuente.get_descent(tamano_fuente)
		var posicion := Vector2((size.x - medida.x) / 2.0, (size.y - alto_texto) / 2.0 + fuente.get_ascent(tamano_fuente))
		draw_string_outline(fuente, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente, 5, Color(0, 0, 0, 0.75))
		draw_string(fuente, posicion, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente, Color.WHITE)


func _caja(color: Color, radio: int) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = color
	caja.set_corner_radius_all(radio)
	caja.anti_aliasing = true
	return caja
