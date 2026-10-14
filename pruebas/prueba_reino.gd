extends "res://pruebas/base_prueba.gd"
## Reino: botín y calidades, armadura estilo LoL, venta, equipo, mazmorras que
## se reinician cada semana y trabajos del rey.


func prueba_probabilidades_de_calidad_suman_100() -> void:
	for nivel in DatosBotin.PROB_CALIDAD:
		var suma := 0.0
		for prob in DatosBotin.PROB_CALIDAD[nivel]:
			suma += prob
		verificar_cerca(suma, 100.0, "Probabilidades del nivel %d" % nivel)
	verificar(DatosBotin.PROB_CALIDAD[4][3] > DatosBotin.PROB_CALIDAD[1][3],
		"Lo legendario sale más en lugares difíciles")


func prueba_sorteo_de_calidad_respeta_las_probabilidades() -> void:
	var rng := rng_fijo()
	var cuenta := {}
	var tiradas := 20000
	for i in tiradas:
		var calidad := DatosBotin.sortear_calidad(1, rng)
		cuenta[calidad] = cuenta.get(calidad, 0) + 1
	for i in DatosBotin.CALIDADES.size():
		var calidad: String = DatosBotin.CALIDADES[i]
		var esperado: float = DatosBotin.PROB_CALIDAD[1][i]
		var obtenido: float = 100.0 * cuenta.get(calidad, 0) / tiradas
		verificar_cerca(obtenido, esperado, "Porcentaje de %s en nivel 1" % calidad, 1.5)


func prueba_botin_generado_es_valido() -> void:
	var rng := rng_fijo()
	for nivel in range(1, 5):
		for i in 200:
			var objeto := DatosBotin.generar(nivel, rng)
			verificar(DatosBotin.RANURAS.has(objeto["ranura"]), "Ranura válida")
			verificar(DatosBotin.CALIDADES.has(objeto["calidad"]), "Calidad válida")
			verificar(String(objeto["nombre"]) != "", "Tiene nombre")
			verificar(int(objeto["precio"]) > 0, "Tiene precio")
			if objeto["ranura"] == "arma":
				verificar(DatosBotin.ARMAS_BOTIN.has(objeto["base"]), "Base de arma válida")
				verificar(objeto["danio_min"] <= objeto["danio_max"], "Daño mínimo <= máximo")
				verificar(objeto["precision"] < 1.0, "Precisión menor que 100%")
			else:
				verificar(objeto["armadura"] >= 0 and objeto["resistencia_magica"] >= 0, "Armadura positiva")
				verificar(objeto["armadura"] + objeto["resistencia_magica"] > 0, "La pieza protege algo")


func prueba_mejor_calidad_es_mas_fuerte_y_mas_cara() -> void:
	var anterior_arma := {}
	var anterior_casco := {}
	var rng := rng_fijo()
	for calidad in DatosBotin.CALIDADES:
		var arma := DatosBotin.crear_arma("espada", 2, calidad)
		var casco := DatosBotin.generar(2, rng, "casco", calidad)
		if not anterior_arma.is_empty():
			verificar(arma["danio_max"] > anterior_arma["danio_max"], "Arma %s pega más" % calidad)
			verificar(arma["precio"] > anterior_arma["precio"], "Arma %s vale más" % calidad)
			verificar(casco["precio"] > anterior_casco["precio"], "Casco %s vale más" % calidad)
		anterior_arma = arma
		anterior_casco = casco
	var facil := DatosBotin.crear_arma("maza", 1, "normal")
	var dificil := DatosBotin.crear_arma("maza", 4, "normal")
	verificar(dificil["danio_max"] > facil["danio_max"], "Un arma de lugar difícil pega más")
	verificar(dificil["precio"] > facil["precio"], "Y se vende más cara")


func prueba_armadura_estilo_lol() -> void:
	verificar_cerca(MotorCombate.multiplicador_armadura(0.0), 1.0, "Sin armadura no reduce")
	verificar_cerca(MotorCombate.multiplicador_armadura(100.0), 0.5, "100 de armadura = la mitad del daño")
	verificar_cerca(MotorCombate.multiplicador_armadura(300.0), 0.25, "300 de armadura = un cuarto")
	verificar_igual(DatosBotin.porcentaje_reduccion(50.0), 33, "50 de armadura reduce 33%")


