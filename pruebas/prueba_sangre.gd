extends "res://pruebas/base_prueba.gd"
## Sangrado (B.1), infecciones (B.4) y lo que los trata: vendas, torniquetes,
## medicinas, descansar y la enfermería.

const ARCHIVO_PRUEBA := "user://prueba_sangre.save"
const SANGRE := DatosHeridas.SANGRE_MAX


func _juego_nuevo() -> EstadoReino:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	juego.rng.seed = 5
	return juego


## Resultado de un golpe acertado con esa herida, para MotorCombate._causar_sangrado.
func _golpe(herida: String, parte_id: String) -> Dictionary:
	return {"parte": parte_id, "herida": herida, "sangrado": 0, "sangrado_tipo": ""}


func _nivel(sangrados: Array[Dictionary], parte_id: String, tipo := "externo") -> int:
	for sangrado in sangrados:
		if sangrado["parte"] == parte_id and sangrado["tipo"] == tipo:
			return int(sangrado["nivel"])
	return 0


func prueba_los_cortes_sangran_por_fuera_y_los_golpes_por_dentro() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var orco := DatosRivales.crear_rival("orco")
	# Un buen corte en el cuello (las arterias) sangra mucho; en la mano, poco.
	var golpe := _golpe("Corte", "cuello")
	MotorCombate._causar_sangrado(rey, orco, "cuello", 17.0, golpe)
	verificar_igual(golpe["sangrado"], 3, "Un corte en el cuello sangra mucho")
	verificar_igual(golpe["sangrado_tipo"], "externo", "Por fuera")
	verificar(orco.sangra_por_fuera(), "Y se ve")
	golpe = _golpe("Corte", "mano_der")
	MotorCombate._causar_sangrado(rey, orco, "mano_der", 17.0, golpe)
	verificar_igual(golpe["sangrado"], 1, "En la mano, poco")
	# La armadura frena el golpe y también el sangrado.
	var acorazado := DatosRivales.crear_rival("orco")
	acorazado.armadura["cabeza"] = {"fisica": 100, "magica": 0}
	golpe = _golpe("Corte", "cuello")
	MotorCombate._causar_sangrado(rey, acorazado, "cuello", 17.0, golpe)
	verificar(golpe["sangrado"] > 0 and golpe["sangrado"] < 3, "Con armadura sangra menos (%d)" % golpe["sangrado"])
	# Un mazazo en el tórax sangra por dentro; en un brazo, no sangra.
	var con_maza := DatosRivales.crear_rey(true, "maza")
	golpe = _golpe("Contusión", "torax_izq")
	MotorCombate._causar_sangrado(con_maza, orco, "torax_izq", 19.0, golpe)
	verificar(golpe["sangrado"] >= 1 and golpe["sangrado_tipo"] == "interno", "Un mazazo en el tórax sangra por dentro")
	verificar(not orco.sangrados.is_empty() and _nivel(orco.sangrados, "torax_izq", "interno") >= 1, "Queda anotado")
	golpe = _golpe("Contusión", "brazo_der")
	MotorCombate._causar_sangrado(con_maza, orco, "brazo_der", 19.0, golpe)
	verificar_igual(golpe["sangrado"], 0, "Un mazazo en un brazo no sangra")
	golpe = _golpe("Fractura", "muslo_izq")
	MotorCombate._causar_sangrado(con_maza, orco, "muslo_izq", 15.0, golpe)
	verificar(golpe["sangrado"] >= DatosHeridas.NIVEL_FRACTURA_MUSLO and golpe["sangrado_tipo"] == "interno",
		"Una fractura de muslo sangra por dentro")
	golpe = _golpe("Quemadura", "cuello")
	MotorCombate._causar_sangrado(rey, orco, "cuello", 13.0, golpe)
	verificar_igual(golpe["sangrado"], 0, "Las quemaduras no sangran")
	# Quien no sangra (por ejemplo, un esqueleto) no sangra nunca.
	var esqueleto := DatosRivales.crear_rival("orco")
	esqueleto.sangra = false
	golpe = _golpe("Corte", "cuello")
	MotorCombate._causar_sangrado(rey, esqueleto, "cuello", 17.0, golpe)
	verificar(golpe["sangrado"] == 0 and esqueleto.sangrados.is_empty(), "Las criaturas que no sangran, no")


