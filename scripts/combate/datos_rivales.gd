class_name DatosRivales
extends RefCounted
## Rivales de la demo de combate y aspecto del rey.
##
## Aspecto: colores por grupo de partes y accesorios. "ancho" y "alto"
## deforman el cuerpo; "escala" cambia el tamaño en pantalla.

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

const ASPECTO_REY := {
	"piel": Color("#e9b98f"), "torso": Color("#2f5fb3"), "hombros": Color("#d4a017"),
	"brazos": Color("#2f5fb3"), "antebrazos": Color("#6b4a2f"), "manos": Color("#e9b98f"),
	"muslos": Color("#3b3f58"), "espinillas": Color("#3b3f58"), "pies": Color("#4a2f1e"),
	"cinturon": Color("#d4a017"), "accesorio": "corona", "pelo": Color("#5b3a21"),
	"capa": Color("#9c1f2e"), "ancho": 1.0, "alto": 1.0, "escala": 1.0,
}


static func rival(rival_id: String) -> Dictionary:
	return RIVALES[rival_id]


static func crear_rival(rival_id: String) -> Luchador:
	var datos: Dictionary = RIVALES[rival_id]
	var luchador := Luchador.new(datos["nombre"], datos["vida"], datos["diestro"], datos["arma"])
	luchador.articulo = datos["articulo"]
	luchador.personalidad = datos["personalidad"]
	return luchador


static func crear_rey(diestro: bool, arma_id: String) -> Luchador:
	return Luchador.new("Rey", 100, diestro, arma_id, true)
