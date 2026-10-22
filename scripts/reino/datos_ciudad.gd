class_name DatosCiudad
extends RefCounted
## Ciudad del reino (provisional): seis edificios fijos que se reconstruyen y
## mejoran con oro, y el peligro de la ciudad. La ciudad se cuida sola: produce
## su comida, cobra impuestos y sus soldados la defienden sin el rey. Si está
## mal protegida, el peligro sube y pueden atacarla. Todos los números son
## provisionales.

const NIVEL_MAXIMO := 3
const ORDEN := ["castillo", "herreria", "granja", "mercado", "barracas", "enfermeria"]

## "costos": oro para pasar al nivel 1, 2 y 3 (el nivel 0 es "en ruinas").
## "articulo": el nombre con su artículo, para las frases ("la granja").
## "posicion": dónde se dibuja en la ciudad (fracción del ancho y del alto).
const EDIFICIOS := {
	"castillo": {
		"nombre": "Castillo", "articulo": "el castillo", "color": Color("#ffd54f"), "posicion": Vector2(0.5, 0.36),
		"descripcion": "El centro de la ciudad. Sus murallas defienden, y ningún otro edificio puede tener más nivel que él. Aquí descansa el rey.",
		"costos": [0, 400, 1000],
	},
	"herreria": {
		"nombre": "Herrería", "articulo": "la herrería", "color": Color("#ff8a65"), "posicion": Vector2(0.16, 0.42),
		"descripcion": "Mejora la calidad de tus armas y armaduras, y equipa a los soldados: con más nivel defienden mejor.",
		"costos": [150, 400, 900],
	},
	"granja": {
		"nombre": "Granja", "articulo": "la granja", "color": Color("#9ccc65"), "posicion": Vector2(0.2, 0.79),
		"descripcion": "Produce la comida de la ciudad cada semana. Los soldados comen; sin comida, se van.",
		"costos": [100, 300, 700],
	},
	"mercado": {
		"nombre": "Mercado", "articulo": "el mercado", "color": Color("#4fc3f7"), "posicion": Vector2(0.8, 0.79),
		"descripcion": "Cobra impuestos cada semana y vende objetos que cambian cada semana. Negociación baja los precios.",
		"costos": [120, 350, 800],
	},
	"barracas": {
		"nombre": "Barracas", "articulo": "las barracas", "color": Color("#ef5350"), "posicion": Vector2(0.84, 0.4),
		"descripcion": "Aquí se reclutan los soldados que cuidan la ciudad: bajan el peligro cada semana y la defienden si la atacan.",
		"costos": [150, 400, 900],
	},
	"enfermeria": {
		"nombre": "Enfermería", "articulo": "la enfermería", "color": Color("#f48fb1"), "posicion": Vector2(0.5, 0.8),
		"descripcion": "Cuida al rey: con más nivel, descansar en el castillo cura más sus heridas.",
		"costos": [120, 300, 700],
	},
}

## Nivel con el que empieza cada edificio en una partida nueva (0 = en ruinas).
const NIVEL_INICIAL := {"castillo": 1, "herreria": 0, "granja": 0, "mercado": 0, "barracas": 0, "enfermeria": 0}

# --- Efectos por nivel (índice = nivel 0 a 3) ---

## Defensa de las murallas del castillo.
const MURALLAS := [0, 4, 8, 12]
## Calidad máxima a la que la herrería sube un objeto.
const CALIDAD_MAXIMA_HERRERIA := ["", "raro", "epico", "legendario"]
## Nombre de la calidad en femenino, para frases con "calidad" ("calidad rara").
const CALIDAD_FEMENINA := {"normal": "normal", "raro": "rara", "epico": "épica", "legendario": "legendaria"}
## Cuánto defiende cada soldado según el equipo que da la herrería.
const EQUIPO_SOLDADOS := [1.0, 1.25, 1.5, 1.75]
## Comida que produce la granja por semana.
const COMIDA_GRANJA := [0, 10, 18, 28]
## Oro de impuestos que cobra el mercado por semana.
const IMPUESTOS := [0, 15, 30, 50]
## Objetos a la venta en el mercado (cambian cada semana), y además pociones.
const OBJETOS_MERCADO := [0, 3, 4, 5]
const POCIONES_MERCADO := [0, 2, 3, 4]
## Soldados que caben en las barracas.
const SOLDADOS_MAXIMOS := [0, 5, 10, 15]
## Descansar una semana en el castillo cura esta parte de la vida del rey (y ×100
## de integridad a cada parte herida), más lo que suma la enfermería.
const CURA_DESCANSO := 0.4
const CURA_ENFERMERIA := [0.0, 0.2, 0.4, 0.6]

