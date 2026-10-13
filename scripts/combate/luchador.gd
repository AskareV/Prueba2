class_name Luchador
extends RefCounted
## Estado de un combatiente durante la batalla. Solo lógica; el dibujo está en Figura.
## Cada parte del cuerpo tiene una integridad de 0 a 100. Las funciones de
## supervivencia (B.2) se calculan a partir de esas integridades.

## Por debajo de esta integridad la parte queda inutilizada.
const INUTILIZADA := 15.0
## Defensa (provisional): probabilidad de que un ataque bien dirigido no llegue.
## Esquiva con las piernas: base + lo que aportan las piernas sanas.
const ESQUIVA_BASE := 0.05
const ESQUIVA_PIERNAS := 0.12
## Cobertura de cabeza y torso: cuánto las protege cada brazo útil (bloquea) y
## cada pierna útil (se aparta). Un brazo o pierna inutilizado ya no cubre.
const COBERTURA_POR_BRAZO := 0.10
const COBERTURA_POR_PIERNA := 0.03
## En guardia, toda zona es más difícil de alcanzar.
const DEFENSA_GUARDIA := 0.2
const ESTADOS := ["Sana", "Leve", "Herida", "Grave", "Inutilizada"]

var nombre: String
## Artículo del nombre para narrar ("el Orco"). Vacío para el jugador.
var articulo := ""
var es_jugador: bool
var vida_max: int
var vida: int
var diestro: bool
var arma: String
## Forma de elegir a qué parte atacar cuando lo controla la máquina.
var personalidad := "normal"

var desarmado := false
## Usa el arma con la mano no dominante (menos precisión y daño).
var mano_torpe := false
## Pierde su próximo turno.
var aturdido := false
## En guardia hasta su próximo turno: se defiende mejor y recibe la mitad de daño.
var defendiendo := false
## Inconsciente: queda fuera de combate.
var desmayado := false

## parte -> integridad (0 a 100).
var integridad: Dictionary = {}
## Golpes recibidos: {parte, tipo, danio, turno}. Base para sangrado, dolor e infecciones.
var heridas: Array[Dictionary] = []
## Partes con fractura: parte -> true.
var fracturas: Dictionary = {}

# Estadísticas para el resumen final.
var danio_causado := 0
var danio_recibido := 0
var ataques := 0
var aciertos := 0


func _init(p_nombre: String, p_vida_max: int, p_diestro: bool, p_arma: String, p_es_jugador := false) -> void:
	nombre = p_nombre
	vida_max = p_vida_max
	vida = p_vida_max
	diestro = p_diestro
	arma = p_arma
	es_jugador = p_es_jugador
	for parte_id in DatosCuerpo.PARTES:
		integridad[parte_id] = 100.0


func fuera_de_combate() -> bool:
	return vida <= 0 or desmayado


# --- Lateralidad y arma ---

func lado_dominante() -> String:
	return "der" if diestro else "izq"


## Lado de la mano que sostiene el arma: la dominante, o la otra con mano torpe.
func lado_arma() -> String:
	if mano_torpe:
		return DatosCuerpo.lado_opuesto(lado_dominante())
	return lado_dominante()


func mano_arma() -> String:
	return "mano_" + lado_arma()


## Sin arma pelea con los puños; si ningún brazo sirve, a patadas.
func arma_actual() -> String:
	if not desarmado:
		return arma
	if extremidad_util("brazo_der") or extremidad_util("brazo_izq"):
		return "punos"
	return "patadas"


func puede_empunar(lado: String) -> bool:
	return extremidad_util("brazo_" + lado)


## Toma el arma con la mano dominante o, si no puede, con la otra.
## Devuelve false si ninguna mano puede sostenerla.
func empunar() -> bool:
	if puede_empunar(lado_dominante()):
		mano_torpe = false
	elif puede_empunar(DatosCuerpo.lado_opuesto(lado_dominante())):
		mano_torpe = true
	else:
		return false
	desarmado = false
	return true


# --- Partes del cuerpo ---

func factor(parte_id: String) -> float:
	return integridad[parte_id] / 100.0


func esta_inutilizada(parte_id: String) -> bool:
	return integridad[parte_id] < INUTILIZADA


## 0 = sana, 1 = leve, 2 = herida, 3 = grave, 4 = inutilizada.
func nivel(parte_id: String) -> int:
	var valor: float = integridad[parte_id]
	if valor >= 99.5:
		return 0
	if valor >= 70.0:
		return 1
	if valor >= 40.0:
		return 2
	if valor >= INUTILIZADA:
		return 3
	return 4


func estado(parte_id: String) -> String:
	var texto: String = ESTADOS[nivel(parte_id)]
	if DatosCuerpo.PARTES[parte_id]["articulo"] == "el" and texto.ends_with("a"):
		texto = texto.substr(0, texto.length() - 1) + "o"
	return texto


