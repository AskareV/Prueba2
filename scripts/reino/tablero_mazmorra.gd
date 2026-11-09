class_name TableroMazmorra
extends Control
## Dibuja la cuadrícula de la mazmorra (como en My Pet Protector): lo no
## descubierto es oscuro; al caminar se descubren las casillas de alrededor.
## Cada estilo (ver GeneradorMazmorra) tiene su aspecto: la cueva, tierra y
## roca; la mina, vigas, rieles y campamentos; el fuerte, la empalizada, el
## patio, las chozas y las atalayas; el castillo, losas, muros de piedra, la
## alfombra, puertas, antorchas y estandartes. En el laberinto de antes, el
## suelo es piedra clara y un muro sigue oscuro aunque esté al lado.
## Espadas cruzadas = enemigo, calavera sobre las espadas = el jefe, cofre =
## tesoro, H = salida. Tocar una casilla vecina pide moverse hacia ella. Todo es
## dibujo de código, provisional.

signal mover(direccion: Vector2i)

const COLOR_OSCURO := Color("#151a17")
const COLOR_JUNTA := Color("#0c0f0d")
const COLOR_SUELO := Color("#cfc6b0")
const COLOR_SUELO_BORDE := Color("#a99f87")
const COLOR_SALIDA := Color("#43a047")

## Colores de cada estilo. "oscuro": lo no descubierto.
const PALETAS := {
	"cueva": {
		"oscuro": Color("#100c0a"), "suelo": Color("#a58d6f"), "suelo_borde": Color("#917a5e"),
		"piedrita": Color("#7d6a54"), "roca": Color("#4b3f36"), "roca_luz": Color("#64554a"),
		"roca_sombra": Color("#2f2722"), "hongo": Color("#4dd0e1"), "hongo_pie": Color("#e0f7fa"),
		"hueso": Color("#e8e0cc"),
	},
	"mina": {
		"oscuro": Color("#0f0d0c"), "suelo": Color("#9b8670"), "suelo_borde": Color("#86735e"),
		"piedrita": Color("#7a6855"), "roca": Color("#4f4640"), "roca_luz": Color("#665b53"),
		"roca_sombra": Color("#312b27"), "mineral": Color("#b5651d"), "madera": Color("#8a5a33"),
		"madera_oscura": Color("#5c3a1f"), "riel": Color("#a7adb3"), "campamento": Color("#ad977b"),
		"manta": Color("#6d8b74"),
	},
	"fuerte": {
		"oscuro": Color("#0e0f0b"), "suelo": Color("#b49f72"), "suelo_borde": Color("#9f8b62"),
		"pasto": Color("#7d8a45"), "tronco": Color("#7b5232"), "tronco_luz": Color("#a06d44"),
		"tronco_sombra": Color("#4f331d"), "paja": Color("#c9a54e"), "paja_oscura": Color("#9c7c32"),
		"tablas": Color("#c4a57a"), "tablas_junta": Color("#9a7d55"),
	},
	"castillo": {
		"oscuro": Color("#0c0c10"), "suelo": Color("#aaa69e"), "suelo_borde": Color("#8f8b83"),
		"losa_oscura": Color("#9a968e"), "piedra": Color("#575c6b"), "piedra_luz": Color("#6c7283"),
		"junta": Color("#3b3f4a"), "alfombra": Color("#8e1f2b"), "alfombra_borde": Color("#c9a227"),
		"madera": Color("#6d4c41"), "madera_oscura": Color("#3e2723"), "llama": Color("#ffb300"),
		"llama_centro": Color("#fff59d"), "estandarte": Color("#5e2a7e"), "oro": Color("#e0b43a"),
	},
}

