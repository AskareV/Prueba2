extends "res://pruebas/base_prueba.gd"
## Mazmorras con estilo propio: la cueva de los goblins, la mina de los
## bandidos, el fuerte de los orcos y el castillo del reino enemigo.

const PLANOS := 120
const DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _planos(mazmorra_id: String, cuantos := PLANOS) -> Array[Dictionary]:
	var planos: Array[Dictionary] = []
	for semana in range(1, cuantos + 1):
		planos.append(GeneradorMazmorra.generar(mazmorra_id, semana, 4242))
	return planos


func _suelo(plano: Dictionary) -> Array[Vector2i]:
	var celdas: Array = plano["celdas"]
	var lista: Array[Vector2i] = []
	for y in GeneradorMazmorra.ALTO:
		for x in GeneradorMazmorra.ANCHO:
			if celdas[y][x] == GeneradorMazmorra.Celda.SUELO:
				lista.append(Vector2i(x, y))
	return lista


func _callejones(plano: Dictionary) -> int:
	var n := 0
	for celda in _suelo(plano):
		var vecinas := 0
		for d in DIRS:
			if GeneradorMazmorra.es_suelo(plano["celdas"], celda + d):
				vecinas += 1
		if vecinas == 1:
			n += 1
	return n


func prueba_cada_mazmorra_tiene_su_estilo() -> void:
	var esperados := {"madriguera_goblin": "cueva", "guarida_bandidos": "mina", "fortaleza_orca": "fuerte",
		"ciudadela_maldita": "castillo"}
	for mazmorra_id in esperados:
		verificar_igual(DatosAventura.MAZMORRAS[mazmorra_id]["estilo"], esperados[mazmorra_id], "Estilo de %s" % mazmorra_id)
		var plano := GeneradorMazmorra.generar(mazmorra_id, 3)
		verificar_igual(plano["estilo"], esperados[mazmorra_id], "El plano dice su estilo (%s)" % mazmorra_id)
		var otro := GeneradorMazmorra.generar(mazmorra_id, 3)
		verificar(plano["aspecto"] == otro["aspecto"], "El aspecto también se repite en la semana (%s)" % mazmorra_id)


func prueba_todos_los_estilos_se_pueden_recorrer() -> void:
	for mazmorra_id in DatosAventura.ORDEN_MAZMORRAS:
		var datos: Dictionary = DatosAventura.MAZMORRAS[mazmorra_id]
		for plano in _planos(mazmorra_id):
			var celdas: Array = plano["celdas"]
			var alcanzables := GeneradorMazmorra.distancias_desde(celdas, plano["entrada"])
			verificar_igual(alcanzables.size(), _suelo(plano).size(), "Todo el suelo se alcanza (%s)" % mazmorra_id)
			verificar_igual(plano["enemigos"].size(), int(datos["cantidad_enemigos"]), "Enemigos (%s)" % mazmorra_id)
			verificar_igual(plano["cofres"].size(), int(datos["cofres"]), "Cofres (%s)" % mazmorra_id)
			# El borde es pared, salvo la entrada.
			for x in GeneradorMazmorra.ANCHO:
				for y in [0, GeneradorMazmorra.ALTO - 1]:
					if Vector2i(x, y) != plano["entrada"]:
						verificar(not GeneradorMazmorra.es_suelo(celdas, Vector2i(x, y)), "Borde cerrado (%s)" % mazmorra_id)
			for y in GeneradorMazmorra.ALTO:
				for x in [0, GeneradorMazmorra.ANCHO - 1]:
					verificar(not GeneradorMazmorra.es_suelo(celdas, Vector2i(x, y)), "Borde cerrado (%s)" % mazmorra_id)
			for celda in plano["enemigos"]:
				var enemigo_id: String = plano["enemigos"][celda]
				verificar(datos["enemigos"].has(enemigo_id) or enemigo_id == datos["jefe"], "Enemigo de la mazmorra (%s)" % mazmorra_id)
				verificar(not plano["cofres"].has(celda), "Enemigo y cofre no comparten casilla")
			for celda in plano["enemigos"].keys() + plano["cofres"].keys():
				verificar(alcanzables.get(celda, 0) >= GeneradorMazmorra.DISTANCIA_MINIMA, "Lejos de la H (%s)" % mazmorra_id)


