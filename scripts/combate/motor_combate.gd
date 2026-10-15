class_name MotorCombate
extends RefCounted
## Reglas provisionales del combate (docs/diseno.md, punto 6): probabilidad de
## acierto, daño y efectos de cada golpe. Todos los números son de prueba.

const ACIERTO_MIN := 0.05
const ACIERTO_MAX := 0.95
## Si la conciencia baja de este valor, el luchador se desmaya.
const UMBRAL_DESMAYO := 0.2
## Integridad bajo la cual un golpe contundente fractura un hueso.
const UMBRAL_FRACTURA := 55.0
const PENALIZACION_MANO_TORPE_PRECISION := 0.85
## Fuerza que conserva un golpe dado con el brazo del arma inutilizado; con el
## brazo sano es 1. Un brazo herido pega más débil, pero no deja de pelear.
const FUERZA_MINIMA := 0.75
## Cuánto sube la probabilidad de desarmar según lo dañada que quede la mano.
const DESARME_POR_HERIDA := 0.25
const PENALIZACION_MANO_TORPE_DANIO := 0.85
## Daño que recibe quien se defiende (la mitad). La Fuerza de agarre de quien se
## defiende lo baja y la Fuerza explosiva de quien ataca lo sube, entre estos límites.
const REDUCCION_DANIO_EN_GUARDIA := 0.5
const GUARDIA_MINIMA := 0.25
const GUARDIA_MAXIMA := 0.8
## Golpe crítico: multiplica el daño (ver Golpe de suerte).
const MULTIPLICADOR_CRITICO := 1.5
## Atemorizado por la Presencia del rey: acierta, pega y avanza menos.
const ATEMORIZADO_ACIERTO := 0.9
const ATEMORIZADO_DANIO := 0.85
const ATEMORIZADO_RAPIDEZ := 0.9


static func prob_acierto(atacante: Luchador, defensor: Luchador, parte_id: String) -> float:
	var arma: Dictionary = atacante.datos_arma()
	var tipo: Dictionary = DatosArmas.tipo(arma["tipo"])
	var tamano: float = DatosCuerpo.PARTES[parte_id]["tamano"]
	var exponente: float = tipo["exp_tamano"]
	var precision: float = arma["precision"]
	var prob := precision * pow(tamano, exponente)
	prob *= 0.5 + 0.5 * atacante.vision()
	if _usa_el_brazo(atacante) and atacante.mano_torpe:
		prob *= atacante.penalizacion_mano_torpe(PENALIZACION_MANO_TORPE_PRECISION)
	prob *= 1.0 - defensor.defensa(DatosCuerpo.zona_de(parte_id))
	# Precisión y Reflejos: un poco en todas las partes.
	prob += DatosEstadisticas.ACIERTO_POR_PRECISION * atacante.puntos("precision")
	prob -= DatosEstadisticas.ESQUIVA_POR_REFLEJOS * defensor.puntos("reflejos")
	if atacante.atemorizado:
		prob *= ATEMORIZADO_ACIERTO
	return clampf(prob, ACIERTO_MIN, ACIERTO_MAX)


## Golpea con el arma (no con un hechizo) y sostiene un arma: cuentan el brazo y
## la mano torpe.
static func _usa_el_brazo(atacante: Luchador) -> bool:
	return atacante.hechizo.is_empty() and not atacante.desarmado


## Promedio de acierto de las partes de una zona (para el botón de la zona).
static func prob_acierto_zona(atacante: Luchador, defensor: Luchador, zona_id: String) -> float:
	var partes := DatosCuerpo.partes_de(zona_id)
	var suma := 0.0
	for parte_id in partes:
		suma += prob_acierto(atacante, defensor, parte_id)
	return suma / partes.size()


## Armadura y resistencia mágica, como en League of Legends: el daño se
## multiplica por 100 / (100 + valor). Con 100, la mitad; con 200, un tercio.
static func multiplicador_armadura(valor: float) -> float:
	return 100.0 / (100.0 + maxf(valor, 0.0))