var plano: Dictionary = {}
var visibles: Dictionary = {}
var posicion_rey := Vector2i.ZERO
var lado := 62.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func actualizar(p_plano: Dictionary, p_visibles: Dictionary, p_posicion: Vector2i) -> void:
	plano = p_plano
	visibles = p_visibles
	posicion_rey = p_posicion
	lado = minf(size.x / GeneradorMazmorra.ANCHO, size.y / GeneradorMazmorra.ALTO)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var boton := event as InputEventMouseButton
	if boton.button_index != MOUSE_BUTTON_LEFT or boton.pressed:
		return
	var celda := Vector2i(floori(boton.position.x / lado), floori(boton.position.y / lado))
	var diferencia := celda - posicion_rey
	if absi(diferencia.x) + absi(diferencia.y) == 1:
		accept_event()
		mover.emit(diferencia)


func _draw() -> void:
	if plano.is_empty():
		return
	var celdas: Array = plano["celdas"]
	var estilo: String = plano.get("estilo", "laberinto")
	var paleta: Dictionary = PALETAS.get(estilo, {})
	for y in GeneradorMazmorra.ALTO:
		for x in GeneradorMazmorra.ANCHO:
			var celda := Vector2i(x, y)
			var rect := Rect2(Vector2(x, y) * lado, Vector2(lado, lado))
			var suelo: bool = celdas[y][x] == GeneradorMazmorra.Celda.SUELO
			if not visibles.has(celda) or (paleta.is_empty() and not suelo):
				draw_rect(rect, paleta.get("oscuro", COLOR_OSCURO))
				draw_rect(rect, COLOR_JUNTA, false, 1.0)
			elif paleta.is_empty():
				draw_rect(rect, COLOR_SUELO)
				draw_rect(rect.grow(-1.0), COLOR_SUELO_BORDE, false, 2.0)
			elif suelo:
				_dibujar_suelo(estilo, paleta, celda, rect)
			else:
				_dibujar_muro(estilo, paleta, celda, rect)
			if visibles.has(celda) and suelo:
				_dibujar_contenido(celda, rect)
	# Lo que ocupa más de una casilla va encima: el techo de las atalayas.
	if estilo == "fuerte":
		for celda in plano.get("aspecto", {}):
			if _que(celda) == "atalaya" and _que(celda + Vector2i.LEFT) != "atalaya" and _que(celda + Vector2i.UP) != "atalaya" \
					and _visible_entera(celda):
				_techo_atalaya(paleta, Vector2(celda) * lado + Vector2.ONE * lado)
	_dibujar_rey(Rect2(Vector2(posicion_rey) * lado, Vector2(lado, lado)))


## Las cuatro casillas de la atalaya que empieza en esa esquina ya se descubrieron.
func _visible_entera(esquina: Vector2i) -> bool:
	for d in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		if not visibles.has(esquina + d):
			return false
	return true


## Qué es esa casilla según el plano ("" si nada en especial).
func _que(celda: Vector2i) -> String:
	return plano.get("aspecto", {}).get(celda, "")


## Número de 0 a 1 que siempre es el mismo para esa casilla (para los detalles
## del dibujo: piedritas, grietas, pasto).
static func _azar(celda: Vector2i, n: int) -> float:
	return float(absi(hash(Vector3i(celda.x, celda.y, n))) % 10000) / 10000.0


# --- Suelo ---

