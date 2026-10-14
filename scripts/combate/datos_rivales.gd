class_name DatosRivales
extends RefCounted
## Rivales de la demo de combate, enemigos del reino y aspecto del rey.
##
## Aspecto: colores por grupo de partes y accesorios. "ancho" y "alto"
## deforman el cuerpo; "escala" cambia el tamaño en pantalla.
## Datos opcionales de los enemigos del reino (provisionales):
## - nivel: dificultad del enemigo, de 1 fácil a 4 difícil (informativo: el
##   botín es del nivel del lugar donde se lo vence).
## - oro: [mínimo, máximo] que dan al vencerlos.
## - armadura: por grupo de zonas ("cabeza", "torso", "brazos", "piernas"),
##   [física, mágica]. Ver MotorCombate.multiplicador_armadura.
## - danio: [mínimo, máximo] de su arma, si no usa el daño básico.
## - precision: precisión de su arma, si no usa la básica.

## Rivales de la demo de combate.
const ORDEN := ["bandido", "orco", "lancero"]

const PERSONALIDADES := {
	"astuto": "Astuto: intenta desarmarte.",
	"bruto": "Bruto: abre tu guardia y va a tu cabeza.",
	"preciso": "Preciso: abre tu guardia y va a tu cuello.",
	"normal": "Ataca donde es más fácil acertar.",
}

const RIVALES := {
	"bandido": {
		"nombre": "Bandido", "articulo": "el", "vida": 80, "diestro": true, "arma": "espada",
		"personalidad": "astuto",
		"aspecto": {
			"piel": Color("#d9a066"), "torso": Color("#5d6b3a"), "hombros": Color("#4a3b2a"),
			"brazos": Color("#5d6b3a"), "antebrazos": Color("#d9a066"), "manos": Color("#d9a066"),
			"muslos": Color("#4a3b2a"), "espinillas": Color("#4a3b2a"), "pies": Color("#2e2219"),
			"cinturon": Color("#2e2219"), "accesorio": "capucha", "accesorio_color": Color("#3b4a2a"),
			"panuelo": Color("#9e2a2b"), "ancho": 0.96, "alto": 0.98, "escala": 1.0,
		},
	},
	"orco": {
		"nombre": "Orco", "articulo": "el", "vida": 105, "diestro": false, "arma": "maza",
		"personalidad": "bruto",
		"aspecto": {
			"piel": Color("#6aa84f"), "torso": Color("#6b4423"), "hombros": Color("#8a8f99"),
			"brazos": Color("#6aa84f"), "antebrazos": Color("#6aa84f"), "manos": Color("#6aa84f"),
			"muslos": Color("#4b3621"), "espinillas": Color("#5f8f45"), "pies": Color("#2b1d12"),
			"cinturon": Color("#2b1d12"), "accesorio": "colmillos", "pelo": Color("#1e1e1e"),
			"ancho": 1.2, "alto": 1.02, "escala": 1.1,
		},
	},
	"lancero": {
		"nombre": "Lancero", "articulo": "el", "vida": 95, "diestro": true, "arma": "lanza",
		"personalidad": "preciso",
		"aspecto": {
			"piel": Color("#c68642"), "torso": Color("#2c6e6a"), "hombros": Color("#b0b7c3"),
			"brazos": Color("#7d8696"), "antebrazos": Color("#b0b7c3"), "manos": Color("#5b4636"),
			"muslos": Color("#2f3b4a"), "espinillas": Color("#b0b7c3"), "pies": Color("#2b2b2b"),
			"cinturon": Color("#5b4636"), "accesorio": "casco", "accesorio_color": Color("#b0b7c3"),
			"ancho": 0.98, "alto": 1.03, "escala": 1.0,
		},
	},
}

## Aspecto base de los goblins: pequeños, verdes y casi sin armadura.
const _GOBLIN := {
	"piel": Color("#7cb342"), "torso": Color("#5d4037"), "hombros": Color("#4e342e"),
	"brazos": Color("#7cb342"), "antebrazos": Color("#7cb342"), "manos": Color("#7cb342"),
	"muslos": Color("#4e342e"), "espinillas": Color("#7cb342"), "pies": Color("#3e2723"),
	"cinturon": Color("#3e2723"), "accesorio": "orejas", "ancho": 0.9, "alto": 0.88, "escala": 0.74,
}
const _ORCO := {
	"piel": Color("#6aa84f"), "torso": Color("#6b4423"), "hombros": Color("#8a8f99"),
	"brazos": Color("#6aa84f"), "antebrazos": Color("#6aa84f"), "manos": Color("#6aa84f"),
	"muslos": Color("#4b3621"), "espinillas": Color("#5f8f45"), "pies": Color("#2b1d12"),
	"cinturon": Color("#2b1d12"), "accesorio": "colmillos", "pelo": Color("#1e1e1e"),
	"ancho": 1.2, "alto": 1.02, "escala": 1.1,
}

