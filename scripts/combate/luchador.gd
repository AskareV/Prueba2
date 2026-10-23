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
## Una parte fracturada rinde esto (30% menos) en las funciones: un brazo pega
## más flojo y se inutiliza antes, una pierna esquiva y avanza menos, etc.
const FACTOR_FRACTURA := 0.7
## Con la respiración baja es más lento en la barra de turnos (hasta 30% menos).
const RESPIRACION_RAPIDEZ := 0.3
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
## Su presencia lo supera: acierta y pega menos y es más lento (ver MotorCombate).
var atemorizado := false

## Subcaracterísticas (ver DatosEstadisticas): sub -> valor. Las que faltan valen
## la base, que no cambia nada. Solo el rey las tiene ("tiene_estadisticas").
var estadisticas: Dictionary = {}
var tiene_estadisticas := false
## Rapidez en la barra de turnos (ver OrdenTurnos).
var rapidez := DatosEstadisticas.RAPIDEZ_BASE
## Coraje ante la presencia del rey: si su Presencia lo supera de lejos, se atemoriza.
var coraje := 0.0
## Maná: lo usan el rey y los enemigos que saben magia (su bastón también lo gasta).
var usa_mana := false
var mana_max := 0.0
var mana := 0.0
## Hechizo que está lanzando: mientras dura, ocupa el lugar del arma
## (ver datos_arma y DatosHechizos).
var hechizo: Dictionary = {}
## Hechizos que lanza un enemigo por su cuenta (ver IAEnemigo). El rey usa el
## botón Magia.
var hechizos: Array[String] = []
## Fuerza de la magia de un enemigo (1 = la del rey sin Arcano): sus hechizos
## pegan y curan más o menos según su bastón.
var poder_magico := 1.0
## Probabilidad propia de empujar al rival con un golpe (los enemigos brutos).
var empuje := 0.0
var _vida_base := 0

## Armadura por zona del cuerpo: zona -> {"fisica": n, "magica": n}. Frena el
## daño como en League of Legends (ver MotorCombate.multiplicador_armadura).
var armadura: Dictionary = {}
## Arma de botín equipada (ver DatosBotin) o vacío para usar el arma básica.
var arma_objeto: Dictionary = {}

## parte -> integridad (0 a 100).
var integridad: Dictionary = {}
## Golpes recibidos: {parte, tipo, danio, turno, nueva: de este combate, limpia:
## se limpió con una venda}. Base para sangrado, dolor e infecciones.
var heridas: Array[Dictionary] = []
## Partes con fractura: parte -> true.
var fracturas: Dictionary = {}

## Sangre (ver DatosHeridas): litros que le quedan y partes que sangran,
## {"parte", "tipo": "externo" o "interno", "nivel": 1 a 3, "turnos": los que le
## faltan a una leve para parar}. No todas las criaturas sangran.
var sangra := true
var sangre := DatosHeridas.SANGRE_MAX
var sangrados: Array[Dictionary] = []
## Murió desangrado: queda fuera de combate.
var muerto := false
## Vida máxima con toda la sangre: la sangre perdida baja vida_max en la misma
## proporción.
var vida_max_sana := 0
## Etapa de su peor infección (ver DatosHeridas.ETAPAS); desde la grave tiene
## fiebre. Solo el rey las arrastra de un día a otro.
var infeccion := 0

# Estadísticas para el resumen final.
var danio_causado := 0
var danio_recibido := 0
var ataques := 0
var aciertos := 0


func _init(p_nombre: String, p_vida_max: int, p_diestro: bool, p_arma: String, p_es_jugador := false) -> void:
	nombre = p_nombre
	vida_max = p_vida_max
	vida = p_vida_max
	vida_max_sana = p_vida_max
	_vida_base = p_vida_max
	diestro = p_diestro
	arma = p_arma
	es_jugador = p_es_jugador
	for parte_id in DatosCuerpo.PARTES:
		integridad[parte_id] = 100.0


func fuera_de_combate() -> bool:
	return vida <= 0 or desmayado or muerto


# --- Características ---

func valor_de(sub_id: String) -> float:
	return float(estadisticas.get(sub_id, DatosEstadisticas.BASE))


