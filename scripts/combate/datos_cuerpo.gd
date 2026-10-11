class_name DatosCuerpo
extends RefCounted
## Cuerpo humano usado en combate (docs/diseno.md, puntos A y B.2).
## 21 partes agrupadas en 6 zonas. "Derecho" e "izquierdo" son siempre del
## personaje, nunca de la pantalla.

## Zonas en el orden acordado (1 a 6). "partes" está en el orden de los botones:
## el rival mira a la cámara, así que su lado derecho queda a la izquierda.
const ZONAS := {
	"cabeza": {"nombre": "Cabeza", "partes": ["craneo", "ojo_der", "ojo_izq", "cuello"]},
	"torso": {"nombre": "Torso", "partes": ["torax_der", "torax_izq", "abdomen"]},
	"brazo_der": {
		"nombre": "Brazo derecho",
		"partes": ["hombro_der", "brazo_der", "antebrazo_der", "mano_der"],
	},
	"brazo_izq": {
		"nombre": "Brazo izquierdo",
		"partes": ["hombro_izq", "brazo_izq", "antebrazo_izq", "mano_izq"],
	},
	"pierna_der": {"nombre": "Pierna derecha", "partes": ["muslo_der", "espinilla_der", "pie_der"]},
	"pierna_izq": {"nombre": "Pierna izquierda", "partes": ["muslo_izq", "espinilla_izq", "pie_izq"]},
}

## Datos de cada parte:
## - corto: texto de los botones (la zona ya indica el lado del brazo o pierna).
## - articulo / texto: para narrar ("el" + "antebrazo derecho").
## - tamano: facilidad para acertarle (1 = muy fácil). Provisional.
## - danio: multiplicador de daño a la vida. Provisional.
## - fragilidad: cuánta integridad pierde por punto de daño. Provisional.
## - hueso: si un golpe contundente puede fracturarla.
const PARTES := {
	"craneo": {
		"nombre": "Cráneo", "corto": "Cráneo", "articulo": "el", "texto": "cráneo",
		"zona": "cabeza", "tamano": 0.72, "danio": 1.5, "fragilidad": 1.25, "hueso": true,
		"organos": "cerebro",
	},
	"ojo_der": {
		"nombre": "Ojo derecho", "corto": "Ojo der.", "articulo": "el", "texto": "ojo derecho",
		"zona": "cabeza", "tamano": 0.3, "danio": 1.2, "fragilidad": 6.0, "hueso": false,
		"organos": "ojo",
	},
	"ojo_izq": {
		"nombre": "Ojo izquierdo", "corto": "Ojo izq.", "articulo": "el", "texto": "ojo izquierdo",
		"zona": "cabeza", "tamano": 0.3, "danio": 1.2, "fragilidad": 6.0, "hueso": false,
		"organos": "ojo",
	},
	"cuello": {
		"nombre": "Cuello", "corto": "Cuello", "articulo": "el", "texto": "cuello",
		"zona": "cabeza", "tamano": 0.55, "danio": 1.6, "fragilidad": 2.4, "hueso": true,
		"organos": "tráquea, arterias carótidas, columna",
	},
	"torax_der": {
		"nombre": "Tórax derecho", "corto": "Tórax der.", "articulo": "el", "texto": "tórax derecho",
		"zona": "torso", "tamano": 0.95, "danio": 1.2, "fragilidad": 1.1, "hueso": true,
		"organos": "pulmón derecho, costillas",
	},
	"torax_izq": {
		"nombre": "Tórax izquierdo", "corto": "Tórax izq.", "articulo": "el", "texto": "tórax izquierdo",
		"zona": "torso", "tamano": 0.95, "danio": 1.3, "fragilidad": 1.1, "hueso": true,
		"organos": "corazón, pulmón izquierdo, costillas",
	},
	"abdomen": {
		"nombre": "Abdomen", "corto": "Abdomen", "articulo": "el", "texto": "abdomen",
		"zona": "torso", "tamano": 0.9, "danio": 1.15, "fragilidad": 1.1, "hueso": false,
		"organos": "hígado, bazo, estómago, intestinos",
	},
	"hombro_der": {
		"nombre": "Hombro y trapecio derecho", "corto": "Hombro y trapecio", "articulo": "el",
		"texto": "hombro derecho", "zona": "brazo_der", "tamano": 0.8, "danio": 0.9,
		"fragilidad": 1.5, "hueso": true, "organos": "clavícula, articulación del hombro",
	},
	"brazo_der": {
		"nombre": "Brazo derecho", "corto": "Brazo", "articulo": "el", "texto": "brazo derecho",
		"zona": "brazo_der", "tamano": 0.78, "danio": 0.8, "fragilidad": 1.8, "hueso": true,
		"organos": "húmero, arteria braquial",
	},
	"antebrazo_der": {
		"nombre": "Antebrazo derecho", "corto": "Antebrazo", "articulo": "el",
		"texto": "antebrazo derecho", "zona": "brazo_der", "tamano": 0.72, "danio": 0.7,
		"fragilidad": 2.2, "hueso": true, "organos": "radio, cúbito, tendones",
	},
	"mano_der": {
		"nombre": "Mano derecha", "corto": "Mano", "articulo": "la", "texto": "mano derecha",
		"zona": "brazo_der", "tamano": 0.55, "danio": 0.6, "fragilidad": 3.0, "hueso": true,
		"organos": "huesos y tendones de la mano",
	},
	"hombro_izq": {
		"nombre": "Hombro y trapecio izquierdo", "corto": "Hombro y trapecio", "articulo": "el",
		"texto": "hombro izquierdo", "zona": "brazo_izq", "tamano": 0.8, "danio": 0.9,
		"fragilidad": 1.5, "hueso": true, "organos": "clavícula, articulación del hombro",
	},
	"brazo_izq": {
		"nombre": "Brazo izquierdo", "corto": "Brazo", "articulo": "el", "texto": "brazo izquierdo",
		"zona": "brazo_izq", "tamano": 0.78, "danio": 0.8, "fragilidad": 1.8, "hueso": true,
		"organos": "húmero, arteria braquial",
	},
	"antebrazo_izq": {
		"nombre": "Antebrazo izquierdo", "corto": "Antebrazo", "articulo": "el",
		"texto": "antebrazo izquierdo", "zona": "brazo_izq", "tamano": 0.72, "danio": 0.7,
		"fragilidad": 2.2, "hueso": true, "organos": "radio, cúbito, tendones",
	},
	"mano_izq": {
		"nombre": "Mano izquierda", "corto": "Mano", "articulo": "la", "texto": "mano izquierda",
		"zona": "brazo_izq", "tamano": 0.55, "danio": 0.6, "fragilidad": 3.0, "hueso": true,
		"organos": "huesos y tendones de la mano",
	},
	"muslo_der": {
		"nombre": "Muslo derecho", "corto": "Muslo", "articulo": "el", "texto": "muslo derecho",
		"zona": "pierna_der", "tamano": 0.85, "danio": 0.9, "fragilidad": 1.5, "hueso": true,
		"organos": "fémur, arteria femoral",
	},
	"espinilla_der": {
		"nombre": "Espinilla derecha", "corto": "Espinilla", "articulo": "la",
		"texto": "espinilla derecha", "zona": "pierna_der", "tamano": 0.75, "danio": 0.75,
		"fragilidad": 2.0, "hueso": true, "organos": "tibia, peroné",
	},
	"pie_der": {
		"nombre": "Pie derecho", "corto": "Pie", "articulo": "el", "texto": "pie derecho",
		"zona": "pierna_der", "tamano": 0.6, "danio": 0.6, "fragilidad": 2.5, "hueso": true,
		"organos": "huesos del pie",
	},
	"muslo_izq": {
		"nombre": "Muslo izquierdo", "corto": "Muslo", "articulo": "el", "texto": "muslo izquierdo",
		"zona": "pierna_izq", "tamano": 0.85, "danio": 0.9, "fragilidad": 1.5, "hueso": true,
		"organos": "fémur, arteria femoral",
	},
	"espinilla_izq": {
		"nombre": "Espinilla izquierda", "corto": "Espinilla", "articulo": "la",
		"texto": "espinilla izquierda", "zona": "pierna_izq", "tamano": 0.75, "danio": 0.75,
		"fragilidad": 2.0, "hueso": true, "organos": "tibia, peroné",
	},
	"pie_izq": {
		"nombre": "Pie izquierdo", "corto": "Pie", "articulo": "el", "texto": "pie izquierdo",
		"zona": "pierna_izq", "tamano": 0.6, "danio": 0.6, "fragilidad": 2.5, "hueso": true,
		"organos": "huesos del pie",
	},
}