func prueba_un_golpe_acertado_puede_hacer_sangrar() -> void:
	var rng := rng_fijo(4)
	var con_sangrado := 0
	for i in 200:
		var rey := DatosRivales.crear_rey(true, "espada")
		var orco := DatosRivales.crear_rival("orco")
		var resultado := MotorCombate.resolver_ataque(rey, orco, "muslo_der", rng, 1)
		if resultado["acierto"]:
			verificar(resultado["sangrado"] >= 2, "Un corte en el muslo sangra bastante (%d)" % resultado["sangrado"])
			con_sangrado += 1
	verificar(con_sangrado > 50, "Aciertan y sangran (%d de 200)" % con_sangrado)


func prueba_la_misma_parte_herida_otra_vez_sangra_mas() -> void:
	var orco := DatosRivales.crear_rival("orco")
	verificar_igual(orco.agregar_sangrado("brazo_der", "externo", 2), 2, "Una herida moderada")
	verificar_igual(orco.agregar_sangrado("brazo_der", "externo", 2), 3, "Dos moderadas en la misma parte: grave")
	verificar_igual(orco.agregar_sangrado("brazo_der", "externo", 1), 3, "Una leve no la baja")
	verificar_igual(orco.agregar_sangrado("mano_der", "externo", 1), 1, "Una leve")
	verificar_igual(orco.agregar_sangrado("mano_der", "externo", 1), 1, "Dos leves siguen leves")
	verificar_igual(orco.agregar_sangrado("brazo_der", "interno", 1), 1, "Por dentro va aparte")
	verificar_igual(orco.sangrados.size(), 3, "Una por parte y tipo")


func prueba_cada_turno_se_pierde_la_sangre_y_las_leves_paran_solas() -> void:
	var orco := DatosRivales.crear_rival("orco")
	orco.agregar_sangrado("mano_der", "externo", 1)
	orco.agregar_sangrado("muslo_der", "externo", 3)
	var perdida := orco.sangrar()
	verificar_cerca(perdida, DatosHeridas.PERDIDA[1] + DatosHeridas.PERDIDA[3], "Pierde lo de todas sus heridas")
	verificar_cerca(orco.sangre, SANGRE - perdida, "Le queda menos sangre")
	for i in DatosHeridas.DURACION_LEVE:
		orco.sangrar()
	verificar_igual(_nivel(orco.sangrados, "mano_der"), 0, "La herida leve para sola")
	verificar_igual(_nivel(orco.sangrados, "muslo_der"), 3, "La grave no para sola")
	# Una parte que se cura del todo deja de sangrar.
	orco.integridad["muslo_der"] = 90.0
	orco.curar(0, 20.0)
	verificar(orco.sangrados.is_empty(), "Curada del todo, deja de sangrar")