## Enemigos del reino (mazmorras y zonas). Es "static var" y no "const"
## porque algunos aspectos se arman a partir de los de arriba.
static var ENEMIGOS := {
	"goblin": {
		"nombre": "Goblin", "articulo": "el", "vida": 45, "diestro": true, "arma": "espada",
		"personalidad": "normal", "nivel": 1, "oro": [3, 8], "danio": [7, 10], "precision": 0.8,
		"armadura": {},
		"aspecto": _GOBLIN,
	},
	"goblin_lancero": {
		"nombre": "Goblin lancero", "articulo": "el", "vida": 48, "diestro": true, "arma": "lanza",
		"personalidad": "preciso", "nivel": 1, "oro": [4, 9], "danio": [7, 10], "precision": 0.85,
		"armadura": {"torso": [4, 0]},
		"aspecto": _GOBLIN.merged({"torso": Color("#6d4c41"), "hombros": Color("#8d6e63")}, true),
	},
	"chaman_goblin": {
		"nombre": "Chamán goblin", "articulo": "el", "vida": 40, "diestro": false, "arma": "baston",
		"personalidad": "normal", "nivel": 1, "oro": [5, 10], "danio": [7, 10], "precision": 0.85,
		"armadura": {"torso": [0, 10], "cabeza": [0, 10]},
		"aspecto": _GOBLIN.merged({"torso": Color("#5e35b1"), "muslos": Color("#5e35b1"), "escala": 0.72}, true),
	},
	"ladron": {
		"nombre": "Ladrón", "articulo": "el", "vida": 60, "diestro": true, "arma": "espada",
		"personalidad": "astuto", "nivel": 2, "oro": [8, 14], "danio": [11, 14], "precision": 0.9,
		"armadura": {"torso": [6, 2]},
		"aspecto": {
			"piel": Color("#d9a066"), "torso": Color("#455a64"), "hombros": Color("#37474f"),
			"brazos": Color("#455a64"), "antebrazos": Color("#d9a066"), "manos": Color("#d9a066"),
			"muslos": Color("#37474f"), "espinillas": Color("#37474f"), "pies": Color("#212121"),
			"cinturon": Color("#212121"), "accesorio": "capucha", "accesorio_color": Color("#37474f"),
			"panuelo": Color("#263238"), "ancho": 0.92, "alto": 0.98, "escala": 0.98,
		},
	},
	"maton": {
		"nombre": "Matón", "articulo": "el", "vida": 90, "diestro": true, "arma": "maza",
		"personalidad": "bruto", "nivel": 2, "oro": [9, 16], "danio": [13, 17],
		"armadura": {"torso": [10, 2], "cabeza": [6, 0]},
		"aspecto": {
			"piel": Color("#c68642"), "torso": Color("#795548"), "hombros": Color("#5d4037"),
			"brazos": Color("#c68642"), "antebrazos": Color("#c68642"), "manos": Color("#c68642"),
			"muslos": Color("#4e342e"), "espinillas": Color("#4e342e"), "pies": Color("#2e2219"),
			"cinturon": Color("#2e2219"), "accesorio": "casco", "accesorio_color": Color("#8d6e63"),
			"ancho": 1.15, "alto": 1.0, "escala": 1.05,
		},
	},
	"orco_guerrero": {
		"nombre": "Orco guerrero", "articulo": "el", "vida": 115, "diestro": false, "arma": "maza",
		"personalidad": "bruto", "nivel": 3, "oro": [14, 24], "danio": [18, 23],
		"armadura": {"cabeza": [15, 4], "torso": [22, 6], "brazos": [10, 3], "piernas": [10, 3]},
		"aspecto": _ORCO.merged({"accesorio": "casco", "accesorio_color": Color("#78909c"),
			"ancho": 1.25, "escala": 1.12}, true),
	},
	"orco_cazador": {
		"nombre": "Orco cazador", "articulo": "el", "vida": 95, "diestro": true, "arma": "lanza",
		"personalidad": "preciso", "nivel": 3, "oro": [12, 22], "danio": [15, 20],
		"armadura": {"torso": [12, 3]},
		"aspecto": _ORCO.merged({"torso": Color("#5d4037"), "hombros": Color("#6d4c41"), "ancho": 1.15,
			"escala": 1.08}, true),
	},
	"chaman_orco": {
		"nombre": "Chamán orco", "articulo": "el", "vida": 85, "diestro": true, "arma": "baston",
		"personalidad": "normal", "nivel": 3, "oro": [15, 25], "danio": [14, 18],
		"armadura": {"cabeza": [4, 18], "torso": [6, 18]},
		"aspecto": _ORCO.merged({"torso": Color("#4a148c"), "muslos": Color("#4a148c"),
			"pelo": Color("#e0e0e0")}, true),
	},
	"caballero_negro": {
		"nombre": "Caballero negro", "articulo": "el", "vida": 140, "diestro": true, "arma": "espada",
		"personalidad": "astuto", "nivel": 4, "oro": [25, 40], "danio": [19, 24], "precision": 0.88,
		"armadura": {"cabeza": [35, 10], "torso": [45, 12], "brazos": [25, 8], "piernas": [25, 8]},
		"aspecto": {
			"piel": Color("#d7ccc8"), "torso": Color("#263238"), "hombros": Color("#37474f"),
			"brazos": Color("#37474f"), "antebrazos": Color("#263238"), "manos": Color("#212121"),
			"muslos": Color("#263238"), "espinillas": Color("#37474f"), "pies": Color("#212121"),
			"cinturon": Color("#b71c1c"), "accesorio": "casco", "accesorio_color": Color("#37474f"),
			"ancho": 1.1, "alto": 1.04, "escala": 1.08,
		},
	},
	"cultista": {
		"nombre": "Cultista", "articulo": "el", "vida": 90, "diestro": true, "arma": "baston",
		"personalidad": "preciso", "nivel": 4, "oro": [22, 36], "danio": [18, 23],
		"armadura": {"cabeza": [5, 35], "torso": [8, 40], "brazos": [4, 25], "piernas": [4, 25]},
		"aspecto": {
			"piel": Color("#e0c3a0"), "torso": Color("#4a148c"), "hombros": Color("#311b92"),
			"brazos": Color("#4a148c"), "antebrazos": Color("#4a148c"), "manos": Color("#e0c3a0"),
			"muslos": Color("#4a148c"), "espinillas": Color("#311b92"), "pies": Color("#1a0033"),
			"cinturon": Color("#ffd54f"), "accesorio": "capucha", "accesorio_color": Color("#311b92"),
			"panuelo": Color("#1a0033"), "ancho": 0.95, "alto": 1.02, "escala": 1.0,
		},
	},
	"verdugo": {
		"nombre": "Verdugo", "articulo": "el", "vida": 135, "diestro": true, "arma": "maza",
		"personalidad": "bruto", "nivel": 4, "oro": [28, 42], "danio": [20, 26],
		"armadura": {"cabeza": [10, 5], "torso": [30, 8], "brazos": [12, 4], "piernas": [12, 4]},
		"aspecto": {
			"piel": Color("#d9a066"), "torso": Color("#d9a066"), "hombros": Color("#212121"),
			"brazos": Color("#d9a066"), "antebrazos": Color("#212121"), "manos": Color("#d9a066"),
			"muslos": Color("#212121"), "espinillas": Color("#212121"), "pies": Color("#111111"),
			"cinturon": Color("#5d4037"), "accesorio": "capucha", "accesorio_color": Color("#111111"),
			"panuelo": Color("#111111"), "ancho": 1.25, "alto": 1.03, "escala": 1.12,
		},
	},
}

