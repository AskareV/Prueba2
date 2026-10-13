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
## Acierto mínimo para ir directo a la cabeza o el torso; si es menor, primero
## inutiliza el brazo del arma del rival para abrir su defensa.
const ACIERTO_PARA_IR_AL_CUERPO := 0.4


## Devuelve {"accion": "atacar", "parte": ...}, {"accion": "defender"} o {"accion": "recoger"}.
static func decidir(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> Dictionary:
	if yo.desarmado and (yo.puede_empunar("der") or yo.puede_empunar("izq")):
		return {"accion": "recoger"}
	if yo.vida <= yo.vida_max * 0.3 and rng.randf() < 0.18:
		return {"accion": "defender"}
	return {"accion": "atacar", "parte": elegir_parte(yo, rival, rng)}


## Plan por personalidad: el astuto va por la mano del arma del rival hasta
## desarmarlo. Los demás buscan la parte de la cabeza o el torso que más vida
## quita, con su preferencia (el bruto el cráneo, el preciso cuello y ojos);
## si está muy cubierta, primero inutilizan el brazo del arma del rival.
static func elegir_parte(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> String:
	if rng.randf() < PROB_IMPROVISAR:
		return parte_al_azar(yo, rival, rng)
	if yo.personalidad == "astuto" and not rival.desarmado:
		return rival.mano_arma()
	var objetivo := mejor_parte(yo, rival, DatosCuerpo.partes_de("cabeza") + DatosCuerpo.partes_de("torso"))
	var brazo_arma := "brazo_" + rival.lado_arma()
	if MotorCombate.prob_acierto(yo, rival, objetivo) < ACIERTO_PARA_IR_AL_CUERPO \
			and not rival.desarmado and rival.extremidad_util(brazo_arma):
		return parte_para_inutilizar(yo, rival, brazo_arma)
	return objetivo


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