func prueba_la_cueva_tiene_tuneles_con_callejones_y_camaras() -> void:
	var callejones := 0
	var con_camara := 0
	for plano in _planos("madriguera_goblin"):
		callejones += _callejones(plano)
		for celda in _suelo(plano):
			var bloque := true
			for d in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				if not GeneradorMazmorra.es_suelo(plano["celdas"], celda + d):
					bloque = false
			if bloque:
				con_camara += 1
				break
	verificar(callejones / float(PLANOS) >= 8.0, "Muchos callejones (%.1f por cueva)" % (callejones / float(PLANOS)))
	verificar(con_camara >= PLANOS * 0.8, "Casi siempre hay alguna cámara (%d de %d)" % [con_camara, PLANOS])


func prueba_la_mina_tiene_galerias_rectas_unidas_en_zigzag() -> void:
	for plano in _planos("guarida_bandidos"):
		var aspecto: Dictionary = plano["aspecto"]
		var galerias := 0
		for y in GeneradorMazmorra.ALTO:
			var seguidas := 0
			var mejor := 0
			for x in GeneradorMazmorra.ANCHO:
				var que: String = aspecto.get(Vector2i(x, y), "")
				# La punta de una galería puede ser parte de un campamento.
				var en_galeria := que in ["galeria", "riel", "campamento"] \
					or (que == "pozo" and GeneradorMazmorra.es_suelo(plano["celdas"], Vector2i(x - 1, y)))
				seguidas = seguidas + 1 if en_galeria else 0
				mejor = maxi(mejor, seguidas)
			if mejor >= 8:
				galerias += 1
		verificar_igual(galerias, 3, "Tres galerías largas")
		verificar(aspecto.values().has("riel"), "La más larga tiene rieles")
		verificar(aspecto.values().has("pozo"), "Hay pozos")


func prueba_el_fuerte_tiene_empalizadas_portones_y_chozas() -> void:
	for plano in _planos("fortaleza_orca"):
		var aspecto: Dictionary = plano["aspecto"]
		var portones := 0
		var chozas := 0
		for celda in aspecto:
			match String(aspecto[celda]):
				"porton":
					portones += 1
					verificar(GeneradorMazmorra.es_suelo(plano["celdas"], celda), "El portón se cruza")
				"puerta":
					chozas += 1
					var da_adentro := false
					for d in DIRS:
						if aspecto.get(celda + d, "") == "interior":
							da_adentro = true
					verificar(da_adentro, "La puerta de la choza da adentro")
		verificar_igual(portones, 2, "Dos empalizadas de adentro, con un portón cada una")
		verificar(chozas >= 2, "Al menos dos chozas (%d)" % chozas)


func prueba_el_castillo_tiene_pasillo_salas_y_puertas() -> void:
	var cofres_en_salas := 0
	var cofres := 0
	for plano in _planos("ciudadela_maldita"):
		var aspecto: Dictionary = plano["aspecto"]
		var alfombra := 0
		for x in GeneradorMazmorra.ANCHO:
			if aspecto.get(Vector2i(x, GeneradorMazmorra.FILA_PASILLO), "") == "alfombra":
				alfombra += 1
		verificar(alfombra >= 10, "Un pasillo largo con alfombra (%d)" % alfombra)
		var puertas := aspecto.values().count("puerta")
		verificar(puertas >= 4, "Puertas entre salas y al pasillo (%d)" % puertas)
		verificar(aspecto.values().count("sala") >= 8, "Salas de piedra")
		# Siempre hay salón del trono, y no da al pasillo: se entra por una sala.
		var trono := Vector2i(GeneradorMazmorra.ANCHO / 2, GeneradorMazmorra.ALTO - 2)
		verificar_igual(aspecto.get(trono, ""), "trono", "Siempre hay trono")
		verificar(not _distancias_sin(plano, "sala").has(trono), "Al trono se llega pasando por una sala")
		for celda in plano["cofres"]:
			cofres += 1
			if aspecto.get(celda, "") in ["sala", "salon"]:
				cofres_en_salas += 1
	verificar(cofres_en_salas >= cofres * 0.95, "Los cofres están en las salas (%d de %d)" % [cofres_en_salas, cofres])


## Pasos desde la entrada sin pisar las casillas de ese aspecto.
func _distancias_sin(plano: Dictionary, evitar: String) -> Dictionary:
	var distancias := {plano["entrada"]: 0}
	var cola: Array[Vector2i] = [plano["entrada"]]
	while not cola.is_empty():
		var actual: Vector2i = cola.pop_front()
		for d in DIRS:
			var siguiente: Vector2i = actual + d
			if GeneradorMazmorra.es_suelo(plano["celdas"], siguiente) and not distancias.has(siguiente) \
					and plano["aspecto"].get(siguiente, "") != evitar:
				distancias[siguiente] = distancias[actual] + 1
				cola.append(siguiente)
	return distancias