func prueba_armadura_fisica_y_magica_se_aplican_por_zona() -> void:
	var atacante := DatosRivales.crear_rey(true, "espada")
	var mago := DatosRivales.crear_rey(true, "baston")
	var defensor := DatosRivales.crear_rival("orco")
	defensor.armadura = {"torso": {"fisica": 100, "magica": 0}}
	var sin_armadura := DatosRivales.crear_rival("orco")
	var con := MotorCombate.multiplicador_golpe(atacante, defensor, "torax_der")
	var sin := MotorCombate.multiplicador_golpe(atacante, sin_armadura, "torax_der")
	verificar_cerca(con, sin * 0.5, "La armadura física reduce el golpe al torso")
	verificar_cerca(MotorCombate.multiplicador_golpe(atacante, defensor, "craneo"),
		MotorCombate.multiplicador_golpe(atacante, sin_armadura, "craneo"), "No protege la cabeza")
	verificar_cerca(MotorCombate.multiplicador_golpe(mago, defensor, "torax_der"),
		MotorCombate.multiplicador_golpe(mago, sin_armadura, "torax_der"), "El daño mágico ignora la armadura física")
	defensor.armadura = {"torso": {"fisica": 0, "magica": 100}}
	verificar_cerca(MotorCombate.multiplicador_golpe(mago, defensor, "torax_der"),
		MotorCombate.multiplicador_golpe(mago, sin_armadura, "torax_der") * 0.5, "La resistencia mágica frena la magia")


func prueba_arma_de_botin_cambia_el_danio() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var base := rey.datos_arma()
	rey.arma_objeto = DatosBotin.crear_arma("espada", 4, "legendario")
	var botin := rey.datos_arma()
	verificar(botin["danio_max"] > base["danio_max"], "El arma legendaria pega más que la básica")
	verificar_igual(botin["nombre"], rey.arma_objeto["nombre"], "Usa el nombre del botín")
	verificar_igual(botin["tipo"], base["tipo"], "Sigue siendo una espada")
	rey.arma = "maza"
	verificar_igual(rey.datos_arma(), DatosArmas.arma("maza"), "Con otra arma no usa los datos del botín")


func prueba_enemigos_del_reino_existen_y_tienen_datos() -> void:
	var lugares := []
	lugares.append_array(DatosAventura.MAZMORRAS.values())
	lugares.append_array(DatosAventura.ZONAS.values())
	for lugar in lugares:
		for enemigo_id in lugar["enemigos"]:
			verificar(DatosRivales.existe(enemigo_id), "Existe el enemigo %s" % enemigo_id)
	for enemigo_id in DatosRivales.ENEMIGOS:
		var luchador := DatosRivales.crear_rival(enemigo_id)
		verificar(luchador.vida > 0, "%s tiene vida" % enemigo_id)
	var goblin := DatosRivales.crear_rival("goblin")
	var caballero := DatosRivales.crear_rival("caballero_negro")
	verificar(goblin.proteccion("torso", false) < caballero.proteccion("torso", false),
		"Los goblins casi no usan armadura")
	var brazos: Array = DatosRivales.ENEMIGOS["caballero_negro"]["armadura"]["brazos"]
	verificar(brazos[0] > 0, "El caballero lleva armadura en los brazos")
	verificar_cerca(caballero.proteccion("brazo_izq", false), float(brazos[0]), "La armadura de brazos cubre el izquierdo")
	verificar_cerca(caballero.proteccion("brazo_der", false), float(brazos[0]), "Y el derecho")


func prueba_vender_y_equipar() -> void:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	verificar(juego.equipo.has("arma"), "Empieza con un arma")
	var casco := juego.agregar(DatosBotin.generar(1, rng_fijo(), "casco", "raro"))
	var espada := juego.agregar(DatosBotin.crear_arma("maza", 2, "epico"))
	verificar_igual(juego.inventario.size(), 2, "Dos objetos en la mochila")
	verificar(juego.equipar(casco["id"]), "Equipa el casco")
	verificar_cerca(float(juego.armadura_por_zona()["cabeza"]["fisica"]), float(casco["armadura"]),
		"El casco protege la cabeza")
	var rey := juego.crear_rey()
	verificar_cerca(rey.proteccion("cabeza", false), float(casco["armadura"]), "El rey lleva el casco al combatir")
	var vieja: Dictionary = juego.equipo["arma"]
	verificar(juego.equipar(espada["id"]), "Equipa la maza")
	verificar_igual(juego.inventario[0]["id"], vieja["id"], "El arma vieja vuelve a la mochila")
	verificar(not juego.quitar("arma"), "El arma no se puede quitar")
	verificar(juego.quitar("casco"), "El casco sí")
	var oro_antes := juego.oro
	var precio := juego.vender(vieja["id"])
	verificar_igual(precio, vieja["precio"], "Se vende a su precio")
	verificar_igual(juego.oro, oro_antes + precio, "Suma el oro")
	verificar_igual(juego.vender(vieja["id"]), 0, "No se puede vender dos veces")
	juego.free()


