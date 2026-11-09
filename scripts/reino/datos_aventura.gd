class_name DatosAventura
extends RefCounted
## Lugares del mapa de aventura: mazmorras (banderín oscuro) y zonas de siete
## días con sucesos al azar (banderín rojo). Números provisionales.

## Con este estrés o más el rey tiene que volver a casa.
const ESTRES_MAXIMO := 70.0

## "nivel": 1 fácil, 2 fácil/medio, 3 medio, 4 difícil (calidad del botín).
## "posicion": lugar en el mapa, en fracciones del ancho y alto.
## "estilo" (solo las mazmorras): cómo se arma su plano y cómo se ve: "cueva",
## "mina", "fuerte" o "castillo" (ver GeneradorMazmorra).
## "jefe" (solo las mazmorras): el enemigo que espera al final, en su lugar (ver
## GeneradorMazmorra.LUGAR_DEL_JEFE). Cuenta como uno de "cantidad_enemigos".
const MAZMORRAS := {
	"madriguera_goblin": {
		"nombre": "Madriguera goblin", "dificultad": "Fácil", "nivel": 1, "estilo": "cueva",
		"descripcion": "Cuevas naturales donde se esconden goblins. Son pequeños y casi no usan armadura: buen lugar para empezar.",
		"enemigos": ["goblin", "goblin", "goblin_lancero", "chaman_goblin"], "jefe": "jefe_goblin",
		"cantidad_enemigos": 5, "cofres": 3, "estres_por_paso": 1.0, "posicion": Vector2(0.2, 0.68),
	},
	"guarida_bandidos": {
		"nombre": "Guarida de bandidos", "dificultad": "Fácil / medio", "nivel": 2, "estilo": "mina",
		"descripcion": "Una mina abandonada donde acampa una banda de ladrones y matones. Guardan lo que roban en los caminos.",
		"enemigos": ["ladron", "ladron", "maton", "bandido"], "jefe": "capitan_bandido",
		"cantidad_enemigos": 5, "cofres": 3, "estres_por_paso": 1.2, "posicion": Vector2(0.46, 0.38),
	},
	"fortaleza_orca": {
		"nombre": "Fortaleza orca", "dificultad": "Medio", "nivel": 3, "estilo": "fuerte",
		"descripcion": "Un fuerte de troncos tomado por orcos: una empalizada con chozas adentro. Los guerreros llevan armadura y los chamanes lanzan magia.",
		"enemigos": ["orco_guerrero", "orco_cazador", "orco", "chaman_orco"], "jefe": "caudillo_orco",
		"cantidad_enemigos": 6, "cofres": 3, "estres_por_paso": 1.4, "posicion": Vector2(0.76, 0.3),
	},
	"ciudadela_maldita": {
		"nombre": "Ciudadela maldita", "dificultad": "Difícil", "nivel": 4, "estilo": "castillo",
		"descripcion": "El castillo de un reino enemigo: salas de piedra y pasillos guardados por caballeros negros, lanceros, cultistas y verdugos. Mucha armadura y mucha magia.",
		"enemigos": ["caballero_negro", "lancero_negro", "cultista", "verdugo"], "jefe": "rey_negro",
		"cantidad_enemigos": 6, "cofres": 4, "estres_por_paso": 1.6, "posicion": Vector2(0.84, 0.74),
	},
}
const ORDEN_MAZMORRAS := ["madriguera_goblin", "guarida_bandidos", "fortaleza_orca", "ciudadela_maldita"]

const ZONAS := {
	"bosque_sombrio": {
		"nombre": "Bosque sombrío", "dificultad": "Fácil", "nivel": 1,
		"descripcion": "Un bosque espeso a un día del castillo. Dicen que los goblins cazan entre sus árboles.",
		"enemigos": ["goblin", "goblin_lancero", "chaman_goblin", "ladron"], "posicion": Vector2(0.3, 0.52),
	},
	"ruinas_castillo": {
		"nombre": "Ruinas del castillo", "dificultad": "Fácil / medio", "nivel": 2,
		"descripcion": "Lo que queda de una vieja fortaleza. Se oyen ruidos entre las piedras: algo vive ahí.",
		"enemigos": ["ladron", "maton", "bandido", "chaman_goblin"], "posicion": Vector2(0.6, 0.6),
	},
	"paso_montana": {
		"nombre": "Paso de la montaña", "dificultad": "Medio", "nivel": 3,
		"descripcion": "Un camino de montaña que usan los orcos para bajar a saquear.",
		"enemigos": ["orco_cazador", "orco_guerrero", "chaman_orco", "maton"], "posicion": Vector2(0.62, 0.2),
	},
}
const ORDEN_ZONAS := ["bosque_sombrio", "ruinas_castillo", "paso_montana"]

