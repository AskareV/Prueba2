extends "res://pruebas/base_prueba.gd"
## Decisiones de los rivales.


func prueba_elige_partes_validas() -> void:
	var rng := rng_fijo(21)
	var lancero := DatosRivales.crear_rival("lancero")
	var rey := DatosRivales.crear_rey(true, "espada")
	for i in 300:
		var parte_id := IAEnemigo.elegir_parte(lancero, rey, rng)
		verificar(DatosCuerpo.PARTES.has(parte_id), "Parte válida: %s" % parte_id)


func prueba_recoge_el_arma_si_puede() -> void:
	var rng := rng_fijo(2)
	var bandido := DatosRivales.crear_rival("bandido")
	var rey := DatosRivales.crear_rey(true, "espada")
	bandido.desarmado = true
	verificar_igual(IAEnemigo.decidir(bandido, rey, rng)["accion"], "recoger", "Desarmado, recoge el arma")
	bandido.integridad["mano_der"] = 0.0
	bandido.integridad["mano_izq"] = 0.0
	verificar_igual(IAEnemigo.decidir(bandido, rey, rng)["accion"] != "recoger", true,
		"Sin manos útiles no intenta recoger")


func prueba_personalidades() -> void:
	var rng := rng_fijo(33)
	var rey := DatosRivales.crear_rey(true, "espada")
	var conteo := {"bandido": 0, "orco": 0, "lancero": 0}
	var objetivos := {"bandido": ["mano_der"], "orco": ["craneo"], "lancero": ["cuello", "ojo_der", "ojo_izq"]}
	var normal := Luchador.new("Prueba", 100, true, "espada")
	var conteo_normal := {"bandido": 0, "orco": 0, "lancero": 0}
	for rival_id in conteo:
		var rival := DatosRivales.crear_rival(rival_id)
		normal.arma = rival.arma
		for i in 2000:
			if objetivos[rival_id].has(IAEnemigo.elegir_parte(rival, rey, rng)):
				conteo[rival_id] += 1
			if objetivos[rival_id].has(IAEnemigo.elegir_parte(normal, rey, rng)):
				conteo_normal[rival_id] += 1
	for rival_id in conteo:
		verificar(conteo[rival_id] > conteo_normal[rival_id] * 1.5,
			"%s prefiere sus partes favoritas (%d contra %d)" % [rival_id, conteo[rival_id], conteo_normal[rival_id]])
