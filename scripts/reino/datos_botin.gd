class_name DatosBotin
extends RefCounted
## Botín del rey: armas y piezas de armadura con calidad normal, rara, épica o
## legendaria, y pociones de curación. Todos los números son provisionales.

const CALIDADES := ["normal", "raro", "epico", "legendario"]

## Por calidad: multiplicadores del daño del arma y de la armadura, precisión
## extra del arma y precio de venta base.
const DATOS_CALIDAD := {
	"normal": {
		"nombre": "Normal", "color": Color("#c8ccd8"), "mult_arma": 1.0, "mult_armadura": 1.0,
		"precision": 0.0, "precio": 8,
	},
	"raro": {
		"nombre": "Raro", "color": Color("#42a5f5"), "mult_arma": 1.15, "mult_armadura": 1.3,
		"precision": 0.02, "precio": 30,
	},
	"epico": {
		"nombre": "Épico", "color": Color("#ba68c8"), "mult_arma": 1.35, "mult_armadura": 1.7,
		"precision": 0.04, "precio": 120,
	},
	"legendario": {
		"nombre": "Legendario", "color": Color("#ffa726"), "mult_arma": 1.6, "mult_armadura": 2.2,
		"precision": 0.06, "precio": 500,
	},
}

## Probabilidad (%) de cada calidad, en el orden de CALIDADES, según el nivel del
## lugar: 1 fácil, 2 fácil/medio, 3 medio, 4 difícil.
const PROB_CALIDAD := {
	1: [75.0, 20.0, 4.5, 0.5],
	2: [65.0, 26.0, 8.0, 1.0],
	3: [55.0, 30.0, 12.0, 3.0],
	4: [40.0, 35.0, 19.0, 6.0],
}

## Material según el nivel del lugar donde se encontró.
const MATERIALES := ["de bronce", "de hierro", "de acero", "de obsidiana"]

## Ranuras de equipo. "zonas": zonas del cuerpo que protege esa pieza.
const RANURAS := {
	"arma": {"nombre": "Arma", "zonas": []},
	"casco": {"nombre": "Casco", "zonas": ["cabeza"]},
	"peto": {"nombre": "Peto", "zonas": ["torso"]},
	"brazales": {"nombre": "Brazales", "zonas": ["brazo_der", "brazo_izq"]},
	"grebas": {"nombre": "Grebas", "zonas": ["pierna_der", "pierna_izq"]},
}
const ORDEN_RANURAS := ["arma", "casco", "peto", "brazales", "grebas"]
const PIEZAS := ["casco", "peto", "brazales", "grebas"]

## Armadura base de cada pieza según el nivel (1 a 4), antes de la calidad.
const ARMADURA_BASE := {
	"casco": [6, 12, 20, 30],
	"peto": [10, 18, 28, 40],
	"brazales": [5, 10, 16, 24],
	"grebas": [6, 12, 18, 26],
}
## Dos estilos de armadura: de metal (mucha armadura, poca resistencia mágica)
## o con runas (al revés). "peso": probabilidad (%) de que salga.
const ESTILOS := {
	"metal": {"fisica": 1.0, "magica": 0.25, "peso": 75.0},
	"runas": {"fisica": 0.55, "magica": 1.0, "peso": 25.0},
}

## Armas que pueden salir como botín (ver DatosArmas).
const ARMAS_BOTIN := ["espada", "maza", "lanza", "baston"]
## Probabilidad de que el botín sea un arma; si no, una pieza de armadura.
const PROB_ARMA := 0.35
## Cuánto más fuerte es un arma por cada nivel del lugar.
const MEJORA_POR_NIVEL := 0.25