## Fuerza del golpe respecto de la del arma: tipo de arma contra esa parte,
## estado del brazo que ataca, armadura de esa zona y guardia del defensor.
static func multiplicador_golpe(atacante: Luchador, defensor: Luchador, parte_id: String) -> float:
	var arma: Dictionary = atacante.datos_arma()
	var mult := DatosArmas.afinidad(arma["tipo"], parte_id)
	var magico := DatosArmas.es_magico(arma["tipo"])
	mult *= multiplicador_armadura(defensor.proteccion(DatosCuerpo.zona_de(parte_id), magico))
	if atacante.hechizo.is_empty():
		mult *= FUERZA_MINIMA + (1.0 - FUERZA_MINIMA) * atacante.fuerza_ataque()
	if _usa_el_brazo(atacante) and atacante.mano_torpe:
		mult *= atacante.penalizacion_mano_torpe(PENALIZACION_MANO_TORPE_DANIO)
	# Arcano para la magia y Fuerza máxima para lo demás.
	if magico:
		mult *= DatosEstadisticas.aumento(atacante.puntos("arcano"), DatosEstadisticas.MAGIA_POR_ARCANO)
	else:
		mult *= DatosEstadisticas.aumento(atacante.puntos("fuerza_maxima"), DatosEstadisticas.DANIO_POR_FUERZA)
	if atacante.atemorizado:
		mult *= ATEMORIZADO_DANIO
	if defensor.defendiendo:
		mult *= factor_guardia(atacante, defensor)
	return mult


## Parte del daño que recibe quien se defiende.
static func factor_guardia(atacante: Luchador, defensor: Luchador) -> float:
	var factor := REDUCCION_DANIO_EN_GUARDIA
	factor -= DatosEstadisticas.GUARDIA_POR_AGARRE * defensor.puntos("fuerza_agarre")
	factor += DatosEstadisticas.GUARDIA_POR_EXPLOSIVA * atacante.puntos("fuerza_explosiva")
	return clampf(factor, GUARDIA_MINIMA, GUARDIA_MAXIMA)


## Vida que quita cada punto de daño del arma en esa parte.
static func multiplicador_danio(atacante: Luchador, defensor: Luchador, parte_id: String) -> float:
	var danio_parte: float = DatosCuerpo.PARTES[parte_id]["danio"]
	return danio_parte * multiplicador_golpe(atacante, defensor, parte_id)


## Integridad que pierde la parte por cada punto de daño del arma.
static func multiplicador_desgaste(atacante: Luchador, defensor: Luchador, parte_id: String) -> float:
	var fragilidad: float = DatosCuerpo.PARTES[parte_id]["fragilidad"]
	return fragilidad * multiplicador_golpe(atacante, defensor, parte_id)


## Golpes acertados que faltan para inutilizar esa parte o, en brazos y piernas,
## para que la extremidad deje de servir (con el cuello inutilizado basta menos).
## Devuelve (golpes si todos pegan fuerte, golpes si todos pegan flojo); (0, 0)
## si ya está inutilizada.
static func golpes_para_inutilizar(atacante: Luchador, defensor: Luchador, parte_id: String) -> Vector2i:
	var zona_id := DatosCuerpo.zona_de(parte_id)
	var umbral := Luchador.INUTILIZADA
	if DatosCuerpo.ZONAS[zona_id]["defensa"] != "cubierta":
		if not defensor.extremidad_util(zona_id):
			return Vector2i.ZERO
		umbral = minf(Luchador.INUTILIZADA / defensor.factor_columna(), 100.0)
	var restante: float = defensor.integridad[parte_id] - umbral
	if restante < 0.0:
		return Vector2i.ZERO
	var arma: Dictionary = atacante.datos_arma()
	var primero := multiplicador_desgaste(atacante, defensor, parte_id)
	# La guardia solo protege del próximo golpe.
	var siguientes := primero / factor_guardia(atacante, defensor) if defensor.defendiendo else primero
	return Vector2i(
		_golpes_hasta(restante, arma["danio_max"] * primero, arma["danio_max"] * siguientes),
		_golpes_hasta(restante, arma["danio_min"] * primero, arma["danio_min"] * siguientes))


## Golpes hasta que el desgaste acumulado supere "restante".
static func _golpes_hasta(restante: float, primero: float, siguientes: float) -> int:
	if primero > restante:
		return 1
	return floori((restante - primero) / maxf(siguientes, 0.01)) + 2


## Daño mínimo y máximo de un golpe acertado en esa parte.
static func rango_danio(atacante: Luchador, defensor: Luchador, parte_id: String) -> Vector2i:
	var arma: Dictionary = atacante.datos_arma()
	var mult := multiplicador_danio(atacante, defensor, parte_id)
	var minimo: int = arma["danio_min"]
	var maximo: int = arma["danio_max"]
	return Vector2i(maxi(1, roundi(minimo * mult)), maxi(1, roundi(maximo * mult)))


