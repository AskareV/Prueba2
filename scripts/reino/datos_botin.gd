class_name DatosBotin
extends RefCounted
## Botín del rey: armas, piezas de armadura y anillos con calidad normal, rara,
## épica o legendaria, pociones y lo que trata las heridas, y los materiales de
## la ciudad. Todos los números son provisionales.

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

## Ranuras de equipo. "zonas": zonas del cuerpo que protege esa pieza;
## "genero" y "plural": para el nombre ("Grebas acolchadas"). El rey lleva dos
## anillos, uno en cada mano: un anillo ("ranura" "anillo") va en cualquiera de
## las dos (ver RANURAS_ANILLO).
const RANURAS := {
	"arma": {"nombre": "Arma", "zonas": []},
	"casco": {"nombre": "Casco", "zonas": ["cabeza"], "genero": "m", "plural": false},
	"peto": {"nombre": "Peto", "zonas": ["torso"], "genero": "m", "plural": false},
	"brazales": {"nombre": "Brazales", "zonas": ["brazo_der", "brazo_izq"], "genero": "m", "plural": true},
	"grebas": {"nombre": "Grebas", "zonas": ["pierna_der", "pierna_izq"], "genero": "f", "plural": true},
	"anillo_der": {"nombre": "Anillo derecho", "zonas": []},
	"anillo_izq": {"nombre": "Anillo izquierdo", "zonas": []},
}
const ORDEN_RANURAS := ["arma", "casco", "peto", "brazales", "grebas", "anillo_der", "anillo_izq"]
const PIEZAS := ["casco", "peto", "brazales", "grebas"]
const RANURAS_ANILLO := ["anillo_der", "anillo_izq"]

## Armadura base de cada pieza según el nivel (1 a 4), antes de la calidad.
const ARMADURA_BASE := {
	"casco": [6, 12, 20, 30],
	"peto": [10, 18, 28, 40],
	"brazales": [5, 10, 16, 24],
	"grebas": [6, 12, 18, 26],
}
## El tipo de cada pieza (acolchada, cuero, malla, placas o runas) sale según el
## nivel del lugar: ver DatosArmaduras.

## Armas que pueden salir como botín (ver DatosArmas).
const ARMAS_BOTIN := ["espada", "maza", "lanza", "baston"]
## Del botín que se equipa: probabilidad de que sea un anillo y, si no, de que
## sea un arma (si tampoco, es una pieza de armadura).
const PROB_ANILLO := 0.15
const PROB_ARMA := 0.35

## Anillos: cada uno da algo que no dan las características, más cuanto mejor es
## su calidad. "efecto": cuánto, por calidad (normal, raro, épico, legendario).
## Vida y maná: puntos que suma a la vida o al maná máximo. Crítico:
## probabilidad que suma a la de Golpe de suerte. Sangrado y estrés: parte que
## quita de la sangre que pierde o del estrés que suma (con dos iguales, el
## segundo quita su parte de lo que queda). Provisionales.
const ANILLOS := {
	"vida": {
		"nombre": "Anillo de vida", "efecto": [10, 20, 35, 50], "corto": "Vida +%d",
		"descripcion": "Más vida máxima (se suma a la de Vitalidad).",
	},
	"mana": {
		"nombre": "Anillo de maná", "efecto": [10, 20, 35, 50], "corto": "Maná +%d",
		"descripcion": "Más maná máximo (se suma al de Mago).",
	},
	"critico": {
		"nombre": "Anillo de críticos", "efecto": [0.03, 0.06, 0.1, 0.15], "corto": "Crítico +%d%%",
		"descripcion": "Más probabilidad de golpe crítico (se suma a la de Golpe de suerte).",
	},
	"sangrado": {
		"nombre": "Anillo coagulante", "efecto": [0.1, 0.2, 0.3, 0.5], "corto": "Sangrado −%d%%",
		"descripcion": "Pierdes menos sangre por tus heridas, en combate y al caminar.",
	},
	"estres": {
		"nombre": "Anillo de calma", "efecto": [0.05, 0.1, 0.15, 0.25], "corto": "Estrés −%d%%",
		"descripcion": "Sumas menos estrés: al caminar, en combates, trampas y trabajos.",
	},
}
const ORDEN_ANILLOS := ["vida", "mana", "critico", "sangrado", "estres"]
## Los que se miden en porcentaje (para mostrarlos).
const ANILLOS_PORCENTAJE := ["critico", "sangrado", "estres"]
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

## Materiales de la ciudad (ver DatosCiudad.MATERIALES): probabilidad (%) de
## cada uno, en el orden de DatosCiudad.ORDEN_MATERIALES (madera, piedra,
## hierro), según el nivel del lugar: en los lugares difíciles sale más hierro.
const PROB_MATERIAL := {
	1: [50.0, 35.0, 15.0],
	2: [40.0, 35.0, 25.0],
	3: [35.0, 35.0, 30.0],
	4: [30.0, 30.0, 40.0],
}
## Cuántos trae, por nivel del lugar: un cofre siempre trae de un material; un
## enemigo vencido, a veces (PROB_MATERIAL_ENEMIGO); un suceso de las zonas, más.
const MATERIAL_COFRE := [1, 3]
const MATERIAL_ENEMIGO := [1, 2]
const PROB_MATERIAL_ENEMIGO := 0.5
const MATERIAL_ZONA := [3, 6]


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


