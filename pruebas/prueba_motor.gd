extends "res://pruebas/base_prueba.gd"
## Reglas provisionales del combate.


func prueba_acierto_entre_limites() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var orco := DatosRivales.crear_rival("orco")
	for parte_id in DatosCuerpo.PARTES:
		var prob := MotorCombate.prob_acierto(rey, orco, parte_id)
		verificar(prob >= MotorCombate.ACIERTO_MIN and prob <= MotorCombate.ACIERTO_MAX,
			"Acierto de %s dentro de los límites" % parte_id)


func prueba_partes_pequenas_cuestan_mas() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var bandido := DatosRivales.crear_rival("bandido")
	var ojo := MotorCombate.prob_acierto(rey, bandido, "ojo_izq")
	var torax := MotorCombate.prob_acierto(rey, bandido, "torax_izq")
	verificar(ojo < torax, "Es más difícil acertar al ojo que al tórax")


func prueba_punzante_apunta_mejor_a_partes_pequenas() -> void:
	var bandido := DatosRivales.crear_rival("bandido")
	var con_espada := DatosRivales.crear_rey(true, "espada")
	var con_lanza := DatosRivales.crear_rey(true, "lanza")
	var relacion_espada := MotorCombate.prob_acierto(con_espada, bandido, "ojo_izq") \
		/ MotorCombate.prob_acierto(con_espada, bandido, "torax_izq")
	var relacion_lanza := MotorCombate.prob_acierto(con_lanza, bandido, "ojo_izq") \
		/ MotorCombate.prob_acierto(con_lanza, bandido, "torax_izq")
	verificar(relacion_lanza > relacion_espada, "La lanza pierde menos precisión en partes pequeñas")


func prueba_ceguera_baja_la_precision() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var bandido := DatosRivales.crear_rival("bandido")
	var normal := MotorCombate.prob_acierto(rey, bandido, "abdomen")
	rey.integridad["ojo_der"] = 0.0
	rey.integridad["ojo_izq"] = 0.0
	verificar(MotorCombate.prob_acierto(rey, bandido, "abdomen") < normal * 0.7, "Sin ojos acierta menos")


func prueba_en_guardia_recibe_menos() -> void:
	var rey := DatosRivales.crear_rey(true, "maza")
	var orco := DatosRivales.crear_rival("orco")
	var acierto := MotorCombate.prob_acierto(rey, orco, "abdomen")
	var danio := MotorCombate.multiplicador_danio(rey, orco, "abdomen")
	orco.defendiendo = true
	verificar(MotorCombate.prob_acierto(rey, orco, "abdomen") < acierto, "En guardia esquiva más")
	verificar_cerca(MotorCombate.multiplicador_danio(rey, orco, "abdomen"), danio * 0.5, "En guardia recibe la mitad")


func prueba_golpe_acertado_aplica_danio() -> void:
	var rng := rng_fijo(7)
	var rey := DatosRivales.crear_rey(true, "espada")
	var bandido := DatosRivales.crear_rival("bandido")
	var aciertos := 0
	for turno in 40:
		if bandido.fuera_de_combate():
			break
		var vida_antes := bandido.vida
		var r := MotorCombate.resolver_ataque(rey, bandido, "abdomen", rng, turno)
		if r["acierto"]:
			aciertos += 1
			verificar_igual(vida_antes - bandido.vida, mini(r["danio"], vida_antes), "La vida baja lo que dice el resultado")
			verificar_igual(r["herida"], "Corte", "La espada produce cortes")
		else:
			verificar_igual(bandido.vida, vida_antes, "Un fallo no resta vida")
	verificar(aciertos > 0, "Algún ataque acierta")
	verificar_igual(rey.aciertos, aciertos, "Cuenta los aciertos")


func prueba_mano_inutilizada_suelta_el_arma() -> void:
	var rng := rng_fijo(3)
	var rey := DatosRivales.crear_rey(true, "lanza")
	var bandido := DatosRivales.crear_rival("bandido")
	bandido.integridad["mano_der"] = 16.0
	var desarmado := false
	for turno in 60:
		var r := MotorCombate.resolver_ataque(rey, bandido, "mano_der", rng, turno)
		if r["acierto"]:
			desarmado = r["desarme"]
			break
	verificar(desarmado, "Inutilizar la mano del arma la hace soltar")
	verificar(bandido.desarmado, "El bandido queda desarmado")
	verificar_igual(bandido.arma_actual(), "punos", "Pelea con los puños")


func prueba_solo_el_craneo_aturde() -> void:
	var rng := rng_fijo(11)
	var rey := DatosRivales.crear_rey(true, "maza")
	var orco := DatosRivales.crear_rival("orco")
	for turno in 200:
		var r := MotorCombate.resolver_ataque(rey, orco, "pie_der", rng, turno)
		verificar(not r["aturdido"], "Un golpe en el pie no aturde")
		orco.vida = orco.vida_max
	var aturdido := false
	for turno in 200:
		orco.integridad["craneo"] = 100.0
		orco.aturdido = false
		var r := MotorCombate.resolver_ataque(rey, orco, "craneo", rng, turno)
		aturdido = aturdido or r["aturdido"]
	verificar(aturdido, "La maza en el cráneo puede aturdir")