## Poción de curación: cura vida y un poco cada parte herida. Se usa en combate
## (gasta el turno) o entre combates.
const POCION_VIDA := 40
const POCION_PARTES := 25.0
const PRECIO_POCION := 10
## Objetos que se gastan al usarlos y se apilan en el inventario: la poción y lo
## que trata el sangrado y las infecciones (ver DatosHeridas). La "ranura" del
## objeto es su id. "precio": lo que pagan al venderlo. Provisionales.
const CONSUMIBLES := {
	"pocion": {
		"nombre": "Poción de curación", "uno": "una poción de curación", "precio": PRECIO_POCION,
		"color": Color("#ec407a"), "accion": "Tomar", "resumen": "cura 40 de vida",
		"descripcion": "Cura 40 de vida y 25 de cada parte herida.",
	},
	"venda": {
		"nombre": "Venda", "uno": "una venda", "precio": 3, "color": Color("#b0bec5"), "accion": "Usar",
		"resumen": "para un sangrado",
		"descripcion": "Para el sangrado por fuera que más sangra (si es grave, solo lo baja a moderado) y limpia la herida: baja su riesgo de infección.",
	},
	"torniquete": {
		"nombre": "Torniquete", "uno": "un torniquete", "precio": 6, "color": Color("#a1887f"), "accion": "Usar",
		"resumen": "brazos y piernas",
		"descripcion": "Para del todo el sangrado por fuera que más sangra en un brazo o una pierna.",
	},
	"medicina": {
		"nombre": "Medicina", "uno": "una medicina", "precio": 12, "color": Color("#81c784"), "accion": "Tomar",
		"resumen": "sangrado interno",
		"descripcion": "Para el sangrado por dentro y cura las infecciones leves.",
	},
}
const ORDEN_CONSUMIBLES := ["pocion", "venda", "torniquete", "medicina"]
## Parte del botín de cofres, enemigos y zonas que sale como uno de estos objetos,
## y cuánto sale cada uno (en %: suman PROB_CONSUMIBLE).
const PROB_CONSUMIBLE := 0.35
const PESO_CONSUMIBLE := {"pocion": 20.0, "venda": 8.0, "torniquete": 3.5, "medicina": 3.5}


static func crear_consumible(tipo: String, cantidad := 1) -> Dictionary:
	var datos: Dictionary = CONSUMIBLES[tipo]
	return {"ranura": tipo, "nombre": datos["nombre"], "calidad": "normal", "nivel": 1,
		"precio": datos["precio"], "cantidad": cantidad}


static func crear_pocion(cantidad := 1) -> Dictionary:
	return crear_consumible("pocion", cantidad)


static func es_consumible(objeto: Dictionary) -> bool:
	return CONSUMIBLES.has(objeto.get("ranura", ""))


static func es_pocion(objeto: Dictionary) -> bool:
	return objeto.get("ranura", "") == "pocion"


## Botín de cofres, enemigos y zonas: a veces una poción, una venda, un torniquete
## o una medicina y si no, un arma o una pieza de armadura (ver generar).
static func generar_botin(nivel: int, rng: RandomNumberGenerator, bonus_calidad := 1.0) -> Dictionary:
	if rng.randf() < PROB_CONSUMIBLE:
		var total := 0.0
		for candidato in ORDEN_CONSUMIBLES:
			total += PESO_CONSUMIBLE[candidato]
		var tirada := rng.randf() * total
		var tipo: String = ORDEN_CONSUMIBLES[-1]
		for candidato in ORDEN_CONSUMIBLES:
			tirada -= PESO_CONSUMIBLE[candidato]
			if tirada < 0.0:
				tipo = candidato
				break
		var objeto := crear_consumible(tipo)
		objeto["nivel"] = clampi(nivel, 1, 4)
		return objeto
	return generar(nivel, rng, "", "", bonus_calidad)


## "Espada de bronce (raro)" o "una poción de curación", para contar lo que se encontró.
static func texto_hallazgo(objeto: Dictionary) -> String:
	if es_consumible(objeto):
		return CONSUMIBLES[objeto["ranura"]]["uno"]
	return "%s (%s)" % [objeto["nombre"], nombre_calidad(objeto["calidad"]).to_lower()]