## Funciones de supervivencia (B.2). La circulación la cubre el sangrado (B.1).
const FUNCIONES := ["conciencia", "vision", "respiracion", "piernas", "brazo_der", "brazo_izq"]

const NOMBRES_FUNCION := {
	"conciencia": "Conciencia",
	"vision": "Visión",
	"respiracion": "Respiración",
	"piernas": "Mov. piernas",
	"brazo_der": "Brazo der.",
	"brazo_izq": "Brazo izq.",
}


static func parte(parte_id: String) -> Dictionary:
	return PARTES[parte_id]


static func zona(zona_id: String) -> Dictionary:
	return ZONAS[zona_id]


static func zona_de(parte_id: String) -> String:
	return PARTES[parte_id]["zona"]


static func partes_de(zona_id: String) -> Array:
	return ZONAS[zona_id]["partes"]


## Nombre sin el lado: "mano_der" -> "mano". Sirve para tablas por tipo de parte.
static func base_de(parte_id: String) -> String:
	if parte_id.ends_with("_der") or parte_id.ends_with("_izq"):
		return parte_id.substr(0, parte_id.length() - 4)
	return parte_id


static func lado_opuesto(lado: String) -> String:
	return "izq" if lado == "der" else "der"


## "la mano derecha"
static func con_articulo(parte_id: String) -> String:
	var p: Dictionary = PARTES[parte_id]
	return "%s %s" % [p["articulo"], p["texto"]]


## "al cuello", "a la mano derecha"
static func a_parte(parte_id: String) -> String:
	var p: Dictionary = PARTES[parte_id]
	if p["articulo"] == "el":
		return "al " + p["texto"]
	return "a la " + p["texto"]


## "tu mano derecha", "su cuello"
static func posesivo(parte_id: String, quien: String) -> String:
	return "%s %s" % [quien, PARTES[parte_id]["texto"]]