## Puntos de esa sub por encima de la base (como mucho el tope): de esto
## dependen sus efectos.
func puntos(sub_id: String) -> float:
	return DatosEstadisticas.puntos_utiles(valor_de(sub_id))


## Fija las características del rey y lo que depende de ellas: vida, maná y rapidez.
func aplicar_estadisticas(p_estadisticas: Dictionary) -> void:
	estadisticas = p_estadisticas
	tiene_estadisticas = true
	vida_max_sana = _vida_base + DatosEstadisticas.vida_extra(puntos("vitalidad"))
	vida = vida_max_sana
	ajustar_vida_max()
	usa_mana = true
	# Entero, aunque el Amuleto deje puntos con decimales.
	mana_max = floorf(DatosEstadisticas.MANA_BASE + DatosEstadisticas.MANA_POR_MAGO * puntos("mago") + 0.001)
	mana = mana_max
	rapidez = DatosEstadisticas.RAPIDEZ_BASE + DatosEstadisticas.RAPIDEZ_POR_VELOCIDAD * puntos("velocidad")


## Maná que recupera al empezar cada uno de sus turnos.
func regeneracion_mana() -> float:
	return DatosEstadisticas.REGENERACION_BASE + DatosEstadisticas.REGENERACION_POR_MAGO * puntos("mago")


func regenerar_mana() -> void:
	if usa_mana:
		mana = minf(mana + regeneracion_mana(), mana_max)


## Rapidez real: las piernas heridas, la falta de aire y el miedo lo frenan.
func rapidez_efectiva() -> float:
	var valor_rapidez := rapidez * (0.6 + 0.4 * mov_piernas())
	valor_rapidez *= 1.0 - RESPIRACION_RAPIDEZ * (1.0 - respiracion())
	if atemorizado:
		valor_rapidez *= MotorCombate.ATEMORIZADO_RAPIDEZ
	return maxf(valor_rapidez, 1.0)


## Probabilidad de golpe crítico: solo con puntos de Golpe de suerte sobre la base.
func prob_critico() -> float:
	return DatosEstadisticas.CRITICO_POR_SUERTE * puntos("golpe_suerte")


## Multiplicador de una penalización de la mano torpe (ej. 0.85): el agarre la achica.
func penalizacion_mano_torpe(base: float) -> float:
	return 1.0 - (1.0 - base) * DatosEstadisticas.reduccion(puntos("fuerza_agarre"), DatosEstadisticas.MANO_TORPE_POR_AGARRE)


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


## Datos del arma con que pelea ahora: el hechizo que está lanzando, el arma de
## botín (con su daño y precisión) o la básica, o los puños o patadas si está
## desarmado. Sin maná, el bastón pega como un palo.
func datos_arma() -> Dictionary:
	if not hechizo.is_empty():
		return hechizo
	var datos: Dictionary
	if desarmado or arma_objeto.is_empty() or arma_objeto.get("base", arma) != arma:
		datos = DatosArmas.arma(arma_actual())
	else:
		datos = DatosArmas.arma(arma).duplicate()
		for clave in ["nombre", "danio_min", "danio_max", "precision"]:
			if arma_objeto.has(clave):
				datos[clave] = arma_objeto[clave]
	if sin_mana_para_baston():
		datos = DatosHechizos.baston_sin_mana(datos)
	return datos


## Pelea con el bastón y no le alcanza el maná para su golpe mágico.
func sin_mana_para_baston() -> bool:
	return usa_mana and not desarmado and arma == "baston" and mana < DatosHechizos.COSTE_BASTON


## Paga el maná de un golpe con el bastón (los hechizos se pagan al lanzarlos).
func pagar_ataque() -> void:
	if hechizo.is_empty() and usa_mana and not desarmado and arma == "baston" and mana >= DatosHechizos.COSTE_BASTON:
		mana -= DatosHechizos.COSTE_BASTON


## Armadura (física o mágica) que protege esa zona; la Resistencia la hace rendir más.
func proteccion(zona_id: String, magica: bool) -> float:
	var datos: Dictionary = armadura.get(zona_id, {})
	var valor_armadura := float(datos.get("magica" if magica else "fisica", 0.0))
	return valor_armadura * DatosEstadisticas.aumento(puntos("resistencia"), DatosEstadisticas.ARMADURA_POR_RESISTENCIA)


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

