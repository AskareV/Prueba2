extends "res://pruebas/base_prueba.gd"
## Características del rey, niveles, barra de turnos por velocidad, maná y hechizos.


func _juego_nuevo() -> EstadoReino:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	return juego


func prueba_partida_nueva_empieza_en_3_con_15_puntos() -> void:
	var juego := _juego_nuevo()
	for car_id in DatosEstadisticas.ORDEN:
		verificar_cerca(juego.valor_principal(car_id), 3.0, "%s empieza en 3" % car_id)
	for sub_id in DatosEstadisticas.todas_las_subs():
		verificar_cerca(juego.valor_sub(sub_id), 3.0, "%s empieza en 3" % sub_id)
	verificar_igual(juego.puntos_principales, 15, "15 puntos para las principales")
	verificar_igual(juego.total_puntos_sub(), 0, "Sin puntos de partes al empezar")
	verificar_igual(DatosEstadisticas.todas_las_subs().size(), 21, "7 principales x 3 subs")
	juego.free()


func prueba_un_punto_principal_sube_sus_tres_subs() -> void:
	var juego := _juego_nuevo()
	verificar(juego.aplicar_puntos({"fuerza": 2}, {}), "Se aplican los puntos")
	verificar_cerca(juego.valor_principal("fuerza"), 5.0, "Fuerza sube a 5")
	for sub_id in DatosEstadisticas.CARACTERISTICAS["fuerza"]["subs"]:
		verificar_cerca(juego.valor_sub(sub_id), 5.0, "%s sube con Fuerza" % sub_id)
	verificar_cerca(juego.valor_sub("precision"), 3.0, "Las demás no cambian")
	verificar_igual(juego.puntos_principales, 13, "Quedan 13")
	verificar(not juego.aplicar_puntos({"fuerza": 20}, {}), "No se gastan más puntos de los que hay")
	verificar(not juego.aplicar_puntos({"inventada": 1}, {}), "Una característica inexistente no vale")
	verificar_igual(juego.puntos_principales, 13, "Lo rechazado no gasta nada")
	juego.free()


func prueba_cada_punto_principal_da_3_solo_para_sus_partes() -> void:
	var juego := _juego_nuevo()
	verificar_igual(DatosEstadisticas.PUNTOS_SUB_POR_PRINCIPAL, 3, "Cada punto principal da 3 para sus partes")
	verificar(juego.aplicar_puntos({"fuerza": 3}, {}), "3 puntos en Fuerza")
	verificar_igual(juego.puntos_sub_de("fuerza"), 9, "3 puntos en Fuerza dan 9 para sus partes")
	verificar_igual(juego.puntos_sub_de("destreza"), 0, "Las demás no reciben puntos")
	verificar(not juego.aplicar_puntos({}, {"velocidad": 1}), "Los puntos de Fuerza no sirven para Destreza")
	verificar(not juego.aplicar_puntos({}, {"fuerza_maxima": 10}), "No más de los 9")
	verificar(juego.aplicar_puntos({}, {"fuerza_maxima": 6, "fuerza_agarre": 3}), "Los 9 en las partes de Fuerza")
	verificar_cerca(juego.valor_sub("fuerza_maxima"), 12.0, "3 + 3 por Fuerza + 6")
	verificar_cerca(juego.valor_sub("fuerza_explosiva"), 6.0, "Sin puntos propios, solo los de Fuerza")
	verificar_igual(juego.puntos_sub_de("fuerza"), 0, "Ya no quedan")
	verificar(not juego.aplicar_puntos({}, {"fuerza_maxima": 1}), "Sin puntos no se puede")
	# El punto principal y sus partes se pueden repartir de una vez.
	verificar(juego.aplicar_puntos({"destreza": 1, "inteligencia": 1}, {"velocidad": 2, "arcano": 3}), "Principal y partes juntos")
	verificar_cerca(juego.valor_sub("velocidad"), 6.0, "3 + 1 por Destreza + 2")
	verificar_igual(juego.puntos_sub_de("destreza"), 1, "Sobra 1 para Destreza")
	verificar_igual(juego.total_puntos_sub(), 1, "En total queda 1")
	verificar(not juego.aplicar_puntos({"carisma": 1}, {"presencia": 4}), "Un punto da 3, no 4")
	verificar_igual(juego.puntos_principales, 10, "Lo rechazado no gasta el punto principal")
	verificar_igual(juego.puntos_sub_de("carisma"), 0, "Ni da sus puntos")
	juego.free()