func prueba_la_sangre_perdida_baja_la_vida_maxima_y_trae_estados() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var orco := DatosRivales.crear_rival("orco")
	var acierto := MotorCombate.prob_acierto(rey, orco, "torax_der")
	var golpe := MotorCombate.multiplicador_golpe(rey, orco, "torax_der")
	rey.vida = 90
	rey.perder_sangre(SANGRE * 0.2)
	verificar_igual(rey.vida_max, roundi(rey.vida_max_sana * 0.8), "Con el 20% de la sangre perdida, 80% de la vida máxima")
	verificar_igual(rey.vida, rey.vida_max, "La vida baja hasta la máxima")
	verificar_igual(rey.estado_sangre(), 1, "Agitado")
	verificar_cerca(MotorCombate.prob_acierto(rey, orco, "torax_der"), acierto * DatosHeridas.ACIERTO_AGITADO,
		"Agitado acierta un poco menos")
	verificar_cerca(MotorCombate.multiplicador_golpe(rey, orco, "torax_der"), golpe, "Pero pega igual")
	rey.perder_sangre(SANGRE * 0.12)
	verificar_igual(rey.estado_sangre(), 2, "Débil y confuso")
	verificar_cerca(MotorCombate.multiplicador_golpe(rey, orco, "torax_der"), golpe * DatosHeridas.DANIO_DEBIL,
		"Débil y confuso pega más flojo")
	var vida := rey.vida
	rey.recuperar_sangre(SANGRE)
	verificar_igual(rey.vida_max, rey.vida_max_sana, "Con la sangre vuelve la vida máxima")
	verificar_igual(rey.vida, vida, "Pero la vida no sube sola")
	rey.perder_sangre(SANGRE * 0.5)
	verificar(rey.muerto and rey.fuera_de_combate(), "Con la mitad de la sangre perdida, muere")


func prueba_al_empezar_el_turno_sangra_y_puede_caer_en_shock() -> void:
	var orco := DatosRivales.crear_rival("orco")
	orco.agregar_sangrado("cuello", "externo", 3)
	var inicio := MotorCombate.empezar_turno(orco, rng_fijo(1))
	verificar_cerca(inicio["sangre"], DatosHeridas.PERDIDA[3], "Al empezar su turno pierde la sangre de sus heridas")
	verificar(not inicio["muerto"] and not inicio["desmayo"], "Con poca sangre perdida, sigue")
	var rng := rng_fijo(3)
	var desmayos := 0
	var perdidos := 0
	for i in 400:
		var en_shock := DatosRivales.crear_rival("orco")
		en_shock.perder_sangre(SANGRE * 0.42)
		if MotorCombate.empezar_turno(en_shock, rng)["desmayo"]:
			desmayos += 1
		var debil := DatosRivales.crear_rival("orco")
		debil.perder_sangre(SANGRE * 0.32)
		if MotorCombate.empezar_turno(debil, rng)["pierde_turno"]:
			perdidos += 1
	var esperados := 400.0 * DatosHeridas.PROB_DESMAYO_SHOCK
	verificar(desmayos > esperados * 0.6 and desmayos < esperados * 1.4, "En shock a veces se desmaya (%d de 400)" % desmayos)
	esperados = 400.0 * DatosHeridas.PROB_PERDER_TURNO
	verificar(perdidos > esperados * 0.6 and perdidos < esperados * 1.4, "Débil y confuso a veces pierde el turno (%d)" % perdidos)
	var casi := DatosRivales.crear_rival("orco")
	casi.perder_sangre(SANGRE * 0.49)
	casi.agregar_sangrado("cuello", "externo", 3)
	verificar(MotorCombate.empezar_turno(casi, rng)["muerto"] and casi.fuera_de_combate(), "Si sigue sangrando, muere")


func prueba_un_combate_simulado_puede_terminar_desangrado() -> void:
	var Simulacion := load("res://pruebas/simulacion.gd")
	var rng := rng_fijo(9)
	var desangrados := 0
	var sangre_perdida := 0.0
	for i in 150:
		var resultado: Dictionary = Simulacion.combatir("espada", "bandido", "ia", true, rng)
		desangrados += int(resultado["desangrados"])
		sangre_perdida += float(resultado["sangre_rey"])
	verificar(desangrados > 0 and desangrados < 60, "A veces alguien se desangra (%d de 150)" % desangrados)
	verificar(sangre_perdida / 150.0 > 0.03, "Contra una espada se pierde sangre")


# --- En el reino ---

