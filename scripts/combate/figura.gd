class_name Figura
extends Node2D
## Dibuja a un luchador con sus 21 partes, su arma y sus heridas, sin gore:
## las heridas se ven como tintes de color y pequeñas marcas.
## El origen del nodo está entre los pies; mira a la cámara, así que su lado
## derecho queda a la izquierda de la pantalla.

enum Modo { NORMAL, ZONAS, PARTES, OBJETIVO }

const CONTORNO := Color("#141726")
const COLOR_OJO := Color("#f4f1ea")
const COLOR_PUPILA := Color("#1b1d2b")
const COLOR_ACERO := Color("#cfd8dc")
const COLOR_ORO := Color("#ffcc33")

const COLORES_ZONA := {
	"cabeza": Color("#ffd54f"),
	"torso": Color("#ff8a65"),
	"brazo_der": Color("#4fc3f7"),
	"brazo_izq": Color("#b39ddb"),
	"pierna_der": Color("#81c784"),
	"pierna_izq": Color("#4db6ac"),
}
const COLORES_PARTE := [Color("#ffd54f"), Color("#4dd0e1"), Color("#f06292"), Color("#aed581")]
const COLORES_HERIDA := {
	"Corte": Color("#c62828"),
	"Contusión": Color("#6a3d9a"),
	"Perforación": Color("#8e1b2c"),
	"Fractura": Color("#4a3a75"),
}
## Cuánto se tiñe una parte según su nivel de herida (0 a 4).
const INTENSIDAD_HERIDA := [0.0, 0.2, 0.36, 0.5, 0.6]
const GRUPO_COLOR := {
	"craneo": "piel", "cuello": "piel", "torax": "torso", "abdomen": "torso",
	"hombro": "hombros", "brazo": "brazos", "antebrazo": "antebrazos", "mano": "manos",
	"muslo": "muslos", "espinilla": "espinillas", "pie": "pies",
}

var luchador: Luchador
var aspecto: Dictionary = {}
## true si su rival está a la derecha (hacia allá mira y embiste).
var mira_derecha := true
var modo := Modo.NORMAL
## Zona resaltada al apuntar (modos ZONAS y PARTES).
var zona_activa := ""
## Parte resaltada (modos PARTES y OBJETIVO).
var parte_activa := ""
## Escala en pantalla sin contar la respiración.
var escala_base := 1.0
## Desplazamiento temporal para animaciones (embestida, sacudida).
var desplazamiento := Vector2.ZERO

var _partes: Dictionary = {}
var _anclas: Dictionary = {}
var _centros: Dictionary = {}
var _areas: Dictionary = {}
## Heridas resumidas por parte (se recalculan solo cuando llega una nueva):
## parte -> {"conteo": {tipo: n}, "ultima": tipo}.
var _resumen_heridas: Dictionary = {}
var _heridas_resumidas := -1
var _lado_arma_dibujado := "?"
var _destellos: Dictionary = {}
var _tiempo := 0.0
var _caido := false


func configurar(p_luchador: Luchador, p_aspecto: Dictionary, p_mira_derecha: bool) -> void:
	luchador = p_luchador
	aspecto = p_aspecto
	mira_derecha = p_mira_derecha
	_tiempo = randf() * 10.0
	_reconstruir()
	queue_redraw()


func _process(delta: float) -> void:
	if luchador == null:
		return
	_tiempo += delta
	if _lado_arma_actual() != _lado_arma_dibujado:
		_reconstruir()
	if luchador.heridas.size() != _heridas_resumidas:
		_resumir_heridas()
	for parte_id in _destellos.keys():
		_destellos[parte_id] = maxf(float(_destellos[parte_id]) - delta * 3.5, 0.0)
		if _destellos[parte_id] <= 0.0:
			_destellos.erase(parte_id)
	if not _caido:
		scale = Vector2(escala_base, escala_base * (1.0 + sin(_tiempo * 2.3) * 0.009))
	queue_redraw()


# --- Consultas ---

## Parte del cuerpo bajo un punto en coordenadas globales, o "" si no hay ninguna.
func parte_en(punto_global: Vector2) -> String:
	var local := to_local(punto_global) - desplazamiento
	for i in range(PlantillaHumanoide.ORDEN.size() - 1, -1, -1):
		var parte_id: String = PlantillaHumanoide.ORDEN[i]
		for forma in _partes[parte_id]:
			if Geometry2D.is_point_in_polygon(local, forma):
				return parte_id
	return ""