func prueba_amuleto_suma_a_las_demas() -> void:
	var juego := _juego_nuevo()
	juego.puntos_sub = {"suerte": 10}
	verificar(juego.aplicar_puntos({}, {"amuleto": 10}), "10 puntos en Amuleto")
	verificar_cerca(juego.valor_sub("amuleto"), 13.0, "Amuleto en 13")
	var suma := 10 * DatosEstadisticas.AMULETO_POR_PUNTO
	verificar_cerca(juego.valor_sub("velocidad"), 3.0 + suma, "10 puntos de Amuleto suman a las demás")
	verificar_cerca(juego.valor_sub("golpe_suerte"), 3.0 + suma, "También a las de Suerte")
	var pendiente := juego.valor_sub("velocidad", {}, {"amuleto": 5})
	verificar_cerca(pendiente, 3.0 + 15 * DatosEstadisticas.AMULETO_POR_PUNTO, "Los puntos sin confirmar se ven antes de aplicarlos")
	juego.extra["amuleto"] = 100
	verificar_cerca(juego.valor_sub("velocidad"), 3.0 + DatosEstadisticas.TOPE_PUNTOS * DatosEstadisticas.AMULETO_POR_PUNTO,
		"Amuleto también tiene tope")
	juego.free()


func prueba_experiencia_y_niveles() -> void:
	var juego := _juego_nuevo()
	var resultado := juego.ganar_xp(DatosEstadisticas.xp_para_subir(1) + 5)
	verificar_igual(juego.nivel, 2, "Sube al nivel 2")
	verificar_igual(resultado["niveles"], 1, "Un nivel")
	verificar_igual(juego.xp, 5, "Sobra experiencia para el siguiente")
	verificar_igual(juego.puntos_principales, 16, "+1 punto principal")
	verificar_igual(juego.total_puntos_sub(), 0, "Los puntos de partes llegan al poner el principal")
	juego.ganar_xp(10000)
	verificar(juego.nivel > 5, "Muchos niveles de una vez")
	verificar(DatosEstadisticas.xp_para_subir(5) > DatosEstadisticas.xp_para_subir(1), "Cada nivel pide más")
	var estudioso := _juego_nuevo()
	estudioso.puntos_sub = {"inteligencia": 10}
	estudioso.aplicar_puntos({}, {"estudio": 10})
	verificar(estudioso.ganar_xp(100)["xp"] > 100, "Estudio da más experiencia")
	juego.free()
	estudioso.free()


func prueba_el_rey_toma_sus_caracteristicas() -> void:
	var juego := _juego_nuevo()
	var base := juego.crear_rey()
	verificar_igual(base.vida_max, 100, "Vitalidad en la base: 100 de vida")
	verificar_cerca(base.rapidez, 13.0, "Rapidez base 13")
	verificar_cerca(base.mana_max, float(DatosEstadisticas.MANA_BASE), "Maná base")
	verificar_cerca(base.prob_critico(), 0.0, "Sin puntos de suerte no hay críticos")
	juego.puntos_sub = {"aguante": 4, "destreza": 3, "inteligencia": 2, "suerte": 3}
	verificar(juego.aplicar_puntos({}, {"vitalidad": 4, "velocidad": 3, "mago": 2, "golpe_suerte": 3}), "Puntos aplicados")
	var rey := juego.crear_rey()
	verificar_igual(rey.vida_max, 120, "Vitalidad sube la vida")
	verificar_cerca(rey.rapidez, 13.0 + 3 * DatosEstadisticas.RAPIDEZ_POR_VELOCIDAD, "Velocidad sube la rapidez")
	verificar(rey.mana_max > base.mana_max and rey.regeneracion_mana() > base.regeneracion_mana(), "Mago: más maná")
	verificar(rey.prob_critico() > 0.0, "Golpe de suerte da críticos")
	juego.free()