func _dibujar_suelo(estilo: String, paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	var que := _que(celda)
	draw_rect(rect, paleta["suelo"])
	match estilo:
		"cueva":
			# Un poco más clara o más oscura cada casilla, y la roca que asoma en
			# los bordes que tocan pared: así los túneles no quedan derechos.
			draw_rect(rect, Color(paleta["suelo"]).darkened(0.08 * _azar(celda, 6)))
			_piedritas(paleta["piedrita"], celda, rect)
			_bordes_de_roca(paleta, celda, rect)
			if celda != plano["entrada"] and not _ocupada(celda):
				if _azar(celda, 7) < 0.12:
					_hongos(paleta, rect, celda)
				elif _azar(celda, 7) < 0.18:
					_hueso(paleta["hueso"], rect, celda)
		"mina":
			if que == "campamento" or que == "fogata":
				draw_rect(rect, paleta["campamento"])
			_piedritas(paleta["piedrita"], celda, rect)
			match que:
				"riel":
					_rieles(paleta, rect)
				"galeria":
					if (celda.x + celda.y) % 3 == 0:
						_viga(paleta, rect, true)
				"pozo":
					if celda.y % 2 == 0:
						_viga(paleta, rect, false)
				"fogata":
					_fogata(rect)
				"campamento":
					if _azar(celda, 3) < 0.5 and not _ocupada(celda):
						_manta(paleta["manta"], rect)
		"fuerte":
			match que:
				"interior", "puerta":
					_tablas(paleta, rect)
					if que == "puerta":
						_marco_puerta(paleta["tronco_sombra"], celda, rect)
				"porton":
					_porton(paleta, rect)
				_:
					if _azar(celda, 5) < 0.3:
						_pasto(paleta["pasto"], rect, celda)
		"castillo":
			match que:
				"alfombra":
					_losas(paleta, celda, rect)
					_alfombra(paleta, celda, rect)
				"salon", "trono":
					_damero(paleta, celda, rect)
					if que == "trono":
						_trono(paleta, rect)
				"puerta":
					_losas(paleta, celda, rect)
					_marco_puerta(paleta["madera_oscura"], celda, rect)
				_:
					_losas(paleta, celda, rect)
	draw_rect(rect, Color(paleta["suelo_borde"], 0.45), false, 1.0)


## Enemigo, cofre o la H: ahí no se dibujan adornos que estorben.
func _ocupada(celda: Vector2i) -> bool:
	return plano["enemigos"].has(celda) or plano["cofres"].has(celda)


## Peñascos de la pared que asoman en el suelo, en los lados que tocan pared.
func _bordes_de_roca(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	var celdas: Array = plano["celdas"]
	for d in GeneradorMazmorra.DIRECCIONES:
		if GeneradorMazmorra.es_suelo(celdas, celda + d):
			continue
		var direccion := Vector2(d)
		var borde := rect.get_center() + direccion * lado * 0.5
		var a_lo_largo := direccion.orthogonal()
		for i in 2:
			var desplazamiento := (_azar(celda + d, 120 + i) - 0.5) * lado * 0.8
			var radio := lado * (0.08 + 0.07 * _azar(celda + d, 130 + i))
			draw_circle(borde + a_lo_largo * desplazamiento, radio, paleta["roca"])


func _piedritas(color: Color, celda: Vector2i, rect: Rect2) -> void:
	for i in 3:
		var punto := rect.position + Vector2(_azar(celda, 20 + i), _azar(celda, 30 + i)) * lado * 0.8 + Vector2.ONE * lado * 0.1
		draw_circle(punto, lado * (0.025 + 0.02 * _azar(celda, 40 + i)), color)


func _hongos(paleta: Dictionary, rect: Rect2, celda: Vector2i) -> void:
	var base := rect.position + Vector2(lado * (0.2 + 0.15 * _azar(celda, 8)), lado * 0.78)
	for i in 2:
		var pie := base + Vector2(lado * 0.14 * i, -lado * 0.04 * i)
		draw_line(pie, pie + Vector2(0, -lado * 0.1), paleta["hongo_pie"], 2.0)
		draw_circle(pie + Vector2(0, -lado * 0.12), lado * 0.06, paleta["hongo"])


func _hueso(color: Color, rect: Rect2, celda: Vector2i) -> void:
	var centro := rect.position + Vector2(lado * (0.3 + 0.4 * _azar(celda, 9)), lado * 0.75)
	var mitad := Vector2(lado * 0.12, -lado * 0.04)
	draw_line(centro - mitad, centro + mitad, color, 3.0, true)
	for punta in [centro - mitad, centro + mitad]:
		draw_circle(punta, lado * 0.035, color)


func _rieles(paleta: Dictionary, rect: Rect2) -> void:
	for i in 3:
		var x := rect.position.x + lado * (0.17 + 0.33 * i)
		draw_line(Vector2(x, rect.position.y + lado * 0.28), Vector2(x, rect.end.y - lado * 0.28), paleta["madera_oscura"], 4.0)
	for y in [0.36, 0.64]:
		draw_line(Vector2(rect.position.x, rect.position.y + lado * y), Vector2(rect.end.x, rect.position.y + lado * y),
			paleta["riel"], 2.5)


## Marco de madera que sostiene el techo del túnel: dos postes a los costados y
## un travesaño ("horizontal": el túnel va de lado a lado).
func _viga(paleta: Dictionary, rect: Rect2, horizontal: bool) -> void:
	var grueso := lado * 0.12
	if horizontal:
		var x := rect.get_center().x - grueso / 2.0
		draw_rect(Rect2(x, rect.position.y, grueso, lado), paleta["madera"])
		draw_rect(Rect2(x, rect.position.y, grueso, lado * 0.14), paleta["madera_oscura"])
		draw_rect(Rect2(x, rect.end.y - lado * 0.14, grueso, lado * 0.14), paleta["madera_oscura"])
	else:
		var y := rect.get_center().y - grueso / 2.0
		draw_rect(Rect2(rect.position.x, y, lado, grueso), paleta["madera"])
		draw_rect(Rect2(rect.position.x, y, lado * 0.14, grueso), paleta["madera_oscura"])
		draw_rect(Rect2(rect.end.x - lado * 0.14, y, lado * 0.14, grueso), paleta["madera_oscura"])


func _fogata(rect: Rect2) -> void:
	var centro := rect.get_center()
	for lado_x in [-1.0, 1.0]:
		draw_line(centro + Vector2(-lado * 0.2 * lado_x, lado * 0.15), centro + Vector2(lado * 0.2 * lado_x, -lado * 0.02),
			Color("#5d4037"), 5.0)
	draw_circle(centro + Vector2(0, -lado * 0.04), lado * 0.13, Color("#ff7043"))
	draw_circle(centro + Vector2(0, -lado * 0.02), lado * 0.07, Color("#ffd54f"))


func _manta(color: Color, rect: Rect2) -> void:
	var manta := Rect2(rect.position + Vector2(lado * 0.18, lado * 0.3), Vector2(lado * 0.64, lado * 0.4))
	draw_rect(manta, color)
	draw_rect(Rect2(manta.position, Vector2(lado * 0.16, manta.size.y)), color.lightened(0.3))


func _tablas(paleta: Dictionary, rect: Rect2) -> void:
	draw_rect(rect, paleta["tablas"])
	for i in range(1, 4):
		var y := rect.position.y + lado * 0.25 * i
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), paleta["tablas_junta"], 1.5)