func prueba_la_sangre_y_los_sangrados_pasan_al_siguiente_combate() -> void:
	var juego := _juego_nuevo()
	var rey := juego.crear_rey()
	rey.perder_sangre(1.0)
	rey.integridad["muslo_der"] = 60.0
	rey.integridad["abdomen"] = 70.0
	rey.agregar_sangrado("muslo_der", "externo", 2)
	rey.agregar_sangrado("abdomen", "interno", 2)
	juego.guardar_salud(rey)
	verificar_cerca(juego.sangre_perdida, 1.0, "Se guarda la sangre perdida")
	var otro := juego.crear_rey()
	verificar_cerca(otro.sangre, SANGRE - 1.0, "El siguiente combate empieza con esa sangre")
	verificar_igual(otro.sangrados.size(), 2, "Y con lo que sigue sangrando")
	verificar_igual(otro.vida_max, roundi(otro.vida_max_sana * 0.8), "Y con menos vida máxima")
	verificar_igual(juego.vida_maxima(), otro.vida_max, "Igual que en el reino")
	# Al caminar sigue sangrando, y también recupera un poco.
	var antes := juego.sangre_perdida
	verificar(not juego.curar_al_caminar(), "Un paso no lo mata")
	verificar_cerca(juego.sangre_perdida, antes + DatosHeridas.PERDIDA[2] * 2 - SANGRE * DatosHeridas.SANGRE_POR_PASO,
		"Pierde por sus dos heridas y recupera un poco")
	# Al volver al castillo le vendan lo de afuera; lo de adentro sigue.
	juego.pasar_semana()
	verificar_igual(_nivel(juego.sangrados, "muslo_der"), 0, "En el castillo le vendan lo que sangra por fuera")
	verificar_igual(_nivel(juego.sangrados, "abdomen", "interno"), 2, "Lo de adentro sigue")
	juego.free()


func prueba_desangrarse_es_como_perder() -> void:
	var juego := _juego_nuevo()
	juego.integridad = {"cuello": 50.0}
	juego.sangre_perdida = SANGRE * 0.49
	juego.sangrados.assign([{"parte": "cuello", "tipo": "externo", "nivel": 3, "turnos": 3}])
	var estres := juego.estres
	verificar(juego.curar_al_caminar(), "Se desangra por el camino")
	verificar_igual(juego.vida_actual(), 1, "Lo traen con 1 de vida")
	verificar(juego.sangrados.is_empty(), "Le paran el sangrado")
	verificar_cerca(juego.estres, estres + DatosAventura.ESTRES_DERROTA, "Y suma el estrés de una derrota")
	# Si se desangra en un combate, igual: lo traen y le paran el sangrado.
	var rey := juego.crear_rey()
	rey.agregar_sangrado("cuello", "externo", 3)
	rey.perder_sangre(SANGRE)
	juego.guardar_salud(rey)
	verificar(juego.sangrados.is_empty() and juego.vida_actual() == 1, "Tras desangrarse en combate vuelve con 1 de vida y sin sangrar")
	juego.free()


func prueba_descansar_recupera_sangre_y_la_enfermeria_trata_lo_de_adentro() -> void:
	var juego := _juego_nuevo()
	juego.integridad = {"abdomen": 30.0}
	juego.sangre_perdida = 2.0
	juego.sangrados.assign([{"parte": "abdomen", "tipo": "interno", "nivel": 2, "turnos": 3}])
	juego.infecciones.assign([{"parte": "abdomen", "etapa": 1, "limpia": false, "sucia": true}])
	var prevision := juego.prevision_descanso()
	verificar_cerca(prevision["sangre"], SANGRE * DatosCiudad.CURA_DESCANSO, "El castillo dice cuánta sangre recuperas")
	verificar(not prevision["trata"], "Sin enfermería no trata lo de adentro")
	juego.descansar()
	verificar_cerca(juego.sangre_perdida, maxf(2.0 - SANGRE * DatosCiudad.CURA_DESCANSO, 0.0), "Descansar recupera sangre")
	verificar_igual(_nivel(juego.sangrados, "abdomen", "interno"), 2, "Sin enfermería, el sangrado por dentro sigue")
	verificar(juego.peor_infeccion() >= 1, "Y la infección")
	juego.edificios["enfermeria"] = 1
	verificar(juego.prevision_descanso()["trata"], "Con enfermería, sí")
	juego.descansar()
	verificar(juego.sangrados.is_empty(), "La enfermería para el sangrado por dentro")
	verificar(juego.infecciones.is_empty(), "Y cura las infecciones")
	juego.free()


