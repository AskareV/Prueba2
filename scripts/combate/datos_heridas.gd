class_name DatosHeridas
extends RefCounted
## Sangrado (docs/diseno.md, B.1) e infecciones (B.4). Todos los números son
## provisionales.
##
## Sangrado: cada luchador tiene SANGRE_MAX litros. Un golpe que corta o perfora
## hace sangrar por fuera; uno contundente en el cráneo, el tórax o el abdomen (o
## que fractura un muslo), por dentro. Cada parte que sangra tiene un nivel (leve,
## moderado o grave) y en cada turno propio, y en cada paso fuera del combate, se
## pierde la suma de todas. La sangre perdida baja la vida máxima en la misma
## proporción y trae los estados de ESTADOS_SANGRE.
##
## Infecciones: las heridas abiertas (cortes y perforaciones) y las del abdomen
## pueden infectarse. Avanzan por días, fuera del combate.

const SANGRE_MAX := 5.0

const NIVELES := ["", "leve", "moderado", "grave"]
## Litros que pierde cada parte que sangra, por turno propio o por paso.
const PERDIDA := [0.0, 0.01, 0.03, 0.08]
## Turnos (o pasos) que tarda en parar sola una herida leve.
const DURACION_LEVE := 3
## Fuerza del golpe × sangrado de la parte desde la que la herida es leve,
## moderada o grave.
const UMBRALES := [8.0, 16.0, 26.0]
## Cuánto sangra cada tipo de herida: cortes y perforaciones por fuera; los golpes
## contundentes, por dentro y solo en las partes con "interno" (ver DatosCuerpo).
const SANGRADO_POR_HERIDA := {
	"Corte": {"tipo": "externo", "factor": 1.0},
	"Perforación": {"tipo": "externo", "factor": 0.9},
	"Contusión": {"tipo": "interno", "factor": 0.6},
	"Fractura": {"tipo": "interno", "factor": 0.6},
}
## Una fractura de muslo sangra por dentro al menos así.
const NIVEL_FRACTURA_MUSLO := 2

## Estados según la parte de la sangre perdida (desde ese valor).
const AGITADO := 0.15
const DEBIL := 0.30
const SHOCK := 0.40
const MUERTE := 0.50
const ESTADOS_SANGRE := ["Normal", "Agitado", "Débil y confuso", "Shock"]
## Agitado: acierta un poco menos.
const ACIERTO_AGITADO := 0.92
## Débil y confuso: pega más flojo y a veces pierde el turno.
const DANIO_DEBIL := 0.85
const PROB_PERDER_TURNO := 0.15
## En shock puede desmayarse en cada turno.
const PROB_DESMAYO_SHOCK := 0.2
## Sangre que se recupera por cada paso fuera del combate (parte de SANGRE_MAX).
const SANGRE_POR_PASO := 0.005

## Infecciones: etapas. Avanzan por días: uno por cada día de marcha en una zona
## y, al pasar la semana, los que faltan hasta DIAS_POR_SEMANA.
const ETAPAS := ["En riesgo", "Infección leve", "Infección grave", "Infección generalizada"]
const DIAS_POR_SEMANA := 7
## Probabilidad por día de que una herida en riesgo se infecte.
const RIESGO_POR_DIA := 0.04
## Más riesgo si la herida se hizo en un lugar sucio (mazmorra) o en el abdomen.
const RIESGO_SUCIA := 2.0
const RIESGO_ABDOMEN := 1.5
## Limpiar y vendar la herida pronto baja el riesgo.
const RIESGO_LIMPIA := 0.3
## Probabilidad por día de pasar a la etapa siguiente sin tratamiento.
const AVANCE_POR_DIA := 0.1
## Infección generalizada: probabilidad por día de morir sin tratamiento.
const MUERTE_POR_DIA := 0.1
## Infección leve: la parte se cura a esta velocidad.
const CURA_INFECTADA := 0.5
## Fiebre (infección grave o generalizada): conciencia y estrés al caminar.
const CONCIENCIA_FIEBRE := [1.0, 1.0, 0.85, 0.7]
const ESTRES_FIEBRE := [1.0, 1.0, 1.5, 2.0]
## Heridas que abren la piel (las contusiones y quemaduras no).
const HERIDAS_ABIERTAS := ["Corte", "Perforación"]


## Hace sangrar esa parte: si ya sangraba (del mismo tipo), queda el nivel mayor;
## dos heridas moderadas en la misma parte la dejan grave. Devuelve el nivel con
## que queda.
static func sumar_sangrado(sangrados: Array[Dictionary], parte_id: String, tipo: String, nivel: int) -> int:
	for sangrado in sangrados:
		if sangrado["parte"] == parte_id and sangrado["tipo"] == tipo:
			var anterior := int(sangrado["nivel"])
			var nuevo := 3 if anterior == 2 and nivel == 2 else maxi(anterior, nivel)
			sangrado["nivel"] = nuevo
			sangrado["turnos"] = DURACION_LEVE
			return nuevo
	sangrados.append({"parte": parte_id, "tipo": tipo, "nivel": nivel, "turnos": DURACION_LEVE})
	return nivel