## Cada mazmorra tiene un jefe al final, en su lugar: la cámara más honda de la
## cueva, el campamento más lejano de la mina, la choza más lejana del fuerte y
## el trono del castillo. Cuenta como uno de los enemigos y no comparte casilla.
func prueba_cada_mazmorra_tiene_su_jefe_al_final() -> void:
	var lugares := {"madriguera_goblin": "camara", "guarida_bandidos": "campamento", "fortaleza_orca": "interior",
		"ciudadela_maldita": "trono"}
	for mazmorra_id in DatosAventura.ORDEN_MAZMORRAS:
		var datos: Dictionary = DatosAventura.MAZMORRAS[mazmorra_id]
		verificar(DatosRivales.ENEMIGOS[datos["jefe"]].get("jefe", false), "El jefe de %s es un jefe" % mazmorra_id)
		var que: String = lugares[mazmorra_id]
		var en_su_lugar := 0
		var lejos := 0.0
		var planos := _planos(mazmorra_id)
		for plano in planos:
			var jefe: Vector2i = plano["jefe"]
			verificar_igual(plano["enemigos"].get(jefe, ""), datos["jefe"], "El jefe está en su casilla (%s)" % mazmorra_id)
			verificar_igual(plano["enemigos"].values().count(datos["jefe"]), 1, "Un solo jefe (%s)" % mazmorra_id)
			verificar(not plano["cofres"].has(jefe), "El jefe no está sobre un cofre (%s)" % mazmorra_id)
			var distancias := GeneradorMazmorra.distancias_desde(plano["celdas"], plano["entrada"])
			if plano["aspecto"].get(jefe, "") == que:
				en_su_lugar += 1
			for celda in plano["aspecto"]:
				if plano["aspecto"][celda] == que:
					verificar(distancias.get(celda, 0) <= distancias[jefe], "Ninguno de su lugar queda más lejos (%s)" % mazmorra_id)
			var mas_lejos := 0
			for celda in distancias:
				mas_lejos = maxi(mas_lejos, distancias[celda])
			lejos += float(distancias[jefe]) / mas_lejos
		# Casi todas las cuevas tienen alguna cámara; si no, el jefe espera en el
		# callejón más lejos.
		var minimo := 0.8 if mazmorra_id == "madriguera_goblin" else 1.0
		verificar(en_su_lugar >= planos.size() * minimo, "%s: el jefe en su lugar (%d de %d)" % [mazmorra_id, en_su_lugar, planos.size()])
		verificar(lejos / planos.size() >= 0.6, "%s: el jefe queda lejos de la entrada (%.0f%% de lo más lejos)" % [
			mazmorra_id, 100.0 * lejos / planos.size()])


func prueba_la_mina_tiene_campamentos() -> void:
	var con_campamento := 0
	for plano in _planos("guarida_bandidos"):
		if plano["aspecto"].values().has("campamento"):
			con_campamento += 1
			verificar(plano["aspecto"].values().has("fogata"), "Cada campamento tiene su fogata")
	verificar(con_campamento >= PLANOS * 0.95, "Casi todas las minas tienen campamento (%d de %d)" % [con_campamento, PLANOS])


func prueba_la_mina_y_el_fuerte_guardan_los_cofres_en_su_lugar() -> void:
	var en_su_lugar := {"guarida_bandidos": 0, "fortaleza_orca": 0}
	var total := {"guarida_bandidos": 0, "fortaleza_orca": 0}
	for mazmorra_id in en_su_lugar:
		for plano in _planos(mazmorra_id):
			for celda in plano["cofres"]:
				total[mazmorra_id] += 1
				var que: String = plano["aspecto"].get(celda, "")
				if que in ["nicho", "campamento", "interior"]:
					en_su_lugar[mazmorra_id] += 1
	verificar(en_su_lugar["guarida_bandidos"] >= total["guarida_bandidos"] * 0.8,
		"En la mina, en nichos y campamentos (%d de %d)" % [en_su_lugar["guarida_bandidos"], total["guarida_bandidos"]])
	verificar(en_su_lugar["fortaleza_orca"] >= total["fortaleza_orca"] * 0.6,
		"En el fuerte, dentro de las chozas (%d de %d)" % [en_su_lugar["fortaleza_orca"], total["fortaleza_orca"]])