# --- Infecciones ---

func prueba_las_heridas_abiertas_pueden_infectarse() -> void:
	var juego := _juego_nuevo()
	juego.combate = {"origen": "mazmorra"}
	var rey := juego.crear_rey()
	rey.recibir_golpe("brazo_der", 3, 20.0, "Corte", 1)
	rey.recibir_golpe("muslo_der", 3, 20.0, "Contusión", 1)
	rey.recibir_golpe("abdomen", 5, 20.0, "Contusión", 2)
	juego.guardar_salud(rey)
	var brazo := juego.infeccion_de("brazo_der")
	verificar(not brazo.is_empty() and int(brazo["etapa"]) == 0, "Un corte queda en riesgo de infección")
	verificar(juego.infeccion_de("muslo_der").is_empty(), "Un golpe que no abre la piel, no")
	verificar(not juego.infeccion_de("abdomen").is_empty(), "En el abdomen, sí")
	verificar(brazo.get("sucia", false), "En una mazmorra la herida queda sucia")
	verificar_cerca(DatosHeridas.prob_avance(brazo), DatosHeridas.RIESGO_POR_DIA * DatosHeridas.RIESGO_SUCIA, "Más riesgo")
	verificar_cerca(DatosHeridas.prob_avance(juego.infeccion_de("abdomen")),
		DatosHeridas.RIESGO_POR_DIA * DatosHeridas.RIESGO_SUCIA * DatosHeridas.RIESGO_ABDOMEN, "El abdomen, todavía más")
	verificar(juego.heridas.all(func(herida: Dictionary) -> bool: return not herida.has("nueva")),
		"El combate siguiente no vuelve a contar estos golpes")
	# Limpiar y vendar la herida baja el riesgo (primero la de más riesgo).
	juego.agregar(DatosBotin.crear_consumible("venda"))
	verificar(juego.sirve("venda"), "La venda sirve para limpiar una herida")
	verificar(juego.usar("venda") != "", "Se usa")
	verificar(juego.infeccion_de("abdomen")["limpia"], "Limpia la de más riesgo")
	verificar_cerca(DatosHeridas.prob_avance(juego.infeccion_de("abdomen")), DatosHeridas.RIESGO_POR_DIA
		* DatosHeridas.RIESGO_SUCIA * DatosHeridas.RIESGO_ABDOMEN * DatosHeridas.RIESGO_LIMPIA, "Y su riesgo baja")
	# Una parte que se cura del todo ya no se infecta.
	juego.curar(0, 100.0)
	verificar(juego.infecciones.is_empty(), "Curada del todo, la herida ya no se infecta")
	juego.free()


func prueba_una_herida_limpiada_en_combate_baja_el_riesgo() -> void:
	var juego := _juego_nuevo()
	var rey := juego.crear_rey()
	rey.recibir_golpe("brazo_der", 3, 20.0, "Corte", 1)
	for herida in rey.heridas:
		herida["limpia"] = true
	juego.guardar_salud(rey)
	verificar(juego.infeccion_de("brazo_der")["limpia"], "Una herida que se limpió con una venda queda limpia")
	rey = juego.crear_rey()
	rey.recibir_golpe("brazo_der", 3, 10.0, "Corte", 1)
	juego.guardar_salud(rey)
	verificar(not juego.infeccion_de("brazo_der")["limpia"], "Una herida nueva sin limpiar la ensucia otra vez")
	juego.free()


