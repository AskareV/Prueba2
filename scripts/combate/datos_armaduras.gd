class_name DatosArmaduras
extends RefCounted
## Tipos de armadura (docs/diseno.md, 7.6). Cada tipo frena mejor un daño que
## otro y los pesados hacen más lento. Todos los números son provisionales.
##
## - fisica / magica: parte del valor de la pieza que da como armadura y como
##   resistencia mágica (las runas frenan la magia y poco lo demás).
## - contra: cuánto rinde su armadura según el tipo de arma que la golpea (ver
##   DatosArmas.TIPOS): la malla frena muy bien un corte y poco un mazazo.
## - peso: rapidez que quita cada pieza puesta (0,03 = 3%).
## - adjetivo: para el nombre ("Peto acolchado"); si no, "de" + nombre.
## - metal: si lleva el material del nivel en el nombre ("de hierro").
const TIPOS := {
	"acolchada": {
		"nombre": "Acolchada", "adjetivo": "acolchad", "metal": false, "fisica": 1.0, "magica": 0.25, "peso": 0.0,
		"contra": {"cortante": 0.9, "punzante": 0.8, "contundente": 1.2},
		"descripcion": "Frena bien los golpes contundentes; los cortes y las estocadas, menos.",
	},
	"cuero": {
		"nombre": "Cuero", "metal": false, "fisica": 1.0, "magica": 0.25, "peso": 0.01,
		"contra": {"cortante": 1.1, "punzante": 0.6, "contundente": 0.8},
		"descripcion": "Frena los cortes; las estocadas la atraviesan.",
	},
	"malla": {
		"nombre": "Malla", "metal": true, "fisica": 1.0, "magica": 0.25, "peso": 0.02,
		"contra": {"cortante": 1.3, "punzante": 0.7, "contundente": 0.5},
		"descripcion": "Frena muy bien los cortes; los mazazos pasan casi enteros.",
	},
	"placas": {
		"nombre": "Placas", "metal": true, "fisica": 1.0, "magica": 0.25, "peso": 0.03,
		"contra": {"cortante": 1.3, "punzante": 1.2, "contundente": 0.8},
		"descripcion": "Frena casi todo, pero pesa.",
	},
	"runas": {
		"nombre": "Runas", "metal": true, "fisica": 0.55, "magica": 1.0, "peso": 0.0,
		"contra": {"cortante": 1.0, "punzante": 1.0, "contundente": 1.0},
		"descripcion": "Frena la magia; lo demás, poco.",
	},
}
const ORDEN := ["acolchada", "cuero", "malla", "placas", "runas"]
## Probabilidad (%) de cada tipo en el botín según el nivel del lugar (1 a 4), en
## el orden de ORDEN: las placas salen en los lugares difíciles.
const PROB_POR_NIVEL := [
	[35.0, 35.0, 10.0, 0.0, 20.0],
	[25.0, 30.0, 20.0, 5.0, 20.0],
	[15.0, 20.0, 30.0, 15.0, 20.0],
	[10.0, 15.0, 30.0, 25.0, 20.0],
]


static func tipo(tipo_id: String) -> Dictionary:
	return TIPOS[tipo_id]


## Cuánto rinde la armadura de ese tipo contra ese tipo de arma (1 sin tipo).
static func eficacia(tipo_id: String, tipo_arma: String) -> float:
	if not TIPOS.has(tipo_id):
		return 1.0
	return float(TIPOS[tipo_id]["contra"].get(tipo_arma, 1.0))


## Sortea el tipo de una pieza de botín de ese nivel.
static func sortear(nivel: int, rng: RandomNumberGenerator) -> String:
	var pesos: Array = PROB_POR_NIVEL[clampi(nivel, 1, 4) - 1]
	var tirada := rng.randf() * 100.0
	for i in ORDEN.size():
		tirada -= float(pesos[i])
		if tirada < 0.0:
			return ORDEN[i]
	return ORDEN[0]


## "Peto acolchado", "Grebas de cuero", "Casco de malla de hierro" o "Brazales de
## bronce con runas". "genero": "m" o "f"; "plural": si el nombre de la pieza lo es.
static func nombre_pieza(pieza: String, genero: String, plural: bool, tipo_id: String, material: String) -> String:
	var datos: Dictionary = TIPOS[tipo_id]
	if tipo_id == "runas":
		return "%s %s con runas" % [pieza, material]
	if datos.has("adjetivo"):
		return "%s %s%s%s" % [pieza, datos["adjetivo"], "a" if genero == "f" else "o", "s" if plural else ""]
	var nombre := "%s de %s" % [pieza, String(datos["nombre"]).to_lower()]
	if datos["metal"]:
		nombre += " " + material
	return nombre