## Litros que pierden esas heridas en "turnos" turnos (o pasos). Las leves paran
## solas: salen de la lista cuando se les acaban los turnos.
static func avanzar_sangrados(sangrados: Array[Dictionary], turnos: int) -> float:
	var perdida := 0.0
	for sangrado in sangrados:
		var nivel := int(sangrado["nivel"])
		var duracion := turnos
		if nivel == 1:
			duracion = clampi(int(sangrado["turnos"]), 0, turnos)
			sangrado["turnos"] = int(sangrado["turnos"]) - turnos
		perdida += PERDIDA[nivel] * duracion
	sangrados.assign(sangrados.filter(func(sangrado: Dictionary) -> bool:
		return int(sangrado["nivel"]) > 1 or int(sangrado["turnos"]) > 0))
	return perdida


## Litros por turno que pierden ahora esas heridas.
static func perdida_por_turno(sangrados: Array[Dictionary]) -> float:
	var total := 0.0
	for sangrado in sangrados:
		total += PERDIDA[int(sangrado["nivel"])]
	return total


## Índice del sangrado de ese tipo que más sangra ("en_extremidad": solo brazos y
## piernas). -1 si no hay.
static func _peor(sangrados: Array[Dictionary], tipo: String, en_extremidad := false) -> int:
	var elegido := -1
	for i in sangrados.size():
		var sangrado: Dictionary = sangrados[i]
		if sangrado["tipo"] != tipo:
			continue
		if en_extremidad and DatosCuerpo.ZONAS[DatosCuerpo.zona_de(sangrado["parte"])]["defensa"] == "cubierta":
			continue
		if elegido < 0 or int(sangrado["nivel"]) > int(sangrados[elegido]["nivel"]):
			elegido = i
	return elegido


## Venda: para el sangrado por fuera que más sangra (si es grave, solo lo baja a
## moderado). Devuelve la parte vendada ("" si nada sangra por fuera).
static func vendar(sangrados: Array[Dictionary]) -> String:
	var i := _peor(sangrados, "externo")
	if i < 0:
		return ""
	var parte_id: String = sangrados[i]["parte"]
	if int(sangrados[i]["nivel"]) == 3:
		sangrados[i]["nivel"] = 2
	else:
		sangrados.remove_at(i)
	return parte_id


## Torniquete: para del todo el sangrado por fuera que más sangra en un brazo o
## una pierna. Devuelve la parte ("" si no hay).
static func poner_torniquete(sangrados: Array[Dictionary]) -> String:
	var i := _peor(sangrados, "externo", true)
	if i < 0:
		return ""
	var parte_id: String = sangrados[i]["parte"]
	sangrados.remove_at(i)
	return parte_id


## Para todos los sangrados de ese tipo. Devuelve cuántos paró.
static func parar(sangrados: Array[Dictionary], tipo: String) -> int:
	var antes := sangrados.size()
	sangrados.assign(sangrados.filter(func(sangrado: Dictionary) -> bool: return sangrado["tipo"] != tipo))
	return antes - sangrados.size()


static func hay_sangrado(sangrados: Array[Dictionary], tipo: String, en_extremidad := false) -> bool:
	return _peor(sangrados, tipo, en_extremidad) >= 0


## El sangrado de ese tipo que más sangra (vacío si no hay), sin tocarlo.
static func peor(sangrados: Array[Dictionary], tipo: String, en_extremidad := false) -> Dictionary:
	var i := _peor(sangrados, tipo, en_extremidad)
	return {} if i < 0 else sangrados[i]


## Nivel de sangrado (0 a 3) de un golpe de esa fuerza en una parte que sangra así.
static func nivel_por_fuerza(fuerza: float) -> int:
	var nivel := 0
	for umbral in UMBRALES:
		if fuerza >= umbral:
			nivel += 1
	return nivel


## Estado (0 a 3) según la parte de la sangre perdida (0 a 1).
static func estado_por_perdida(perdida: float) -> int:
	if perdida >= SHOCK:
		return 3
	if perdida >= DEBIL:
		return 2
	if perdida >= AGITADO:
		return 1
	return 0


## Una herida abre riesgo de infección si abre la piel o es del abdomen (las
## quemaduras no).
static func abre_riesgo(herida: Dictionary) -> bool:
	return herida["tipo"] in HERIDAS_ABIERTAS or (herida["parte"] == "abdomen" and herida["tipo"] != "Quemadura")


## Probabilidad por día de que esa infección pase a la etapa siguiente.
static func prob_avance(infeccion: Dictionary) -> float:
	if int(infeccion["etapa"]) > 0:
		return AVANCE_POR_DIA
	var prob := RIESGO_POR_DIA
	if infeccion.get("sucia", false):
		prob *= RIESGO_SUCIA
	if infeccion["parte"] == "abdomen":
		prob *= RIESGO_ABDOMEN
	if infeccion.get("limpia", false):
		prob *= RIESGO_LIMPIA
	return prob


## "La herida del muslo derecho se infectó." para las noticias de la semana.
static func texto_avance(parte_id: String, etapa: int) -> String:
	match etapa:
		1:
			return "La herida %s se infectó." % _de_parte(parte_id)
		2:
			return "La infección %s empeoró: tienes fiebre." % _de_parte(parte_id)
	return "La infección %s se generalizó: sin tratamiento puede matarte." % _de_parte(parte_id)


## "del muslo derecho", "de la mano izquierda"
static func _de_parte(parte_id: String) -> String:
	var parte: Dictionary = DatosCuerpo.PARTES[parte_id]
	return ("del " if parte["articulo"] == "el" else "de la ") + String(parte["texto"])


## "1,2 L"
static func litros(valor: float) -> String:
	return ("%.1f L" % valor).replace(".", ",")