func prueba_el_botin_de_un_enemigo_es_del_nivel_del_lugar() -> void:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	juego.rng.seed = 3
	# El orco de la demo no tiene nivel propio: en un lugar de nivel 3 suelta botín de nivel 3.
	var objetos := 0
	for i in 60:
		var oro_antes := juego.oro
		var botin := juego.recompensa_enemigo("orco", 3)
		verificar_igual(juego.oro, oro_antes + int(botin["oro"]), "Suma el oro")
		verificar(int(botin["oro"]) >= 9, "Sin oro propio, paga según el nivel del lugar")
		var objeto: Dictionary = botin["objeto"]
		if not objeto.is_empty():
			objetos += 1
			verificar_igual(objeto["nivel"], 3, "El objeto es del nivel del lugar")
	verificar(objetos > 0, "A veces suelta un objeto")
	juego.free()


func prueba_la_semana_reinicia_lo_que_estaba_en_curso() -> void:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	juego.mazmorra = {"id": "madriguera_goblin"}
	juego.expedicion = {"id": "bosque_sombrio"}
	for i in 300:
		juego.pasar_semana()
	verificar_igual(juego.semana, 301, "Las semanas no tienen límite")
	verificar(juego.mazmorra.is_empty() and juego.expedicion.is_empty(), "La mazmorra se reinicia")
	juego.free()


func prueba_mazmorra_igual_en_la_semana_y_distinta_en_otra() -> void:
	for mazmorra_id in DatosAventura.MAZMORRAS:
		var a := GeneradorMazmorra.generar(mazmorra_id, 5)
		var b := GeneradorMazmorra.generar(mazmorra_id, 5)
		var c := GeneradorMazmorra.generar(mazmorra_id, 6)
		verificar(a["celdas"] == b["celdas"] and a["enemigos"] == b["enemigos"],
			"%s es igual dentro de la misma semana" % mazmorra_id)
		verificar(a["celdas"] != c["celdas"], "%s cambia la semana siguiente" % mazmorra_id)


func prueba_mazmorra_se_puede_recorrer_entera() -> void:
	for semana in range(1, 30):
		for mazmorra_id in DatosAventura.MAZMORRAS:
			var datos: Dictionary = DatosAventura.MAZMORRAS[mazmorra_id]
			var plano := GeneradorMazmorra.generar(mazmorra_id, semana)
			var celdas: Array = plano["celdas"]
			var alcanzables := GeneradorMazmorra.distancias_desde(celdas, plano["entrada"])
			var suelo := 0
			for y in GeneradorMazmorra.ALTO:
				for x in GeneradorMazmorra.ANCHO:
					if celdas[y][x] == GeneradorMazmorra.Celda.SUELO:
						suelo += 1
			verificar_igual(alcanzables.size(), suelo, "Todo el suelo se alcanza desde la H")
			verificar_igual(plano["enemigos"].size(), int(datos["cantidad_enemigos"]), "Cantidad de enemigos")
			verificar_igual(plano["cofres"].size(), int(datos["cofres"]), "Cantidad de cofres")
			for celda in plano["enemigos"]:
				verificar(not plano["cofres"].has(celda), "Enemigo y cofre no comparten casilla")
				verificar(alcanzables[celda] >= GeneradorMazmorra.DISTANCIA_MINIMA, "Ningún enemigo junto a la H")


func prueba_semana_de_trabajo() -> void:
	var rng := rng_fijo()
	for oficio_id in DatosTrabajos.ORDEN:
		var oficio: Dictionary = DatosTrabajos.OFICIOS[oficio_id]
		var resultado := DatosTrabajos.trabajar_semana(oficio_id, 0.0, rng)
		var buenos: int = resultado["dias"].count(true)
		verificar_igual(resultado["dias"].size(), DatosTrabajos.DIAS, "Siete días de trabajo")
		verificar_igual(resultado["oro"], buenos * int(oficio["pago"]) + int(resultado["bono"]), "Solo se cobran los días buenos")
		verificar_cerca(resultado["dominio"], DatosTrabajos.DIAS * DatosTrabajos.DOMINIO_POR_DIA, "Gana dominio")
	verificar(DatosTrabajos.prob_exito(100.0) > DatosTrabajos.prob_exito(0.0), "Con dominio sale mejor")
	verificar(DatosTrabajos.prob_exito(100.0) <= 0.95, "Nunca es seguro")
