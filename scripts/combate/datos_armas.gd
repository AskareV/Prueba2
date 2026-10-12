class_name DatosArmas
extends RefCounted
## Armas provisionales de la demo (docs/diseno.md, punto 6). Todos los números
## son de prueba y se ajustarán cuando definamos armas y daño.

## "danio_min" y "danio_max" son la fuerza del golpe; cada parte la convierte en
## vida perdida y en desgaste de la parte (ver DatosCuerpo.PARTES). El rango es
## estrecho para que el daño dependa poco de la suerte.
## "efectos" (opcional, 1 si falta) multiplica la probabilidad de aturdir y de
## desarmar: los puños aturden y desarman mucho menos que una maza.
const ARMAS := {
	"espada": {"nombre": "Espada", "tipo": "cortante", "danio_min": 14, "danio_max": 17, "precision": 0.85},
	"maza": {"nombre": "Maza", "tipo": "contundente", "danio_min": 15, "danio_max": 19, "precision": 0.78},
	"lanza": {"nombre": "Lanza", "tipo": "punzante", "danio_min": 12, "danio_max": 16, "precision": 0.9},
	"punos": {"nombre": "Puños", "tipo": "contundente", "danio_min": 4, "danio_max": 5, "precision": 0.85, "efectos": 0.4},
	"patadas": {"nombre": "Patadas", "tipo": "contundente", "danio_min": 9, "danio_max": 11, "precision": 0.8, "efectos": 0.5},
}

## Armas que se pueden elegir. Sin arma se pelea con los puños o, si ningún
## brazo sirve, a patadas.
const ELEGIBLES := ["espada", "maza", "lanza"]

## Color de cada tipo de arma en los botones.
const COLORES_TIPO := {"cortante": Color("#ef5350"), "contundente": Color("#ab47bc"), "punzante": Color("#29b6f6")}

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
		"prob_aturdir": 0.1,
		"prob_desarmar": 0.25,
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
		"prob_aturdir": 0.15,
		"prob_desarmar": 0.3,
		"afinidad": {"craneo": 1.15, "torax": 1.1, "hombro": 1.1, "cuello": 0.9, "ojo": 0.8},
	},
	"punzante": {
		"nombre": "Punzante",
		"herida": "Perforación",
		"descripcion": "Más precisa con partes pequeñas; más daño en tórax, abdomen y cuello.",
		"exp_tamano": 0.6,
		"prob_aturdir": 0.12,
		"prob_desarmar": 0.12,
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
