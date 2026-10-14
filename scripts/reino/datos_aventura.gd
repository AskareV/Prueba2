class_name DatosAventura
extends RefCounted
## Lugares del mapa de aventura: mazmorras (banderín oscuro) y zonas de siete
## días con sucesos al azar (banderín rojo). Números provisionales.

## Con este estrés o más el rey tiene que volver a casa.
const ESTRES_MAXIMO := 70.0

## "nivel": 1 fácil, 2 fácil/medio, 3 medio, 4 difícil (calidad del botín).
## "posicion": lugar en el mapa, en fracciones del ancho y alto.
const MAZMORRAS := {
	"madriguera_goblin": {
		"nombre": "Madriguera goblin", "dificultad": "Fácil", "nivel": 1,
		"descripcion": "Túneles estrechos donde se esconden goblins. Son pequeños y casi no usan armadura: buen lugar para empezar.",
		"enemigos": ["goblin", "goblin", "goblin_lancero", "chaman_goblin"],
		"cantidad_enemigos": 5, "cofres": 3, "estres_por_paso": 1.0, "posicion": Vector2(0.2, 0.68),
	},
	"guarida_bandidos": {
		"nombre": "Guarida de bandidos", "dificultad": "Fácil / medio", "nivel": 2,
		"descripcion": "Una cueva usada por una banda de ladrones y matones. Guardan lo que roban en los caminos.",
		"enemigos": ["ladron", "ladron", "maton", "bandido"],
		"cantidad_enemigos": 5, "cofres": 3, "estres_por_paso": 1.2, "posicion": Vector2(0.46, 0.38),
	},
	"fortaleza_orca": {
		"nombre": "Fortaleza orca", "dificultad": "Medio", "nivel": 3,
		"descripcion": "Un fuerte de madera y piedra tomado por orcos. Los guerreros llevan armadura y los chamanes lanzan magia.",
		"enemigos": ["orco_guerrero", "orco_cazador", "orco", "chaman_orco"],
		"cantidad_enemigos": 6, "cofres": 3, "estres_por_paso": 1.4, "posicion": Vector2(0.76, 0.3),
	},
	"ciudadela_maldita": {
		"nombre": "Ciudadela maldita", "dificultad": "Difícil", "nivel": 4,
		"descripcion": "Ruinas de un castillo donde un culto oscuro guarda tesoros antiguos. Mucha armadura y mucha magia.",
		"enemigos": ["caballero_negro", "cultista", "verdugo"],
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
	"nada": 25.0,
	"oro": 20.0,
	"objeto": 10.0,
	"descanso": 10.0,
	"trampa": 5.0,
}
## Probabilidad de que un enemigo vencido suelte un objeto.
const PROB_BOTIN_ENEMIGO := 0.4
## Estrés al ganar o perder un combate (como en My Pet Protector).
const ESTRES_VICTORIA := 3.0
const ESTRES_DERROTA := 50.0


static func lugar(lugar_id: String) -> Dictionary:
	if MAZMORRAS.has(lugar_id):
		return MAZMORRAS[lugar_id]
	return ZONAS[lugar_id]


static func es_mazmorra(lugar_id: String) -> bool:
	return MAZMORRAS.has(lugar_id)


## Sortea el suceso de un día en una zona.
static func sortear_suceso(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for suceso in SUCESOS:
		total += SUCESOS[suceso]
	var tirada := rng.randf() * total
	for suceso in SUCESOS:
		tirada -= SUCESOS[suceso]
		if tirada < 0.0:
			return suceso
	return "nada"


## Nombres de los enemigos de un lugar, sin repetir: "goblins, chamanes..."
static func nombres_enemigos(lugar_id: String) -> String:
	var nombres: PackedStringArray = []
	for enemigo_id in lugar(lugar_id)["enemigos"]:
		var nombre: String = DatosRivales.rival(enemigo_id)["nombre"]
		if not nombres.has(nombre):
			nombres.append(nombre)
	return ", ".join(nombres)