## Probabilidad (%) de cada calidad según el nivel del lugar. "bonus" (Buen ojo)
## multiplica las calidades raras o mejores; lo normal queda con el resto.
static func probabilidades(nivel: int, bonus := 1.0) -> Array[float]:
	var tabla: Array = PROB_CALIDAD[clampi(nivel, 1, 4)]
	var resultado: Array[float] = [0.0]
	var mejores := 0.0
	for i in range(1, CALIDADES.size()):
		var prob: float = float(tabla[i]) * bonus
		resultado.append(prob)
		mejores += prob
	# Si el bonus fuera enorme, se reparte todo entre las mejores.
	if mejores > 100.0:
		for i in range(1, resultado.size()):
			resultado[i] *= 100.0 / mejores
		mejores = 100.0
	resultado[0] = 100.0 - mejores
	return resultado


## Sortea la calidad según el nivel del lugar (y el bonus de Buen ojo).
static func sortear_calidad(nivel: int, rng: RandomNumberGenerator, bonus := 1.0) -> String:
	var tabla := probabilidades(nivel, bonus)
	var tirada := rng.randf() * 100.0
	for i in CALIDADES.size():
		tirada -= tabla[i]
		if tirada < 0.0:
			return CALIDADES[i]
	return CALIDADES[-1]


## Crea un objeto de botín. "ranura" vacía = arma o pieza al azar; "calidad"
## vacía = se sortea (con "bonus_calidad", ver probabilidades). No tiene "id":
## lo pone el inventario al guardarlo.
static func generar(nivel: int, rng: RandomNumberGenerator, ranura := "", calidad := "", bonus_calidad := 1.0) -> Dictionary:
	nivel = clampi(nivel, 1, 4)
	if calidad == "":
		calidad = sortear_calidad(nivel, rng, bonus_calidad)
	if ranura == "":
		ranura = "arma" if rng.randf() < PROB_ARMA else PIEZAS[rng.randi() % PIEZAS.size()]
	var objeto := {"ranura": ranura, "calidad": calidad, "nivel": nivel}
	if ranura == "arma":
		_completar_arma(objeto, ARMAS_BOTIN[rng.randi() % ARMAS_BOTIN.size()])
	else:
		var estilo := "runas" if rng.randf() * 100.0 < ESTILOS["runas"]["peso"] else "metal"
		_completar_pieza(objeto, estilo)
	objeto["precio"] = precio_venta(objeto)
	return objeto


## Arma de botín de esa base ("espada", "maza"...), nivel y calidad.
static func crear_arma(base: String, nivel: int, calidad: String) -> Dictionary:
	var objeto := {"ranura": "arma", "calidad": calidad, "nivel": clampi(nivel, 1, 4)}
	_completar_arma(objeto, base)
	objeto["precio"] = precio_venta(objeto)
	return objeto


## El mismo objeto con otra calidad: conserva su base, estilo, nivel e id
## (para la herrería).
static func con_calidad(objeto: Dictionary, calidad: String) -> Dictionary:
	var nuevo := objeto.duplicate()
	nuevo["calidad"] = calidad
	if nuevo["ranura"] == "arma":
		_completar_arma(nuevo, nuevo["base"])
	else:
		_completar_pieza(nuevo, nuevo["estilo"])
	nuevo["precio"] = precio_venta(nuevo)
	return nuevo


static func _completar_arma(objeto: Dictionary, base: String) -> void:
	var arma: Dictionary = DatosArmas.arma(base)
	var calidad: Dictionary = DATOS_CALIDAD[objeto["calidad"]]
	var nivel: int = objeto["nivel"]
	var mult: float = (1.0 + MEJORA_POR_NIVEL * (nivel - 1)) * calidad["mult_arma"]
	objeto["base"] = base
	objeto["nombre"] = "%s %s" % [arma["nombre"], MATERIALES[nivel - 1]]
	objeto["danio_min"] = maxi(1, roundi(arma["danio_min"] * mult))
	objeto["danio_max"] = maxi(objeto["danio_min"], roundi(arma["danio_max"] * mult))
	objeto["precision"] = minf(float(arma["precision"]) + float(calidad["precision"]), 0.99)


