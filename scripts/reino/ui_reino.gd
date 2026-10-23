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


## Barra con la vida del rey fuera del combate (las heridas duran).
static func barra_vida() -> Barra:
	var nueva := Barra.new()
	nueva.custom_minimum_size = Vector2(200, 26)
	nueva.tamano_fuente = 16
	return nueva


## "inmediato": sin animar (al abrir una pantalla).
static func actualizar_vida(barra: Barra, inmediato := false) -> void:
	var vida := Juego.vida_actual()
	var maxima := Juego.vida_maxima()
	barra.valor = float(vida) / maxima
	barra.texto = "%d / %d" % [vida, maxima]
	if inmediato:
		barra._mostrado = barra.valor


## Muestra el estrés en la barra: llena al llegar al límite de 70.
## "inmediato": sin animar (al abrir una pantalla).
static func actualizar_estres(barra: Barra, estres: float, inmediato := false) -> void:
	barra.valor = estres / DatosAventura.ESTRES_MAXIMO
	barra.color_fijo = color_estres(estres)
	# Hacia abajo: la barra no debe mostrar 70 mientras el rey sigue por debajo.
	barra.texto = "%d / %d" % [floori(estres), roundi(DatosAventura.ESTRES_MAXIMO)]
	if inmediato:
		barra._mostrado = barra.valor


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
	if DatosBotin.es_consumible(objeto):
		texto += "\n×%d · %s" % [int(objeto.get("cantidad", 1)), DatosBotin.CONSUMIBLES[objeto["ranura"]]["resumen"]]
	elif objeto["ranura"] == "arma":
		texto += "\nDaño %d–%d" % [objeto["danio_min"], objeto["danio_max"]]
	else:
		texto += "\nArm. %d · Res. mág. %d" % [objeto["armadura"], objeto["resistencia_magica"]]
	var nuevo := boton(texto, al_pulsar, tamano, 16)
	nuevo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nuevo.clip_text = true
	nuevo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Estilo.con_franja(nuevo, DatosBotin.color_calidad(objeto["calidad"]))
	return nuevo


## Botones para usar objetos entre combates (pociones, vendas, torniquetes y
## medicinas), con cuántos hay; los que ahora no servirían, apagados. "al_usar"
## recibe el tipo; "ancho" es el de cada botón.
static func lista_objetos(al_usar: Callable, ancho: float, columnas := 1) -> GridContainer:
	var lista := GridContainer.new()
	lista.columns = columnas
	lista.add_theme_constant_override("h_separation", 6)
	lista.add_theme_constant_override("v_separation", 6)
	for tipo in DatosBotin.ORDEN_CONSUMIBLES:
		var datos: Dictionary = DatosBotin.CONSUMIBLES[tipo]
		var nombre: String = "Poción" if tipo == "pocion" and columnas > 1 else datos["nombre"]
		var nuevo := boton("%s (%d)" % [nombre, Juego.cantidad(tipo)], al_usar.bind(tipo), Vector2(ancho, 42), 18)
		nuevo.focus_mode = Control.FOCUS_NONE
		nuevo.disabled = Juego.cantidad(tipo) == 0 or not Juego.sirve(tipo)
		Estilo.con_franja(nuevo, datos["color"])
		lista.add_child(nuevo)
	return lista


## Total de pociones, vendas, torniquetes y medicinas.
static func total_objetos() -> int:
	var total := 0
	for tipo in DatosBotin.ORDEN_CONSUMIBLES:
		total += Juego.cantidad(tipo)
	return total


## Una línea con la sangre, lo que sangra y las infecciones del rey ("" si está
## bien): "Sangre 82% (agitado) · sangras · infección leve".
static func texto_salud() -> String:
	var partes: PackedStringArray = []
	if Juego.sangre_perdida > 0.005:
		var texto := "Sangre %d%%" % roundi(Juego.fraccion_sangre() * 100.0)
		var estado := Juego.estado_sangre()
		if estado > 0:
			texto += " (%s)" % String(DatosHeridas.ESTADOS_SANGRE[estado]).to_lower()
		partes.append(texto)
	if DatosHeridas.hay_sangrado(Juego.sangrados, "externo"):
		partes.append("sangras")
	if DatosHeridas.hay_sangrado(Juego.sangrados, "interno"):
		partes.append("sangras por dentro")
	var etapa := Juego.peor_infeccion()
	if etapa > 0:
		partes.append(String(DatosHeridas.ETAPAS[etapa]).to_lower())
	if partes.is_empty():
		return ""
	var linea := " · ".join(partes)
	return linea[0].to_upper() + linea.substr(1)