## Resuelve un ataque y aplica sus efectos al defensor. Devuelve qué pasó:
## acierto, danio, critico, herida, fractura, inutilizada, expuesto (un brazo o
## pierna dejó de cubrir la cabeza y el torso), desarme, aturdido, desmayo y
## empujon (pierde tiempo en la barra de turnos; lo aplica quien lleva los turnos).
## Un golpe con bastón gasta maná, acierte o no.
static func resolver_ataque(atacante: Luchador, defensor: Luchador, parte_id: String,
		rng: RandomNumberGenerator, turno: int) -> Dictionary:
	var resultado := _resolver_ataque(atacante, defensor, parte_id, rng, turno)
	atacante.pagar_ataque()
	return resultado


static func _resolver_ataque(atacante: Luchador, defensor: Luchador, parte_id: String,
		rng: RandomNumberGenerator, turno: int) -> Dictionary:
	var arma_id: String = atacante.hechizo.get("hechizo", atacante.arma_actual())
	var arma: Dictionary = atacante.datos_arma()
	var tipo_id: String = arma["tipo"]
	var tipo: Dictionary = DatosArmas.tipo(tipo_id)
	var resultado := {
		"parte": parte_id, "arma": arma_id, "acierto": false, "danio": 0, "herida": "",
		"fractura": false, "inutilizada": false, "expuesto": false, "desarme": false,
		"aturdido": false, "desmayo": false, "critico": false, "empujon": false,
	}
	atacante.ataques += 1
	if rng.randf() >= prob_acierto(atacante, defensor, parte_id):
		return resultado

	var danio_min: int = arma["danio_min"]
	var danio_max: int = arma["danio_max"]
	var base := float(rng.randi_range(danio_min, danio_max))
	var prob_critico := atacante.prob_critico()
	if prob_critico > 0.0 and rng.randf() < prob_critico:
		base *= MULTIPLICADOR_CRITICO
		resultado["critico"] = true
	var danio := maxi(1, roundi(base * multiplicador_danio(atacante, defensor, parte_id)))
	var desgaste := base * multiplicador_desgaste(atacante, defensor, parte_id)
	var herida: String = tipo["herida"]
	var podia_empunar := not defensor.desarmado and defensor.puede_empunar(defensor.lado_arma())
	var cobertura_antes := defensor.cobertura()
	var antes := defensor.recibir_golpe(parte_id, danio, desgaste, herida, turno)
	var despues: float = defensor.integridad[parte_id]
	atacante.aciertos += 1
	atacante.danio_causado += danio
	resultado["acierto"] = true
	resultado["danio"] = danio
	resultado["herida"] = herida

	var es_hueso: bool = DatosCuerpo.PARTES[parte_id]["hueso"]
	var umbral_fractura := UMBRAL_FRACTURA + DatosEstadisticas.FRACTURA_POR_EXPLOSIVA * atacante.puntos("fuerza_explosiva")
	if tipo_id == "contundente" and es_hueso and despues < umbral_fractura \
			and not defensor.fracturas.has(parte_id):
		defensor.fracturas[parte_id] = true
		defensor.heridas[-1]["tipo"] = "Fractura"
		resultado["fractura"] = true
		resultado["herida"] = "Fractura"

	if antes >= Luchador.INUTILIZADA and despues < Luchador.INUTILIZADA:
		resultado["inutilizada"] = true

	if defensor.conciencia() < umbral_desmayo(defensor) and not defensor.desmayado:
		defensor.desmayado = true
		resultado["desmayo"] = true
	# Quien queda fuera de combate ya no suelta el arma, ni queda aturdido o expuesto.
	if defensor.fuera_de_combate():
		return resultado

	resultado["expuesto"] = defensor.cobertura() < cobertura_antes

	var efectos: float = arma.get("efectos", 1.0)
	resultado["desarme"] = _intentar_desarme(atacante, defensor, parte_id, tipo, despues, podia_empunar, efectos, rng)

	if parte_id == "craneo" and not defensor.aturdido:
		var prob_base: float = tipo["prob_aturdir"] * efectos
		var prob_aturdir := prob_base * (1.6 - defensor.conciencia())
		prob_aturdir *= DatosEstadisticas.aumento(atacante.puntos("fuerza_explosiva"), DatosEstadisticas.ATURDIR_POR_EXPLOSIVA)
		prob_aturdir *= DatosEstadisticas.reduccion(defensor.puntos("firmeza"), DatosEstadisticas.ATURDIR_POR_FIRMEZA)
		prob_aturdir *= _resistencia_a_estados(defensor)
		if rng.randf() < prob_aturdir:
			defensor.aturdido = true
			resultado["aturdido"] = true

	var prob_empujon := prob_empujar(atacante, defensor)
	if prob_empujon > 0.0 and rng.randf() < prob_empujon:
		resultado["empujon"] = true
	return resultado