func prueba_efectos_fuera_del_combate() -> void:
	var juego := _juego_nuevo()
	var objeto := DatosBotin.crear_arma("espada", 2, "raro")
	verificar_igual(juego.precio_venta(objeto), int(objeto["precio"]), "Sin Negociación, precio base")
	verificar_cerca(juego.estres_de_paso(1.0), 1.0, "Sin Cardio, el paso cuesta lo mismo")
	juego.puntos_sub = {"carisma": 10, "aguante": 5, "resiliencia": 5, "suerte": 5}
	verificar(juego.aplicar_puntos({}, {"negociacion": 5, "cardio": 5, "compostura": 5, "presencia": 5, "buen_ojo": 5}),
		"Puntos aplicados")
	verificar(juego.precio_venta(objeto) > int(objeto["precio"]), "Negociación: vendes más caro")
	verificar(juego.estres_de_paso(1.0) < 1.0, "Cardio: cada paso cuesta menos")
	verificar(juego.estres_mental(10.0) < 10.0, "Compostura: menos estrés")
	verificar(juego.multiplicador_pago() > 1.0, "Presencia: los trabajos pagan más")
	verificar(juego.oro_hallado(100) > 100, "Buen ojo: más oro")
	juego.puntos_sub = {"aguante": 1000}
	juego.aplicar_puntos({}, {"cardio": 1000})
	verificar(juego.estres_de_paso(1.0) >= DatosEstadisticas.MINIMO_REDUCCION - 0.001, "El paso nunca deja de costar")
	juego.free()


func prueba_buen_ojo_mejora_la_calidad() -> void:
	for nivel in range(1, 5):
		for bonus in [1.0, 1.5, 3.0, 100.0]:
			var tabla := DatosBotin.probabilidades(nivel, bonus)
			var suma := 0.0
			for prob in tabla:
				suma += prob
				verificar(prob >= 0.0, "Ninguna probabilidad negativa")
			verificar_cerca(suma, 100.0, "Suman 100 (nivel %d, bonus %s)" % [nivel, bonus])
	var normal := DatosBotin.probabilidades(1, 1.0)
	var con_ojo := DatosBotin.probabilidades(1, 1.5)
	verificar(con_ojo[3] > normal[3] and con_ojo[0] < normal[0], "Más legendarios, menos normales")


func prueba_amuleto_mejora_los_dias_de_las_zonas() -> void:
	var sin := DatosAventura.pesos_sucesos(0.0)
	var con := DatosAventura.pesos_sucesos(10.0)
	verificar(con["oro"] > sin["oro"] and con["descanso"] > sin["descanso"], "Más días buenos")
	verificar(con["trampa"] < sin["trampa"], "Menos trampas")
	verificar_cerca(con["combate"], sin["combate"], "Los combates no cambian")


func prueba_barra_misma_velocidad_se_alternan() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var rival := DatosRivales.crear_rival("bandido")
	var orden := OrdenTurnos.new(rey, rival)
	var esperado := [rey, rival, rey, rival, rey, rival]
	for i in esperado.size():
		verificar(orden.siguiente() == esperado[i], "Turno %d alternado" % (i + 1))


