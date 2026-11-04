class_name DatosCiudad
extends RefCounted
## Ciudad del reino (provisional): seis edificios fijos que se reconstruyen y
## mejoran con oro. La ciudad se cuida sola: produce su comida y cobra impuestos.
## Ya no hay invasiones: los soldados no tienen uso por ahora (más adelante,
## quizá batallas campales). Todos los números son provisionales.

const NIVEL_MAXIMO := 3
const ORDEN := ["castillo", "herreria", "granja", "mercado", "barracas", "enfermeria"]

## "costos": oro para pasar al nivel 1, 2 y 3 (el nivel 0 es "en ruinas").
## "articulo": el nombre con su artículo, para las frases ("la granja").
## "posicion": dónde se dibuja en la ciudad (fracción del ancho y del alto).
const EDIFICIOS := {
	"castillo": {
		"nombre": "Castillo", "articulo": "el castillo", "color": Color("#ffd54f"), "posicion": Vector2(0.5, 0.36),
		"descripcion": "El centro de la ciudad: ningún otro edificio puede tener más nivel que él. Aquí descansa el rey.",
		"costos": [0, 400, 1000],
	},
	"herreria": {
		"nombre": "Herrería", "articulo": "la herrería", "color": Color("#ff8a65"), "posicion": Vector2(0.16, 0.42),
		"descripcion": "Mejora la calidad de tus armas y armaduras.",
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
		"descripcion": "Aquí se reclutan soldados. Por ahora no tienen uso: ya no hay invasiones.",
		"costos": [150, 400, 900],
	},
	"enfermeria": {
		"nombre": "Enfermería", "articulo": "la enfermería", "color": Color("#f48fb1"), "posicion": Vector2(0.5, 0.8),
		"descripcion": "Cuida al rey: al descansar en el castillo le para el sangrado por dentro y le cura las infecciones; con más nivel, cura más sus heridas.",
		"costos": [120, 300, 700],
	},
}

## Nivel con el que empieza cada edificio en una partida nueva (0 = en ruinas).
const NIVEL_INICIAL := {"castillo": 1, "herreria": 0, "granja": 0, "mercado": 0, "barracas": 0, "enfermeria": 0}

# --- Efectos por nivel (índice = nivel 0 a 3) ---

## Calidad máxima a la que la herrería sube un objeto.
const CALIDAD_MAXIMA_HERRERIA := ["", "raro", "epico", "legendario"]
## Nombre de la calidad en femenino, para frases con "calidad" ("calidad rara").
const CALIDAD_FEMENINA := {"normal": "normal", "raro": "rara", "epico": "épica", "legendario": "legendaria"}
## Comida que produce la granja por semana.
const COMIDA_GRANJA := [0, 10, 18, 28]
## Oro de impuestos que cobra el mercado por semana.
const IMPUESTOS := [0, 15, 30, 50]
## Objetos a la venta en el mercado (cambian cada semana) y, además, cuántas
## pociones, vendas, torniquetes y medicinas tiene según su nivel.
const OBJETOS_MERCADO := [0, 3, 4, 5]
const POCIONES_MERCADO := [0, 2, 3, 4]
const CONSUMIBLES_MERCADO := {
	"pocion": POCIONES_MERCADO, "venda": [0, 3, 4, 5], "torniquete": [0, 1, 2, 2], "medicina": [0, 1, 2, 3],
}
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
		return "En ruinas: no hace nada hasta que se reconstruya."
	match edificio_id:
		"castillo":
			return "Los demás edificios llegan hasta nivel %d." % nivel
		"herreria":
			return "Mejora objetos hasta calidad %s." % CALIDAD_FEMENINA[CALIDAD_MAXIMA_HERRERIA[nivel]]
		"granja":
			return "Produce %d de comida por semana." % COMIDA_GRANJA[nivel]
		"mercado":
			return "Cobra %d de oro por semana y vende %d objetos de nivel %d." % [IMPUESTOS[nivel], OBJETOS_MERCADO[nivel], nivel]
		"barracas":
			return "Caben %d soldados (por ahora sin uso)." % SOLDADOS_MAXIMOS[nivel]
		"enfermeria":
			var cura := roundi((CURA_DESCANSO + CURA_ENFERMERIA[nivel]) * 100.0)
			return "Al descansar recuperas el %d%% de tu vida máxima y de tu sangre y %d de cada parte herida (sin ella, %d%% y %d), y te cura el sangrado por dentro y las infecciones." % [
				cura, cura, roundi(CURA_DESCANSO * 100.0), roundi(CURA_DESCANSO * 100.0)]
	return ""