const ASPECTO_REY := {
	"piel": Color("#e9b98f"), "torso": Color("#2f5fb3"), "hombros": Color("#d4a017"),
	"brazos": Color("#2f5fb3"), "antebrazos": Color("#6b4a2f"), "manos": Color("#e9b98f"),
	"muslos": Color("#3b3f58"), "espinillas": Color("#3b3f58"), "pies": Color("#4a2f1e"),
	"cinturon": Color("#d4a017"), "accesorio": "corona", "pelo": Color("#5b3a21"),
	"capa": Color("#9c1f2e"), "ancho": 1.0, "alto": 1.0, "escala": 1.0,
}


## Datos de un rival de la demo o de un enemigo del reino.
static func rival(rival_id: String) -> Dictionary:
	if RIVALES.has(rival_id):
		return RIVALES[rival_id]
	return ENEMIGOS[rival_id]


static func existe(rival_id: String) -> bool:
	return RIVALES.has(rival_id) or ENEMIGOS.has(rival_id)


static func crear_rival(rival_id: String) -> Luchador:
	var datos := rival(rival_id)
	var luchador := Luchador.new(datos["nombre"], datos["vida"], datos["diestro"], datos["arma"])
	luchador.articulo = datos["articulo"]
	luchador.personalidad = datos["personalidad"]
	if datos.has("danio") or datos.has("precision"):
		var base: Dictionary = DatosArmas.arma(datos["arma"])
		var danio: Array = datos.get("danio", [base["danio_min"], base["danio_max"]])
		luchador.arma_objeto = {
			"danio_min": danio[0], "danio_max": danio[1], "precision": datos.get("precision", base["precision"]),
		}
	var armadura: Dictionary = datos.get("armadura", {})
	for grupo in armadura:
		for zona_id in ZONAS_DE_GRUPO[grupo]:
			luchador.armadura[zona_id] = {"fisica": armadura[grupo][0], "magica": armadura[grupo][1]}
	return luchador


## Zonas del cuerpo de cada grupo de armadura de los enemigos.
const ZONAS_DE_GRUPO := {
	"cabeza": ["cabeza"], "torso": ["torso"], "brazos": ["brazo_der", "brazo_izq"],
	"piernas": ["pierna_der", "pierna_izq"],
}


static func crear_rey(diestro: bool, arma_id: String) -> Luchador:
	return Luchador.new("Rey", 100, diestro, arma_id, true)
