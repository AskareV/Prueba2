class_name Estilo
extends Node
## Tema visual de toda la interfaz. El autoload "Tema" lo aplica al iniciar;
## las funciones estáticas se usan con Estilo.caja(), Estilo.con_franja(), etc.

const FONDO_PANEL := Color(0.05, 0.06, 0.12, 0.9)
const BORDE_PANEL := Color(1, 1, 1, 0.12)
const TEXTO := Color("#eef0ff")
const TEXTO_SUAVE := Color("#aab2d6")

static var _tema: Theme


func _ready() -> void:
	get_tree().root.theme = tema()


## Tema compartido (se crea una sola vez).
static func tema() -> Theme:
	if _tema == null:
		_tema = crear_tema()
	return _tema


static func caja(fondo: Color, borde: Color, radio := 14, grosor := 2) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = fondo
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(radio)
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	estilo.anti_aliasing = true
	return estilo


static func crear_tema() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = 22
	tema.set_stylebox("normal", "Button", caja(Color("#283055"), Color("#3d4a80")))
	tema.set_stylebox("hover", "Button", caja(Color("#2d365f"), Color("#5566aa")))
	tema.set_stylebox("pressed", "Button", caja(Color("#3f4d8c"), Color("#ffd54f")))
	tema.set_stylebox("hover_pressed", "Button", caja(Color("#46559a"), Color("#ffd54f")))
	tema.set_stylebox("disabled", "Button", caja(Color("#1a1e33"), Color("#262c48")))
	tema.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	tema.set_color("font_color", "Button", TEXTO)
	tema.set_color("font_hover_color", "Button", Color.WHITE)
	tema.set_color("font_focus_color", "Button", TEXTO)
	tema.set_color("font_pressed_color", "Button", Color("#ffe082"))
	tema.set_color("font_hover_pressed_color", "Button", Color("#ffe082"))
	tema.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	tema.set_font_size("font_size", "Button", 24)
	tema.set_stylebox("panel", "PanelContainer", caja(FONDO_PANEL, BORDE_PANEL, 18))
	tema.set_stylebox("panel", "Panel", caja(FONDO_PANEL, BORDE_PANEL, 18))
	tema.set_color("font_color", "Label", TEXTO)
	tema.set_color("default_color", "RichTextLabel", TEXTO)
	tema.set_font_size("normal_font_size", "RichTextLabel", 20)
	return tema


## Botón con una franja de color a la izquierda (zonas, partes, armas).
## Toma los estilos del tema, no del botón, porque puede no estar aún en pantalla.
static func con_franja(boton: Button, color: Color) -> void:
	for estado in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var copia: StyleBoxFlat = tema().get_stylebox(estado, "Button").duplicate()
		copia.border_width_left = 10
		copia.content_margin_left = 24
		if estado == "disabled":
			copia.border_color = color.darkened(0.6)
		elif not estado.contains("pressed"):
			copia.border_color = color
		boton.add_theme_stylebox_override(estado, copia)
