class_name DatosEstadisticas
extends RefCounted
## Características del rey: 7 principales con 3 subcaracterísticas cada una.
## Todas empiezan en BASE (3). Un punto en una principal sube +1 sus tres subs
## y da PUNTOS_SUB_POR_PRINCIPAL para repartir solo entre esas tres. Los
## efectos dependen de cuánto supera cada sub a la BASE, así que un luchador
## sin características (los enemigos y el rey de la demo) pelea como antes.
## Todos los números son provisionales.

const BASE := 3.0
## Puntos para las principales al empezar una partida.
const PUNTOS_INICIALES := 15
## Al subir de nivel: puntos para las principales.
const PUNTOS_PRINCIPAL_POR_NIVEL := 1
## Cada punto puesto en una principal da estos puntos para sus 3 subs (solo
## para esas, no para las de otra principal).
const PUNTOS_SUB_POR_PRINCIPAL := 7
## Cada punto de Amuleto por encima de la base suma esto a todas las demás subs.
const AMULETO_POR_PUNTO := 0.1

const ORDEN := ["fuerza", "destreza", "aguante", "resiliencia", "suerte", "inteligencia", "carisma"]

const CARACTERISTICAS := {
	"fuerza": {"nombre": "Fuerza", "color": Color("#ef5350"),
		"subs": ["fuerza_maxima", "fuerza_explosiva", "fuerza_agarre"]},
	"destreza": {"nombre": "Destreza", "color": Color("#ffca28"),
		"subs": ["precision", "reflejos", "velocidad"]},
	"aguante": {"nombre": "Aguante", "color": Color("#66bb6a"),
		"subs": ["vitalidad", "cardio", "recuperacion"]},
	"resiliencia": {"nombre": "Resiliencia", "color": Color("#8d6e63"),
		"subs": ["compostura", "resistencia", "firmeza"]},
	"suerte": {"nombre": "Suerte", "color": Color("#26c6da"),
		"subs": ["golpe_suerte", "buen_ojo", "amuleto"]},
	"inteligencia": {"nombre": "Inteligencia", "color": Color("#7e57c2"),
		"subs": ["arcano", "estudio", "mago"]},
	"carisma": {"nombre": "Carisma", "color": Color("#ec407a"),
		"subs": ["negociacion", "liderazgo", "presencia"]},
}

## "sin_efecto": todavía no hace nada porque falta el sistema del que depende.
const SUBS := {
	"fuerza_maxima": {"nombre": "Fuerza máxima", "descripcion": "Más daño con armas físicas."},
	"fuerza_explosiva": {"nombre": "Fuerza explosiva",
		"descripcion": "Más fácil fracturar y aturdir, rompe la guardia del rival y a veces lo empuja hacia atrás en la barra de turnos."},
	"fuerza_agarre": {"nombre": "Fuerza de agarre",
		"descripcion": "Al defenderte bloqueas más daño. Te cuesta más soltar el arma, desarmas mejor y la mano torpe castiga menos."},
	"precision": {"nombre": "Precisión", "descripcion": "Un poco más de acierto en todas las partes del cuerpo."},
	"reflejos": {"nombre": "Reflejos", "descripcion": "Al rival le cuesta más acertarte."},
	"velocidad": {"nombre": "Velocidad",
		"descripcion": "Avanzas más rápido en la barra de turnos (puedes actuar dos veces seguidas) y huyes más fácil."},
	"vitalidad": {"nombre": "Vitalidad", "descripcion": "Más vida máxima."},
	"cardio": {"nombre": "Cardio", "descripcion": "Cada paso en la mazmorra suma menos estrés."},
	"recuperacion": {"nombre": "Recuperación",
		"descripcion": "Sangrado, infecciones y curar heridas.", "sin_efecto": true},
	"compostura": {"nombre": "Compostura", "descripcion": "Menos estrés por combates, trampas y trabajos."},
	"resistencia": {"nombre": "Resistencia",
		"descripcion": "Un poco de resistencia a todo (aturdir, desarmar, empujones) y tu armadura rinde más."},
	"firmeza": {"nombre": "Firmeza", "descripcion": "Mucha resistencia al aturdimiento, al desmayo y a los empujones."},
	"golpe_suerte": {"nombre": "Golpe de suerte", "descripcion": "Probabilidad de golpe crítico (más daño)."},
	"buen_ojo": {"nombre": "Buen ojo", "descripcion": "Mejor calidad y más oro en cofres y enemigos."},
	"amuleto": {"nombre": "Amuleto",
		"descripcion": "Cada punto suma 0,1 a todas las demás subcaracterísticas. Más días buenos y menos trampas en las zonas."},
	"arcano": {"nombre": "Arcano", "descripcion": "Más daño mágico (bastón y hechizos) y curas más fuertes."},
	"estudio": {"nombre": "Estudio", "descripcion": "Más experiencia ganada."},
	"mago": {"nombre": "Mago", "descripcion": "Más maná máximo y más maná recuperado por turno."},
	"negociacion": {"nombre": "Negociación", "descripcion": "Vendes más caro y compras más barato en el mercado."},
	"liderazgo": {"nombre": "Liderazgo",
		"descripcion": "Moral de los soldados de la ciudad: defienden mejor y bajan más el peligro."},
	"presencia": {"nombre": "Presencia",
		"descripcion": "Más pago en los trabajos. Si supera de lejos al enemigo, este queda atemorizado todo el combate."},
}

