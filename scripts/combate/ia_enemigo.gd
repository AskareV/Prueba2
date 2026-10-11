class_name IAEnemigo
extends RefCounted
## Decide qué hace un luchador controlado por la máquina.
## Cada personalidad prefiere ciertas partes del rival (ver DatosRivales).

## Preferencias por personalidad: tipo de parte -> peso extra.
const PREFERENCIAS := {
	"bruto": {"craneo": 2.2, "torax": 1.4},
	"preciso": {"cuello": 2.5, "ojo": 2.0},
	"astuto": {},
	"normal": {},
}


## Devuelve {"accion": "atacar", "parte": ...}, {"accion": "defender"} o {"accion": "recoger"}.
static func decidir(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> Dictionary:
	if yo.desarmado and (yo.puede_empunar("der") or yo.puede_empunar("izq")):
		return {"accion": "recoger"}
	if yo.vida <= yo.vida_max * 0.3 and rng.randf() < 0.18:
		return {"accion": "defender"}
	return {"accion": "atacar", "parte": elegir_parte(yo, rival, rng)}


## Elige una parte al azar, con más peso donde acierta más, hace más daño o
## prefiere su personalidad.
static func elegir_parte(yo: Luchador, rival: Luchador, rng: RandomNumberGenerator) -> String:
	var pesos := {}
	var total := 0.0
	for parte_id in DatosCuerpo.PARTES:
		var peso := MotorCombate.prob_acierto(yo, rival, parte_id)
		peso *= MotorCombate.multiplicador_danio(yo, rival, parte_id)
		peso *= preferencia(yo, rival, parte_id)
		if rival.esta_inutilizada(parte_id):
			peso *= 0.4
		peso = pow(peso, 1.5)
		pesos[parte_id] = peso
		total += peso
	var tirada := rng.randf() * total
	for parte_id in pesos:
		tirada -= pesos[parte_id]
		if tirada <= 0.0:
			return parte_id
	return "torax_der"


static func preferencia(yo: Luchador, rival: Luchador, parte_id: String) -> float:
	if yo.personalidad == "astuto" and not rival.desarmado:
		if parte_id == rival.mano_arma():
			return 5.0
		if parte_id == "antebrazo_" + rival.lado_arma():
			return 2.0
		return 1.0
	var tabla: Dictionary = PREFERENCIAS.get(yo.personalidad, {})
	return tabla.get(DatosCuerpo.base_de(parte_id), 1.0)
