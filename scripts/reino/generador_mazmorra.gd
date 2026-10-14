class_name GeneradorMazmorra
extends RefCounted
## Crea el plano de una mazmorra: un laberinto en cuadrícula con la entrada
## arriba, enemigos y cofres. La misma semilla da siempre el mismo plano; al
## cambiar de semana cambia la semilla y la mazmorra se reinicia.

enum Celda { MURO, SUELO }

const ANCHO := 15
const ALTO := 9
## Paredes internas que se abren de más para que haya caminos alternativos.
const PROPORCION_ATAJOS := 0.12
## Distancia mínima (en pasos) entre la entrada y un enemigo o cofre.
const DISTANCIA_MINIMA := 3


## Semilla de una mazmorra en una semana.
static func semilla(mazmorra_id: String, semana: int) -> int:
	return hash("%s:%d" % [mazmorra_id, semana])


## Devuelve {"celdas": Array de filas (Array de Celda), "entrada": Vector2i,
## "enemigos": {Vector2i: enemigo_id}, "cofres": {Vector2i: true}}.
static func generar(mazmorra_id: String, semana: int) -> Dictionary:
	var datos: Dictionary = DatosAventura.MAZMORRAS[mazmorra_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla(mazmorra_id, semana)
	var celdas := _laberinto(rng)
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
	# Los cofres prefieren los callejones sin salida.
	var sin_salida := candidatas.filter(func(c: Vector2i) -> bool: return _vecinos_de_suelo(celdas, c) == 1)
	var cofres := {}
	for celda in sin_salida:
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
	return {"celdas": celdas, "entrada": entrada, "enemigos": enemigos, "cofres": cofres}


## Laberinto por búsqueda en profundidad sobre las celdas de coordenadas
## impares, con algunos atajos extra.
static func _laberinto(rng: RandomNumberGenerator) -> Array:
	var celdas := []
	for y in ALTO:
		var fila := []
		fila.resize(ANCHO)
		fila.fill(Celda.MURO)
		celdas.append(fila)
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


static func _dentro_interior(c: Vector2i) -> bool:
	return c.x >= 1 and c.y >= 1 and c.x <= ANCHO - 2 and c.y <= ALTO - 2


static func es_suelo(celdas: Array, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < ANCHO and c.y < ALTO and celdas[c.y][c.x] == Celda.SUELO


static func _vecinos_de_suelo(celdas: Array, c: Vector2i) -> int:
	var n := 0
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if es_suelo(celdas, c + d):
			n += 1
	return n


## Pasos desde "origen" hasta cada celda de suelo alcanzable.
static func distancias_desde(celdas: Array, origen: Vector2i) -> Dictionary:
	var distancias := {origen: 0}
	var cola: Array[Vector2i] = [origen]
	while not cola.is_empty():
		var actual: Vector2i = cola.pop_front()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var siguiente: Vector2i = actual + d
			if es_suelo(celdas, siguiente) and not distancias.has(siguiente):
				distancias[siguiente] = distancias[actual] + 1
				cola.append(siguiente)
	return distancias