# --- Soldados y comida ---

const COSTO_SOLDADO := 40
const COMIDA_POR_SOLDADO := 2
const COMIDA_INICIAL := 20

# --- Peligro y ataques ---

## Lo que sube el peligro cada semana si la ciudad no tiene defensa.
const PELIGRO_POR_SEMANA := 10.0
## Cuánto peligro baja por semana cada punto de defensa.
const PELIGRO_POR_DEFENSA := 0.8
## Fuerza de un ataque: FUERZA_BASE + FUERZA_POR_SEMANA × semana, con azar.
const FUERZA_BASE := 8.0
const FUERZA_POR_SEMANA := 0.8
const AZAR_ATAQUE := Vector2(0.8, 1.25)
const AZAR_DEFENSA := Vector2(0.85, 1.15)
## Al ganar: el peligro baja esto y muere hasta esta fracción de los soldados
## (redondeado hacia abajo: con menos de 7 soldados no muere ninguno).
const PELIGRO_VICTORIA := 30.0
const BAJAS_VICTORIA := 0.15
## Al perder: se llevan esta parte del oro y de la comida, mueren esta parte de
## los soldados, un edificio baja un nivel (si son las barracas, se van los que
## ya no caben) y el peligro baja un poco (se van).
const SAQUEO_ORO := 0.2
const SAQUEO_COMIDA := 0.5
const BAJAS_DERROTA := 0.5
const PELIGRO_DERROTA := 20.0

## Precio en el mercado: el precio de venta por esto, rebajado por Negociación.
const MARGEN_MERCADO := 4.0
## Mejorar la calidad en la herrería: el precio de venta base del objeto ya
## mejorado por esto.
const COSTO_HERRERIA := 3.0


static func edificio(edificio_id: String) -> Dictionary:
	return EDIFICIOS[edificio_id]


## Oro para pasar de "nivel" a "nivel + 1" (-1 si ya está al máximo).
static func costo_mejora(edificio_id: String, nivel: int) -> int:
	if nivel >= NIVEL_MAXIMO:
		return -1
	return int(EDIFICIOS[edificio_id]["costos"][nivel])


## Qué hace el edificio con ese nivel, en una línea.
static func efecto(edificio_id: String, nivel: int) -> String:
	if nivel <= 0:
		return "En ruinas: no hace nada hasta reconstruirlo."
	match edificio_id:
		"castillo":
			return "Murallas: +%d de defensa. Los demás edificios llegan hasta nivel %d." % [MURALLAS[nivel], nivel]
		"herreria":
			return "Mejora objetos hasta calidad %s. Soldados ×%s de defensa." % [
				CALIDAD_FEMENINA[CALIDAD_MAXIMA_HERRERIA[nivel]], String.num(EQUIPO_SOLDADOS[nivel]).replace(".", ",")]
		"granja":
			return "Produce %d de comida por semana." % COMIDA_GRANJA[nivel]
		"mercado":
			return "Cobra %d de oro por semana y vende %d objetos de nivel %d." % [IMPUESTOS[nivel], OBJETOS_MERCADO[nivel], nivel]
		"barracas":
			return "Caben %d soldados." % SOLDADOS_MAXIMOS[nivel]
		"enfermeria":
			return "Descansar en el castillo cura el %d%% (sin ella, el %d%%)." % [
				roundi((CURA_DESCANSO + CURA_ENFERMERIA[nivel]) * 100.0), roundi(CURA_DESCANSO * 100.0)]
	return ""