## Cuánto rinde una parte para las funciones (0 a 1): su integridad, y menos si
## está fracturada.
func factor(parte_id: String) -> float:
	var valor: float = integridad[parte_id] / 100.0
	if fracturas.has(parte_id):
		valor *= FACTOR_FRACTURA
	return valor


## Lo que rinde una parte por estar (o no) fracturada: 0,7 o 1.
func factor_fractura(parte_id: String) -> float:
	return FACTOR_FRACTURA if fracturas.has(parte_id) else 1.0


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
	heridas.append({"parte": parte_id, "tipo": tipo_herida, "danio": danio, "turno": turno, "nueva": true})
	return antes


## Cuenta las heridas de una parte por tipo: {"Corte": 2, ...}.
func heridas_de(parte_id: String) -> Dictionary:
	var conteo := {}
	for herida in heridas:
		if herida["parte"] == parte_id:
			conteo[herida["tipo"]] = int(conteo.get(herida["tipo"], 0)) + 1
	return conteo


# --- Funciones de supervivencia (B.2), de 0 a 1 ---

## La fiebre de una infección grave también la baja.
func conciencia() -> float:
	return factor("craneo") * DatosHeridas.CONCIENCIA_FIEBRE[infeccion]


## Sin los dos ojos (los dos inutilizados) está ciego: acierta mucho menos.
func esta_ciego() -> bool:
	return esta_inutilizada("ojo_der") and esta_inutilizada("ojo_izq")


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


# --- Sangre (B.1) ---

## Parte de su sangre que perdió (0 a 1).
func sangre_perdida() -> float:
	return 1.0 - sangre / DatosHeridas.SANGRE_MAX


## 0 normal, 1 agitado, 2 débil y confuso, 3 shock (ver DatosHeridas).
func estado_sangre() -> int:
	return DatosHeridas.estado_por_perdida(sangre_perdida())


## Hace sangrar esa parte (ver DatosHeridas.sumar_sangrado). Devuelve el nivel con
## que queda.
func agregar_sangrado(parte_id: String, tipo: String, nivel: int) -> int:
	return DatosHeridas.sumar_sangrado(sangrados, parte_id, tipo, nivel)


## Sangra por fuera (se ve).
func sangra_por_fuera() -> bool:
	return DatosHeridas.hay_sangrado(sangrados, "externo")


## Pierde la sangre de sus heridas durante esos turnos (las leves paran solas).
## Devuelve los litros perdidos.
func sangrar(turnos := 1) -> float:
	var perdida := DatosHeridas.avanzar_sangrados(sangrados, turnos)
	perder_sangre(perdida)
	return perdida


## Si llega a perder la mitad de su sangre, muere.
func perder_sangre(litros: float) -> void:
	if litros <= 0.0:
		return
	sangre = maxf(sangre - litros, 0.0)
	ajustar_vida_max()
	if sangre_perdida() >= DatosHeridas.MUERTE - 0.0001:
		muerto = true


func recuperar_sangre(litros: float) -> void:
	sangre = minf(sangre + litros, DatosHeridas.SANGRE_MAX)
	ajustar_vida_max()


## La vida máxima baja con la sangre perdida (y la vida, si queda por encima).
func ajustar_vida_max() -> void:
	vida_max = maxi(1, roundi(vida_max_sana * sangre / DatosHeridas.SANGRE_MAX))
	vida = mini(vida, vida_max)


## Cura vida y la integridad de todas las partes a la vez (una poción). Una parte
## que se cura del todo deja de estar fracturada y de sangrar.
func curar(cantidad_vida: int, partes: float) -> int:
	var antes := vida
	vida = mini(vida + cantidad_vida, vida_max)
	for parte_id in integridad:
		integridad[parte_id] = minf(integridad[parte_id] + partes, 100.0)
		if integridad[parte_id] >= 100.0:
			fracturas.erase(parte_id)
	sangrados.assign(sangrados.filter(func(sangrado: Dictionary) -> bool: return integridad[sangrado["parte"]] < 100.0))
	return vida - antes


## Le falta vida o tiene alguna parte herida.
func esta_herido() -> bool:
	if vida < vida_max:
		return true
	for parte_id in integridad:
		if integridad[parte_id] < 100.0:
			return true
	return false


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
