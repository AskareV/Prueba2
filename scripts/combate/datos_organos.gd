class_name DatosOrganos
extends RefCounted
## Órganos de la cabeza y el torso (docs/diseno.md, B.2). Un golpe acertado que
## pasa la armadura con fuerza puede dañar un órgano de la parte golpeada. El daño
## dura como una fractura: hasta que esa parte se cura del todo. Los ojos ya son
## partes (ver DatosCuerpo), y los huesos y las arterias de brazos y piernas ya
## los cubren las fracturas y el sangrado. Todos los números son provisionales.
##
## Por órgano:
## - parte: dónde está.
## - prob: probabilidad de dañarlo con un golpe de cada tipo de arma con la fuerza
##   de referencia (ver penetracion). La magia no daña órganos.
## - fractura: cuánto más fácil si la parte ya está fracturada (una costilla rota
##   pincha el pulmón; un cráneo roto deja el cerebro expuesto).
## - sangra: al dañarlo, esa parte sangra grave por fuera o por dentro.
## - infecta: al dañarlo, la herida se infecta (al terminar el combate).
## - efecto: lo que hace, para mostrarlo.
const ORGANOS := {
	"cerebro": {
		"nombre": "cerebro", "articulo": "el", "parte": "craneo", "fractura": 2.0,
		"prob": {"cortante": 0.02, "punzante": 0.06, "contundente": 0.2},
		"efecto": "conciencia −30%: se aturde y se desmaya antes",
	},
	"traquea": {
		"nombre": "tráquea", "articulo": "la", "parte": "cuello",
		"prob": {"cortante": 0.12, "punzante": 0.1, "contundente": 0.08},
		"efecto": "respiración −50%",
	},
	"carotida": {
		"nombre": "carótida", "articulo": "la", "parte": "cuello", "sangra": "externo",
		"prob": {"cortante": 0.15, "punzante": 0.1, "contundente": 0.01},
		"efecto": "sangra grave por fuera",
	},
	"columna": {
		"nombre": "columna", "articulo": "la", "parte": "cuello", "fractura": 2.0,
		"prob": {"cortante": 0.02, "punzante": 0.03, "contundente": 0.04},
		"efecto": "brazos y piernas −40%",
	},
	"pulmon_der": {
		"nombre": "pulmón derecho", "articulo": "el", "parte": "torax_der", "fractura": 2.0,
		"prob": {"cortante": 0.05, "punzante": 0.18, "contundente": 0.05},
		"efecto": "respiración −40%",
	},
	"pulmon_izq": {
		"nombre": "pulmón izquierdo", "articulo": "el", "parte": "torax_izq", "fractura": 2.0,
		"prob": {"cortante": 0.04, "punzante": 0.12, "contundente": 0.04},
		"efecto": "respiración −40%",
	},
	"corazon": {
		"nombre": "corazón", "articulo": "el", "parte": "torax_izq", "sangra": "interno",
		"prob": {"cortante": 0.01, "punzante": 0.06, "contundente": 0.01},
		"efecto": "sangra grave por dentro",
	},
	"higado": {
		"nombre": "hígado", "articulo": "el", "parte": "abdomen", "sangra": "interno",
		"prob": {"cortante": 0.05, "punzante": 0.1, "contundente": 0.08},
		"efecto": "sangra grave por dentro",
	},
	"bazo": {
		"nombre": "bazo", "articulo": "el", "parte": "abdomen", "sangra": "interno",
		"prob": {"cortante": 0.03, "punzante": 0.06, "contundente": 0.06},
		"efecto": "sangra grave por dentro",
	},
	"intestinos": {
		"nombre": "intestinos", "articulo": "los", "parte": "abdomen", "infecta": true,
		"prob": {"cortante": 0.12, "punzante": 0.15, "contundente": 0.02},
		"efecto": "la herida se infecta",
	},
}
const ORDEN := ["cerebro", "traquea", "carotida", "columna", "pulmon_der", "pulmon_izq", "corazon", "higado",
	"bazo", "intestinos"]

## Mientras está dañado, multiplica esa función (ver Luchador).
const CONCIENCIA_CEREBRO := 0.7
const RESPIRACION_TRAQUEA := 0.5
const RESPIRACION_PULMON := 0.6
const MOVIMIENTO_COLUMNA := 0.6
## Penetración: la fuerza del golpe (con la armadura y todo, ver
## MotorCombate.multiplicador_golpe) tiene que pasar FUERZA_MINIMA, más
## UMBRAL_POR_ARMADURA por cada punto de armadura que frena ese golpe, para llegar
## a un órgano; con FUERZA_REFERENCIA de más llega con la probabilidad de la
## tabla, y si es más fuerte, hasta PENETRACION_MAXIMA veces. Así la armadura
## que frena bien ese daño casi no deja llegar a los órganos (la malla, un corte),
## y la que lo frena mal sí (la malla, un mazazo). Un puñetazo nunca llega.
const FUERZA_MINIMA := 6.0
const UMBRAL_POR_ARMADURA := 0.25
const FUERZA_REFERENCIA := 16.0
const PENETRACION_MAXIMA := 1.5


static func organo(organo_id: String) -> Dictionary:
	return ORGANOS[organo_id]


## Órganos de esa parte, en el orden de ORDEN ([] si no tiene).
static func organos_de(parte_id: String) -> Array[String]:
	var lista: Array[String] = []
	for organo_id in ORDEN:
		if ORGANOS[organo_id]["parte"] == parte_id:
			lista.append(organo_id)
	return lista


static func parte_de(organo_id: String) -> String:
	return ORGANOS[organo_id]["parte"]


## "el corazón"
static func con_articulo(organo_id: String) -> String:
	return "%s %s" % [ORGANOS[organo_id]["articulo"], ORGANOS[organo_id]["nombre"]]


## "Tráquea dañada", "Intestinos dañados": el nombre con mayúscula y concordado.
static func danado(organo_id: String) -> String:
	var datos: Dictionary = ORGANOS[organo_id]
	var nombre: String = datos["nombre"]
	var final: String = {"el": "o", "la": "a", "los": "os", "las": "as"}[datos["articulo"]]
	return "%s%s dañad%s" % [nombre[0].to_upper(), nombre.substr(1), final]


## De 0 a PENETRACION_MAXIMA: cuánto del golpe llega adentro, con esa armadura
## frenándolo (la que rinde contra ese tipo de arma, ver Luchador.proteccion).
static func penetracion(fuerza: float, armadura := 0.0) -> float:
	var umbral := FUERZA_MINIMA + UMBRAL_POR_ARMADURA * maxf(armadura, 0.0)
	return clampf((fuerza - umbral) / (FUERZA_REFERENCIA - FUERZA_MINIMA), 0.0, PENETRACION_MAXIMA)


## Probabilidad de dañar ese órgano con un golpe acertado de ese tipo de arma,
## esa fuerza y esa armadura ("fracturada": si su parte ya está fracturada).
static func probabilidad(organo_id: String, tipo_arma: String, fuerza: float, fracturada := false,
		armadura := 0.0) -> float:
	var datos: Dictionary = ORGANOS[organo_id]
	var prob := float(datos["prob"].get(tipo_arma, 0.0)) * penetracion(fuerza, armadura)
	if fracturada:
		prob *= float(datos.get("fractura", 1.0))
	return minf(prob, 1.0)