func _pasto(color: Color, rect: Rect2, celda: Vector2i) -> void:
	var base := rect.position + Vector2(lado * (0.2 + 0.5 * _azar(celda, 11)), lado * (0.4 + 0.4 * _azar(celda, 12)))
	for dx in [-0.06, 0.0, 0.06]:
		draw_line(base, base + Vector2(lado * dx, -lado * 0.12), color, 2.0)


## Portón abierto de una empalizada: los postes quedan arriba y abajo de la casilla.
func _porton(paleta: Dictionary, rect: Rect2) -> void:
	var grueso := lado * 0.16
	for y in [rect.position.y, rect.end.y - grueso]:
		draw_rect(Rect2(rect.position.x + lado * 0.1, y, lado * 0.8, grueso), paleta["tronco"])
		draw_rect(Rect2(rect.position.x + lado * 0.1, y, lado * 0.8, grueso), paleta["tronco_sombra"], false, 1.5)


## Marco de una puerta: dos jambas en los lados de la casilla que tocan pared.
func _marco_puerta(color: Color, celda: Vector2i, rect: Rect2) -> void:
	var grueso := lado * 0.1
	var celdas: Array = plano["celdas"]
	var lados_pared_x := not GeneradorMazmorra.es_suelo(celdas, celda + Vector2i.LEFT) \
		and not GeneradorMazmorra.es_suelo(celdas, celda + Vector2i.RIGHT)
	if lados_pared_x:
		draw_rect(Rect2(rect.position, Vector2(grueso, lado)), color)
		draw_rect(Rect2(rect.end.x - grueso, rect.position.y, grueso, lado), color)
	else:
		draw_rect(Rect2(rect.position, Vector2(lado, grueso)), color)
		draw_rect(Rect2(rect.position.x, rect.end.y - grueso, lado, grueso), color)