func prueba_las_infecciones_avanzan_por_dias() -> void:
	var juego := _juego_nuevo()
	juego.integridad = {"brazo_der": 50.0}
	juego.infecciones.assign([{"parte": "brazo_der", "etapa": 0, "limpia": false, "sucia": true}])
	var dias := 0
	var texto := ""
	while juego.peor_infeccion() == 0 and dias < 1000:
		texto = juego.avanzar_dias(1)["texto"]
		dias += 1
	verificar_igual(juego.peor_infeccion(), 1, "Tarde o temprano se infecta")
	verificar(texto.contains("infectó"), "Y lo cuenta (%s)" % texto)
	# Infectada, la parte se cura a la mitad.
	juego.curar(0, 10.0)
	verificar_cerca(juego.integridad["brazo_der"], 50.0 + 10.0 * DatosHeridas.CURA_INFECTADA, "Infectada se cura más lento")
	# Grave: fiebre. Baja la conciencia y caminar cansa más.
	juego.infecciones[0]["etapa"] = 2
	verificar_cerca(juego.crear_rey().conciencia(), DatosHeridas.CONCIENCIA_FIEBRE[2], "Con fiebre baja la conciencia")
	verificar_cerca(juego.estres_de_paso(1.0), DatosHeridas.ESTRES_FIEBRE[2], "Y caminar cansa más")
	# La medicina cura solo las leves.
	juego.agregar(DatosBotin.crear_consumible("medicina"))
	verificar(not juego.sirve("medicina"), "La medicina no cura una infección grave")
	juego.infecciones[0]["etapa"] = 1
	verificar(juego.sirve("medicina"), "Pero sí una leve")
	juego.usar("medicina")
	verificar(juego.infecciones.is_empty(), "Y la cura")
	# La generalizada, sin tratamiento, puede matarlo: es como perder.
	juego.infecciones.assign([{"parte": "brazo_der", "etapa": 3, "limpia": false, "sucia": false}])
	var muerte := false
	for i in 300:
		if juego.avanzar_dias(1)["muerte"]:
			muerte = true
			break
	verificar(muerte, "La infección generalizada puede matarlo")
	verificar(juego.infecciones.is_empty() and juego.vida_actual() == 1, "Lo salvan con 1 de vida")
	juego.free()


func prueba_al_pasar_la_semana_pasan_los_dias_que_faltan() -> void:
	var juego := _juego_nuevo()
	juego.integridad = {"brazo_der": 50.0}
	juego.infecciones.assign([{"parte": "brazo_der", "etapa": 1, "limpia": false, "sucia": false}])
	# Con todos los días de la semana ya pasados (por ejemplo, en una zona), no avanza más.
	for i in DatosHeridas.DIAS_POR_SEMANA:
		juego.pasar_dia()
	var etapa := juego.peor_infeccion()
	juego.infecciones[0]["etapa"] = 1
	juego.dias_semana = DatosHeridas.DIAS_POR_SEMANA
	juego.pasar_semana()
	verificar_igual(juego.peor_infeccion(), 1, "Si ya pasaron los siete días, la semana no suma más")
	verificar_igual(juego.dias_semana, 0, "Y empieza la cuenta de la semana siguiente")
	verificar(etapa >= 1, "Los días de la zona cuentan")
	juego.free()


# --- Objetos ---

