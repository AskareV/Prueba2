class_name UIReino
extends RefCounted
## Piezas de interfaz compartidas por las pantallas del reino (provisionales).
## Las pantallas se diseñan en un área de 1280×720 centrada, que siempre cabe.

const COLOR_TITULO := Color("#ffe082")
const COLOR_FONDO := Color("#120e18")
const COLOR_AVISO := Color("#ffcc80")
const ANCHO := 1280.0
const ALTO := 720.0


static func etiqueta(texto: String, tamano := 20, color := Estilo.TEXTO) -> Label:
	var nueva := Label.new()
	nueva.text = texto
	nueva.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nueva.add_theme_font_size_override("font_size", tamano)
	nueva.add_theme_color_override("font_color", color)
	return nueva


## Etiqueta de varias líneas que ajusta el texto al ancho dado.
static func parrafo(texto: String, ancho: float, tamano := 18, color := Estilo.TEXTO_SUAVE) -> Label:
	var nueva := etiqueta(texto, tamano, color)
	nueva.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nueva.custom_minimum_size = Vector2(ancho, 0)
	return nueva


static func boton(texto: String, al_pulsar: Callable, tamano: Vector2, fuente := 22) -> Button:
	var nuevo := Button.new()
	nuevo.text = texto
	nuevo.custom_minimum_size = tamano
	nuevo.add_theme_font_size_override("font_size", fuente)
	nuevo.pressed.connect(al_pulsar)
	return nuevo


static func panel() -> PanelContainer:
	var nuevo := PanelContainer.new()
	nuevo.mouse_filter = Control.MOUSE_FILTER_PASS
	return nuevo


## Área de 1280×720 centrada en la pantalla, donde se ubica todo el contenido.
static func area_centrada(padre: Control) -> Control:
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.set_anchors_preset(Control.PRESET_CENTER)
	area.offset_left = -ANCHO / 2.0
	area.offset_right = ANCHO / 2.0
	area.offset_top = -ALTO / 2.0
	area.offset_bottom = ALTO / 2.0
	padre.add_child(area)
	return area


## Fondo oscuro que cubre toda la pantalla.
static func fondo(padre: Control) -> void:
	var capa := ColorRect.new()
	capa.color = COLOR_FONDO
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(capa)


## Verde con poco estrés, amarillo a medio camino y rojo cerca del límite.
static func color_estres(estres: float) -> Color:
	var fraccion := estres / DatosAventura.ESTRES_MAXIMO
	if fraccion < 0.5:
		return Color("#66bb6a")
	if fraccion < 0.85:
		return Color("#ffca28")
	return Color("#ef5350")


static func barra_estres() -> Barra:
	var nueva := Barra.new()
	nueva.custom_minimum_size = Vector2(220, 26)
	nueva.tamano_fuente = 16
	return nueva


## Muestra el estrés en la barra: llena al llegar al límite de 70.
static func actualizar_estres(barra: Barra, estres: float) -> void:
	barra.valor = estres / DatosAventura.ESTRES_MAXIMO
	barra.color_fijo = color_estres(estres)
	barra.texto = "%d / %d" % [roundi(estres), roundi(DatosAventura.ESTRES_MAXIMO)]


## Ignora los toques un momento al entrar a una pantalla: un doble toque en la
## anterior no debe pulsar sin querer lo que quede debajo.
static func bloquear_toques(padre: Control, segundos := 0.45) -> void:
	var escudo := Control.new()
	escudo.set_anchors_preset(Control.PRESET_FULL_RECT)
	escudo.mouse_filter = Control.MOUSE_FILTER_STOP
	padre.add_child(escudo)
	padre.get_tree().create_timer(segundos).timeout.connect(escudo.queue_free)


## Botón de un objeto: franja del color de su calidad, nombre y dato principal.
static func boton_objeto(objeto: Dictionary, al_pulsar: Callable, tamano: Vector2) -> Button:
	var texto: String = objeto["nombre"]
	if objeto["ranura"] == "arma":
		texto += "\nDaño %d–%d" % [objeto["danio_min"], objeto["danio_max"]]
	else:
		texto += "\nArm. %d · Res. mág. %d" % [objeto["armadura"], objeto["resistencia_magica"]]
	var nuevo := boton(texto, al_pulsar, tamano, 16)
	nuevo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nuevo.clip_text = true
	Estilo.con_franja(nuevo, DatosBotin.color_calidad(objeto["calidad"]))
	return nuevo
