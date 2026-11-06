class_name GeneradorMazmorra
extends RefCounted
## Crea el plano de una mazmorra en una cuadrícula, con la entrada (la H) arriba,
## enemigos y cofres. Cada mazmorra tiene su estilo ("estilo" en
## DatosAventura.MAZMORRAS), que cambia cómo se arma el plano y cómo se ve (ver
## TableroMazmorra):
## - "cueva": cuevas naturales (los goblins): túneles que crecen como raíces y
##   nunca se tocan, con cámaras en algunas puntas y recovecos a los costados.
## - "mina": una mina abandonada (los bandidos): tres galerías rectas a
##   distintas alturas, unidas en zigzag por pozos en sus puntas, con nichos y
##   algún campamento.
## - "fuerte": un fuerte de troncos (los orcos): la empalizada alrededor y un
##   patio partido en tres corrales por empalizadas con un portón, con chozas
##   (cada una con su puerta) y atalayas.
## - "castillo": el castillo de un reino enemigo: un pasillo con alfombra y
##   salas de piedra en fila, unidas por puertas, a los dos lados; a veces, un
##   salón del trono.
## - "laberinto": el laberinto de antes (si la mazmorra no dice su estilo).
## Los planos están pensados para que limpiar una mazmorra pida caminar más o
## menos lo mismo que el laberinto de antes (así el estrés sigue igual).
## La misma semilla da siempre el mismo plano; al cambiar de semana cambia la
## semilla y la mazmorra se reinicia. Cada partida suma su propia semilla, así
## que dos partidas no tienen las mismas mazmorras.
##
## Además de las casillas, el plano trae su "aspecto": {casilla: qué es} para lo
## que el tablero dibuja distinto (una puerta, la alfombra, una choza, una viga).
## Es solo para el dibujo y para elegir dónde van los cofres.

enum Celda { MURO, SUELO }

const ANCHO := 15
const ALTO := 9
const DIRECCIONES := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Distancia mínima (en pasos) entre la entrada y un enemigo o cofre.
const DISTANCIA_MINIMA := 3
## Laberinto: paredes internas que se abren de más para que haya caminos alternativos.
const PROPORCION_ATAJOS := 0.12
## Cueva: casillas de túnel que crecen, cuántas veces dobla un túnel en cada
## paso, cuántas cámaras como mucho y la probabilidad de abrir una en la punta
## de un túnel.
const SUELO_CUEVA := 50
const GIRO_CUEVA := 0.45
const CAMARAS_CUEVA := 3
const CAMARA_EN_LA_PUNTA := 0.8
## Cueva: recovecos (una casilla de más al costado de un túnel) que intenta abrir.
const RECOVECOS_CUEVA := 6
## Mina: filas de las tres galerías (una de estas al azar), probabilidad de un
## pozo de ventilación entre dos galerías (hace una vuelta) y nichos que
## intenta cavar.
const NIVELES_MINA := [[1, 4, 7], [1, 3, 6], [2, 4, 7], [1, 4, 6], [2, 5, 7]]
const VENTILACION_MINA := 0.1
const NICHOS_MINA := 8
## Fuerte: chozas que intenta levantar.
const CHOZAS_FUERTE := 5
## Castillo: fila del pasillo principal (las salas quedan arriba y abajo),
## probabilidad de que una fila de salas tenga una segunda puerta al pasillo y
## de que su puerta esté en la sala de la punta (la más lejos de la entrada).
const FILA_PASILLO := 4
const SEGUNDA_PUERTA_CASTILLO := 0.3
const PUERTA_EN_LA_PUNTA := 0.6


## Semilla de una mazmorra en una semana de una partida.
static func semilla(mazmorra_id: String, semana: int, semilla_partida := 0) -> int:
	return hash("%s:%d:%d" % [mazmorra_id, semana, semilla_partida])