static func _completar_pieza(objeto: Dictionary, estilo: String) -> void:
	var ranura: String = objeto["ranura"]
	var nivel: int = objeto["nivel"]
	var valor: float = ARMADURA_BASE[ranura][nivel - 1] * float(DATOS_CALIDAD[objeto["calidad"]]["mult_armadura"])
	objeto["estilo"] = estilo
	objeto["nombre"] = "%s %s" % [RANURAS[ranura]["nombre"], MATERIALES[nivel - 1]]
	if estilo == "runas":
		objeto["nombre"] += " con runas"
	objeto["armadura"] = roundi(valor * ESTILOS[estilo]["fisica"])
	objeto["resistencia_magica"] = roundi(valor * ESTILOS[estilo]["magica"])


## Oro que da venderlo: depende sobre todo de la calidad, y algo del nivel.
static func precio_venta(objeto: Dictionary) -> int:
	var base: int = DATOS_CALIDAD[objeto["calidad"]]["precio"]
	return roundi(base * (1.0 + 0.5 * (int(objeto["nivel"]) - 1)))


static func nombre_calidad(calidad: String) -> String:
	return DATOS_CALIDAD[calidad]["nombre"]


static func color_calidad(calidad: String) -> Color:
	return DATOS_CALIDAD[calidad]["color"]


## Reducción de daño en porcentaje que da ese valor de armadura (ej. 100 -> 50).
static func porcentaje_reduccion(valor: float) -> int:
	return roundi((1.0 - MotorCombate.multiplicador_armadura(valor)) * 100.0)


## Líneas de texto con los datos del objeto, para mostrarlo. "precio": lo que
## pagan por él (con Negociación); -1 = su precio base.
static func describir(objeto: Dictionary, precio := -1) -> PackedStringArray:
	var lineas: PackedStringArray = []
	if es_consumible(objeto):
		lineas.append("Tienes %d" % int(objeto.get("cantidad", 1)))
		lineas.append(CONSUMIBLES[objeto["ranura"]]["descripcion"])
		lineas.append("Se usa en combate (gasta el turno) o entre combates.")
		var de_a := "de a una" if String(CONSUMIBLES[objeto["ranura"]]["uno"]).begins_with("una ") else "de a uno"
		lineas.append("Se vende por %d de oro (%s)" % [objeto["precio"] if precio < 0 else precio, de_a])
		return lineas
	lineas.append("%s · nivel %d" % [nombre_calidad(objeto["calidad"]), objeto["nivel"]])
	if objeto["ranura"] == "arma":
		var tipo: Dictionary = DatosArmas.tipo_de(objeto["base"])
		lineas.append("Daño %d–%d · %s" % [objeto["danio_min"], objeto["danio_max"], String(tipo["nombre"]).to_lower()])
		lineas.append("Precisión %d%%" % roundi(float(objeto["precision"]) * 100.0))
		if DatosArmas.es_magico(DatosArmas.arma(objeto["base"])["tipo"]):
			lineas.append("Daño mágico")
	else:
		var zonas: Array = RANURAS[objeto["ranura"]]["zonas"]
		var nombres: PackedStringArray = []
		for zona_id in zonas:
			nombres.append(String(DatosCuerpo.ZONAS[zona_id]["nombre"]).to_lower())
		lineas.append("Protege: %s" % ", ".join(nombres))
		lineas.append("Armadura %d (−%d%% daño físico)" % [objeto["armadura"], porcentaje_reduccion(objeto["armadura"])])
		lineas.append("Resist. mágica %d (−%d%% daño mágico)" % [
			objeto["resistencia_magica"], porcentaje_reduccion(objeto["resistencia_magica"])])
	lineas.append("Se vende por %d de oro" % (objeto["precio"] if precio < 0 else precio))
	return lineas