func prueba_barra_el_mas_rapido_actua_dos_veces() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var rival := DatosRivales.crear_rival("bandido")
	rey.rapidez = 12.0
	rival.rapidez = 8.0
	var orden := OrdenTurnos.new(rey, rival)
	var vista := orden.vista_previa(10)
	var texto := ""
	for luchador in vista:
		texto += "R" if luchador == rey else "E"
	verificar_igual(texto, "RERRERERRE", "Con 12 contra 8: R E R R E R E R R E")
	for i in 10:
		verificar(orden.siguiente() == vista[i], "La vista previa coincide con lo que pasa")


func prueba_barra_nunca_mas_de_dos_seguidos() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var rival := DatosRivales.crear_rival("bandido")
	rey.rapidez = 60.0
	var orden := OrdenTurnos.new(rey, rival)
	var seguidos := 0
	var maximo := 0
	var turnos_rival := 0
	for i in 60:
		if orden.siguiente() == rey:
			seguidos += 1
			maximo = maxi(maximo, seguidos)
		else:
			seguidos = 0
			turnos_rival += 1
	verificar_igual(maximo, OrdenTurnos.MAX_SEGUIDOS, "Como mucho dos turnos seguidos")
	verificar(turnos_rival >= 19, "El lento igual actúa")


func prueba_barra_retrasar_y_piernas() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var rival := DatosRivales.crear_rival("bandido")
	var orden := OrdenTurnos.new(rey, rival)
	orden.siguiente()
	orden.retrasar(rival, 100.0)
	verificar(orden.vista_previa(1)[0] == rey, "Retrasado un turno entero, vuelve a tocarle al rey")
	var rapidez_sana := rival.rapidez_efectiva()
	for parte_id in ["muslo_der", "muslo_izq"]:
		rival.integridad[parte_id] = 0.0
	verificar(rival.rapidez_efectiva() < rapidez_sana, "Con las piernas inutilizadas es más lento")
	var lenta := rival.rapidez_efectiva()
	rival.atemorizado = true
	verificar_cerca(rival.rapidez_efectiva(), lenta * MotorCombate.ATEMORIZADO_RAPIDEZ, "Atemorizado, todavía más lento")


func prueba_precision_reflejos_y_fuerza() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var habil := DatosRivales.crear_rey(true, "espada", {"precision": 8.0, "fuerza_maxima": 8.0, "reflejos": 8.0})
	var rival := DatosRivales.crear_rival("bandido")
	for parte_id in ["craneo", "abdomen", "mano_der"]:
		var normal := MotorCombate.prob_acierto(rey, rival, parte_id)
		var mejor := MotorCombate.prob_acierto(habil, rival, parte_id)
		verificar_cerca(mejor - normal, 5 * DatosEstadisticas.ACIERTO_POR_PRECISION, "Precisión suma un poco en %s" % parte_id, 0.0001)
	verificar(MotorCombate.prob_acierto(rival, habil, "abdomen") < MotorCombate.prob_acierto(rival, rey, "abdomen"),
		"Reflejos: le cuesta más acertarte")
	verificar(MotorCombate.multiplicador_golpe(habil, rival, "abdomen") > MotorCombate.multiplicador_golpe(rey, rival, "abdomen"),
		"Fuerza máxima: más daño")


func prueba_guardia_agarre_y_explosiva() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var rival := DatosRivales.crear_rival("bandido")
	verificar_cerca(MotorCombate.factor_guardia(rival, rey), MotorCombate.REDUCCION_DANIO_EN_GUARDIA, "En la base, la mitad")
	var agarre := DatosRivales.crear_rey(true, "espada", {"fuerza_agarre": 8.0})
	verificar(MotorCombate.factor_guardia(rival, agarre) < 0.5, "Agarre: al defenderte recibes menos")
	var bruto := DatosRivales.crear_rey(true, "maza", {"fuerza_explosiva": 100.0})
	verificar_cerca(MotorCombate.factor_guardia(bruto, rival), MotorCombate.GUARDIA_MAXIMA, "Romper la guardia tiene tope")
	verificar_cerca(MotorCombate.prob_empujar(rey, rival), 0.0, "Sin Fuerza explosiva no empuja")
	verificar(MotorCombate.prob_empujar(bruto, rival) > 0.0, "Fuerza explosiva empuja")
	var firme := DatosRivales.crear_rey(true, "espada", {"firmeza": 10.0})
	verificar(MotorCombate.prob_empujar(bruto, firme) < MotorCombate.prob_empujar(bruto, rival), "Firmeza resiste empujones")
	verificar(MotorCombate.umbral_desmayo(firme) < MotorCombate.umbral_desmayo(rey), "Firmeza: cuesta más desmayarse")