func prueba_desmayo_por_conciencia() -> void:
	var rng := rng_fijo(5)
	var rey := DatosRivales.crear_rey(true, "maza")
	var orco := DatosRivales.crear_rival("orco")
	orco.vida = 1000
	var turnos := 0
	while not orco.desmayado and turnos < 300:
		MotorCombate.resolver_ataque(rey, orco, "craneo", rng, turnos)
		turnos += 1
	verificar(orco.desmayado, "Muchos golpes en el cráneo desmayan")
	verificar(orco.conciencia() < MotorCombate.UMBRAL_DESMAYO, "Se desmaya con poca conciencia")
	verificar(orco.fuera_de_combate(), "Desmayado queda fuera de combate")


func prueba_fractura_solo_contundente_en_hueso() -> void:
	var rng := rng_fijo(9)
	var con_espada := DatosRivales.crear_rey(true, "espada")
	var con_maza := DatosRivales.crear_rey(true, "maza")
	var bandido := DatosRivales.crear_rival("bandido")
	bandido.vida = 10000
	for turno in 100:
		var r := MotorCombate.resolver_ataque(con_espada, bandido, "antebrazo_izq", rng, turno)
		verificar(not r["fractura"], "La espada no fractura")
	var otro := DatosRivales.crear_rival("bandido")
	otro.vida = 10000
	var fracturas := 0
	for turno in 100:
		var r := MotorCombate.resolver_ataque(con_maza, otro, "antebrazo_izq", rng, turno)
		if r["fractura"]:
			fracturas += 1
		var abdomen := MotorCombate.resolver_ataque(con_maza, otro, "abdomen", rng, turno)
		verificar(not abdomen["fractura"], "El abdomen no tiene hueso que fracturar")
	verificar_igual(fracturas, 1, "La maza fractura el antebrazo una sola vez")


func prueba_huir_depende_de_las_piernas() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var orco := DatosRivales.crear_rival("orco")
	var sano := MotorCombate.prob_huir(rey, orco)
	rey.integridad["muslo_der"] = 10.0
	rey.integridad["muslo_izq"] = 10.0
	verificar(MotorCombate.prob_huir(rey, orco) < sano, "Con las piernas heridas cuesta más huir")


func prueba_golpe_final_no_desarma_ni_aturde() -> void:
	var rng := rng_fijo(17)
	var rey := DatosRivales.crear_rey(true, "maza")
	for intento in 300:
		var orco := DatosRivales.crear_rival("orco")
		orco.vida = 1
		var r := MotorCombate.resolver_ataque(rey, orco, "craneo", rng, intento)
		if r["acierto"]:
			verificar(orco.fuera_de_combate(), "El golpe deja al orco fuera de combate")
			verificar(not r["desarme"] and not r["aturdido"], "Fuera de combate no suelta el arma ni queda aturdido")
			return
	verificar(false, "Algún golpe debía acertar")


func prueba_punos_aturden_menos_que_la_maza() -> void:
	var rng := rng_fijo(23)
	var con_maza := DatosRivales.crear_rey(true, "maza")
	var sin_arma := DatosRivales.crear_rey(true, "maza")
	sin_arma.desarmado = true
	var aturdidos := {"maza": 0, "punos": 0}
	for intento in 3000:
		for atacante in [con_maza, sin_arma]:
			var rival := DatosRivales.crear_rival("bandido")
			var r := MotorCombate.resolver_ataque(atacante, rival, "craneo", rng, intento)
			if r["aturdido"]:
				aturdidos[atacante.arma_actual()] += 1
	verificar(aturdidos["punos"] * 2 < aturdidos["maza"],
		"Los puños aturden mucho menos (%d contra %d)" % [aturdidos["punos"], aturdidos["maza"]])


func prueba_lesion_de_cuello_hace_soltar_el_arma() -> void:
	var rng := rng_fijo(31)
	var rey := DatosRivales.crear_rey(true, "lanza")
	for intento in 300:
		var bandido := DatosRivales.crear_rival("bandido")
		bandido.vida = 1000
		# Brazo del arma ya dañado: con la columna lesionada no podrá sostenerla.
		bandido.integridad["antebrazo_der"] = 40.0
		bandido.integridad["cuello"] = 16.0
		var r := MotorCombate.resolver_ataque(rey, bandido, "cuello", rng, intento)
		if r["acierto"]:
			verificar(not bandido.puede_empunar("der"), "Con el cuello inutilizado el brazo no sostiene el arma")
			verificar(r["desarme"] and bandido.desarmado, "Suelta el arma aunque el golpe fue en el cuello")
			return
	verificar(false, "Algún golpe debía acertar")