## Con la niebla (el rey solo conoce lo que descubrió), limpiar cada mazmorra
## pide caminar parecido a como pedía el laberinto de antes (unos 95 pasos):
## así el estrés sigue igual de exigente.
func prueba_hay_que_caminar_como_antes() -> void:
	for mazmorra_id in DatosAventura.ORDEN_MAZMORRAS:
		var total := 0.0
		var planos := _planos(mazmorra_id, 60)
		for plano in planos:
			total += _pasos_con_niebla(plano)
		var promedio := total / planos.size()
		verificar(promedio >= 75.0 and promedio <= 115.0, "%s: unos %.0f pasos para limpiarla" % [mazmorra_id, promedio])


func _pasos_con_niebla(plano: Dictionary) -> int:
	var celdas: Array = plano["celdas"]
	var conocidas := {}
	var pos: Vector2i = plano["entrada"]
	_revelar(conocidas, pos)
	var objetivos := {}
	for celda in plano["enemigos"].keys() + plano["cofres"].keys():
		objetivos[celda] = true
	var pasos := 0
	for _vuelta in 500:
		if objetivos.is_empty():
			break
		var dist := _distancias(celdas, conocidas, pos)
		var meta := Vector2i(-1, -1)
		for o in objetivos:
			if dist.has(o) and (meta.x < 0 or dist[o] < dist[meta]):
				meta = o
		if meta.x < 0:
			for celda in dist:
				var frontera := DIRS.any(func(d: Vector2i) -> bool: return not conocidas.has(celda + d))
				if frontera and celda != pos and (meta.x < 0 or dist[celda] < dist[meta]):
					meta = celda
		if meta.x < 0:
			break
		var camino := _camino(celdas, conocidas, pos, meta)
		for paso in camino:
			pos = paso
			pasos += 1
			_revelar(conocidas, pos)
		objetivos.erase(pos)
	return pasos + _camino(celdas, conocidas, pos, plano["entrada"]).size()


func _revelar(conocidas: Dictionary, celda: Vector2i) -> void:
	conocidas[celda] = true
	for d in DIRS:
		conocidas[celda + d] = true


func _distancias(celdas: Array, conocidas: Dictionary, origen: Vector2i) -> Dictionary:
	var dist := {origen: 0}
	var cola: Array[Vector2i] = [origen]
	while not cola.is_empty():
		var actual: Vector2i = cola.pop_front()
		for d in DIRS:
			var siguiente: Vector2i = actual + d
			if conocidas.has(siguiente) and GeneradorMazmorra.es_suelo(celdas, siguiente) and not dist.has(siguiente):
				dist[siguiente] = dist[actual] + 1
				cola.append(siguiente)
	return dist


func _camino(celdas: Array, conocidas: Dictionary, desde: Vector2i, hasta: Vector2i) -> Array[Vector2i]:
	var dist := _distancias(celdas, conocidas, hasta)
	var camino: Array[Vector2i] = []
	var pos := desde
	while pos != hasta:
		for d in DIRS:
			var siguiente: Vector2i = pos + d
			if dist.has(siguiente) and dist[siguiente] == dist[pos] - 1:
				pos = siguiente
				break
		camino.append(pos)
	return camino


func prueba_el_reino_enemigo_tiene_lanceros() -> void:
	var lugar: Dictionary = DatosAventura.MAZMORRAS["ciudadela_maldita"]
	verificar(lugar["enemigos"].has("lancero_negro"), "La ciudadela tiene lanceros")
	var datos: Dictionary = DatosRivales.ENEMIGOS["lancero_negro"]
	verificar_igual(datos["nivel"], 4, "De nivel 4, como los demás de la ciudadela")
	verificar_igual(datos["arma"], "lanza", "Con lanza")
	verificar(datos.has("oro") and datos.has("armadura"), "Con oro y armadura")
	var lancero := DatosRivales.crear_rival("lancero_negro")
	var demo := DatosRivales.crear_rival("lancero")
	verificar(lancero.proteccion("torso", "cortante") > demo.proteccion("torso", "cortante"), "Más protegido que el de la demo")
	var salen := false
	for plano in _planos("ciudadela_maldita", 20):
		if plano["enemigos"].values().has("lancero_negro"):
			salen = true
	verificar(salen, "Aparecen en la ciudadela")
