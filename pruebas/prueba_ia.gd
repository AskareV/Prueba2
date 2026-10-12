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


## Cuenta cuántas veces, en 1000 decisiones, elige alguna de esas partes.
func _veces(rival: Luchador, rey: Luchador, partes: Array, rng: RandomNumberGenerator) -> int:
	var veces := 0
	for i in 1000:
		if partes.has(IAEnemigo.elegir_parte(rival, rey, rng)):
			veces += 1
	return veces


func prueba_el_astuto_va_por_la_mano_del_arma() -> void:
	var rng := rng_fijo(33)
	var bandido := DatosRivales.crear_rival("bandido")
	verificar(_veces(bandido, DatosRivales.crear_rey(true, "espada"), ["mano_der"], rng) > 600,
		"Contra un diestro busca la mano derecha")
	verificar(_veces(bandido, DatosRivales.crear_rey(false, "espada"), ["mano_izq"], rng) > 600,
		"Contra un zurdo busca la mano izquierda")


func prueba_con_la_guardia_cerrada_abre_el_brazo_del_arma() -> void:
	var rng := rng_fijo(34)
	for rival_id in ["orco", "lancero"]:
		for diestro in [true, false]:
			var rey := DatosRivales.crear_rey(diestro, "espada")
			var brazo := "brazo_der" if diestro else "brazo_izq"
			verificar(_veces(DatosRivales.crear_rival(rival_id), rey, DatosCuerpo.partes_de(brazo), rng) > 600,
				"El %s primero ataca tu brazo del arma si tu cabeza y torso están cubiertos" % rival_id)


func prueba_con_la_guardia_abierta_sigue_su_personalidad() -> void:
	var rng := rng_fijo(35)
	var rey := DatosRivales.crear_rey(true, "espada")
	# Sin brazos útiles, la cabeza y el torso quedan expuestos.
	rey.integridad["mano_der"] = 5.0
	rey.integridad["mano_izq"] = 5.0
	rey.desarmado = true
	var orco := DatosRivales.crear_rival("orco")
	var lancero := DatosRivales.crear_rival("lancero")
	verificar(_veces(orco, rey, ["craneo"], rng) > 600, "El orco (bruto) va a tu cráneo")
	verificar(_veces(lancero, rey, ["cuello", "ojo_der", "ojo_izq"], rng) > 600, "El lancero (preciso) va a tu cuello y ojos")