# --- Efectos por punto sobre la base (provisionales) ---

const DANIO_POR_FUERZA := 0.03
const ATURDIR_POR_EXPLOSIVA := 0.05
const FRACTURA_POR_EXPLOSIVA := 2.0
const GUARDIA_POR_EXPLOSIVA := 0.02
const EMPUJON_POR_EXPLOSIVA := 0.02
const EMPUJON_MAXIMO := 0.25
const GUARDIA_POR_AGARRE := 0.02
const DESARME_POR_AGARRE := 0.05
const MANO_TORPE_POR_AGARRE := 0.06
const ACIERTO_POR_PRECISION := 0.01
const ESQUIVA_POR_REFLEJOS := 0.01
## Rapidez del rey en la base y lo que suma cada punto de Velocidad.
const RAPIDEZ_BASE := 13.0
const RAPIDEZ_POR_VELOCIDAD := 0.5
const HUIDA_POR_VELOCIDAD := 0.02
const VIDA_POR_VITALIDAD := 5
const PASO_POR_CARDIO := 0.04
const ESTRES_POR_COMPOSTURA := 0.04
const ARMADURA_POR_RESISTENCIA := 0.03
const ESTADOS_POR_RESISTENCIA := 0.03
const ATURDIR_POR_FIRMEZA := 0.06
const EMPUJON_POR_FIRMEZA := 0.08
const DESMAYO_POR_FIRMEZA := 0.06
const CRITICO_POR_SUERTE := 0.015
const CALIDAD_POR_BUEN_OJO := 0.05
const ORO_POR_BUEN_OJO := 0.05
const SUCESOS_POR_AMULETO := 0.05
const MAGIA_POR_ARCANO := 0.05
const CURA_POR_ARCANO := 2
const XP_POR_ESTUDIO := 0.05
const MANA_BASE := 20
const MANA_POR_MAGO := 5
const REGENERACION_BASE := 2.0
const REGENERACION_POR_MAGO := 0.5
const VENTA_POR_NEGOCIACION := 0.03
const COMPRA_POR_NEGOCIACION := 0.02
const MORAL_POR_LIDERAZGO := 0.03
const PAGO_POR_PRESENCIA := 0.03
## Presencia que debe superar al "valor" del enemigo para atemorizarlo.
const VENTAJA_PARA_ATEMORIZAR := 3.0
## Ningún multiplicador que reduce (estrés, estados) baja de esto.
const MINIMO_REDUCCION := 0.3


static func caracteristica_de(sub_id: String) -> String:
	for car_id in ORDEN:
		if CARACTERISTICAS[car_id]["subs"].has(sub_id):
			return car_id
	return ""


static func todas_las_subs() -> Array[String]:
	var lista: Array[String] = []
	for car_id in ORDEN:
		for sub_id in CARACTERISTICAS[car_id]["subs"]:
			lista.append(sub_id)
	return lista


## Multiplicador que reduce algo según los puntos (nunca por debajo del mínimo).
static func reduccion(puntos: float, por_punto: float) -> float:
	return maxf(1.0 - puntos * por_punto, MINIMO_REDUCCION)


## Multiplicador que aumenta algo según los puntos.
static func aumento(puntos: float, por_punto: float) -> float:
	return maxf(1.0 + puntos * por_punto, 0.0)


## Experiencia necesaria para pasar del nivel "nivel" al siguiente.
static func xp_para_subir(nivel: int) -> int:
	return 50 * nivel