## Sortea un material según el nivel del lugar y cuántos trae: entre
## cantidad[0] y cantidad[1] por el nivel, por "multiplicador" (Buen ojo).
## Devuelve {"material": id, "cantidad": n}.
static func sortear_material(nivel: int, rng: RandomNumberGenerator, cantidad: Array, multiplicador := 1.0) -> Dictionary:
	nivel = clampi(nivel, 1, 4)
	var tabla: Array = PROB_MATERIAL[nivel]
	var tirada := rng.randf() * 100.0
	var material_id: String = DatosCiudad.ORDEN_MATERIALES[-1]
	for i in DatosCiudad.ORDEN_MATERIALES.size():
		tirada -= float(tabla[i])
		if tirada < 0.0:
			material_id = DatosCiudad.ORDEN_MATERIALES[i]
			break
	var base := rng.randi_range(int(cantidad[0]), int(cantidad[1])) * nivel
	return {"material": material_id, "cantidad": maxi(1, roundi(base * multiplicador))}


## "3 de madera", para contar lo que se encontró.
static func texto_material(hallazgo: Dictionary) -> String:
	return DatosCiudad.texto_materiales({hallazgo["material"]: hallazgo["cantidad"]})


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


## Crea un objeto de botín. "ranura" vacía = anillo, arma o pieza al azar
## ("anillo" = un anillo al azar); "calidad" vacía = se sortea (con
## "bonus_calidad", ver probabilidades). No tiene "id": lo pone el inventario al
## guardarlo.
static func generar(nivel: int, rng: RandomNumberGenerator, ranura := "", calidad := "", bonus_calidad := 1.0) -> Dictionary:
	nivel = clampi(nivel, 1, 4)
	if calidad == "":
		calidad = sortear_calidad(nivel, rng, bonus_calidad)
	if ranura == "":
		var tirada := rng.randf()
		if tirada < PROB_ANILLO:
			ranura = "anillo"
		elif tirada < PROB_ANILLO + (1.0 - PROB_ANILLO) * PROB_ARMA:
			ranura = "arma"
		else:
			ranura = PIEZAS[rng.randi() % PIEZAS.size()]
	var objeto := {"ranura": ranura, "calidad": calidad, "nivel": nivel}
	if ranura == "arma":
		_completar_arma(objeto, ARMAS_BOTIN[rng.randi() % ARMAS_BOTIN.size()])
	elif ranura == "anillo":
		_completar_anillo(objeto, ORDEN_ANILLOS[rng.randi() % ORDEN_ANILLOS.size()])
	else:
		_completar_pieza(objeto, DatosArmaduras.sortear(nivel, rng))
	objeto["precio"] = precio_venta(objeto)
	return objeto


## Arma de botín de esa base ("espada", "maza"...), nivel y calidad.
static func crear_arma(base: String, nivel: int, calidad: String) -> Dictionary:
	var objeto := {"ranura": "arma", "calidad": calidad, "nivel": clampi(nivel, 1, 4)}
	_completar_arma(objeto, base)
	objeto["precio"] = precio_venta(objeto)
	return objeto


## El mismo objeto con otra calidad: conserva su base, tipo (o el efecto del
## anillo), nivel e id (para la herrería).
static func con_calidad(objeto: Dictionary, calidad: String) -> Dictionary:
	var nuevo := objeto.duplicate()
	nuevo["calidad"] = calidad
	if nuevo["ranura"] == "arma":
		_completar_arma(nuevo, nuevo["base"])
	elif es_anillo(nuevo):
		_completar_anillo(nuevo, nuevo["anillo"])
	else:
		_completar_pieza(nuevo, nuevo["tipo"])
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


## Pieza de armadura de ese tipo (ver DatosArmaduras), con su nivel y calidad.
static func crear_pieza(ranura: String, tipo_id: String, nivel: int, calidad: String) -> Dictionary:
	var objeto := {"ranura": ranura, "calidad": calidad, "nivel": clampi(nivel, 1, 4)}
	_completar_pieza(objeto, tipo_id)
	objeto["precio"] = precio_venta(objeto)
	return objeto


## Anillo de ese efecto (ver ANILLOS), con su nivel y calidad. El nivel solo
## cambia lo que pagan por él; lo que hace depende de la calidad.
static func crear_anillo(anillo_id: String, nivel: int, calidad: String) -> Dictionary:
	var objeto := {"ranura": "anillo", "calidad": calidad, "nivel": clampi(nivel, 1, 4)}
	_completar_anillo(objeto, anillo_id)
	objeto["precio"] = precio_venta(objeto)
	return objeto


