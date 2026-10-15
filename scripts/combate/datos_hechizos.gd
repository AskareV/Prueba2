class_name DatosHechizos
extends RefCounted
## Maná y hechizos del rey (provisionales). El bastón gasta maná en cada golpe;
## sin maná pega como un palo. Los hechizos se pagan al lanzarlos y no dependen
## del arma ni del brazo. Arcano los hace más fuertes; Mago da más maná.

## Maná que gasta cada golpe con el bastón.
const COSTE_BASTON := 3.0
## Sin maná, el bastón pega con esta parte de su daño y como arma contundente.
const BASTON_SIN_MANA := 0.5
## Turno que pierde quien recibe "Ralentizar" o un empujón (100 = un turno entero).
const RETRASO_RALENTIZAR := 50.0
const RETRASO_EMPUJON := 35.0

## "objetivo": "parte" (se apunta como un ataque), "propio" o "rival".
## "arma": datos con los que se resuelve como un ataque (ver MotorCombate).
const HECHIZOS := {
	"llamarada": {
		"nombre": "Llamarada", "coste": 6.0, "objetivo": "parte",
		"descripcion": "Fuego mágico contra la parte que elijas. No necesita arma.",
		"arma": {"nombre": "Llamarada", "tipo": "arcano", "danio_min": 10, "danio_max": 13, "precision": 0.9},
	},
	"curacion": {
		"nombre": "Curación", "coste": 8.0, "objetivo": "propio", "cura": 15,
		"descripcion": "Recuperas vida.",
	},
	"ralentizar": {
		"nombre": "Ralentizar", "coste": 5.0, "objetivo": "rival",
		"descripcion": "El rival pierde medio turno en la barra.",
	},
}
const ORDEN := ["llamarada", "curacion", "ralentizar"]


static func hechizo(hechizo_id: String) -> Dictionary:
	return HECHIZOS[hechizo_id]


## Datos con que se resuelve un hechizo que se apunta como un ataque.
static func como_arma(hechizo_id: String) -> Dictionary:
	var datos: Dictionary = HECHIZOS[hechizo_id]["arma"].duplicate()
	datos["hechizo"] = hechizo_id
	return datos


static func puede_lanzar(luchador: Luchador, hechizo_id: String) -> bool:
	return luchador.usa_mana and luchador.mana >= float(HECHIZOS[hechizo_id]["coste"])


## Vida que recupera "Curación" según su Arcano.
static func cura(luchador: Luchador) -> int:
	return int(HECHIZOS["curacion"]["cura"]) + roundi(DatosEstadisticas.CURA_POR_ARCANO * luchador.puntos("arcano"))


## Datos del bastón cuando no alcanza el maná: golpe contundente más débil.
static func baston_sin_mana(datos: Dictionary) -> Dictionary:
	var debil := datos.duplicate()
	debil["nombre"] = "%s (sin maná)" % datos["nombre"]
	debil["tipo"] = "contundente"
	debil["danio_min"] = maxi(1, roundi(int(datos["danio_min"]) * BASTON_SIN_MANA))
	debil["danio_max"] = maxi(int(debil["danio_min"]), roundi(int(datos["danio_max"]) * BASTON_SIN_MANA))
	return debil
