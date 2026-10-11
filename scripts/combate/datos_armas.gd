class_name DatosArmas
extends RefCounted
## Armas provisionales de la demo (docs/diseno.md, punto 6). Todos los números
## son de prueba y se ajustarán cuando definamos armas y daño.

const ARMAS := {
	"espada": {"nombre": "Espada", "tipo": "cortante", "danio_min": 12, "danio_max": 18, "precision": 0.85},
	"maza": {"nombre": "Maza", "tipo": "contundente", "danio_min": 13, "danio_max": 20, "precision": 0.78},
	"lanza": {"nombre": "Lanza", "tipo": "punzante", "danio_min": 10, "danio_max": 17, "precision": 0.9},
	"punos": {"nombre": "Puños", "tipo": "contundente", "danio_min": 3, "danio_max": 6, "precision": 0.85},
}

## Armas que se pueden elegir (los puños solo se usan al quedar desarmado).
const ELEGIBLES := ["espada", "maza", "lanza"]

## Datos por tipo de arma:
## - herida: cómo se registra el golpe (para el sangrado e infecciones futuras).
## - exp_tamano: < 1 hace más fácil acertar a partes pequeñas.
## - prob_aturdir: base para aturdir con un golpe en el cráneo.
## - prob_desarmar: base para hacer soltar el arma con un golpe en la mano.
## - afinidad: multiplicador de daño por tipo de parte (1.0 si no aparece).
const TIPOS := {
	"cortante": {
		"nombre": "Cortante",
		"herida": "Corte",
		"descripcion": "Más daño en extremidades y cuello; menos en el cráneo.",
		"exp_tamano": 1.0,
		"prob_aturdir": 0.15,
		"prob_desarmar": 0.35,
		"afinidad": {
			"craneo": 0.9, "cuello": 1.15, "brazo": 1.15, "antebrazo": 1.15, "mano": 1.15,
			"muslo": 1.15, "espinilla": 1.15, "pie": 1.1,
		},
	},
	"contundente": {
		"nombre": "Contundente",
		"herida": "Contusión",
		"descripcion": "Más daño en el cráneo; aturde y desarma con más facilidad; puede fracturar.",
		"exp_tamano": 1.0,
		"prob_aturdir": 0.35,
		"prob_desarmar": 0.45,
		"afinidad": {"craneo": 1.25, "torax": 1.1, "hombro": 1.1, "cuello": 0.9, "ojo": 0.8},
	},
	"punzante": {
		"nombre": "Punzante",
		"herida": "Perforación",
		"descripcion": "Más precisa con partes pequeñas; más daño en tórax, abdomen y cuello.",
		"exp_tamano": 0.6,
		"prob_aturdir": 0.2,
		"prob_desarmar": 0.35,
		"afinidad": {
			"craneo": 0.85, "ojo": 1.25, "cuello": 1.2, "torax": 1.2, "abdomen": 1.2,
			"mano": 0.85, "pie": 0.85,
		},
	},
}


static func arma(arma_id: String) -> Dictionary:
	return ARMAS[arma_id]


static func tipo(tipo_id: String) -> Dictionary:
	return TIPOS[tipo_id]


static func tipo_de(arma_id: String) -> Dictionary:
	return TIPOS[ARMAS[arma_id]["tipo"]]


static func afinidad(tipo_id: String, parte_id: String) -> float:
	var tabla: Dictionary = TIPOS[tipo_id]["afinidad"]
	return tabla.get(DatosCuerpo.base_de(parte_id), 1.0)


## "Espada (cortante)"
static func descripcion_corta(arma_id: String) -> String:
	var a: Dictionary = ARMAS[arma_id]
	return "%s (%s)" % [a["nombre"], String(a["tipo"])]