## Losas: cuatro piedras por casilla, con las juntas corridas fila por medio.
func _losas(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	if (celda.x + celda.y) % 2 == 0:
		draw_rect(Rect2(rect.position + Vector2(lado * 0.5, 0), Vector2(lado * 0.5, lado * 0.5)), paleta["losa_oscura"])
	draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), paleta["suelo_borde"], 1.5)
	var corrido := lado * (0.5 if celda.y % 2 == 0 else 0.25)
	draw_line(Vector2(rect.position.x + corrido, rect.position.y), Vector2(rect.position.x + corrido, rect.get_center().y),
		paleta["suelo_borde"], 1.5)


func _damero(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	for i in 2:
		for j in 2:
			if (i + j + celda.x + celda.y) % 2 == 0:
				draw_rect(Rect2(rect.position + Vector2(i, j) * lado * 0.5, Vector2.ONE * lado * 0.5), paleta["losa_oscura"].darkened(0.15))


## Alfombra roja con borde dorado, en la dirección del pasillo.
func _alfombra(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	var horizontal := _que(celda + Vector2i.LEFT) == "alfombra" or _que(celda + Vector2i.RIGHT) == "alfombra"
	if _que(celda + Vector2i.UP) == "alfombra" and _que(celda + Vector2i.DOWN) == "alfombra":
		horizontal = false
	var franja := Rect2(rect.position.x, rect.position.y + lado * 0.16, lado, lado * 0.68) if horizontal \
		else Rect2(rect.position.x + lado * 0.16, rect.position.y, lado * 0.68, lado)
	draw_rect(franja, paleta["alfombra"])
	if horizontal:
		for y in [franja.position.y + 3.0, franja.end.y - 3.0]:
			draw_line(Vector2(franja.position.x, y), Vector2(franja.end.x, y), paleta["alfombra_borde"], 2.0)
	else:
		for x in [franja.position.x + 3.0, franja.end.x - 3.0]:
			draw_line(Vector2(x, franja.position.y), Vector2(x, franja.end.y), paleta["alfombra_borde"], 2.0)


func _trono(paleta: Dictionary, rect: Rect2) -> void:
	var centro := rect.get_center()
	var respaldo := Rect2(centro + Vector2(-lado * 0.22, -lado * 0.36), Vector2(lado * 0.44, lado * 0.4))
	draw_rect(respaldo, paleta["oro"])
	draw_rect(Rect2(centro + Vector2(-lado * 0.26, 0), Vector2(lado * 0.52, lado * 0.22)), paleta["alfombra"])
	draw_rect(Rect2(centro + Vector2(-lado * 0.26, 0), Vector2(lado * 0.52, lado * 0.22)), paleta["oro"], false, 2.0)


# --- Muros ---

func _dibujar_muro(estilo: String, paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	var que := _que(celda)
	match estilo:
		"cueva", "mina":
			_roca(paleta, celda, rect)
			if estilo == "mina" and _azar(celda, 13) < 0.2:
				for i in 3:
					var punto := rect.position + Vector2(_azar(celda, 50 + i), _azar(celda, 60 + i)) * lado * 0.7 + Vector2.ONE * lado * 0.15
					draw_circle(punto, lado * 0.04, paleta["mineral"])
		"fuerte":
			match que:
				"choza":
					_paja(paleta, celda, rect)
				"atalaya":
					_atalaya(paleta, celda, rect)
				_:
					_empalizada(paleta, rect)
		"castillo":
			_sillares(paleta, celda, rect)
			if que == "antorcha":
				_antorcha(paleta, rect)
			elif que == "estandarte":
				_estandarte(paleta, rect)


## Roca: un fondo oscuro con dos o tres peñascos de luz y sombra.
func _roca(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	draw_rect(rect, paleta["roca"])
	for i in 3:
		var centro := rect.position + Vector2(_azar(celda, 70 + i), _azar(celda, 80 + i)) * lado * 0.7 + Vector2.ONE * lado * 0.15
		var radio := lado * (0.12 + 0.1 * _azar(celda, 90 + i))
		draw_circle(centro + Vector2(radio * 0.2, radio * 0.25), radio, paleta["roca_sombra"])
		draw_circle(centro, radio, paleta["roca_luz"])
	draw_line(rect.position + Vector2(lado * 0.2, lado * 0.85), rect.position + Vector2(lado * 0.45, lado * 0.7),
		paleta["roca_sombra"], 1.5)


## Empalizada: troncos parados con la punta afilada.
func _empalizada(paleta: Dictionary, rect: Rect2) -> void:
	draw_rect(rect, paleta["tronco_sombra"])
	var ancho := lado / 4.0
	for i in 4:
		var x := rect.position.x + ancho * i
		var cuerpo := Rect2(x + 1.0, rect.position.y + lado * 0.18, ancho - 2.0, lado * 0.82)
		draw_rect(cuerpo, paleta["tronco"])
		draw_rect(Rect2(cuerpo.position, Vector2(ancho * 0.3, cuerpo.size.y)), paleta["tronco_luz"])
		draw_colored_polygon(PackedVector2Array([
			Vector2(cuerpo.position.x, cuerpo.position.y), Vector2(cuerpo.end.x, cuerpo.position.y),
			Vector2(cuerpo.get_center().x, rect.position.y + 2.0)]), paleta["tronco_luz"])


## Techo de paja de una choza.
func _paja(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	draw_rect(rect, paleta["paja"])
	for i in 5:
		var x := rect.position.x + lado * (0.1 + 0.2 * i) + lado * 0.05 * _azar(celda, 100 + i)
		draw_line(Vector2(x, rect.position.y + 3.0), Vector2(x - lado * 0.08, rect.end.y - 3.0), paleta["paja_oscura"], 1.5)
	draw_rect(rect, paleta["paja_oscura"], false, 1.5)


## Atalaya de 2 × 2 vista desde arriba: una plataforma de tablas con borde de
## troncos (el techo en punta va encima, ver _techo_atalaya).
func _atalaya(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	_tablas(paleta, rect)
	for d in GeneradorMazmorra.DIRECCIONES:
		if _que(celda + d) == "atalaya":
			continue
		var direccion := Vector2(d)
		var centro_lado := rect.get_center() + direccion * lado * 0.44
		var tamano := Vector2(lado, lado * 0.12) if d.y != 0 else Vector2(lado * 0.12, lado)
		draw_rect(Rect2(centro_lado - tamano / 2.0, tamano), paleta["tronco"])


## Techo en punta de una atalaya, centrado en "centro" (el medio de sus 2 × 2).
func _techo_atalaya(paleta: Dictionary, centro: Vector2) -> void:
	var radio := lado * 0.6
	var puntas := PackedVector2Array([centro + Vector2(0, -radio), centro + Vector2(radio, 0), centro + Vector2(0, radio),
		centro + Vector2(-radio, 0)])
	draw_colored_polygon(puntas, paleta["paja"])
	for punta in puntas:
		draw_line(centro, punta, paleta["paja_oscura"], 2.0)
	puntas.append(puntas[0])
	draw_polyline(puntas, paleta["tronco_sombra"], 2.0)


## Muro de sillares: hileras de piedras con las juntas corridas.
func _sillares(paleta: Dictionary, celda: Vector2i, rect: Rect2) -> void:
	draw_rect(rect, paleta["piedra"])
	var alto := lado / 3.0
	for fila in 3:
		var y := rect.position.y + alto * fila
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), paleta["junta"], 2.0)
		draw_line(Vector2(rect.position.x, y + 2.0), Vector2(rect.end.x, y + 2.0), paleta["piedra_luz"], 1.0)
		var corrido := lado * (0.5 if (fila + celda.x) % 2 == 0 else 0.25)
		for x in [rect.position.x + corrido, rect.position.x + corrido + lado * 0.5]:
			if x < rect.end.x - 1.0:
				draw_line(Vector2(x, y), Vector2(x, y + alto), paleta["junta"], 2.0)


func _antorcha(paleta: Dictionary, rect: Rect2) -> void:
	var centro := rect.get_center()
	draw_rect(Rect2(centro + Vector2(-lado * 0.04, -lado * 0.05), Vector2(lado * 0.08, lado * 0.3)), paleta["madera"])
	draw_circle(centro + Vector2(0, -lado * 0.12), lado * 0.13, paleta["llama"])
	draw_circle(centro + Vector2(0, -lado * 0.1), lado * 0.06, paleta["llama_centro"])


func _estandarte(paleta: Dictionary, rect: Rect2) -> void:
	var tela := Rect2(rect.position + Vector2(lado * 0.28, lado * 0.08), Vector2(lado * 0.44, lado * 0.7))
	draw_rect(tela, paleta["estandarte"])
	draw_colored_polygon(PackedVector2Array([
		Vector2(tela.position.x, tela.end.y), Vector2(tela.get_center().x, tela.end.y - lado * 0.12),
		Vector2(tela.end.x, tela.end.y), Vector2(tela.end.x, tela.end.y + lado * 0.1), Vector2(tela.position.x, tela.end.y + lado * 0.1)]),
		paleta["piedra"])
	draw_circle(tela.get_center() + Vector2(0, -lado * 0.06), lado * 0.08, paleta["oro"])


# --- Contenido ---

func _dibujar_contenido(celda: Vector2i, rect: Rect2) -> void:
	var centro := rect.get_center()
	if celda == plano["entrada"]:
		var fuente := get_theme_default_font()
		var tamano := int(lado * 0.6)
		var medida := fuente.get_string_size("H", HORIZONTAL_ALIGNMENT_LEFT, -1, tamano)
		draw_string_outline(fuente, centro + Vector2(-medida.x / 2.0, tamano * 0.35), "H", HORIZONTAL_ALIGNMENT_LEFT, -1,
			tamano, 4, Color(0, 0, 0, 0.6))
		draw_string(fuente, centro + Vector2(-medida.x / 2.0, tamano * 0.35), "H", HORIZONTAL_ALIGNMENT_LEFT, -1,
			tamano, COLOR_SALIDA)
	elif plano["enemigos"].has(celda):
		if celda == plano.get("jefe", Vector2i(-1, -1)):
			dibujar_jefe(self, centro, lado * 0.32)
		else:
			dibujar_espadas(self, centro, lado * 0.32)
	elif plano["cofres"].has(celda):
		dibujar_cofre(self, centro, lado * 0.3)


func _dibujar_rey(rect: Rect2) -> void:
	var centro := rect.get_center()
	var radio := lado * 0.3
	draw_circle(centro + Vector2(0, radio * 0.25), radio, Color("#2f5fb3"))
	draw_arc(centro + Vector2(0, radio * 0.25), radio, 0.0, TAU, 20, Color("#141726"), 2.0, true)
	var corona := PackedVector2Array([
		centro + Vector2(-radio * 0.7, -radio * 0.35), centro + Vector2(-radio * 0.7, -radio * 0.95),
		centro + Vector2(-radio * 0.35, -radio * 0.6), centro + Vector2(0, -radio * 1.1),
		centro + Vector2(radio * 0.35, -radio * 0.6), centro + Vector2(radio * 0.7, -radio * 0.95),
		centro + Vector2(radio * 0.7, -radio * 0.35)])
	draw_colored_polygon(corona, Color("#ffcc33"))


## Espadas cruzadas (enemigo). Estática para usarla también en la leyenda.
static func dibujar_espadas(lienzo: CanvasItem, centro: Vector2, radio: float) -> void:
	for lado_x in [-1.0, 1.0]:
		var punta := centro + Vector2(radio * lado_x, -radio)
		var mango := centro + Vector2(-radio * lado_x, radio)
		lienzo.draw_line(mango, punta, Color("#eceff1"), 4.0, true)
		lienzo.draw_line(mango, punta, Color("#37474f"), 1.5, true)
		var guarda := mango.lerp(punta, 0.28)
		var normal := (punta - mango).normalized().orthogonal() * radio * 0.35
		lienzo.draw_line(guarda - normal, guarda + normal, Color("#5d4037"), 4.0, true)


## Jefe: una calavera sobre las espadas cruzadas, con un halo rojo. Estática
## para usarla también en la leyenda.
static func dibujar_jefe(lienzo: CanvasItem, centro: Vector2, radio: float) -> void:
	lienzo.draw_circle(centro, radio * 1.25, Color(0.85, 0.1, 0.1, 0.35))
	dibujar_espadas(lienzo, centro, radio * 1.1)
	var hueso := Color("#f3ecd9")
	var sombra := Color("#2b2320")
	var craneo := centro + Vector2(0, -radio * 0.12)
	lienzo.draw_circle(craneo, radio * 0.6, sombra)
	lienzo.draw_circle(craneo, radio * 0.52, hueso)
	var mandibula := Rect2(centro + Vector2(-radio * 0.3, radio * 0.22), Vector2(radio * 0.6, radio * 0.32))
	lienzo.draw_rect(mandibula.grow(radio * 0.07), sombra)
	lienzo.draw_rect(mandibula, hueso)
	for lado_x in [-1.0, 1.0]:
		lienzo.draw_circle(craneo + Vector2(radio * 0.21 * lado_x, radio * 0.02), radio * 0.15, sombra)
	lienzo.draw_colored_polygon(PackedVector2Array([craneo + Vector2(0, radio * 0.14),
		craneo + Vector2(-radio * 0.08, radio * 0.3), craneo + Vector2(radio * 0.08, radio * 0.3)]), sombra)
	for i in 3:
		var x := mandibula.position.x + mandibula.size.x * (i + 1) / 4.0
		lienzo.draw_line(Vector2(x, mandibula.position.y), Vector2(x, mandibula.end.y), sombra, 1.5)


## Cofre (tesoro). Estática para usarla también en la leyenda.
static func dibujar_cofre(lienzo: CanvasItem, centro: Vector2, radio: float) -> void:
	var caja := Rect2(centro + Vector2(-radio, -radio * 0.55), Vector2(radio * 2.0, radio * 1.4))
	lienzo.draw_rect(caja, Color("#8d6e63"))
	lienzo.draw_rect(Rect2(caja.position, Vector2(caja.size.x, radio * 0.45)), Color("#6d4c41"))
	lienzo.draw_rect(caja, Color("#3e2723"), false, 2.0)
	lienzo.draw_rect(Rect2(centro + Vector2(-radio * 0.18, -radio * 0.2), Vector2(radio * 0.36, radio * 0.4)),
		Color("#ffcc33"))
