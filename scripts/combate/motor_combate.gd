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
const PENALIZACION_MANO_TORPE_PRECISION := 0.75
const PENALIZACION_MANO_TORPE_DANIO := 0.8
const REDUCCION_DANIO_EN_GUARDIA := 0.5


static func prob_acierto(atacante: Luchador, defensor: Luchador, parte_id: String) -> float:
	var arma: Dictionary = DatosArmas.arma(atacante.arma_actual())
	var tipo: Dictionary = DatosArmas.tipo(arma["tipo"])
	var tamano: float = DatosCuerpo.PARTES[parte_id]["tamano"]
	var exponente: float = tipo["exp_tamano"]
	var precision: float = arma["precision"]
	var prob := precision * pow(tamano, exponente)
	prob *= 0.5 + 0.5 * atacante.vision()
	if atacante.mano_torpe and not atacante.desarmado:
		prob *= PENALIZACION_MANO_TORPE_PRECISION
	prob *= 1.0 - defensor.esquiva()
	return clampf(prob, ACIERTO_MIN, ACIERTO_MAX)


## Promedio de acierto de las partes de una zona (para el botón de la zona).
static func prob_acierto_zona(atacante: Luchador, defensor: Luchador, zona_id: String) -> float:
	var partes := DatosCuerpo.partes_de(zona_id)
	var suma := 0.0
	for parte_id in partes:
		suma += prob_acierto(atacante, defensor, parte_id)
	return suma / partes.size()


static func multiplicador_danio(atacante: Luchador, defensor: Luchador, parte_id: String) -> float:
	var arma: Dictionary = DatosArmas.arma(atacante.arma_actual())
	var danio_parte: float = DatosCuerpo.PARTES[parte_id]["danio"]
	var mult := danio_parte * DatosArmas.afinidad(arma["tipo"], parte_id)
	mult *= 0.4 + 0.6 * atacante.fuerza_ataque()
	if atacante.mano_torpe and not atacante.desarmado:
		mult *= PENALIZACION_MANO_TORPE_DANIO
	if defensor.defendiendo:
		mult *= REDUCCION_DANIO_EN_GUARDIA
	return mult


## Daño mínimo y máximo de un golpe acertado en esa parte.
static func rango_danio(atacante: Luchador, defensor: Luchador, parte_id: String) -> Vector2i:
	var arma: Dictionary = DatosArmas.arma(atacante.arma_actual())
	var mult := multiplicador_danio(atacante, defensor, parte_id)
	var minimo: int = arma["danio_min"]
	var maximo: int = arma["danio_max"]
	return Vector2i(maxi(1, roundi(minimo * mult)), maxi(1, roundi(maximo * mult)))


## Resuelve un ataque y aplica sus efectos al defensor. Devuelve qué pasó:
## acierto, danio, herida, fractura, inutilizada, desarme, aturdido, desmayo.
static func resolver_ataque(atacante: Luchador, defensor: Luchador, parte_id: String,
		rng: RandomNumberGenerator, turno: int) -> Dictionary:
	var arma_id := atacante.arma_actual()
	var arma: Dictionary = DatosArmas.arma(arma_id)
	var tipo_id: String = arma["tipo"]
	var tipo: Dictionary = DatosArmas.tipo(tipo_id)
	var resultado := {
		"parte": parte_id, "arma": arma_id, "acierto": false, "danio": 0, "herida": "",
		"fractura": false, "inutilizada": false, "desarme": false, "aturdido": false,
		"desmayo": false,
	}
	atacante.ataques += 1
	if rng.randf() >= prob_acierto(atacante, defensor, parte_id):
		return resultado

	var danio_min: int = arma["danio_min"]
	var danio_max: int = arma["danio_max"]
	var base := rng.randi_range(danio_min, danio_max)
	var danio := maxi(1, roundi(base * multiplicador_danio(atacante, defensor, parte_id)))
	var herida: String = tipo["herida"]
	var podia_empunar := not defensor.desarmado and defensor.puede_empunar(defensor.lado_arma())
	var antes := defensor.recibir_golpe(parte_id, danio, herida, turno)
	var despues: float = defensor.integridad[parte_id]
	atacante.aciertos += 1
	atacante.danio_causado += danio
	resultado["acierto"] = true
	resultado["danio"] = danio
	resultado["herida"] = herida

	var es_hueso: bool = DatosCuerpo.PARTES[parte_id]["hueso"]
	if tipo_id == "contundente" and es_hueso and despues < UMBRAL_FRACTURA \
			and not defensor.fracturas.has(parte_id):
		defensor.fracturas[parte_id] = true
		defensor.heridas[-1]["tipo"] = "Fractura"
		resultado["fractura"] = true
		resultado["herida"] = "Fractura"

	if antes >= Luchador.INUTILIZADA and despues < Luchador.INUTILIZADA:
		resultado["inutilizada"] = true

	if defensor.conciencia() < UMBRAL_DESMAYO and not defensor.desmayado:
		defensor.desmayado = true
		resultado["desmayo"] = true
	# Quien queda fuera de combate ya no suelta el arma ni queda aturdido.
	if defensor.fuera_de_combate():
		return resultado

	var efectos: float = arma.get("efectos", 1.0)
	resultado["desarme"] = _intentar_desarme(defensor, parte_id, tipo, despues, podia_empunar, efectos, rng)

	if parte_id == "craneo" and not defensor.aturdido:
		var prob_base: float = tipo["prob_aturdir"] * efectos
		if rng.randf() < prob_base * (1.6 - defensor.conciencia()):
			defensor.aturdido = true
			resultado["aturdido"] = true
	return resultado


## Un golpe en la mano del arma (o, menos, en ese antebrazo) puede hacerla soltar.
## Si esa mano o brazo queda inutilizado, la suelta siempre.
static func _intentar_desarme(defensor: Luchador, parte_id: String, tipo: Dictionary,
		integridad_despues: float, podia_empunar: bool, efectos: float, rng: RandomNumberGenerator) -> bool:
	if defensor.desarmado:
		return false
	var lado := defensor.lado_arma()
	var prob_base: float = tipo["prob_desarmar"] * efectos
	var prob := 0.0
	if parte_id == "mano_" + lado:
		prob = prob_base + (1.0 - integridad_despues / 100.0) * 0.4
	elif parte_id == "antebrazo_" + lado:
		prob = prob_base * 0.4
	# Si el brazo del arma ya no puede sostenerla (por un golpe en ese brazo o en el
	# cuello, que afecta la columna), la suelta siempre.
	if not defensor.puede_empunar(lado) and (podia_empunar or DatosCuerpo.zona_de(parte_id) == "brazo_" + lado):
		prob = 1.0
	if prob > 0.0 and rng.randf() < prob:
		defensor.desarmado = true
		return true
	return false


## Probabilidad de huir: depende de las piernas de ambos.
static func prob_huir(quien_huye: Luchador, perseguidor: Luchador) -> float:
	var prob := 0.25 + 0.5 * quien_huye.mov_piernas() - 0.2 * perseguidor.mov_piernas()
	return clampf(prob, 0.05, 0.9)