func prueba_criticos_solo_con_suerte() -> void:
	var rng := rng_fijo(7)
	var con_suerte := DatosRivales.crear_rey(true, "espada", {"golpe_suerte": 60.0})
	var criticos := 0
	for i in 300:
		var rival := DatosRivales.crear_rival("orco")
		rival.vida = 100000
		var resultado := MotorCombate.resolver_ataque(con_suerte, rival, "abdomen", rng, 1)
		if resultado["critico"]:
			criticos += 1
			verificar(resultado["acierto"], "Un crítico siempre acierta")
	verificar(criticos > 20, "Con mucha suerte salen críticos (%d)" % criticos)
	verificar_cerca(con_suerte.prob_critico(), DatosEstadisticas.CRITICO_POR_SUERTE * DatosEstadisticas.TOPE_PUNTOS,
		"Pero con tope: 60 puntos valen como 20")
	var sin_suerte := DatosRivales.crear_rey(true, "espada")
	for i in 100:
		var rival := DatosRivales.crear_rival("orco")
		verificar(not MotorCombate.resolver_ataque(sin_suerte, rival, "abdomen", rng, 1)["critico"], "Sin suerte no hay críticos")


func prueba_atemorizar_con_presencia() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var goblin := DatosRivales.crear_rival("goblin")
	verificar(not MotorCombate.puede_atemorizar(rey, goblin), "Con presencia 3 no atemoriza a nadie")
	var imponente := DatosRivales.crear_rey(true, "espada", {"presencia": 6.0})
	verificar(MotorCombate.puede_atemorizar(imponente, goblin), "Con presencia 6 atemoriza a un goblin")
	verificar(not MotorCombate.puede_atemorizar(imponente, DatosRivales.crear_rival("caballero_negro")),
		"Pero no a un caballero negro")
	var normal := MotorCombate.prob_acierto(goblin, rey, "abdomen")
	var danio := MotorCombate.multiplicador_golpe(goblin, rey, "abdomen")
	goblin.atemorizado = true
	verificar(MotorCombate.prob_acierto(goblin, rey, "abdomen") < normal, "Atemorizado acierta menos")
	verificar(MotorCombate.multiplicador_golpe(goblin, rey, "abdomen") < danio, "Atemorizado pega menos")


func prueba_baston_gasta_mana() -> void:
	var rng := rng_fijo(3)
	var rey := DatosRivales.crear_rey(true, "baston")
	var rival := DatosRivales.crear_rival("orco")
	rival.vida = 100000
	var mana := rey.mana
	MotorCombate.resolver_ataque(rey, rival, "abdomen", rng, 1)
	verificar_cerca(rey.mana, mana - DatosHechizos.COSTE_BASTON, "Cada golpe con bastón gasta maná")
	verificar_igual(rey.datos_arma()["tipo"], "arcano", "Con maná pega con magia")
	rey.mana = 1.0
	var debil := rey.datos_arma()
	verificar_igual(debil["tipo"], "contundente", "Sin maná pega como un palo")
	verificar(int(debil["danio_max"]) < int(DatosArmas.arma("baston")["danio_max"]), "Y más flojo")
	MotorCombate.resolver_ataque(rey, rival, "abdomen", rng, 1)
	verificar_cerca(rey.mana, 1.0, "Sin maná no gasta")
	rey.regenerar_mana()
	verificar(rey.mana > 1.0, "Recupera maná en su turno")
	var goblin := DatosRivales.crear_rival("goblin")
	verificar(not goblin.usa_mana, "Los enemigos sin magia no usan maná")
	var chaman := DatosRivales.crear_rival("chaman_goblin")
	verificar(chaman.usa_mana and chaman.datos_arma()["tipo"] == "arcano", "Los chamanes usan maná")
	var mana_chaman := chaman.mana
	MotorCombate.resolver_ataque(chaman, DatosRivales.crear_rey(true, "espada"), "abdomen", rng, 1)
	verificar_cerca(chaman.mana, mana_chaman - DatosHechizos.COSTE_BASTON, "Su bastón también gasta maná")