## Devuelve {"celdas": Array de filas (Array de Celda), "entrada": Vector2i,
## "enemigos": {Vector2i: enemigo_id}, "cofres": {Vector2i: true}, "estilo",
## "aspecto": {Vector2i: String}}.
static func generar(mazmorra_id: String, semana: int, semilla_partida := 0) -> Dictionary:
	var datos: Dictionary = DatosAventura.MAZMORRAS[mazmorra_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla(mazmorra_id, semana, semilla_partida)
	var estilo: String = datos.get("estilo", "laberinto")
	var aspecto := {}
	var celdas: Array
	match estilo:
		"cueva":
			celdas = _cueva(rng)
		"mina":
			celdas = _mina(rng, aspecto)
		"fuerte":
			celdas = _fuerte(rng, aspecto)
		"castillo":
			celdas = _castillo(rng, aspecto)
		_:
			estilo = "laberinto"
			celdas = _laberinto(rng)
	var entrada := Vector2i(ANCHO / 2, 0)
	celdas[0][entrada.x] = Celda.SUELO
	var distancias := distancias_desde(celdas, entrada)
	# Candidatas: suelo lejos de la entrada, en orden al azar (con la semilla,
	# para que el plano de la semana sea siempre el mismo).
	var candidatas: Array[Vector2i] = []
	for celda in distancias:
		if distancias[celda] >= DISTANCIA_MINIMA:
			candidatas.append(celda)
	for i in range(candidatas.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var cambio := candidatas[i]
		candidatas[i] = candidatas[j]
		candidatas[j] = cambio
	# Los cofres prefieren su lugar (el fondo de las salas, las chozas, los
	# nichos y campamentos de la mina) y después los callejones sin salida.
	var propias: Array[Vector2i] = []
	var callejones: Array[Vector2i] = []
	for celda in candidatas:
		if _lugar_de_cofre(estilo, aspecto, celda):
			propias.append(celda)
		elif _vecinos_de_suelo(celdas, celda) == 1:
			callejones.append(celda)
	var cofres := {}
	for lista in [propias, callejones]:
		for celda in lista:
			if cofres.size() >= int(datos["cofres"]):
				break
			cofres[celda] = true
	var enemigos := {}
	var posibles: Array = datos["enemigos"]
	for celda in candidatas:
		if enemigos.size() >= int(datos["cantidad_enemigos"]):
			break
		if cofres.has(celda):
			continue
		enemigos[celda] = posibles[rng.randi() % posibles.size()]
	for celda in candidatas:
		if cofres.size() >= int(datos["cofres"]):
			break
		if not enemigos.has(celda):
			cofres[celda] = true
	return {"celdas": celdas, "entrada": entrada, "enemigos": enemigos, "cofres": cofres, "estilo": estilo,
		"aspecto": aspecto}


static func _lugar_de_cofre(estilo: String, aspecto: Dictionary, celda: Vector2i) -> bool:
	var que: String = aspecto.get(celda, "")
	match estilo:
		"castillo":
			return que == "sala" or que == "salon"
		"fuerte":
			return que == "interior"
		"mina":
			return que == "nicho" or que == "campamento"
	return false


# --- Cueva ---

## Cuevas naturales: los túneles crecen desde la entrada como raíces. Cada uno
## avanza doblando al azar y nunca toca a otro (no hay atajos, así que los
## caminos son largos y tienen callejones); de un túnel nacen otros. En la
## punta de algunos se abre una cámara, y a los costados quedan recovecos.
static func _cueva(rng: RandomNumberGenerator) -> Array:
	var celdas := _lleno()
	var inicio := Vector2i(ANCHO / 2, 1)
	celdas[inicio.y][inicio.x] = Celda.SUELO
	var tuneles: Array[Vector2i] = [inicio]
	var camaras := 0
	for _intento in 400:
		if tuneles.size() >= SUELO_CUEVA:
			break
		var pos: Vector2i = tuneles[rng.randi() % tuneles.size()]
		var direccion: Vector2i = DIRECCIONES[rng.randi() % DIRECCIONES.size()]
		var ultima := direccion
		var largo := 0
		for _paso in rng.randi_range(3, 8):
			if largo > 0 and rng.randf() < GIRO_CUEVA:
				direccion = Vector2i(direccion.y, direccion.x) * (1 if rng.randf() < 0.5 else -1)
			var siguiente: Vector2i = pos + direccion
			if not _dentro_interior(siguiente) or not _roca_alrededor(celdas, siguiente, pos):
				break
			celdas[siguiente.y][siguiente.x] = Celda.SUELO
			tuneles.append(siguiente)
			pos = siguiente
			ultima = direccion
			largo += 1
		# A veces, en la punta del túnel se abre una cámara.
		if largo >= 2 and camaras < CAMARAS_CUEVA and rng.randf() < CAMARA_EN_LA_PUNTA:
			var camara := _camara_delante(pos, ultima, rng)
			if _sala_libre(celdas, camara, pos):
				for y in range(camara.position.y, camara.end.y):
					for x in range(camara.position.x, camara.end.x):
						celdas[y][x] = Celda.SUELO
						tuneles.append(Vector2i(x, y))
				camaras += 1
	# Recovecos: una casilla de más al costado de un túnel, que no lleva a ningún
	# lado (así las paredes no quedan derechas).
	var recovecos := 0
	for _intento in 60:
		if recovecos >= RECOVECOS_CUEVA:
			break
		var base: Vector2i = tuneles[rng.randi() % tuneles.size()]
		var celda: Vector2i = base + DIRECCIONES[rng.randi() % DIRECCIONES.size()]
		if _dentro_interior(celda) and _roca_alrededor(celdas, celda, base):
			celdas[celda.y][celda.x] = Celda.SUELO
			recovecos += 1
	return celdas


## Cámara de 2 × 2 o 3 × 2 justo delante de la punta de un túnel que avanza
## "hacia" esa dirección, de modo que la punta dé a uno de sus lados.
static func _camara_delante(punta: Vector2i, hacia: Vector2i, rng: RandomNumberGenerator) -> Rect2i:
	var largo := rng.randi_range(2, 3)
	if hacia.x != 0:
		var tamano := Vector2i(2, largo)
		var x := punta.x + 1 if hacia.x > 0 else punta.x - tamano.x
		return Rect2i(Vector2i(x, punta.y - rng.randi_range(0, tamano.y - 1)), tamano)
	var tamano := Vector2i(largo, 2)
	var y := punta.y + 1 if hacia.y > 0 else punta.y - tamano.y
	return Rect2i(Vector2i(punta.x - rng.randi_range(0, tamano.x - 1), y), tamano)


# --- Mina ---

## Mina abandonada: de la entrada baja un pozo hasta la primera galería, y las
## galerías (rectas, a varias alturas, con roca entre una y otra) se unen en
## zigzag por pozos en sus puntas, una vez a un lado y otra al otro, como en
## una mina de verdad. A veces un pozo de ventilación une dos galerías por el
## medio (hace una vuelta). Hay nichos (callejones cortos) y uno o dos
## campamentos al final de una galería.
static func _mina(rng: RandomNumberGenerator, aspecto: Dictionary) -> Array:
	var celdas := _lleno()
	var centro := ANCHO / 2
	var niveles: Array[int] = []
	niveles.assign(NIVELES_MINA[rng.randi() % NIVELES_MINA.size()])
	for y in range(1, niveles[0]):
		_cavar(celdas, aspecto, Vector2i(centro, y), "pozo")
	# Galerías: [fila, desde, hasta], casi de lado a lado. La más larga lleva rieles.
	var tramos: Array = []
	for y in niveles:
		tramos.append([y, rng.randi_range(1, 2), rng.randi_range(ANCHO - 3, ANCHO - 2)])
	var mas_larga := 0
	for i in tramos.size():
		if tramos[i][2] - tramos[i][1] > tramos[mas_larga][2] - tramos[mas_larga][1]:
			mas_larga = i
	for i in tramos.size():
		for x in range(tramos[i][1], tramos[i][2] + 1):
			_cavar(celdas, aspecto, Vector2i(x, tramos[i][0]), "riel" if i == mas_larga else "galeria")
	# Pozos en zigzag: de cada galería a la siguiente por una punta, alternando
	# el lado.
	var a_la_izquierda := rng.randf() < 0.5
	var pozos: Array[int] = []
	for i in range(tramos.size() - 1):
		var arriba: Array = tramos[i]
		var abajo: Array = tramos[i + 1]
		var x: int
		if a_la_izquierda:
			x = maxi(arriba[1], abajo[1]) + rng.randi_range(0, 1)
		else:
			x = mini(arriba[2], abajo[2]) - rng.randi_range(0, 1)
		a_la_izquierda = not a_la_izquierda
		pozos.append(x)
		for y in range(int(arriba[0]) + 1, int(abajo[0])):
			_cavar(celdas, aspecto, Vector2i(x, y), "pozo")
	# Pozos de ventilación: unen dos galerías seguidas lejos de los otros pozos.
	for i in range(tramos.size() - 1):
		var arriba: Array = tramos[i]
		var abajo: Array = tramos[i + 1]
		var opciones: Array[int] = []
		for x in range(maxi(arriba[1], abajo[1]), mini(arriba[2], abajo[2]) + 1):
			if absi(x - pozos[i]) >= 4:
				opciones.append(x)
		if opciones.is_empty() or rng.randf() >= VENTILACION_MINA:
			continue
		var x: int = opciones[rng.randi() % opciones.size()]
		for y in range(int(arriba[0]) + 1, int(abajo[0])):
			_cavar(celdas, aspecto, Vector2i(x, y), "pozo")
	# Campamentos: una sala de 2 o 3 de ancho y 2 de alto al final de una galería.
	var campamentos := 0
	for _intento in 12:
		if campamentos >= 2:
			break
		var tramo: Array = tramos[rng.randi() % tramos.size()]
		var hacia_la_izquierda := rng.randf() < 0.5
		var punta := Vector2i(tramo[1] if hacia_la_izquierda else tramo[2], tramo[0])
		var ancho := rng.randi_range(2, 3)
		var x0: int = punta.x - ancho if hacia_la_izquierda else punta.x + 1
		var y0: int = punta.y - 1 if rng.randf() < 0.5 else punta.y
		var sala := Rect2i(x0, y0, ancho, 2)
		if not _sala_libre(celdas, sala, punta):
			continue
		for y in range(sala.position.y, sala.end.y):
			for x in range(sala.position.x, sala.end.x):
				_cavar(celdas, aspecto, Vector2i(x, y), "campamento")
		aspecto[Vector2i(sala.position.x + rng.randi_range(0, ancho - 1), sala.position.y + rng.randi_range(0, 1))] = "fogata"
		campamentos += 1
	# Nichos: callejones de una o dos casillas arriba o abajo de una galería,
	# sin tocar otro túnel.
	var nichos := 0
	for _intento in 80:
		if nichos >= NICHOS_MINA:
			break
		var tramo: Array = tramos[rng.randi() % tramos.size()]
		var x := rng.randi_range(tramo[1], tramo[2])
		var paso: Vector2i = Vector2i.UP if rng.randf() < 0.5 else Vector2i.DOWN
		var nuevas: Array[Vector2i] = []
		var anterior := Vector2i(x, tramo[0])
		for _casilla in rng.randi_range(1, 3):
			var celda: Vector2i = anterior + paso
			if not _dentro_interior(celda) or not _roca_alrededor(celdas, celda, anterior):
				break
			nuevas.append(celda)
			anterior = celda
		if nuevas.is_empty():
			continue
		for celda in nuevas:
			_cavar(celdas, aspecto, celda, "nicho")
		nichos += 1
	return celdas


## La sala (dentro del interior) y la roca que la rodea están libres de túneles,
## salvo la casilla por donde se entra.
static func _sala_libre(celdas: Array, sala: Rect2i, entrada: Vector2i) -> bool:
	if sala.position.x < 1 or sala.position.y < 1 or sala.end.x > ANCHO - 1 or sala.end.y > ALTO - 1:
		return false
	var borde := sala.grow(1)
	for y in range(borde.position.y, borde.end.y):
		for x in range(borde.position.x, borde.end.x):
			var celda := Vector2i(x, y)
			if celda != entrada and es_suelo(celdas, celda):
				return false
	return true


## La casilla es roca y también sus vecinas, salvo "desde" (para cavar un
## nicho sin abrir paso a otro túnel).
static func _roca_alrededor(celdas: Array, celda: Vector2i, desde: Vector2i) -> bool:
	if es_suelo(celdas, celda):
		return false
	for d in DIRECCIONES:
		var vecina: Vector2i = celda + d
		if vecina != desde and es_suelo(celdas, vecina):
			return false
	return true


# --- Fuerte ---

## Fuerte de troncos: la empalizada es el borde y adentro hay un patio,
## partido en tres corrales por dos empalizadas con un portón cada una (una
## arriba y la otra abajo: hay que dar la vuelta). En los corrales se levantan
## chozas (de 3 × 3 o 4 × 3, con una casilla o dos adentro y una puerta) y
## alguna atalaya pegada a la empalizada. Cada cosa se pone solo si deja todo el
## patio conectado y un paso libre alrededor de las otras chozas y atalayas; la
## puerta de entrada queda despejada.
static func _fuerte(rng: RandomNumberGenerator, aspecto: Dictionary) -> Array:
	var celdas := _lleno()
	for y in range(1, ALTO - 1):
		for x in range(1, ANCHO - 1):
			celdas[y][x] = Celda.SUELO
	var empalizadas := {}
	var abajo := rng.randf() < 0.5
	for x in [rng.randi_range(4, 5), rng.randi_range(9, 10)]:
		var porton := ALTO - 2 if abajo else 1
		abajo = not abajo
		for y in range(1, ALTO - 1):
			var celda := Vector2i(x, y)
			empalizadas[celda] = true
			if y == porton:
				aspecto[celda] = "porton"
			else:
				celdas[y][x] = Celda.MURO
				aspecto[celda] = "empalizada"
	var ocupado := {}
	var chozas := 0
	for _intento in 250:
		if chozas >= CHOZAS_FUERTE:
			break
		var tamano := [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)][rng.randi() % 3] as Vector2i
		var choza := Rect2i(rng.randi_range(1, ANCHO - 1 - tamano.x), rng.randi_range(1, ALTO - 1 - tamano.y), tamano.x, tamano.y)
		if _poner_choza(celdas, aspecto, ocupado, empalizadas, choza, rng):
			chozas += 1
	var atalayas := 0
	for _intento in 30:
		if atalayas >= 2:
			break
		var x := 1 if rng.randf() < 0.5 else ANCHO - 3
		var y := 1 if rng.randf() < 0.5 else ALTO - 3
		if _poner_atalaya(celdas, aspecto, ocupado, empalizadas, Rect2i(x, y, 2, 2)):
			atalayas += 1
	return celdas


## Levanta una choza en ese rectángulo si cabe (ver _cabe): paredes de madera,
## suelo adentro y una puerta en un lado (no en una esquina) que da al patio.
static func _poner_choza(celdas: Array, aspecto: Dictionary, ocupado: Dictionary, empalizadas: Dictionary,
		choza: Rect2i, rng: RandomNumberGenerator) -> bool:
	if not _cabe(ocupado, empalizadas, choza):
		return false
	var puertas: Array[Vector2i] = []
	for y in range(choza.position.y, choza.end.y):
		for x in range(choza.position.x, choza.end.x):
			var borde := x == choza.position.x or x == choza.end.x - 1 or y == choza.position.y or y == choza.end.y - 1
			var esquina := (x == choza.position.x or x == choza.end.x - 1) and (y == choza.position.y or y == choza.end.y - 1)
			if not borde or esquina:
				continue
			# La puerta da a una casilla del patio (no a una empalizada).
			var afuera := Vector2i(x, y) + _hacia_afuera(choza, Vector2i(x, y))
			if _dentro_interior(afuera) and celdas[afuera.y][afuera.x] == Celda.SUELO:
				puertas.append(Vector2i(x, y))
	if puertas.is_empty():
		return false
	var puerta: Vector2i = puertas[rng.randi() % puertas.size()]
	var antes := {}
	for y in range(choza.position.y, choza.end.y):
		for x in range(choza.position.x, choza.end.x):
			var celda := Vector2i(x, y)
			antes[celda] = celdas[y][x]
			var borde := x == choza.position.x or x == choza.end.x - 1 or y == choza.position.y or y == choza.end.y - 1
			celdas[y][x] = Celda.MURO if borde and celda != puerta else Celda.SUELO
	if not _todo_conectado(celdas):
		for celda in antes:
			celdas[celda.y][celda.x] = antes[celda]
		return false
	for y in range(choza.position.y, choza.end.y):
		for x in range(choza.position.x, choza.end.x):
			var celda := Vector2i(x, y)
			ocupado[celda] = true
			if celda == puerta:
				aspecto[celda] = "puerta"
			elif celdas[y][x] == Celda.MURO:
				aspecto[celda] = "choza"
			else:
				aspecto[celda] = "interior"
	return true


## Pone una atalaya (un bloque macizo) si cabe y no corta el patio.
static func _poner_atalaya(celdas: Array, aspecto: Dictionary, ocupado: Dictionary, empalizadas: Dictionary,
		bloque: Rect2i) -> bool:
	if not _cabe(ocupado, empalizadas, bloque):
		return false
	for y in range(bloque.position.y, bloque.end.y):
		for x in range(bloque.position.x, bloque.end.x):
			celdas[y][x] = Celda.MURO
	if not _todo_conectado(celdas):
		for y in range(bloque.position.y, bloque.end.y):
			for x in range(bloque.position.x, bloque.end.x):
				celdas[y][x] = Celda.SUELO
		return false
	for y in range(bloque.position.y, bloque.end.y):
		for x in range(bloque.position.x, bloque.end.x):
			ocupado[Vector2i(x, y)] = true
			aspecto[Vector2i(x, y)] = "atalaya"
	return true


## El rectángulo está dentro del patio, no pisa una empalizada, deja un paso
## libre alrededor de las chozas y atalayas que ya hay y no tapa la entrada
## (las dos casillas bajo la H y sus lados).
static func _cabe(ocupado: Dictionary, empalizadas: Dictionary, rect: Rect2i) -> bool:
	if rect.position.x < 1 or rect.position.y < 1 or rect.end.x > ANCHO - 1 or rect.end.y > ALTO - 1:
		return false
	if rect.intersects(Rect2i(ANCHO / 2 - 1, 1, 3, 2)):
		return false
	for celda in empalizadas:
		if rect.has_point(celda):
			return false
	var alrededor := rect.grow(1)
	for celda in ocupado:
		if alrededor.has_point(celda):
			return false
	return true


## Hacia dónde está el afuera de una casilla del borde de un rectángulo.
static func _hacia_afuera(rect: Rect2i, celda: Vector2i) -> Vector2i:
	if celda.x == rect.position.x:
		return Vector2i.LEFT
	if celda.x == rect.end.x - 1:
		return Vector2i.RIGHT
	if celda.y == rect.position.y:
		return Vector2i.UP
	return Vector2i.DOWN


## Todo el suelo se alcanza desde la casilla de debajo de la entrada.
static func _todo_conectado(celdas: Array) -> bool:
	var alcanzables := distancias_desde(celdas, Vector2i(ANCHO / 2, 1))
	var suelo := 0
	for y in ALTO:
		for x in ANCHO:
			if celdas[y][x] == Celda.SUELO:
				suelo += 1
	return alcanzables.size() == suelo


# --- Castillo ---

## Castillo de un reino enemigo: de la H baja la entrada hasta un pasillo largo
## con alfombra; arriba y abajo del pasillo hay salas de piedra en fila, unidas
## entre sí por puertas (como las habitaciones de un palacio): de cada fila,
## solo una sala (a veces dos) tiene puerta al pasillo. La mitad de las veces,
## abajo en el medio hay un salón del trono con sus salas a los lados.
static func _castillo(rng: RandomNumberGenerator, aspecto: Dictionary) -> Array:
	var celdas := _lleno()
	var centro := ANCHO / 2
	var desde := rng.randi_range(1, 2)
	var hasta := rng.randi_range(ANCHO - 3, ANCHO - 2)
	for x in range(desde, hasta + 1):
		_cavar(celdas, aspecto, Vector2i(x, FILA_PASILLO), "alfombra")
	for y in range(1, FILA_PASILLO):
		_cavar(celdas, aspecto, Vector2i(centro, y), "alfombra")
	var arriba := 1
	var abajo := FILA_PASILLO + 2
	# Arriba, a los dos lados de la entrada (con un muro entre la entrada y las salas).
	_puerta_al_pasillo(celdas, aspecto, rng, _salas(celdas, aspecto, rng, 1, centro - 2, arriba), FILA_PASILLO - 1, desde, hasta)
	_puerta_al_pasillo(celdas, aspecto, rng, _salas(celdas, aspecto, rng, centro + 2, ANCHO - 2, arriba), FILA_PASILLO - 1,
		desde, hasta)
	if rng.randf() < 0.5:
		# Salón del trono: se entra desde el pasillo, frente a la entrada, y a sus
		# lados hay salas que solo dan a él.
		var salon := Rect2i(centro - 2, abajo, 5, 2)
		for y in range(salon.position.y, salon.end.y):
			for x in range(salon.position.x, salon.end.x):
				_cavar(celdas, aspecto, Vector2i(x, y), "salon")
		_cavar(celdas, aspecto, Vector2i(centro, FILA_PASILLO + 1), "puerta")
		aspecto[Vector2i(centro, ALTO - 2)] = "trono"
		_salas(celdas, aspecto, rng, 1, centro - 4, abajo)
		_salas(celdas, aspecto, rng, centro + 4, ANCHO - 2, abajo)
		_cavar(celdas, aspecto, Vector2i(centro - 3, rng.randi_range(abajo, abajo + 1)), "puerta")
		_cavar(celdas, aspecto, Vector2i(centro + 3, rng.randi_range(abajo, abajo + 1)), "puerta")
	else:
		_puerta_al_pasillo(celdas, aspecto, rng, _salas(celdas, aspecto, rng, 1, ANCHO - 2, abajo), FILA_PASILLO + 1,
			desde, hasta)
	# Antorchas en los muros del pasillo y estandartes en el muro de arriba.
	for x in range(desde, hasta + 1):
		for y in [FILA_PASILLO - 1, FILA_PASILLO + 1]:
			var celda := Vector2i(x, y)
			if not es_suelo(celdas, celda) and rng.randf() < 0.3:
				aspecto[celda] = "antorcha"
	for x in range(1, ANCHO - 1):
		if es_suelo(celdas, Vector2i(x, 1)) and x != centro and rng.randf() < 0.35:
			aspecto[Vector2i(x, 0)] = "estandarte"
	return celdas


## Salas en fila entre las columnas "x0" y "x1": de 2 a 4 de ancho y 2 de alto
## (desde la fila "fila"), separadas por un muro con una puerta. Devuelve las salas.
static func _salas(celdas: Array, aspecto: Dictionary, rng: RandomNumberGenerator, x0: int, x1: int,
		fila: int) -> Array[Rect2i]:
	var salas: Array[Rect2i] = []
	var x := x0
	while x <= x1:
		var resto := x1 - x + 1
		var ancho := resto if resto <= 4 else rng.randi_range(2, mini(4, resto - 3))
		var sala := Rect2i(x, fila, ancho, 2)
		for y in range(sala.position.y, sala.end.y):
			for columna in range(sala.position.x, sala.end.x):
				_cavar(celdas, aspecto, Vector2i(columna, y), "sala")
		if not salas.is_empty():
			_cavar(celdas, aspecto, Vector2i(x - 1, rng.randi_range(fila, fila + 1)), "puerta")
		salas.append(sala)
		x += ancho + 1
	return salas


## Puerta al pasillo (en "fila_puerta") de una de esas salas al azar y, a
## veces, de otra más (hace una vuelta). La puerta va en una columna que el
## pasillo alcanza.
static func _puerta_al_pasillo(celdas: Array, aspecto: Dictionary, rng: RandomNumberGenerator, salas: Array[Rect2i],
		fila_puerta: int, desde: int, hasta: int) -> void:
	# Casi siempre, la sala de la punta más lejos de la entrada: hay que recorrer
	# la fila entera.
	var lejos_izquierda := ANCHO / 2 - salas[0].position.x
	var lejos_derecha := salas[-1].end.x - 1 - ANCHO / 2
	var punta := 0 if lejos_izquierda > lejos_derecha else salas.size() - 1
	if lejos_izquierda == lejos_derecha and rng.randf() < 0.5:
		punta = 0
	var elegidas: Array[int] = [punta if rng.randf() < PUERTA_EN_LA_PUNTA else rng.randi() % salas.size()]
	if salas.size() > 2 and rng.randf() < SEGUNDA_PUERTA_CASTILLO:
		var otra := rng.randi() % salas.size()
		if otra != elegidas[0]:
			elegidas.append(otra)
	for i in elegidas:
		var sala := salas[i]
		var columna := rng.randi_range(maxi(sala.position.x, desde), mini(sala.end.x - 1, hasta))
		_cavar(celdas, aspecto, Vector2i(columna, fila_puerta), "puerta")


# --- Laberinto (el de antes) ---

## Laberinto por búsqueda en profundidad sobre las celdas de coordenadas
## impares, con algunos atajos extra.
static func _laberinto(rng: RandomNumberGenerator) -> Array:
	var celdas := _lleno()
	var inicio := Vector2i(ANCHO / 2, 1)
	if inicio.x % 2 == 0:
		inicio.x += 1
	celdas[inicio.y][inicio.x] = Celda.SUELO
	var pila: Array[Vector2i] = [inicio]
	var direcciones := [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	while not pila.is_empty():
		var actual: Vector2i = pila[-1]
		var opciones: Array[Vector2i] = []
		for d in direcciones:
			var siguiente: Vector2i = actual + d
			if _dentro_interior(siguiente) and celdas[siguiente.y][siguiente.x] == Celda.MURO:
				opciones.append(siguiente)
		if opciones.is_empty():
			pila.pop_back()
			continue
		var elegida: Vector2i = opciones[rng.randi() % opciones.size()]
		var medio: Vector2i = (actual + elegida) / 2
		celdas[medio.y][medio.x] = Celda.SUELO
		celdas[elegida.y][elegida.x] = Celda.SUELO
		pila.append(elegida)
	# Atajos: abrir algunas paredes entre dos pasillos.
	for y in range(1, ALTO - 1):
		for x in range(1, ANCHO - 1):
			if celdas[y][x] != Celda.MURO or rng.randf() >= PROPORCION_ATAJOS:
				continue
			var horizontal: bool = celdas[y][x - 1] == Celda.SUELO and celdas[y][x + 1] == Celda.SUELO
			var vertical: bool = celdas[y - 1][x] == Celda.SUELO and celdas[y + 1][x] == Celda.SUELO
			if horizontal != vertical:
				celdas[y][x] = Celda.SUELO
	return celdas


# --- Ayudas ---

## Cuadrícula toda de muro.
static func _lleno() -> Array:
	var celdas := []
	for y in ALTO:
		var fila := []
		fila.resize(ANCHO)
		fila.fill(Celda.MURO)
		celdas.append(fila)
	return celdas


## Abre esa casilla y anota qué es (sin pisar lo que ya tenía anotado).
static func _cavar(celdas: Array, aspecto: Dictionary, celda: Vector2i, que: String) -> void:
	celdas[celda.y][celda.x] = Celda.SUELO
	if not aspecto.has(celda):
		aspecto[celda] = que


static func _dentro_interior(c: Vector2i) -> bool:
	return c.x >= 1 and c.y >= 1 and c.x <= ANCHO - 2 and c.y <= ALTO - 2


static func es_suelo(celdas: Array, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ANCHO and c.y < ALTO and celdas[c.y][c.x] == Celda.SUELO


static func _vecinos_de_suelo(celdas: Array, c: Vector2i) -> int:
	var n := 0
	for d in DIRECCIONES:
		if es_suelo(celdas, c + d):
			n += 1
	return n


## Pasos desde "origen" hasta cada celda de suelo alcanzable.
static func distancias_desde(celdas: Array, origen: Vector2i) -> Dictionary:
	var distancias := {origen: 0}
	var cola: Array[Vector2i] = [origen]
	while not cola.is_empty():
		var actual: Vector2i = cola.pop_front()
		for d in DIRECCIONES:
			var siguiente: Vector2i = actual + d
			if es_suelo(celdas, siguiente) and not distancias.has(siguiente):
				distancias[siguiente] = distancias[actual] + 1
				cola.append(siguiente)
	return distancias