static func _completar_anillo(objeto: Dictionary, anillo_id: String) -> void:
	var datos: Dictionary = ANILLOS[anillo_id]
	objeto["anillo"] = anillo_id
	objeto["nombre"] = datos["nombre"]
	objeto["efecto"] = datos["efecto"][CALIDADES.find(objeto["calidad"])]


static func es_anillo(objeto: Dictionary) -> bool:
	return objeto.get("ranura", "") == "anillo"


## Ranuras del equipo donde puede ir ese objeto: la suya o, un anillo, las dos
## manos.
static func ranuras_de(objeto: Dictionary) -> Array:
	return RANURAS_ANILLO if es_anillo(objeto) else [objeto["ranura"]]


## "Vida +20", "Crítico +6%": lo que hace un anillo, corto.
static func texto_anillo(objeto: Dictionary) -> String:
	var anillo_id: String = objeto["anillo"]
	var valor := float(objeto["efecto"])
	if ANILLOS_PORCENTAJE.has(anillo_id):
		valor *= 100.0
	return String(ANILLOS[anillo_id]["corto"]) % roundi(valor)


## Lo que dan juntos esos anillos: {"vida", "mana": puntos que suman; "critico":
## probabilidad que suma; "sangrado", "estres": multiplican la sangre que se
## pierde y el estrés que se suma (1 = igual)}.
static func efectos_anillos(anillos: Array) -> Dictionary:
	var efectos := {"vida": 0, "mana": 0, "critico": 0.0, "sangrado": 1.0, "estres": 1.0}
	for anillo in anillos:
		var anillo_id: String = anillo["anillo"]
		var valor := float(anillo["efecto"])
		match anillo_id:
			"vida", "mana":
				efectos[anillo_id] = int(efectos[anillo_id]) + roundi(valor)
			"critico":
				efectos["critico"] = float(efectos["critico"]) + valor
			"sangrado", "estres":
				efectos[anillo_id] = float(efectos[anillo_id]) * (1.0 - valor)
	return efectos


## Las piezas de antes de los tipos de armadura ("estilo" metal o runas) pasan a
## ser de malla o con runas. Devuelve true si cambió algo.
static func migrar(objeto: Dictionary) -> bool:
	if not objeto.has("estilo") or objeto.has("tipo"):
		return false
	_completar_pieza(objeto, "runas" if objeto["estilo"] == "runas" else "malla")
	objeto.erase("estilo")
	return true


static func _completar_pieza(objeto: Dictionary, tipo_id: String) -> void:
	var ranura: String = objeto["ranura"]
	var nivel: int = objeto["nivel"]
	var valor: float = ARMADURA_BASE[ranura][nivel - 1] * float(DATOS_CALIDAD[objeto["calidad"]]["mult_armadura"])
	var tipo: Dictionary = DatosArmaduras.tipo(tipo_id)
	var datos_ranura: Dictionary = RANURAS[ranura]
	objeto["tipo"] = tipo_id
	objeto["nombre"] = DatosArmaduras.nombre_pieza(datos_ranura["nombre"], datos_ranura["genero"], datos_ranura["plural"],
		tipo_id, MATERIALES[nivel - 1])
	objeto["armadura"] = roundi(valor * float(tipo["fisica"]))
	objeto["resistencia_magica"] = roundi(valor * float(tipo["magica"]))


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


## "corte −12% · perforación −7% · contusión −5%": cuánto frena esa armadura de
## ese tipo cada daño físico.
static func texto_proteccion(tipo_id: String, valor: float) -> String:
	var textos: PackedStringArray = []
	for tipo_arma in ["cortante", "punzante", "contundente"]:
		textos.append("%s −%d%%" % [String(DatosArmas.tipo(tipo_arma)["herida"]).to_lower(),
			porcentaje_reduccion(valor * DatosArmaduras.eficacia(tipo_id, tipo_arma))])
	return " · ".join(textos)


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
	if es_anillo(objeto):
		lineas.append(texto_anillo(objeto))
		lineas.append(ANILLOS[objeto["anillo"]]["descripcion"])
		lineas.append("Llevas hasta dos anillos, uno en cada mano.")
	elif objeto["ranura"] == "arma":
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
		var tipo: Dictionary = DatosArmaduras.tipo(objeto["tipo"])
		lineas.append("Protege: %s · %s" % [", ".join(nombres), String(tipo["nombre"]).to_lower()])
		lineas.append(tipo["descripcion"])
		lineas.append("Armadura %d: %s" % [objeto["armadura"], texto_proteccion(objeto["tipo"], objeto["armadura"])])
		lineas.append("Resist. mágica %d (−%d%% daño mágico)" % [
			objeto["resistencia_magica"], porcentaje_reduccion(objeto["resistencia_magica"])])
		if float(tipo["peso"]) > 0.0:
			lineas.append("Pesa: −%d%% de rapidez" % roundi(100.0 * float(tipo["peso"])))
	lineas.append("Se vende por %d de oro" % (objeto["precio"] if precio < 0 else precio))
	return lineas
