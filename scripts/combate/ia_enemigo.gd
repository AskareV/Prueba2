class_name IAEnemigo
extends RefCounted
## Decide qué hace un luchador controlado por la máquina. Casi siempre sigue el
## plan de su personalidad (ver DatosRivales.PERSONALIDADES); a veces improvisa.

## Peso extra de ciertas partes según la personalidad: tipo de parte -> peso.
const PREFERENCIAS := {
	"bruto": {"craneo": 1.6},
	"preciso": {"cuello": 2.0, "ojo": 1.5},
	"astuto": {},
	"normal": {},
}
## Probabilidad de improvisar (atacar otra parte) en vez de seguir su plan.
const PROB_IMPROVISAR := 0.25
## Con esta parte de su vida o menos, se defiende 1 de cada 4 turnos.
const VIDA_PARA_DEFENDER := 0.5
const PROB_DEFENDER := 0.25
## Los que saben magia: se curan con poca vida, frenan al rival si es más rápido
## y a veces lanzan una llamarada.
const VIDA_PARA_CURARSE := 0.4
const PROB_CURARSE := 0.5
const PROB_RALENTIZAR := 0.15
const PROB_LLAMARADA := 0.3


## Devuelve {"accion": "atacar", "parte": ...}, {"accion": "defender"},
## {"accion": "recoger"} o {"accion": "hechizo", "hechizo": ..., "parte": ...}.
static func decidir(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> Dictionary:
	if yo.desarmado and (yo.puede_empunar("der") or yo.puede_empunar("izq")):
		return {"accion": "recoger"}
	var magia := elegir_hechizo(yo, rival, rng)
	if not magia.is_empty():
		return magia
	if yo.vida <= yo.vida_max * VIDA_PARA_DEFENDER and rng.randf() < PROB_DEFENDER:
		return {"accion": "defender"}
	return {"accion": "atacar", "parte": elegir_parte(yo, rival, rng)}


## Un hechizo que le conviene lanzar ahora, o vacío (los que no saben magia, nunca).
static func elegir_hechizo(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> Dictionary:
	if yo.hechizos.is_empty():
		return {}
	if _puede(yo, "curacion") and yo.vida <= yo.vida_max * VIDA_PARA_CURARSE and rng.randf() < PROB_CURARSE:
		return {"accion": "hechizo", "hechizo": "curacion"}
	if _puede(yo, "ralentizar") and rival.rapidez_efectiva() > yo.rapidez_efectiva() and rng.randf() < PROB_RALENTIZAR:
		return {"accion": "hechizo", "hechizo": "ralentizar"}
	if _puede(yo, "llamarada") and rng.randf() < PROB_LLAMARADA:
		# Apunta como un ataque, pero con los datos de la llamarada.
		yo.hechizo = DatosHechizos.como_arma("llamarada", yo)
		var parte := elegir_parte(yo, rival, rng)
		yo.hechizo = {}
		return {"accion": "hechizo", "hechizo": "llamarada", "parte": parte}
	return {}


static func _puede(yo: Luchador, hechizo_id: String) -> bool:
	return yo.hechizos.has(hechizo_id) and DatosHechizos.puede_lanzar(yo, hechizo_id)


## Plan por personalidad: el astuto va por la mano del arma del rival hasta
## desarmarlo. Los demás buscan la parte de la cabeza o el torso que más vida
## quita, con su preferencia (el bruto el cráneo, el preciso cuello y ojos);
## primero inutilizan el brazo del arma del rival si así lo tumban en menos
## turnos (sin ese brazo, la cabeza y el torso quedan menos cubiertos).
static func elegir_parte(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> String:
	if rng.randf() < PROB_IMPROVISAR:
		return parte_al_azar(yo, rival, rng)
	if yo.personalidad == "astuto" and not rival.desarmado:
		return rival.mano_arma()
	var objetivo := mejor_parte(yo, rival, DatosCuerpo.partes_de("cabeza") + DatosCuerpo.partes_de("torso"))
	var brazo_arma := "brazo_" + rival.lado_arma()
	if not rival.desarmado and rival.extremidad_util(brazo_arma):
		var parte := parte_para_inutilizar(yo, rival, brazo_arma)
		if turnos_abriendo_guardia(yo, rival, parte) < turnos_para_tumbar(yo, rival, objetivo, rival.vida):
			return parte
	return objetivo


## Vida que quita de media cada ataque a esa parte: acierto × daño medio del
## golpe (con los críticos).
static func danio_por_ataque(yo: Luchador, rival: Luchador, parte_id: String) -> float:
	var arma: Dictionary = yo.datos_arma()
	var base := (float(arma["danio_min"]) + float(arma["danio_max"])) / 2.0
	base *= 1.0 + clampf(yo.prob_critico(), 0.0, 1.0) * (MotorCombate.MULTIPLICADOR_CRITICO - 1.0)
	return MotorCombate.prob_acierto(yo, rival, parte_id) * base * MotorCombate.multiplicador_danio(yo, rival, parte_id)


## Turnos que tardaría en quitarle esa vida atacando siempre esa parte.
static func turnos_para_tumbar(yo: Luchador, rival: Luchador, parte_id: String, vida: float) -> float:
	return maxf(vida, 0.0) / maxf(danio_por_ataque(yo, rival, parte_id), 0.01)


## Turnos que tardaría en tumbar al rival si primero inutiliza su brazo del arma
## golpeando esa parte y después va a la cabeza o el torso, ya menos cubiertos.
## Lo de después se calcula como si esa parte ya estuviera inutilizada.
static func turnos_abriendo_guardia(yo: Luchador, rival: Luchador, parte_id: String) -> float:
	var golpes := MotorCombate.golpes_para_inutilizar(yo, rival, parte_id)
	var turnos := maxf((golpes.x + golpes.y) / 2.0, 1.0) / MotorCombate.prob_acierto(yo, rival, parte_id)
	var vida := float(rival.vida) - turnos * danio_por_ataque(yo, rival, parte_id)
	var integridad: float = rival.integridad[parte_id]
	rival.integridad[parte_id] = 0.0
	var objetivo := mejor_parte(yo, rival, DatosCuerpo.partes_de("cabeza") + DatosCuerpo.partes_de("torso"))
	var despues := turnos_para_tumbar(yo, rival, objetivo, vida)
	rival.integridad[parte_id] = integridad
	return turnos + despues


## Valor de atacar una parte: acierto × vida que quita × preferencia. Vale menos
## si ya está inutilizada.
static func valor(yo: Luchador, rival: Luchador, parte_id: String) -> float:
	var peso := MotorCombate.prob_acierto(yo, rival, parte_id)
	peso *= MotorCombate.multiplicador_danio(yo, rival, parte_id)
	peso *= preferencia(yo, parte_id)
	if rival.esta_inutilizada(parte_id):
		peso *= 0.4
	return peso


## La parte de la lista con más valor.
static func mejor_parte(yo: Luchador, rival: Luchador, partes: Array) -> String:
	var mejor: String = partes[0]
	var mejor_valor := -1.0
	for parte_id in partes:
		var v := valor(yo, rival, parte_id)
		if v > mejor_valor:
			mejor_valor = v
			mejor = parte_id
	return mejor


## La parte de ese brazo o pierna que se inutiliza en menos turnos esperados.
static func parte_para_inutilizar(yo: Luchador, rival: Luchador, zona_id: String) -> String:
	var mejor := ""
	var menos_turnos := INF
	for parte_id in DatosCuerpo.partes_de(zona_id):
		var golpes := MotorCombate.golpes_para_inutilizar(yo, rival, parte_id)
		var turnos := maxf((golpes.x + golpes.y) / 2.0, 1.0) / MotorCombate.prob_acierto(yo, rival, parte_id)
		if turnos < menos_turnos:
			menos_turnos = turnos
			mejor = parte_id
	return mejor


## Cualquier parte del cuerpo, con más probabilidad las de más valor.
static func parte_al_azar(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> String:
	var pesos := {}
	var total := 0.0
	for parte_id in DatosCuerpo.PARTES:
		var peso := pow(valor(yo, rival, parte_id), 1.5)
		pesos[parte_id] = peso
		total += peso
	var tirada := rng.randf() * total
	for parte_id in pesos:
		tirada -= pesos[parte_id]
		if tirada <= 0.0:
			return parte_id
	return "torax_der"


static func preferencia(yo: Luchador, parte_id: String) -> float:
	var tabla: Dictionary = PREFERENCIAS.get(yo.personalidad, {})
	return tabla.get(DatosCuerpo.base_de(parte_id), 1.0)