func prueba_vendas_torniquetes_y_medicinas() -> void:
	var juego := _juego_nuevo()
	juego.integridad = {"cuello": 50.0, "muslo_izq": 40.0, "abdomen": 60.0}
	juego.sangrados.assign([
		{"parte": "cuello", "tipo": "externo", "nivel": 3, "turnos": 3},
		{"parte": "muslo_izq", "tipo": "externo", "nivel": 2, "turnos": 3},
		{"parte": "abdomen", "tipo": "interno", "nivel": 2, "turnos": 3},
	])
	verificar_igual(juego.usar("venda"), "", "Sin vendas no se puede")
	juego.agregar(DatosBotin.crear_consumible("venda", 2))
	juego.agregar(DatosBotin.crear_consumible("torniquete"))
	juego.agregar(DatosBotin.crear_consumible("medicina"))
	verificar_igual(juego.cantidad("venda"), 2, "Las vendas se apilan")
	verificar_igual(juego.inventario.size(), 3, "Una pila por tipo")
	verificar(juego.sirve("pocion") and juego.usar("pocion") == "", "Herido pero sin pociones, no se toma ninguna")
	juego.usar("venda")
	verificar_igual(_nivel(juego.sangrados, "cuello"), 2, "La venda baja el sangrado grave del cuello a moderado")
	juego.usar("venda")
	verificar_igual(_nivel(juego.sangrados, "cuello"), 0, "Otra venda lo para")
	verificar_igual(juego.cantidad("venda"), 0, "Se gastan")
	verificar(juego.usar("torniquete") != "", "El torniquete se usa")
	verificar_igual(_nivel(juego.sangrados, "muslo_izq"), 0, "Y para el sangrado del muslo")
	verificar(juego.usar("medicina") != "", "La medicina se toma")
	verificar(juego.sangrados.is_empty(), "Y para el sangrado por dentro")
	juego.agregar(DatosBotin.crear_consumible("torniquete"))
	verificar(not juego.sirve("torniquete"), "Sin sangrados no sirve")
	juego.sangrados.assign([{"parte": "cuello", "tipo": "externo", "nivel": 3, "turnos": 3}])
	verificar(not juego.sirve("torniquete"), "En el cuello no se puede poner un torniquete")
	verificar_igual(juego.usar("torniquete"), "", "Y no se gasta")
	verificar_igual(juego.cantidad("torniquete"), 1, "Sigue en la mochila")
	# Se venden de a uno y no se equipan.
	var pila: Dictionary = juego.inventario.filter(func(objeto: Dictionary) -> bool: return objeto["ranura"] == "torniquete")[0]
	verificar(not juego.equipar(pila["id"]), "No se equipa")
	juego.agregar(DatosBotin.crear_consumible("torniquete"))
	verificar_igual(juego.vender(pila["id"]), juego.precio_venta(pila), "Se vende")
	verificar_igual(juego.cantidad("torniquete"), 1, "De a uno")
	juego.free()


func prueba_la_sangre_y_las_infecciones_se_guardan() -> void:
	var juego := _juego_nuevo()
	juego.integridad = {"muslo_der": 40.0}
	juego.sangre_perdida = 1.5
	juego.sangrados.assign([{"parte": "muslo_der", "tipo": "externo", "nivel": 2, "turnos": 3}])
	juego.infecciones.assign([{"parte": "muslo_der", "etapa": 1, "limpia": true, "sucia": true}])
	juego.dias_semana = 3
	juego.agregar(DatosBotin.crear_consumible("torniquete", 2))
	verificar(juego.guardar(ARCHIVO_PRUEBA), "Se guarda")
	var cargado := EstadoReino.new()
	verificar(cargado.cargar(ARCHIVO_PRUEBA), "Se carga")
	verificar_cerca(cargado.sangre_perdida, 1.5, "La sangre perdida")
	verificar_igual(cargado.sangrados, juego.sangrados, "Lo que sangra")
	verificar_igual(cargado.infecciones, juego.infecciones, "Las infecciones")
	verificar_igual(cargado.dias_semana, 3, "Los días de la semana")
	verificar_igual(cargado.cantidad("torniquete"), 2, "Los torniquetes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO_PRUEBA))
	juego.free()
	cargado.free()
