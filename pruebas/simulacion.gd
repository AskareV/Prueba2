extends RefCounted
## Combates automáticos sin interfaz, para el simulador (simular.gd) y las pruebas
## de equilibrio. El rival lo maneja la IA; el rey sigue una estrategia.

const MAX_TURNOS := 200
## Estrategias del rey:
## - ia: la misma IA que usan los rivales.
## - azar: cualquier parte, sin pensar.
## - abdomen, craneo, cuello: siempre esa parte.
## - torso: la parte del torso que más vida quita en promedio.
## - brazos / piernas: inutiliza primero esas extremidades (el brazo del arma
##   antes) y después va a la cabeza o el torso.
## - brazo_arma: solo inutiliza el brazo dominante (el del arma) y después va
##   a la cabeza o el torso.
const ESTRATEGIAS := ["ia", "azar", "abdomen", "torso", "craneo", "cuello", "brazos", "brazo_arma", "piernas"]


## Juega un combate completo. Devuelve victorias (1 o 0), turnos, desmayos,
## vida final del rey y ataques y aciertos de cada uno.
static func combatir(arma_id: String, rival_id: String, estrategia: String, diestro: bool,
		rng: RandomNumberGenerator) -> Dictionary:
	var rey := DatosRivales.crear_rey(diestro, arma_id)
	var rival := DatosRivales.crear_rival(rival_id)
	var turno := 0
	while turno < MAX_TURNOS:
		turno += 1
		actuar(rey, rival, rng, turno, estrategia)
		if rival.fuera_de_combate():
			break
		actuar(rival, rey, rng, turno, "ia")
		if rey.fuera_de_combate():
			break
	return {
		"victorias": 1 if rival.fuera_de_combate() and not rey.fuera_de_combate() else 0,
		"turnos": turno,
		"desmayos": 1 if rey.desmayado or rival.desmayado else 0,
		"vida_rey": rey.vida,
		"ataques_rey": rey.ataques, "aciertos_rey": rey.aciertos,
		"ataques_rival": rival.ataques, "aciertos_rival": rival.aciertos,
	}


## Hace actuar a un luchador como en la escena de combate.
static func actuar(yo: Luchador, otro: Luchador, rng: RandomNumberGenerator, turno: int, estrategia: String) -> void:
	yo.defendiendo = false
	if yo.aturdido:
		yo.aturdido = false
		return
	var decision := IAEnemigo.decidir(yo, otro, rng)
	if estrategia != "ia" and decision["accion"] == "atacar":
		decision["parte"] = elegir_parte(estrategia, yo, otro, rng)
	match decision["accion"]:
		"recoger":
			yo.empunar()
		"defender":
			yo.defendiendo = true
		"atacar":
			MotorCombate.resolver_ataque(yo, otro, decision["parte"], rng, turno)


static func elegir_parte(estrategia: String, yo: Luchador, otro: Luchador, rng: RandomNumberGenerator) -> String:
	match estrategia:
		"azar":
			var partes := DatosCuerpo.PARTES.keys()
			return partes[rng.randi() % partes.size()]
		"abdomen", "craneo", "cuello":
			return estrategia
		"torso":
			return IAEnemigo.mejor_parte(yo, otro, DatosCuerpo.partes_de("torso"))
		"brazos":
			var lado_arma := otro.lado_arma()
			for zona_id in ["brazo_" + lado_arma, "brazo_" + DatosCuerpo.lado_opuesto(lado_arma)]:
				if otro.extremidad_util(zona_id):
					return IAEnemigo.parte_para_inutilizar(yo, otro, zona_id)
		"brazo_arma":
			var zona_arma := "brazo_" + otro.lado_dominante()
			if otro.extremidad_util(zona_arma):
				return IAEnemigo.parte_para_inutilizar(yo, otro, zona_arma)
		"piernas":
			for zona_id in ["pierna_der", "pierna_izq"]:
				if otro.extremidad_util(zona_id):
					return IAEnemigo.parte_para_inutilizar(yo, otro, zona_id)
	# Con las extremidades ya inutilizadas: la parte de cabeza o torso que más vida quita.
	return IAEnemigo.mejor_parte(yo, otro, DatosCuerpo.partes_de("cabeza") + DatosCuerpo.partes_de("torso"))