## Probabilidad de que un golpe acertado empuje al defensor hacia atrás en la
## barra de turnos (solo con Fuerza explosiva y golpes con arma, no hechizos).
static func prob_empujar(atacante: Luchador, defensor: Luchador) -> float:
	if not atacante.hechizo.is_empty():
		return 0.0
	var prob := minf(DatosEstadisticas.EMPUJON_POR_EXPLOSIVA * atacante.puntos("fuerza_explosiva"),
		DatosEstadisticas.EMPUJON_MAXIMO)
	if prob <= 0.0:
		return 0.0
	prob *= DatosEstadisticas.reduccion(defensor.puntos("firmeza"), DatosEstadisticas.EMPUJON_POR_FIRMEZA)
	return prob * _resistencia_a_estados(defensor)


## Conciencia bajo la cual se desmaya: la Firmeza la baja.
static func umbral_desmayo(luchador: Luchador) -> float:
	return UMBRAL_DESMAYO * DatosEstadisticas.reduccion(luchador.puntos("firmeza"), DatosEstadisticas.DESMAYO_POR_FIRMEZA)


## La Resistencia baja un poco la probabilidad de cualquier estado en contra.
static func _resistencia_a_estados(defensor: Luchador) -> float:
	return DatosEstadisticas.reduccion(defensor.puntos("resistencia"), DatosEstadisticas.ESTADOS_POR_RESISTENCIA)


## Un golpe en la mano del arma (o, menos, en ese antebrazo) puede hacerla soltar.
## Si esa mano o brazo queda inutilizado, la suelta siempre.
static func _intentar_desarme(atacante: Luchador, defensor: Luchador, parte_id: String, tipo: Dictionary,
		integridad_despues: float, podia_empunar: bool, efectos: float, rng: RandomNumberGenerator) -> bool:
	if defensor.desarmado:
		return false
	var lado := defensor.lado_arma()
	var prob_base: float = tipo["prob_desarmar"] * efectos
	var prob := 0.0
	if parte_id == "mano_" + lado:
		prob = prob_base + (1.0 - integridad_despues / 100.0) * DESARME_POR_HERIDA
	elif parte_id == "antebrazo_" + lado:
		prob = prob_base * 0.4
	# Fuerza de agarre: desarma mejor y lo desarman menos.
	prob *= DatosEstadisticas.aumento(atacante.puntos("fuerza_agarre"), DatosEstadisticas.DESARME_POR_AGARRE)
	prob *= DatosEstadisticas.reduccion(defensor.puntos("fuerza_agarre"), DatosEstadisticas.DESARME_POR_AGARRE)
	prob *= _resistencia_a_estados(defensor)
	# Si el brazo del arma ya no puede sostenerla (por un golpe en ese brazo o en el
	# cuello, que afecta la columna), la suelta siempre.
	if not defensor.puede_empunar(lado) and (podia_empunar or DatosCuerpo.zona_de(parte_id) == "brazo_" + lado):
		prob = 1.0
	if prob > 0.0 and rng.randf() < prob:
		defensor.desarmado = true
		return true
	return false


## Probabilidad de huir: depende de las piernas de ambos y de la Velocidad.
static func prob_huir(quien_huye: Luchador, perseguidor: Luchador) -> float:
	var prob := 0.25 + 0.5 * quien_huye.mov_piernas() - 0.2 * perseguidor.mov_piernas()
	prob += DatosEstadisticas.HUIDA_POR_VELOCIDAD * quien_huye.puntos("velocidad")
	return clampf(prob, 0.05, 0.9)


## La Presencia del rey supera de lejos el coraje del rival.
static func puede_atemorizar(rey: Luchador, rival: Luchador) -> bool:
	return rey.tiene_estadisticas and rey.valor_de("presencia") >= rival.coraje + DatosEstadisticas.VENTAJA_PARA_ATEMORIZAR