func posicion_global_de(parte_id: String) -> Vector2:
	return to_global(_centros[parte_id] + desplazamiento)


## Parte de una zona que el dedo quiso tocar: la que contiene el punto o la que
## está a menos de "margen" píxeles de pantalla. Si hay varias, gana la más pequeña,
## para que ojos, manos y pies se puedan tocar. Devuelve "" si no hay ninguna.
func parte_cercana(punto_global: Vector2, zona_id: String, margen: float) -> String:
	var local := to_local(punto_global) - desplazamiento
	var margen_local := margen / maxf(global_scale.x, 0.01)
	var elegida := ""
	var area_elegida := INF
	for parte_id in DatosCuerpo.partes_de(zona_id):
		var distancia := INF
		for forma in _partes[parte_id]:
			distancia = minf(distancia, _distancia_a_forma(local, forma))
		var area: float = _areas[parte_id]
		if distancia <= margen_local and area < area_elegida:
			elegida = parte_id
			area_elegida = area
	return elegida


static func _distancia_a_forma(punto: Vector2, forma: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(punto, forma):
		return 0.0
	var minima := INF
	for i in forma.size():
		var cercano := Geometry2D.get_closest_point_to_segment(punto, forma[i], forma[(i + 1) % forma.size()])
		minima = minf(minima, punto.distance_to(cercano))
	return minima


## Rectángulo que ocupa una zona, en coordenadas locales (sin la escala del nodo).
func caja_zona(zona_id: String) -> Rect2:
	var caja := Rect2()
	var primera := true
	for parte_id in DatosCuerpo.partes_de(zona_id):
		for forma in _partes[parte_id]:
			for punto in forma:
				if primera:
					caja = Rect2(punto, Vector2.ZERO)
					primera = false
				else:
					caja = caja.expand(punto)
	return caja


# --- Animaciones ---

## Embestida hacia el rival. Devuelve el tween para esperar a que termine.
func embestir() -> Tween:
	var dx := 70.0 if mira_derecha else -70.0
	var tween := create_tween()
	tween.tween_property(self, "desplazamiento", Vector2(dx, -8), 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "desplazamiento", Vector2.ZERO, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween


func recibir_impacto(parte_id: String) -> void:
	_destellos[parte_id] = 1.0
	var atras := -1.0 if mira_derecha else 1.0
	var tween := create_tween()
	tween.tween_property(self, "desplazamiento", Vector2(10 * atras, 0), 0.05)
	tween.tween_property(self, "desplazamiento", Vector2(-5 * atras, 0), 0.06)
	tween.tween_property(self, "desplazamiento", Vector2.ZERO, 0.08)


## Cae hacia atrás, lejos del rival (vida en cero o inconsciente).
func caer() -> void:
	if _caido:
		return
	_caido = true
	var tween := create_tween()
	tween.tween_property(self, "rotation", -1.45 if mira_derecha else 1.45, 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Resalta en rojo la parte a la que apunta el rival ("" para quitarlo).
func marcar_objetivo(parte_id: String) -> void:
	if parte_id == "":
		modo = Modo.NORMAL
		parte_activa = ""
	else:
		modo = Modo.OBJETIVO
		parte_activa = parte_id


# --- Construcción ---

func _lado_arma_actual() -> String:
	return "" if luchador.desarmado else luchador.lado_arma()


func _reconstruir() -> void:
	_lado_arma_dibujado = _lado_arma_actual()
	var plantilla := PlantillaHumanoide.crear(aspecto.get("ancho", 1.0), aspecto.get("alto", 1.0), _lado_arma_dibujado)
	_partes = plantilla["partes"]
	_anclas = plantilla["anclas"]
	_centros.clear()
	_areas.clear()
	for parte_id in _partes:
		var formas: Array = _partes[parte_id]
		_centros[parte_id] = PlantillaHumanoide.centro(formas[formas.size() - 1])
		var area := 0.0
		for forma in formas:
			area += PlantillaHumanoide.area(forma)
		_areas[parte_id] = area


func _resumir_heridas() -> void:
	_resumen_heridas.clear()
	for herida in luchador.heridas:
		var parte_id: String = herida["parte"]
		if not _resumen_heridas.has(parte_id):
			_resumen_heridas[parte_id] = {"conteo": {}, "ultima": ""}
		var resumen: Dictionary = _resumen_heridas[parte_id]
		var conteo: Dictionary = resumen["conteo"]
		conteo[herida["tipo"]] = int(conteo.get(herida["tipo"], 0)) + 1
		resumen["ultima"] = herida["tipo"]
	_heridas_resumidas = luchador.heridas.size()


# --- Dibujo ---

func _draw() -> void:
	if luchador == null:
		return
	draw_set_transform(desplazamiento)
	_dibujar_sombra()
	_dibujar_detras()
	var mano_con_arma := "" if luchador.desarmado else luchador.mano_arma()
	for parte_id in PlantillaHumanoide.ORDEN:
		if parte_id == mano_con_arma:
			_dibujar_arma(luchador.arma, _anclas[parte_id], 0.21 * signf(_anclas[parte_id].x))
		_dibujar_parte(parte_id)
		if parte_id == "abdomen":
			_dibujar_cinturon()
	_dibujar_cara()
	_dibujar_accesorio()
	_dibujar_marcas()
	if luchador.desarmado:
		_dibujar_arma_en_suelo()
	if modo != Modo.NORMAL:
		_dibujar_resaltado()
	if luchador.defendiendo and not luchador.fuera_de_combate():
		_dibujar_guardia()
	if luchador.aturdido and not luchador.fuera_de_combate():
		_dibujar_estrellas()
	draw_set_transform(Vector2.ZERO)


func _dibujar_parte(parte_id: String) -> void:
	var color := _color_parte(parte_id)
	for forma in _partes[parte_id]:
		draw_colored_polygon(forma, color)
		_contorno(forma, CONTORNO, 2.0)


func _contorno(forma: PackedVector2Array, color: Color, grosor: float) -> void:
	var cerrada := forma.duplicate()
	cerrada.append(forma[0])
	draw_polyline(cerrada, color, grosor, true)


func _color_aspecto(clave: String) -> Color:
	return aspecto.get(clave, Color.GRAY)


func _color_parte(parte_id: String) -> Color:
	var nivel := luchador.nivel(parte_id)
	var color: Color
	if parte_id.begins_with("ojo_"):
		if nivel == 4 or luchador.desmayado:
			color = _color_aspecto("piel").darkened(0.12)
		else:
			color = COLOR_OJO.lerp(Color("#e57373"), 0.12 * nivel)
	else:
		color = _color_aspecto(GRUPO_COLOR[DatosCuerpo.base_de(parte_id)])
		if nivel > 0:
			var tono: Color = COLORES_HERIDA.get(_herida_principal(parte_id), COLORES_HERIDA["Corte"])
			color = color.lerp(tono, INTENSIDAD_HERIDA[nivel])
			if nivel == 4:
				color = color.darkened(0.3)
	var destello: float = _destellos.get(parte_id, 0.0)
	if destello > 0.0:
		color = color.lerp(Color.WHITE, destello * 0.85)
	return color


func _herida_principal(parte_id: String) -> String:
	if luchador.fracturas.has(parte_id):
		return "Fractura"
	if _resumen_heridas.has(parte_id):
		return _resumen_heridas[parte_id]["ultima"]
	return "Corte"


func _escala_aspecto() -> Vector2:
	return Vector2(aspecto.get("ancho", 1.0), aspecto.get("alto", 1.0))


func _dibujar_sombra() -> void:
	var sombra := PlantillaHumanoide.elipse(Vector2(0, -2), 72.0 * _escala_aspecto().x, 12.0)
	draw_colored_polygon(sombra, Color(0, 0, 0, 0.35))


## Lo que va detrás del cuerpo: capa y parte trasera de la capucha.
func _dibujar_detras() -> void:
	if aspecto.has("capa"):
		var capa := PlantillaHumanoide.escalar(PackedVector2Array([
			Vector2(-44, -302), Vector2(44, -302), Vector2(72, -118), Vector2(36, -104),
			Vector2(0, -112), Vector2(-36, -104), Vector2(-72, -118)]), _escala_aspecto())
		draw_colored_polygon(capa, aspecto["capa"])
		_contorno(capa, CONTORNO, 2.0)
	if aspecto.get("accesorio", "") == "capucha":
		var cabeza: Vector2 = _anclas["cabeza"]
		var radio: Vector2 = _anclas["radio_cabeza"]
		var capucha := PlantillaHumanoide.elipse(cabeza + Vector2(0, -2), radio.x + 8, radio.y + 7)
		draw_colored_polygon(capucha, aspecto["accesorio_color"])
		_contorno(capucha, CONTORNO, 2.0)


func _dibujar_cinturon() -> void:
	var cintura: Vector2 = _anclas["cintura"]
	var ancho := 44.0 * _escala_aspecto().x
	var banda := Rect2(cintura.x - ancho, cintura.y - 6, ancho * 2.0, 11)
	draw_rect(banda, aspecto.get("cinturon", Color("#2e2219")))
	draw_rect(banda, CONTORNO, false, 1.5)
	var hebilla := Rect2(cintura.x - 7, cintura.y - 7, 14, 13)
	draw_rect(hebilla, COLOR_ORO.darkened(0.15))
	draw_rect(hebilla, CONTORNO, false, 1.5)


func _dibujar_cara() -> void:
	var mirada := 1.0 if mira_derecha else -1.0
	var enojado := not luchador.es_jugador
	for lado in ["der", "izq"]:
		var ojo_id: String = "ojo_" + lado
		var centro: Vector2 = _anclas[ojo_id]
		if luchador.esta_inutilizada(ojo_id) or luchador.desmayado:
			draw_line(centro + Vector2(-5, 0.5), centro + Vector2(5, 0.5), CONTORNO, 2.0, true)
		else:
			draw_circle(centro + Vector2(2.2 * mirada, 0.6), 2.7, COLOR_PUPILA)
		# Ceja: el extremo interior baja en los rivales (gesto de enojo).
		var interior := 1.0 if lado == "der" else -1.0
		var caida := 3.5 if enojado else 0.0
		draw_line(centro + Vector2(-6 * interior, -9), centro + Vector2(6 * interior, -9 + caida), CONTORNO, 2.5, true)
	var boca: Vector2 = _anclas["boca"]
	if luchador.desmayado:
		draw_circle(boca, 3.0, CONTORNO)
	elif enojado:
		draw_arc(boca + Vector2(0, 7), 8.0, PI * 1.3, PI * 1.7, 8, CONTORNO, 2.0, true)
	else:
		draw_arc(boca + Vector2(0, -6), 8.0, PI * 0.3, PI * 0.7, 8, CONTORNO, 2.0, true)


func _dibujar_accesorio() -> void:
	var cabeza: Vector2 = _anclas["cabeza"]
	var radio: Vector2 = _anclas["radio_cabeza"]
	match aspecto.get("accesorio", ""):
		"corona":
			_dibujar_pelo(cabeza, radio, aspecto.get("pelo", Color("#5b3a21")))
			_dibujar_corona(cabeza, radio)
		"capucha":
			_dibujar_pelo(cabeza, radio + Vector2(4, 3), aspecto["accesorio_color"])
			_dibujar_panuelo(cabeza, radio)
		"colmillos":
			_dibujar_mono(cabeza, radio)
			_dibujar_colmillos()
		"casco":
			_dibujar_casco(cabeza, radio)


## Pelo (o frente de la capucha): cubre la parte de arriba de la cabeza.
func _dibujar_pelo(cabeza: Vector2, radio: Vector2, color: Color) -> void:
	var forma := PlantillaHumanoide.arco(cabeza, radio.x + 2, radio.y + 3, PI + 0.25, TAU - 0.25, 18)
	forma.append(cabeza + Vector2(radio.x * 0.6, -radio.y * 0.42))
	forma.append(cabeza + Vector2(0, -radio.y * 0.33))
	forma.append(cabeza + Vector2(-radio.x * 0.6, -radio.y * 0.42))
	draw_colored_polygon(forma, color)
	_contorno(forma, CONTORNO, 2.0)


func _dibujar_corona(cabeza: Vector2, radio: Vector2) -> void:
	var base_y := cabeza.y - radio.y + 5
	var ancho := radio.x * 0.78
	var corona := PackedVector2Array([
		Vector2(-ancho, base_y), Vector2(-ancho, base_y - 18), Vector2(-ancho * 0.5, base_y - 9),
		Vector2(0, base_y - 23), Vector2(ancho * 0.5, base_y - 9), Vector2(ancho, base_y - 18),
		Vector2(ancho, base_y)])
	draw_colored_polygon(corona, COLOR_ORO)
	_contorno(corona, CONTORNO, 2.0)
	draw_circle(Vector2(0, base_y - 6), 3.5, Color("#e53935"))
	draw_circle(Vector2(-ancho * 0.6, base_y - 5), 2.5, Color("#42a5f5"))
	draw_circle(Vector2(ancho * 0.6, base_y - 5), 2.5, Color("#42a5f5"))


## Pañuelo que tapa la boca del bandido.
func _dibujar_panuelo(cabeza: Vector2, radio: Vector2) -> void:
	var forma := PlantillaHumanoide.arco(cabeza, radio.x + 1, radio.y + 1, 0.28, PI - 0.28, 14)
	draw_colored_polygon(forma, aspecto.get("panuelo", Color("#9e2a2b")))
	_contorno(forma, CONTORNO, 2.0)


## Moño del orco.
func _dibujar_mono(cabeza: Vector2, radio: Vector2) -> void:
	var mono := PlantillaHumanoide.elipse(cabeza + Vector2(0, -radio.y - 6), 9, 11)
	draw_colored_polygon(mono, aspecto.get("pelo", Color("#1e1e1e")))
	_contorno(mono, CONTORNO, 2.0)


func _dibujar_colmillos() -> void:
	var boca: Vector2 = _anclas["boca"]
	for lado in [-1.0, 1.0]:
		var colmillo := PackedVector2Array([
			boca + Vector2(7 * lado, 1), boca + Vector2(12 * lado, 1), boca + Vector2(10 * lado, -9)])
		draw_colored_polygon(colmillo, COLOR_OJO)
		_contorno(colmillo, CONTORNO, 1.5)


func _dibujar_casco(cabeza: Vector2, radio: Vector2) -> void:
	var color: Color = aspecto.get("accesorio_color", COLOR_ACERO)
	var cupula := PlantillaHumanoide.arco(cabeza, radio.x + 3, radio.y + 3, PI + 0.18, TAU - 0.18, 20)
	draw_colored_polygon(cupula, color)
	_contorno(cupula, CONTORNO, 2.0)
	var borde_y := cabeza.y - (radio.y + 3) * sin(0.18)
	var borde := Rect2(cabeza.x - radio.x - 5, borde_y - 3, (radio.x + 5) * 2.0, 7)
	draw_rect(borde, color.darkened(0.2))
	draw_rect(borde, CONTORNO, false, 1.5)
	var nasal := Rect2(cabeza.x - 3, borde_y, 6, 17)
	draw_rect(nasal, color.darkened(0.1))
	draw_rect(nasal, CONTORNO, false, 1.5)


## Dibuja un arma con el mango en "origen". "giro" en radianes (0 = hacia arriba).
func _dibujar_arma(arma_id: String, origen: Vector2, giro: float, escala := 1.0) -> void:
	draw_set_transform(desplazamiento + origen, giro, Vector2(escala, escala))
	match arma_id:
		"espada":
			draw_rect(Rect2(-3.5, -4, 7, 24), Color("#5d4037"))
			draw_circle(Vector2(0, 22), 5.0, COLOR_ORO.darkened(0.1))
			var hoja := PackedVector2Array([
				Vector2(-5.5, -12), Vector2(5.5, -12), Vector2(4.5, -110), Vector2(0, -126), Vector2(-4.5, -110)])
			draw_colored_polygon(hoja, COLOR_ACERO)
			_contorno(hoja, CONTORNO, 2.0)
			draw_line(Vector2(0, -16), Vector2(0, -106), Color("#90a4ae"), 1.5)
			var guarda := Rect2(-17, -15, 34, 7)
			draw_rect(guarda, COLOR_ORO.darkened(0.1))
			draw_rect(guarda, CONTORNO, false, 1.5)
		"maza":
			var mango := Rect2(-4, -72, 8, 94)
			draw_rect(mango, Color("#6d4c41"))
			draw_rect(mango, CONTORNO, false, 1.5)
			var centro := Vector2(0, -86)
			for i in 6:
				var angulo := TAU * i / 6.0
				var pua := PackedVector2Array([
					centro + Vector2.from_angle(angulo - 0.28) * 13, centro + Vector2.from_angle(angulo) * 25,
					centro + Vector2.from_angle(angulo + 0.28) * 13])
				draw_colored_polygon(pua, COLOR_ACERO.darkened(0.25))
				_contorno(pua, CONTORNO, 1.5)
			draw_circle(centro, 16.0, Color("#8d939b"))
			draw_arc(centro, 16.0, 0.0, TAU, 28, CONTORNO, 2.0, true)
		"lanza":
			var asta := Rect2(-3, -150, 6, 212)
			draw_rect(asta, Color("#8d6e63"))
			draw_rect(asta, CONTORNO, false, 1.5)
			var punta := PackedVector2Array([
				Vector2(0, -186), Vector2(9, -164), Vector2(4, -148), Vector2(-4, -148), Vector2(-9, -164)])
			draw_colored_polygon(punta, COLOR_ACERO)
			_contorno(punta, CONTORNO, 2.0)
			draw_rect(Rect2(-5, -153, 10, 8), Color("#5d4037"))
	draw_set_transform(desplazamiento)


## Arma caída junto a los pies, del lado de la mano que la tenía.
func _dibujar_arma_en_suelo() -> void:
	var izquierda_pantalla := luchador.lado_arma() == "der"
	var signo := -1.0 if izquierda_pantalla else 1.0
	var posicion := Vector2(signo * 96.0 * _escala_aspecto().x, -8.0)
	_dibujar_arma(luchador.arma, posicion, PI / 2.0 * signo, 0.85)


## Marcas pequeñas y sin sangre: líneas para cortes, puntos para perforaciones,
## zigzag para fracturas.
func _dibujar_marcas() -> void:
	for parte_id in _centros:
		if parte_id.begins_with("ojo_") or luchador.nivel(parte_id) == 0:
			continue
		if not _resumen_heridas.has(parte_id):
			continue
		var centro: Vector2 = _centros[parte_id]
		var conteo: Dictionary = _resumen_heridas[parte_id]["conteo"]
		var cortes := mini(int(conteo.get("Corte", 0)), 3)
		for i in cortes:
			var y := (i - (cortes - 1) / 2.0) * 6.0
			draw_line(centro + Vector2(-6, y - 3), centro + Vector2(6, y + 3), Color("#7f0000"), 2.0, true)
		var perforaciones := mini(int(conteo.get("Perforación", 0)), 3)
		for i in perforaciones:
			draw_circle(centro + Vector2((i - (perforaciones - 1) / 2.0) * 7.0, 0), 2.6, Color("#5a0010"))
		if luchador.fracturas.has(parte_id):
			var zigzag := PackedVector2Array([
				centro + Vector2(-7, -5), centro + Vector2(-2, 1), centro + Vector2(2, -3), centro + Vector2(7, 4)])
			draw_polyline(zigzag, Color("#241a45"), 2.5, true)


func _dibujar_resaltado() -> void:
	var pulso := 0.5 + 0.5 * sin(_tiempo * 6.0)
	for parte_id in PlantillaHumanoide.ORDEN:
		var zona_id := DatosCuerpo.zona_de(parte_id)
		var color := Color.BLACK
		var alfa := 0.0
		var con_borde := false
		match modo:
			Modo.ZONAS:
				color = COLORES_ZONA[zona_id]
				alfa = 0.3 + 0.15 * pulso
				if zona_id == zona_activa:
					alfa = 0.65
					con_borde = true
			Modo.PARTES:
				if zona_id == zona_activa:
					var indice := DatosCuerpo.partes_de(zona_id).find(parte_id)
					color = COLORES_PARTE[indice % COLORES_PARTE.size()]
					alfa = 0.75 if parte_id == parte_activa else 0.38 + 0.2 * pulso
					con_borde = true
				else:
					alfa = 0.4
			Modo.OBJETIVO:
				if parte_id != parte_activa:
					continue
				color = Color("#ff5252")
				alfa = 0.45 + 0.3 * pulso
				con_borde = true
		for forma in _partes[parte_id]:
			draw_colored_polygon(forma, Color(color, alfa))
			if con_borde:
				_contorno(forma, color.lightened(0.35), 3.0)


## Escudo translúcido delante del cuerpo mientras está en guardia.
func _dibujar_guardia() -> void:
	var centro := Vector2(0, -250) * _escala_aspecto()
	var desde := -0.95 if mira_derecha else PI - 0.95
	var color := Color("#64b5f6")
	draw_arc(centro, 104.0, desde, desde + 1.9, 24, Color(color, 0.85), 5.0, true)
	draw_arc(centro, 94.0, desde + 0.15, desde + 1.75, 24, Color(color, 0.4), 3.0, true)


## Estrellas girando sobre la cabeza mientras está aturdido.
func _dibujar_estrellas() -> void:
	var cabeza: Vector2 = _anclas["cabeza"]
	var radio: Vector2 = _anclas["radio_cabeza"]
	for i in 3:
		var angulo := _tiempo * 3.0 + TAU * i / 3.0
		var centro := cabeza + Vector2(cos(angulo) * radio.x * 1.25, -radio.y * 1.15 + sin(angulo) * 7.0)
		var estrella := PackedVector2Array()
		for punta in 10:
			var largo := 7.0 if punta % 2 == 0 else 3.0
			estrella.append(centro + Vector2.from_angle(-PI / 2.0 + TAU * punta / 10.0) * largo)
		draw_colored_polygon(estrella, Color("#ffeb3b"))