## Aplica un golpe acertado: resta "danio" de vida y "desgaste" de integridad a
## la parte. Devuelve la integridad previa.
func recibir_golpe(parte_id: String, danio: int, desgaste: float, tipo_herida: String, turno: int) -> float:
	var antes: float = integridad[parte_id]
	vida = maxi(vida - danio, 0)
	danio_recibido += danio
	integridad[parte_id] = maxf(antes - desgaste, 0.0)
	heridas.append({"parte": parte_id, "tipo": tipo_herida, "danio": danio, "turno": turno})
	return antes


## Cuenta las heridas de una parte por tipo: {"Corte": 2, ...}.
func heridas_de(parte_id: String) -> Dictionary:
	var conteo := {}
	for herida in heridas:
		if herida["parte"] == parte_id:
			conteo[herida["tipo"]] = int(conteo.get(herida["tipo"], 0)) + 1
	return conteo


# --- Funciones de supervivencia (B.2), de 0 a 1 ---

func conciencia() -> float:
	return factor("craneo")


## Con un ojo se ve peor (sin profundidad); sin los dos, casi nada.
func vision() -> float:
	var der := factor("ojo_der")
	var izq := factor("ojo_izq")
	return maxf(der, izq) * 0.7 + minf(der, izq) * 0.3


func respiracion() -> float:
	return minf(factor("cuello"), (factor("torax_der") + factor("torax_izq")) / 2.0)


## Una lesión que inutiliza el cuello (columna) afecta brazos y piernas a la vez.
func factor_columna() -> float:
	return 0.3 if esta_inutilizada("cuello") else 1.0


func mov_brazo(lado: String) -> float:
	var minimo := minf(
		minf(factor("hombro_" + lado), factor("brazo_" + lado)),
		minf(factor("antebrazo_" + lado), factor("mano_" + lado)))
	return minimo * factor_columna()


## Una pierna vale lo que su parte más dañada.
func mov_pierna(lado: String) -> float:
	var minimo := minf(factor("muslo_" + lado), minf(factor("espinilla_" + lado), factor("pie_" + lado)))
	return minimo * factor_columna()


func mov_piernas() -> float:
	return (mov_pierna("der") + mov_pierna("izq")) / 2.0


## Movimiento del brazo o la pierna de esa zona (1 para cabeza y torso).
func movilidad(zona_id: String) -> float:
	if zona_id.begins_with("brazo_"):
		return mov_brazo(zona_id.substr(6))
	if zona_id.begins_with("pierna_"):
		return mov_pierna(zona_id.substr(7))
	return 1.0


func funcion(funcion_id: String) -> float:
	match funcion_id:
		"conciencia":
			return conciencia()
		"vision":
			return vision()
		"respiracion":
			return respiracion()
		"piernas":
			return mov_piernas()
		"brazo_der":
			return mov_brazo("der")
		"brazo_izq":
			return mov_brazo("izq")
	return 1.0


# --- Valores derivados para el combate (provisionales) ---

## Esquiva al moverse: depende de las piernas.
func esquiva() -> float:
	return ESQUIVA_BASE + ESQUIVA_PIERNAS * mov_piernas()


## Brazo o pierna que aún se puede usar (no está inutilizado).
func extremidad_util(zona_id: String) -> bool:
	return movilidad(zona_id) >= INUTILIZADA / 100.0


## Cuánto cubren la cabeza y el torso los brazos (bloqueando) y las piernas
## (apartándose). Cada brazo o pierna inutilizado deja de cubrir.
func cobertura() -> float:
	var valor := 0.0
	for lado in ["der", "izq"]:
		if extremidad_util("brazo_" + lado):
			valor += COBERTURA_POR_BRAZO
		if extremidad_util("pierna_" + lado):
			valor += COBERTURA_POR_PIERNA
	return valor


## Cobertura con los dos brazos y las dos piernas útiles.
static func cobertura_maxima() -> float:
	return (COBERTURA_POR_BRAZO + COBERTURA_POR_PIERNA) * 2.0


## Probabilidad de que un ataque a esa zona no llegue (ver "defensa" en DatosCuerpo.ZONAS).
func defensa(zona_id: String) -> float:
	var valor := 0.0
	match String(DatosCuerpo.ZONAS[zona_id]["defensa"]):
		"cubierta":
			valor = esquiva() + cobertura()
		"esquiva":
			valor = esquiva()
	if defendiendo:
		valor += DEFENSA_GUARDIA
	return valor


## Capacidad del brazo con que ataca (el mejor si pelea sin arma, o las
## piernas si pelea a patadas).
func fuerza_ataque() -> float:
	match arma_actual():
		"punos":
			return maxf(mov_brazo("der"), mov_brazo("izq"))
		"patadas":
			return mov_piernas()
	return mov_brazo(lado_arma())


# --- Textos para narrar ---

## "el Orco"; el jugador no lleva artículo.
func con_articulo() -> String:
	return nombre if articulo == "" else "%s %s" % [articulo, nombre]


## "al Orco", "a la Bruja"
func a_nombre() -> String:
	return "al " + nombre if articulo == "el" else "a " + con_articulo()


## "del Orco", "de la Bruja"
func de_nombre() -> String:
	return "del " + nombre if articulo == "el" else "de " + con_articulo()


func lateralidad() -> String:
	return "Diestro" if diestro else "Zurdo"