func prueba_hechizos() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	for hechizo_id in DatosHechizos.ORDEN:
		verificar(DatosHechizos.puede_lanzar(rey, hechizo_id), "Con el maná inicial alcanza para %s" % hechizo_id)
	rey.mana = 0.0
	verificar(not DatosHechizos.puede_lanzar(rey, "curacion"), "Sin maná no se lanza")
	var sabio := DatosRivales.crear_rey(true, "espada", {"arcano": 8.0})
	verificar(DatosHechizos.cura(sabio) > DatosHechizos.cura(rey), "Arcano cura más")
	var rival := DatosRivales.crear_rival("bandido")
	rey.hechizo = DatosHechizos.como_arma("llamarada")
	sabio.hechizo = DatosHechizos.como_arma("llamarada")
	verificar(DatosArmas.es_magico(rey.datos_arma()["tipo"]), "La llamarada es magia")
	verificar(MotorCombate.multiplicador_golpe(sabio, rival, "abdomen") > MotorCombate.multiplicador_golpe(rey, rival, "abdomen"),
		"Arcano: la llamarada pega más")
	rey.desarmado = true
	verificar(DatosArmas.es_magico(rey.datos_arma()["tipo"]), "Se lanza aunque esté desarmado")
	var resultado := MotorCombate.resolver_ataque(rey, rival, "abdomen", rng_fijo(1), 1)
	verificar_igual(resultado["arma"], "llamarada", "El golpe se narra como el hechizo")


func prueba_ninguna_parte_mejora_mas_alla_del_tope() -> void:
	var tope := DatosEstadisticas.BASE + DatosEstadisticas.TOPE_PUNTOS
	var en_el_tope := DatosRivales.crear_rey(true, "espada", {"fuerza_maxima": tope, "vitalidad": tope, "velocidad": tope})
	var pasado := DatosRivales.crear_rey(true, "espada", {"fuerza_maxima": tope + 40, "vitalidad": tope + 40, "velocidad": tope + 40})
	var rival := DatosRivales.crear_rival("bandido")
	verificar_cerca(pasado.puntos("fuerza_maxima"), DatosEstadisticas.TOPE_PUNTOS, "Los puntos útiles llegan al tope")
	verificar_cerca(MotorCombate.multiplicador_golpe(pasado, rival, "abdomen"), MotorCombate.multiplicador_golpe(en_el_tope, rival, "abdomen"),
		"Fuerza máxima no crece más allá del tope")
	verificar_igual(pasado.vida_max, en_el_tope.vida_max, "Vitalidad tampoco")
	verificar_cerca(pasado.rapidez, en_el_tope.rapidez, "Ni Velocidad")
	var juego := _juego_nuevo()
	juego.extra["buen_ojo"] = 100
	verificar_cerca(juego.puntos_de("buen_ojo"), DatosEstadisticas.TOPE_PUNTOS, "En el reino también")
	verificar_cerca(juego.prob_botin_enemigo(), minf(DatosAventura.PROB_BOTIN_ENEMIGO
		* (1.0 + DatosEstadisticas.OBJETOS_POR_BUEN_OJO * DatosEstadisticas.TOPE_PUNTOS), 1.0), "Buen ojo: más objetos, con tope")
	juego.free()
