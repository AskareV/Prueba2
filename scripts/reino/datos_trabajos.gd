class_name DatosTrabajos
extends RefCounted
## Trabajos del rey (pestaña Trabajo). Como en My Pet Protector, un trabajo
## ocupa la semana entera: cada día sale bien o mal según el dominio que el rey
## tenga de esa tarea, y solo se cobran los días buenos. Números provisionales.

const OFICIOS := {
	"audiencias": {
		"nombre": "Audiencias reales", "pago": 10, "estres": 2.0,
		"descripcion": "Escuchas las peticiones y las quejas del pueblo desde el trono.",
	},
	"murallas": {
		"nombre": "Patrullar las murallas", "pago": 12, "estres": 3.0,
		"descripcion": "Recorres las murallas con la guardia y revisas las defensas.",
	},
	"guardia": {
		"nombre": "Entrenar a la guardia", "pago": 9, "estres": 4.0,
		"descripcion": "Diriges el entrenamiento de los soldados del castillo.",
	},
	"impuestos": {
		"nombre": "Cobrar impuestos", "pago": 16, "estres": 3.5,
		"descripcion": "Visitas las aldeas para recaudar el tributo de la corona.",
	},
	"tribunal": {
		"nombre": "Presidir el tribunal", "pago": 20, "estres": 5.0,
		"descripcion": "Juzgas los pleitos y los crímenes del reino.",
	},
	"mercaderes": {
		"nombre": "Negociar con mercaderes", "pago": 26, "estres": 6.0,
		"descripcion": "Discutes precios y permisos con los gremios de comerciantes.",
	},
}
const ORDEN := ["audiencias", "murallas", "guardia", "impuestos", "tribunal", "mercaderes"]

const DIAS := 7
## Con este estrés o más el rey no puede trabajar.
const ESTRES_MAXIMO := 60.0
## Probabilidad de que un día salga bien: base + dominio (0 a 100) / divisor.
const EXITO_BASE := 0.55
const EXITO_DIVISOR := 250.0
## Dominio que se gana por cada día trabajado (hasta 100).
const DOMINIO_POR_DIA := 2.0
## Si los siete días salen bien, se cobra este múltiplo del pago diario de más.
const BONO_SEMANA_PERFECTA := 3


static func prob_exito(dominio: float) -> float:
	return minf(EXITO_BASE + dominio / EXITO_DIVISOR, 0.95)


## Pago por día que sale bien, con el multiplicador de Presencia.
static func pago_dia(oficio_id: String, multiplicador := 1.0) -> int:
	return roundi(int(OFICIOS[oficio_id]["pago"]) * multiplicador)


## Simula la semana de trabajo. Devuelve {"dias": [bool], "oro": n,
## "pago_dia": n, "estres": n, "bono": n, "dominio": nuevo dominio}.
static func trabajar_semana(oficio_id: String, dominio: float, rng: RandomNumberGenerator,
		multiplicador_pago := 1.0) -> Dictionary:
	var oficio: Dictionary = OFICIOS[oficio_id]
	var pago := pago_dia(oficio_id, multiplicador_pago)
	var dias: Array[bool] = []
	var oro := 0
	for dia in DIAS:
		var bien := rng.randf() < prob_exito(dominio)
		dias.append(bien)
		if bien:
			oro += pago
		dominio = minf(dominio + DOMINIO_POR_DIA, 100.0)
	var bono := 0
	if not dias.has(false):
		bono = pago * BONO_SEMANA_PERFECTA
	return {
		"dias": dias, "oro": oro + bono, "pago_dia": pago, "bono": bono, "estres": float(oficio["estres"]) * DIAS,
		"dominio": dominio,
	}
