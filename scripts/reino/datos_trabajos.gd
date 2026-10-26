class_name DatosTrabajos
extends RefCounted
## Trabajos del rey (pestaña Trabajo). Un trabajo ocupa la semana entera y se
## cobran los siete días. El pago sube con tres partes de las características
## que tocan a cada trabajo: la primera es la que más pesa. Números provisionales.

const OFICIOS := {
	"audiencias": {
		"nombre": "Audiencias reales", "pago": 6, "estres": 2.0,
		"partes": {"presencia": 0.5, "compostura": 0.3, "estudio": 0.2},
		"descripcion": "Escuchas las peticiones y las quejas del pueblo desde el trono.",
	},
	"murallas": {
		"nombre": "Patrullar las murallas", "pago": 7, "estres": 3.0,
		"partes": {"cardio": 0.5, "reflejos": 0.3, "resistencia": 0.2},
		"descripcion": "Recorres las murallas con la guardia y revisas las defensas.",
	},
	"guardia": {
		"nombre": "Entrenar a la guardia", "pago": 5, "estres": 4.0,
		"partes": {"liderazgo": 0.5, "fuerza_maxima": 0.3, "precision": 0.2},
		"descripcion": "Diriges el entrenamiento de los soldados del castillo.",
	},
	"impuestos": {
		"nombre": "Cobrar impuestos", "pago": 9, "estres": 3.5,
		"partes": {"presencia": 0.5, "velocidad": 0.3, "buen_ojo": 0.2},
		"descripcion": "Visitas las aldeas para recaudar el tributo de la corona.",
	},
	"tribunal": {
		"nombre": "Presidir el tribunal", "pago": 11, "estres": 5.0,
		"partes": {"estudio": 0.5, "compostura": 0.3, "firmeza": 0.2},
		"descripcion": "Juzgas los pleitos y los crímenes del reino.",
	},
	"mercaderes": {
		"nombre": "Negociar con mercaderes", "pago": 15, "estres": 6.0,
		"partes": {"negociacion": 0.5, "buen_ojo": 0.3, "golpe_suerte": 0.2},
		"descripcion": "Discutes precios y permisos con los gremios de comerciantes.",
	},
}
const ORDEN := ["audiencias", "murallas", "guardia", "impuestos", "tribunal", "mercaderes"]

const DIAS := 7
## Con este estrés o más el rey no puede trabajar.
const ESTRES_MAXIMO := 60.0
## Cuánto sube el pago cada punto de las partes del trabajo (sobre 3, hasta el
## tope de +20), según su peso: con +20 en las tres, ×2.
const PAGO_POR_PUNTO := 0.05


## Multiplicador del pago con esos puntos útiles por parte ({"presencia": 10.0, ...};
## las que falten cuentan 0).
static func multiplicador(oficio_id: String, puntos: Dictionary) -> float:
	var suma := 0.0
	var partes: Dictionary = OFICIOS[oficio_id]["partes"]
	for sub_id in partes:
		suma += float(partes[sub_id]) * float(puntos.get(sub_id, 0.0))
	return DatosEstadisticas.aumento(suma, PAGO_POR_PUNTO)


## Pago por día con ese multiplicador.
static func pago_dia(oficio_id: String, multiplicador_pago := 1.0) -> int:
	return roundi(int(OFICIOS[oficio_id]["pago"]) * multiplicador_pago)


## "Presencia (50%), Compostura (30%) y Estudio (20%)"
static func texto_partes(oficio_id: String) -> String:
	var textos: PackedStringArray = []
	var partes: Dictionary = OFICIOS[oficio_id]["partes"]
	for sub_id in partes:
		textos.append("%s (%d%%)" % [String(DatosEstadisticas.SUBS[sub_id]["nombre"]), roundi(100.0 * float(partes[sub_id]))])
	return ", ".join(textos.slice(0, textos.size() - 1)) + " y " + textos[textos.size() - 1]


## La semana de trabajo: se cobran los siete días. Devuelve {"oro", "pago_dia",
## "estres"}.
static func trabajar_semana(oficio_id: String, multiplicador_pago := 1.0) -> Dictionary:
	var pago := pago_dia(oficio_id, multiplicador_pago)
	return {"oro": pago * DIAS, "pago_dia": pago, "estres": float(OFICIOS[oficio_id]["estres"]) * DIAS}