## Días de una salida a una zona.
const DIAS_ZONA := 7
## Estrés que suma cada día de marcha en una zona.
const ESTRES_POR_DIA := 5.0
## Sucesos de un día en una zona y su peso (probabilidad relativa).
const SUCESOS := {
	"combate": 30.0,
	"nada": 15.0,
	"oro": 20.0,
	"objeto": 10.0,
	"materiales": 10.0,
	"descanso": 10.0,
	"trampa": 5.0,
}
## Probabilidad de que un enemigo vencido suelte un objeto.
const PROB_BOTIN_ENEMIGO := 0.4
## Estrés al ganar o perder un combate (como en My Pet Protector).
const ESTRES_VICTORIA := 3.0
const ESTRES_DERROTA := 50.0
## Experiencia por vencer a un enemigo y por abrir un cofre, por nivel del lugar.
## Un jefe da XP_JEFE veces la de un enemigo y siempre suelta un objeto. Si un
## enemigo huye, da su experiencia pero se lleva su oro.
const XP_POR_VICTORIA := 10
const XP_POR_COFRE := 4
const XP_JEFE := 3
## Al caminar el rey se va curando (ver EstadoReino.curar_al_caminar): cada paso
## cura esta parte de la vida máxima (y ×100 de integridad a cada parte, 1 punto)
## y este maná. Un día de marcha en una zona cuenta como PASOS_POR_DIA pasos.
const CURA_POR_PASO := 0.01
const MANA_POR_PASO := 0.5
const PASOS_POR_DIA := 4.0
## Sucesos buenos de las zonas: el Amuleto los hace más probables (y la trampa menos).
const SUCESOS_BUENOS := ["oro", "objeto", "materiales", "descanso"]
## Lo que cuenta el suceso de materiales, según lo que encontró.
const TEXTO_MATERIALES := {
	"madera": "Encuentras troncos ya cortados junto al camino: %s.",
	"piedra": "Encuentras piedras talladas entre unas ruinas: %s.",
	"hierro": "Encuentras armas viejas y oxidadas para fundir: %s.",
}


static func lugar(lugar_id: String) -> Dictionary:
	if MAZMORRAS.has(lugar_id):
		return MAZMORRAS[lugar_id]
	return ZONAS[lugar_id]


static func es_mazmorra(lugar_id: String) -> bool:
	return MAZMORRAS.has(lugar_id)


## Peso de cada suceso con los puntos de Amuleto del rey.
static func pesos_sucesos(puntos_amuleto := 0.0) -> Dictionary:
	var pesos := {}
	for suceso in SUCESOS:
		var peso: float = SUCESOS[suceso]
		if SUCESOS_BUENOS.has(suceso):
			peso *= DatosEstadisticas.aumento(puntos_amuleto, DatosEstadisticas.SUCESOS_POR_AMULETO)
		elif suceso == "trampa":
			peso *= DatosEstadisticas.reduccion(puntos_amuleto, DatosEstadisticas.SUCESOS_POR_AMULETO)
		pesos[suceso] = peso
	return pesos


## Sortea el suceso de un día en una zona.
static func sortear_suceso(rng: RandomNumberGenerator, puntos_amuleto := 0.0) -> String:
	var pesos := pesos_sucesos(puntos_amuleto)
	var total := 0.0
	for suceso in pesos:
		total += pesos[suceso]
	var tirada := rng.randf() * total
	for suceso in pesos:
		tirada -= pesos[suceso]
		if tirada < 0.0:
			return suceso
	return "nada"


## Nombre del jefe de una mazmorra ("" si el lugar no tiene).
static func nombre_jefe(lugar_id: String) -> String:
	var jefe_id: String = lugar(lugar_id).get("jefe", "")
	return "" if jefe_id == "" else String(DatosRivales.rival(jefe_id)["nombre"])


## Nombres de los enemigos de un lugar, sin repetir: "goblins, chamanes..."
static func nombres_enemigos(lugar_id: String) -> String:
	var nombres: PackedStringArray = []
	for enemigo_id in lugar(lugar_id)["enemigos"]:
		var nombre: String = DatosRivales.rival(enemigo_id)["nombre"]
		if not nombres.has(nombre):
			nombres.append(nombre)
	return ", ".join(nombres)
