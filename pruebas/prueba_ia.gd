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


## Abrir la guardia del rey (inutilizar su brazo del arma) contra ir directo a su
## cráneo: turnos que tardaría el orco de cada forma.
func _turnos(orco: Luchador, rey: Luchador) -> Vector2:
	var brazo := IAEnemigo.parte_para_inutilizar(orco, rey, "brazo_" + rey.lado_arma())
	return Vector2(IAEnemigo.turnos_abriendo_guardia(orco, rey, brazo), IAEnemigo.turnos_para_tumbar(orco, rey, "craneo", rey.vida))


## Con el brazo del arma útil, primero lo inutiliza si así tumba al rey en menos
## turnos (sin ese brazo la cabeza y el torso quedan menos cubiertos); si no, va
## directo.
func prueba_abre_la_guardia_si_tumba_antes() -> void:
	var rng := rng_fijo(36)
	var orco := DatosRivales.crear_rival("orco")
	var rey := DatosRivales.crear_rey(true, "espada")
	verificar(_turnos(orco, rey).x < _turnos(orco, rey).y, "Contra el rey sano, abrir la guardia tarda menos")
	verificar(_veces(orco, rey, DatosCuerpo.partes_de("brazo_der"), rng) > 600, "Entonces abre la guardia")
	# Brazo izquierdo (sin arma) y piernas inutilizados: el cráneo queda tan expuesto que ir directo tarda menos.
	rey.integridad["mano_izq"] = 5.0
	rey.integridad["pie_der"] = 5.0
	rey.integridad["pie_izq"] = 5.0
	verificar(_turnos(orco, rey).y < _turnos(orco, rey).x, "Con el cráneo expuesto, ir directo tarda menos")
	verificar(_veces(orco, rey, ["craneo"], rng) > 600, "Entonces va directo al cráneo")
	for parte_id in DatosCuerpo.partes_de("brazo_der"):
		verificar_igual(rey.integridad[parte_id], 100.0, "Calcular los turnos no cambia al rey (%s)" % parte_id)
	# Al rey casi vencido lo remata directo.
	var herido := DatosRivales.crear_rey(true, "espada")
	herido.vida = 20
	verificar(_veces(orco, herido, ["craneo"], rng) > 600, "Con 20 de vida, el orco va directo a rematarlo")


## Con más Reflejos el orco guerrero no cambia de plan: sigue abriendo primero la
## guardia (antes, con +10, dejaba de hacerlo por un umbral fijo de acierto).
func prueba_con_reflejos_el_orco_sigue_su_plan() -> void:
	for p in [0, 5, 10, 15, 20]:
		var juego := EstadoReino.new()
		juego.nueva_partida(true)
		juego.extra["reflejos"] = p
		var rey := juego.crear_rey()
		juego.free()
		var orco := DatosRivales.crear_rival("orco_guerrero")
		var objetivo := IAEnemigo.mejor_parte(orco, rey, DatosCuerpo.partes_de("cabeza") + DatosCuerpo.partes_de("torso"))
		var brazo := IAEnemigo.parte_para_inutilizar(orco, rey, "brazo_" + rey.lado_arma())
		verificar(IAEnemigo.turnos_abriendo_guardia(orco, rey, brazo) < IAEnemigo.turnos_para_tumbar(orco, rey, objetivo, rey.vida),
			"Con Reflejos +%d abre primero la guardia" % p)


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


func prueba_con_poca_vida_se_defiende_mas() -> void:
	var rng := rng_fijo(40)
	var rey := DatosRivales.crear_rey(true, "espada")
	var orco := DatosRivales.crear_rival("orco")
	var defensas := 0
	for i in 1000:
		if IAEnemigo.decidir(orco, rey, rng)["accion"] == "defender":
			defensas += 1
	verificar_igual(defensas, 0, "Sano no se defiende")
	orco.vida = orco.vida_max / 2
	defensas = 0
	for i in 1000:
		if IAEnemigo.decidir(orco, rey, rng)["accion"] == "defender":
			defensas += 1
	verificar(defensas > 200 and defensas < 300, "Con la mitad de vida, 1 de cada 4 (%d de 1000)" % defensas)


func prueba_los_chamanes_lanzan_hechizos() -> void:
	var rng := rng_fijo(41)
	var rey := DatosRivales.crear_rey(true, "espada")
	var chaman := DatosRivales.crear_rival("chaman_orco")
	verificar(chaman.usa_mana and chaman.hechizos.has("llamarada"), "El chamán orco sabe magia")
	verificar(chaman.poder_magico > DatosRivales.crear_rival("chaman_goblin").poder_magico, "Más fuerte que el goblin")
	var llamaradas := 0
	for i in 400:
		var decision := IAEnemigo.decidir(chaman, rey, rng)
		if decision["accion"] == "hechizo" and decision["hechizo"] == "llamarada":
			llamaradas += 1
			verificar(DatosCuerpo.PARTES.has(decision["parte"]), "Apunta a una parte")
	verificar(llamaradas > 60, "A veces lanza una llamarada (%d de 400)" % llamaradas)
	verificar(chaman.hechizo.is_empty(), "Elegir no lo deja con el hechizo puesto")
	# Con poca vida se cura.
	chaman.vida = 10
	var curas := 0
	for i in 400:
		var decision := IAEnemigo.decidir(chaman, rey, rng)
		if decision["accion"] == "hechizo" and decision["hechizo"] == "curacion":
			curas += 1
	verificar(curas > 120, "Herido, se cura (%d de 400)" % curas)
	var mana := chaman.mana
	var efecto := MotorCombate.lanzar_hechizo(chaman, "curacion")
	verificar(int(efecto["cura"]) > 0 and chaman.vida > 10, "La curación le devuelve vida")
	verificar_cerca(chaman.mana, mana - float(DatosHechizos.hechizo("curacion")["coste"]), "Y gasta maná")
	# La llamarada de un enemigo pega según su poder mágico.
	var resultado := MotorCombate.lanzar_hechizo_a(chaman, rey, "llamarada", "abdomen", rng, 1)
	verificar_igual(resultado["arma"], "llamarada", "Se resuelve como la llamarada")
	verificar(chaman.hechizo.is_empty(), "Después vuelve a su bastón")
	verificar(int(DatosHechizos.como_arma("llamarada", chaman)["danio_max"]) > int(DatosHechizos.como_arma("llamarada")["danio_max"]),
		"Su llamarada pega más que la base")
	# Sin maná ya no lanza nada.
	chaman.mana = 0.0
	for i in 200:
		verificar(IAEnemigo.decidir(chaman, rey, rng)["accion"] != "hechizo", "Sin maná no hay hechizos")
	var bandido := DatosRivales.crear_rival("bandido")
	for i in 200:
		verificar(IAEnemigo.decidir(bandido, rey, rng)["accion"] != "hechizo", "Quien no sabe magia nunca la lanza")
