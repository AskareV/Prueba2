class_name EstadoReino
extends Node
## Estado de la partida del reino (autoload "Juego"): semana, oro, estrés,
## inventario, equipo, la salud del rey, la ciudad y lo que está en curso
## (mazmorra, zona o combate). Por ahora el juego no tiene fin: las semanas
## siguen sin límite. La partida del autoload se guarda sola en ARCHIVO cada vez
## que algo cambia (lo mira cada segundo) y al salir o pasar la aplicación a
## segundo plano; al abrir el juego se carga.

## Estrés que baja al descansar una semana en el castillo (provisional).
const ESTRES_DESCANSO := 40.0
## Archivo de la partida guardada. Si cambia el formato, sube la versión y las
## partidas viejas se ignoran.
const ARCHIVO := "user://partida.save"
const VERSION_GUARDADO := 1
## Cada cuántos segundos se mira si hay algo nuevo que guardar.
const INTERVALO_GUARDADO := 1.0

var en_curso := false
var semana := 1
var oro := 0
var estres := 0.0
var diestro := true
## Objetos guardados (los más nuevos primero). Cada uno tiene un "id" único.
var inventario: Array[Dictionary] = []
## Objeto equipado en cada ranura (ver DatosBotin.RANURAS).
var equipo: Dictionary = {}
## Dominio (0 a 100) de cada trabajo del rey.
## Mazmorra en curso (ver mazmorra.gd) o vacío.
var mazmorra: Dictionary = {}
## Salida a una zona en curso (ver expedicion.gd) o vacío.
var expedicion: Dictionary = {}
## Combate del reino: {"origen", "escena", "rival", "resultado"} o vacío.
var combate: Dictionary = {}
## Mensaje para mostrar al volver a la pantalla principal del reino.
var aviso := ""
## Pestaña que abre la pantalla del reino al volver (ej. "aventura").
var pestana := "rey"
var rng := RandomNumberGenerator.new()
## Semilla propia de la partida: cada partida tiene sus propias mazmorras.
var semilla := 0
var _siguiente_id := 1

## Nivel y experiencia (ver DatosEstadisticas.xp_para_subir).
var nivel := 1
var xp := 0
## Puntos sin repartir para las principales.
var puntos_principales := 0
## Puntos sin repartir para las subs, por principal: {principal: n}. Solo se
## gastan en las 3 subs de esa principal.
var puntos_sub: Dictionary = {}
## Puntos puestos en cada principal (sube sus 3 subs) y en cada sub.
var veces: Dictionary = {}
var extra: Dictionary = {}

## Ciudad (ver DatosCiudad): nivel de cada edificio (0 = en ruinas), comida,
## soldados, peligro (0 a 100), lo que vende el mercado esta semana y el informe
## de la última semana.
var edificios: Dictionary = {}
var comida := 0
var soldados := 0
var peligro := 0.0
var mercado: Array[Dictionary] = []
var informe_ciudad: Dictionary = {}

## Salud del rey entre combates (las heridas duran): vida y maná que le faltan,
## integridad de las partes heridas (las que no están, sanas), fracturas y golpes
## recibidos en las partes que siguen heridas.
var vida_perdida := 0
var mana_perdido := 0.0
var integridad: Dictionary = {}
var fracturas: Dictionary = {}
var heridas: Array[Dictionary] = []
## Decimales de vida curada que todavía no llegan a un punto (al caminar se cura
## poco a poco: así Recuperación también se nota ahí).
var resto_vida := 0.0
## Sangre que le falta (litros) y partes que siguen sangrando (ver
## Luchador.sangrados). Infecciones: [{"parte", "etapa": 0 a 3 (ver
## DatosHeridas.ETAPAS), "limpia": la limpió y vendó pronto, "sucia": la herida
## se hizo en una mazmorra}].
var sangre_perdida := 0.0
var sangrados: Array[Dictionary] = []
var infecciones: Array[Dictionary] = []
## Días de esta semana que ya pasaron para las infecciones (en una zona, uno por
## día de marcha); al pasar la semana pasan los que faltan.
var dias_semana := 0

## Solo la partida del autoload se guarda sola (las de las pruebas, no).
var _guardado_automatico := false
var _ultimo_guardado := ""
var _reloj_guardado := 0.0


func _ready() -> void:
	_guardado_automatico = true
	cargar()


func _process(delta: float) -> void:
	if not _guardado_automatico or not en_curso:
		return
	_reloj_guardado += delta
	if _reloj_guardado >= INTERVALO_GUARDADO:
		_reloj_guardado = 0.0
		guardar()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if _guardado_automatico and en_curso:
			guardar()


func nueva_partida(p_diestro: bool) -> void:
	en_curso = true
	semana = 1
	oro = 0
	estres = 0.0
	diestro = p_diestro
	inventario = []
	equipo = {}
	mazmorra = {}
	expedicion = {}
	combate = {}
	aviso = ""
	pestana = "rey"
	_siguiente_id = 1
	rng.randomize()
	semilla = rng.randi()
	equipo["arma"] = _con_id(DatosBotin.crear_arma("espada", 1, "normal"))
	nivel = 1
	xp = 0
	puntos_principales = DatosEstadisticas.PUNTOS_INICIALES
	puntos_sub = {}
	veces = {}
	extra = {}
	edificios = DatosCiudad.NIVEL_INICIAL.duplicate()
	comida = DatosCiudad.COMIDA_INICIAL
	soldados = 0
	peligro = 0.0
	mercado = []
	informe_ciudad = {}
	vida_perdida = 0
	mana_perdido = 0.0
	integridad = {}
	fracturas = {}
	heridas = []
	resto_vida = 0.0
	sangre_perdida = 0.0
	sangrados = []
	infecciones = []
	dias_semana = 0
	aviso = "Reparte tus %d puntos iniciales en la pestaña Rey." % DatosEstadisticas.PUNTOS_INICIALES


# --- Guardar y cargar ---

## Todo lo que hace falta para seguir la partida, en un diccionario.
func datos_guardado() -> Dictionary:
	return {
		"version": VERSION_GUARDADO, "semana": semana, "oro": oro, "estres": estres, "diestro": diestro,
		"inventario": inventario, "equipo": equipo, "mazmorra": mazmorra,
		"expedicion": expedicion, "combate": combate, "aviso": aviso, "pestana": pestana,
		"semilla": semilla, "siguiente_id": _siguiente_id, "rng_semilla": rng.seed, "rng_estado": rng.state,
		"nivel": nivel, "xp": xp, "puntos_principales": puntos_principales, "puntos_sub": puntos_sub,
		"veces": veces, "extra": extra, "edificios": edificios, "comida": comida, "soldados": soldados,
		"peligro": peligro, "mercado": mercado, "informe_ciudad": informe_ciudad,
		"vida_perdida": vida_perdida, "mana_perdido": mana_perdido, "integridad": integridad,
		"fracturas": fracturas, "heridas": heridas, "resto_vida": resto_vida,
		"sangre_perdida": sangre_perdida, "sangrados": sangrados, "infecciones": infecciones,
		"dias_semana": dias_semana,
	}


## Tipo de cada dato guardado (los números pueden venir como enteros o decimales).
const TIPOS_GUARDADO := {
	"semana": TYPE_INT, "oro": TYPE_INT, "estres": TYPE_FLOAT, "diestro": TYPE_BOOL,
	"inventario": TYPE_ARRAY, "equipo": TYPE_DICTIONARY,
	"mazmorra": TYPE_DICTIONARY, "expedicion": TYPE_DICTIONARY, "combate": TYPE_DICTIONARY,
	"aviso": TYPE_STRING, "pestana": TYPE_STRING, "semilla": TYPE_INT, "siguiente_id": TYPE_INT,
	"rng_semilla": TYPE_INT, "rng_estado": TYPE_INT, "nivel": TYPE_INT, "xp": TYPE_INT,
	"puntos_principales": TYPE_INT, "puntos_sub": TYPE_DICTIONARY, "veces": TYPE_DICTIONARY,
	"extra": TYPE_DICTIONARY, "edificios": TYPE_DICTIONARY, "comida": TYPE_INT, "soldados": TYPE_INT,
	"peligro": TYPE_FLOAT, "mercado": TYPE_ARRAY, "informe_ciudad": TYPE_DICTIONARY,
	"vida_perdida": TYPE_INT, "mana_perdido": TYPE_FLOAT, "integridad": TYPE_DICTIONARY,
	"fracturas": TYPE_DICTIONARY, "heridas": TYPE_ARRAY, "resto_vida": TYPE_FLOAT,
	"sangre_perdida": TYPE_FLOAT, "sangrados": TYPE_ARRAY, "infecciones": TYPE_ARRAY, "dias_semana": TYPE_INT,
}


## Los datos guardados tienen el tipo que se espera (así un archivo dañado no deja
## la partida a medio cargar).
static func _guardado_valido(datos: Dictionary) -> bool:
	for clave in TIPOS_GUARDADO:
		if not datos.has(clave):
			continue
		var tipo := typeof(datos[clave])
		var esperado: int = TIPOS_GUARDADO[clave]
		var numero := esperado in [TYPE_INT, TYPE_FLOAT] and tipo in [TYPE_INT, TYPE_FLOAT]
		if tipo != esperado and not numero:
			return false
	for clave in ["inventario", "mercado", "heridas", "sangrados", "infecciones"]:
		for elemento in datos.get(clave, []):
			if not (elemento is Dictionary):
				return false
	return true


## Guarda la partida si cambió algo desde la última vez. Escribe primero en un
## archivo aparte y después lo renombra: si la aplicación se cierra a la mitad,
## la partida anterior sigue entera. Devuelve false si no se pudo escribir.
func guardar(ruta := ARCHIVO) -> bool:
	var texto := var_to_str(datos_guardado())
	if texto == _ultimo_guardado:
		return true
	var temporal := ruta + ".tmp"
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	if DirAccess.rename_absolute(temporal, ruta) != OK:
		return false
	_ultimo_guardado = texto
	return true


## Carga la partida guardada, si hay una válida. Lo que falte en el archivo queda
## como en una partida nueva.
func cargar(ruta := ARCHIVO) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var datos: Variant = str_to_var(FileAccess.get_file_as_string(ruta))
	if not (datos is Dictionary) or int(datos.get("version", 0)) != VERSION_GUARDADO or not _guardado_valido(datos):
		return false
	nueva_partida(bool(datos.get("diestro", true)))
	semana = int(datos.get("semana", semana))
	oro = int(datos.get("oro", oro))
	estres = float(datos.get("estres", estres))
	inventario.assign(datos.get("inventario", inventario))
	equipo = datos.get("equipo", equipo)
	mazmorra = datos.get("mazmorra", mazmorra)
	expedicion = datos.get("expedicion", expedicion)
	combate = datos.get("combate", combate)
	aviso = String(datos.get("aviso", ""))
	pestana = String(datos.get("pestana", pestana))
	semilla = int(datos.get("semilla", semilla))
	_siguiente_id = int(datos.get("siguiente_id", _siguiente_id))
	rng.seed = int(datos.get("rng_semilla", rng.seed))
	rng.state = int(datos.get("rng_estado", rng.state))
	nivel = int(datos.get("nivel", nivel))
	xp = int(datos.get("xp", xp))
	puntos_principales = int(datos.get("puntos_principales", puntos_principales))
	puntos_sub = datos.get("puntos_sub", puntos_sub)
	veces = datos.get("veces", veces)
	extra = datos.get("extra", extra)
	edificios = DatosCiudad.NIVEL_INICIAL.merged(datos.get("edificios", {}), true)
	comida = int(datos.get("comida", comida))
	soldados = int(datos.get("soldados", soldados))
	peligro = float(datos.get("peligro", peligro))
	mercado.assign(datos.get("mercado", mercado))
	informe_ciudad = datos.get("informe_ciudad", informe_ciudad)
	vida_perdida = int(datos.get("vida_perdida", 0))
	mana_perdido = float(datos.get("mana_perdido", 0.0))
	integridad = datos.get("integridad", {})
	fracturas = datos.get("fracturas", {})
	heridas.assign(datos.get("heridas", []))
	resto_vida = float(datos.get("resto_vida", 0.0))
	sangre_perdida = float(datos.get("sangre_perdida", 0.0))
	sangrados.assign(datos.get("sangrados", []))
	infecciones.assign(datos.get("infecciones", []))
	dias_semana = int(datos.get("dias_semana", 0))
	_ultimo_guardado = var_to_str(datos_guardado())
	return true




# --- Semanas y estrés ---

## Termina la semana: la ciudad vive su semana (ver semana_ciudad), las
## mazmorras se reinician, el rey recupera todo su maná y empieza la siguiente.
## Las heridas no se curan solas: hay que descansar (o caminar, o una poción). En
## el castillo le vendan las heridas (dejan de sangrar por fuera) y pasan los
## días que faltan de la semana para las infecciones.
func pasar_semana() -> void:
	semana_ciudad()
	DatosHeridas.parar(sangrados, "externo")
	var salud := avanzar_dias(DatosHeridas.DIAS_POR_SEMANA - dias_semana)
	if salud["texto"] != "":
		informe_ciudad["salud"] = salud["texto"]
	dias_semana = 0
	semana += 1
	mazmorra = {}
	expedicion = {}
	combate = {}
	mana_perdido = 0.0


## Descansa una semana en el castillo: baja el estrés, recupera sangre y cura
## las heridas (más con la enfermería y con Recuperación). La enfermería además
## para el sangrado por dentro y cura las infecciones.
func descansar() -> void:
	sumar_estres(-ESTRES_DESCANSO)
	var fraccion := cura_al_descansar()
	recuperar_sangre(DatosHeridas.SANGRE_MAX * fraccion * multiplicador_curacion())
	if nivel_edificio("enfermeria") > 0:
		DatosHeridas.parar(sangrados, "interno")
		infecciones = []
	curar_fraccion(fraccion)
	pasar_semana()


func sumar_estres(cantidad: float) -> void:
	# Redondeado a centésimas: sumar 1,4 cincuenta veces debe dar 70 justo, no 69,999…
	estres = clampf(snappedf(estres + cantidad, 0.01), 0.0, 100.0)


# --- Inventario y equipo ---

func _con_id(objeto: Dictionary) -> Dictionary:
	objeto["id"] = _siguiente_id
	_siguiente_id += 1
	return objeto


## Guarda un objeto nuevo en el inventario y lo devuelve con su id. Las pociones,
## vendas, torniquetes y medicinas se apilan: si ya hay de ese tipo, suma a la
## cantidad y devuelve esa pila.
func agregar(objeto: Dictionary) -> Dictionary:
	if DatosBotin.es_consumible(objeto):
		for guardado in inventario:
			if guardado["ranura"] == objeto["ranura"]:
				guardado["cantidad"] = int(guardado.get("cantidad", 1)) + int(objeto.get("cantidad", 1))
				return guardado
	var guardado := _con_id(objeto)
	inventario.push_front(guardado)
	return guardado


func _indice(id: int) -> int:
	for i in inventario.size():
		if inventario[i]["id"] == id:
			return i
	return -1


## Vende un objeto del inventario (de una pila, uno). Devuelve el oro ganado (0
## si no estaba).
func vender(id: int) -> int:
	var i := _indice(id)
	if i < 0:
		return 0
	var objeto: Dictionary = inventario[i]
	var precio := precio_venta(objeto)
	if DatosBotin.es_consumible(objeto) and int(objeto.get("cantidad", 1)) > 1:
		objeto["cantidad"] = int(objeto["cantidad"]) - 1
	else:
		inventario.remove_at(i)
	oro += precio
	return precio


## Equipa un objeto del inventario; lo que había en esa ranura vuelve al inventario.
func equipar(id: int) -> bool:
	var i := _indice(id)
	if i < 0 or DatosBotin.es_consumible(inventario[i]):
		return false
	var objeto: Dictionary = inventario[i]
	inventario.remove_at(i)
	var ranura: String = objeto["ranura"]
	if equipo.has(ranura):
		inventario.push_front(equipo[ranura])
	equipo[ranura] = objeto
	return true


## Guarda en el inventario lo que hay en esa ranura. El arma no se puede quitar
## (se cambia equipando otra).
func quitar(ranura: String) -> bool:
	if ranura == "arma" or not equipo.has(ranura):
		return false
	inventario.push_front(equipo[ranura])
	equipo.erase(ranura)
	return true


## Armadura total por zona del cuerpo: zona -> {"fisica": n, "magica": n}.
func armadura_por_zona() -> Dictionary:
	var total := {}
	for ranura in DatosBotin.PIEZAS:
		if not equipo.has(ranura):
			continue
		var pieza: Dictionary = equipo[ranura]
		for zona_id in DatosBotin.RANURAS[ranura]["zonas"]:
			var actual: Dictionary = total.get(zona_id, {"fisica": 0, "magica": 0})
			actual["fisica"] += int(pieza["armadura"])
			actual["magica"] += int(pieza["resistencia_magica"])
			total[zona_id] = actual
	return total


## El rey listo para combatir, con su arma, su armadura, sus características y
## las heridas que todavía tiene (siempre con al menos 1 de vida).
func crear_rey() -> Luchador:
	var arma: Dictionary = equipo.get("arma", {})
	var rey := DatosRivales.crear_rey(diestro, arma.get("base", "espada"), estadisticas())
	rey.arma_objeto = arma
	rey.armadura = armadura_por_zona()
	rey.sangre = DatosHeridas.SANGRE_MAX - sangre_perdida
	rey.sangrados.assign(sangrados.duplicate(true))
	rey.infeccion = peor_infeccion()
	rey.ajustar_vida_max()
	rey.vida = clampi(rey.vida_max_sana - vida_perdida, 1, rey.vida_max)
	rey.mana = clampf(rey.mana_max - mana_perdido, 0.0, rey.mana_max)
	for parte_id in integridad:
		rey.integridad[parte_id] = float(integridad[parte_id])
	rey.fracturas = fracturas.duplicate()
	rey.heridas.assign(heridas.duplicate(true))
	# Si la mano del arma quedó inútil, toma el arma con la otra (o pelea sin ella).
	if not rey.empunar():
		rey.desarmado = true
	return rey


# --- Salud del rey: las heridas duran entre combates ---

## Guarda cómo quedó el rey al terminar un combate. Aunque pierda, lo traen con
## 1 de vida y despierto (el cráneo justo por encima del desmayo); si se desangró,
## además le paran el sangrado. Las heridas abiertas nuevas quedan en riesgo de
## infección.
func guardar_salud(rey: Luchador) -> void:
	vida_perdida = mini(rey.vida_max_sana - rey.vida, rey.vida_max_sana - 1)
	mana_perdido = rey.mana_max - rey.mana
	sangre_perdida = DatosHeridas.SANGRE_MAX - rey.sangre
	sangrados.assign([] if rey.muerto else rey.sangrados.duplicate(true))
	integridad = {}
	for parte_id in rey.integridad:
		if rey.integridad[parte_id] < 100.0:
			integridad[parte_id] = rey.integridad[parte_id]
	if rey.desmayado:
		var despierto := MotorCombate.umbral_desmayo(rey) * 100.0 / rey.factor_fractura("craneo") + 1.0
		integridad["craneo"] = minf(maxf(float(integridad.get("craneo", 100.0)), despierto), 99.0)
	fracturas = {}
	for parte_id in rey.fracturas:
		if integridad.has(parte_id):
			fracturas[parte_id] = true
	_sumar_riesgos(rey.heridas)
	heridas.assign(rey.heridas.filter(func(herida: Dictionary) -> bool: return integridad.has(herida["parte"])))
	for herida in heridas:
		herida.erase("nueva")
		herida.erase("limpia")


## Las heridas abiertas nuevas (cortes y perforaciones) y las del abdomen quedan
## en riesgo de infección; las que se hicieron en una mazmorra, más. Una parte
## queda limpia solo si todas sus heridas nuevas se limpiaron con una venda.
func _sumar_riesgos(golpes: Array[Dictionary]) -> void:
	var sucia: bool = combate.get("origen", "") == "mazmorra"
	for herida in golpes:
		if not herida.get("nueva", false) or not DatosHeridas.abre_riesgo(herida):
			continue
		var limpia: bool = herida.get("limpia", false)
		var infeccion := infeccion_de(herida["parte"])
		if infeccion.is_empty():
			infecciones.append({"parte": herida["parte"], "etapa": 0, "limpia": limpia, "sucia": sucia})
		elif int(infeccion["etapa"]) == 0:
			infeccion["limpia"] = infeccion["limpia"] and limpia
			infeccion["sucia"] = infeccion["sucia"] or sucia


## Vida máxima con toda la sangre.
func vida_maxima_sana() -> int:
	return DatosEstadisticas.VIDA_BASE + DatosEstadisticas.vida_extra(puntos_de("vitalidad"))


## Vida máxima ahora: la sangre perdida la baja en la misma proporción.
func vida_maxima() -> int:
	return maxi(1, roundi(vida_maxima_sana() * fraccion_sangre()))


## Parte de la sangre que le queda (0 a 1).
func fraccion_sangre() -> float:
	return 1.0 - sangre_perdida / DatosHeridas.SANGRE_MAX


## 0 normal, 1 agitado, 2 débil y confuso, 3 shock (ver DatosHeridas).
func estado_sangre() -> int:
	return DatosHeridas.estado_por_perdida(sangre_perdida / DatosHeridas.SANGRE_MAX)


## Vida que tiene ahora (al menos 1: aunque pierda un combate, lo traen vivo).
func vida_actual() -> int:
	return clampi(vida_maxima_sana() - vida_perdida, 1, vida_maxima())


## Le falta vida (de la que puede tener ahora) o tiene alguna parte herida.
func esta_herido() -> bool:
	return vida_actual() < vida_maxima() or not integridad.is_empty()


## La vida no puede pasar de la máxima de ahora (baja con la sangre perdida).
func _limitar_vida() -> void:
	vida_perdida = maxi(vida_perdida, vida_maxima_sana() - vida_maxima())


## Pierde sangre fuera del combate. Devuelve true si se desangró (ver morir).
func perder_sangre(litros: float) -> bool:
	sangre_perdida = minf(sangre_perdida + maxf(litros, 0.0), DatosHeridas.SANGRE_MAX)
	_limitar_vida()
	return sangre_perdida >= DatosHeridas.SANGRE_MAX * DatosHeridas.MUERTE - 0.0001


func recuperar_sangre(litros: float) -> void:
	sangre_perdida = maxf(sangre_perdida - maxf(litros, 0.0), 0.0)


## Murió desangrado o de una infección: como al perder un combate, lo traen al
## castillo con 1 de vida y +50 de estrés, le paran el sangrado y le curan las
## infecciones.
func morir() -> void:
	vida_perdida = vida_maxima_sana() - 1
	sangrados = []
	infecciones = []
	sumar_estres(estres_mental(DatosAventura.ESTRES_DERROTA))


# --- Infecciones (B.4) ---

func infeccion_de(parte_id: String) -> Dictionary:
	for infeccion in infecciones:
		if infeccion["parte"] == parte_id:
			return infeccion
	return {}


## Etapa de la peor infección (0 si no hay ninguna o solo hay riesgo).
func peor_infeccion() -> int:
	var peor := 0
	for infeccion in infecciones:
		peor = maxi(peor, int(infeccion["etapa"]))
	return peor


## Pasan esos días para las infecciones (ver DatosHeridas): una herida en riesgo
## puede infectarse y una infección sin tratar, empeorar; la generalizada puede
## matarlo (ver morir). Devuelve {"texto": qué pasó, para contarlo ("" si nada),
## "muerte": si murió}.
func avanzar_dias(dias: int) -> Dictionary:
	var antes := {}
	for infeccion in infecciones:
		antes[infeccion["parte"]] = int(infeccion["etapa"])
	for dia in maxi(dias, 0):
		for infeccion in infecciones:
			var etapa := int(infeccion["etapa"])
			if etapa >= 3:
				if rng.randf() < DatosHeridas.MUERTE_POR_DIA:
					morir()
					return {"texto": "La infección casi te mata: te salvaron en el castillo.", "muerte": true}
			elif rng.randf() < DatosHeridas.prob_avance(infeccion):
				infeccion["etapa"] = etapa + 1
	var textos: PackedStringArray = []
	for infeccion in infecciones:
		var etapa := int(infeccion["etapa"])
		if etapa > int(antes.get(infeccion["parte"], 0)):
			textos.append(DatosHeridas.texto_avance(infeccion["parte"], etapa))
	return {"texto": " ".join(textos), "muerte": false}


## Un día de marcha en una zona también cuenta para las infecciones.
func pasar_dia() -> Dictionary:
	dias_semana += 1
	return avanzar_dias(1)


## Cuánto más se cura el rey gracias a Recuperación.
func multiplicador_curacion() -> float:
	return DatosEstadisticas.aumento(puntos_de("recuperacion"), DatosEstadisticas.CURA_POR_RECUPERACION)


## Cura "vida" puntos de vida (sin pasar de la vida máxima de ahora) y "partes"
## de integridad a cada parte herida (la mitad si está infectada). Una parte que
## se cura del todo deja de estar fracturada, olvida sus golpes, deja de sangrar
## y, si solo estaba en riesgo, de poder infectarse.
func curar(vida: int, partes: float) -> void:
	vida_perdida = maxi(vida_perdida - vida, 0)
	_limitar_vida()
	for parte_id in integridad.keys():
		var infeccion := infeccion_de(parte_id)
		var infectada := not infeccion.is_empty() and int(infeccion["etapa"]) > 0
		var valor := float(integridad[parte_id]) + partes * (DatosHeridas.CURA_INFECTADA if infectada else 1.0)
		if valor >= 100.0:
			integridad.erase(parte_id)
			fracturas.erase(parte_id)
		else:
			integridad[parte_id] = valor
	heridas.assign(heridas.filter(func(herida: Dictionary) -> bool: return integridad.has(herida["parte"])))
	sangrados.assign(sangrados.filter(func(sangrado: Dictionary) -> bool: return integridad.has(sangrado["parte"])))
	infecciones.assign(infecciones.filter(func(infeccion: Dictionary) -> bool:
		return int(infeccion["etapa"]) > 0 or integridad.has(infeccion["parte"])))


## Cura esa parte de la vida máxima y esos puntos ×100 de cada parte (0,05 = 5%
## de la vida y 5 de integridad), aumentado por Recuperación. Los decimales de
## vida se guardan para la próxima vez (sano, no se acumulan).
func curar_fraccion(fraccion: float) -> void:
	var exacta := _vida_exacta(fraccion)
	var entera := vida_curada(fraccion)
	resto_vida = exacta - entera if vida_perdida > entera else 0.0
	curar(entera, partes_curadas(fraccion))


## Vida que cura curar_fraccion ahora (con Recuperación y los decimales guardados).
func vida_curada(fraccion: float) -> int:
	# Un poco de margen: 100 × 0,01 debe dar 1, no 0,9999…
	return floori(_vida_exacta(fraccion) + 0.0001)


func _vida_exacta(fraccion: float) -> float:
	return vida_maxima_sana() * fraccion * multiplicador_curacion() + resto_vida


## Integridad que cura curar_fraccion a cada parte herida (con Recuperación).
func partes_curadas(fraccion: float) -> float:
	return 100.0 * fraccion * multiplicador_curacion()


## Al caminar el rey se va curando: cada paso de la mazmorra (y cada día de una
## zona, que cuenta como varios pasos) cura un poco la vida, todas las partes a
## la vez, el maná y la sangre. Antes pierde la sangre de las heridas que siguen
## sangrando (las leves paran solas). Devuelve true si se desangró por el camino:
## entonces muere (ver morir).
func curar_al_caminar(pasos := 1.0) -> bool:
	if perder_sangre(DatosHeridas.avanzar_sangrados(sangrados, roundi(pasos))):
		morir()
		return true
	recuperar_sangre(DatosHeridas.SANGRE_MAX * DatosHeridas.SANGRE_POR_PASO * pasos * multiplicador_curacion())
	curar_fraccion(DatosAventura.CURA_POR_PASO * pasos)
	mana_perdido = maxf(mana_perdido - DatosAventura.MANA_POR_PASO * pasos, 0.0)
	return false


## Lo que curaría descansar una semana ahora: {"vida": puntos (como mucho hasta
## la vida máxima que tendrá con la sangre recuperada), "partes": puntos de cada
## parte herida, "sangre": litros, "trata": la enfermería para el sangrado por
## dentro y cura las infecciones}.
func prevision_descanso() -> Dictionary:
	var fraccion := cura_al_descansar()
	var sangre := minf(DatosHeridas.SANGRE_MAX * fraccion * multiplicador_curacion(), sangre_perdida)
	var maxima := maxi(1, roundi(vida_maxima_sana() * (1.0 - (sangre_perdida - sangre) / DatosHeridas.SANGRE_MAX)))
	var trata := nivel_edificio("enfermeria") > 0 and (DatosHeridas.hay_sangrado(sangrados, "interno") or not infecciones.is_empty())
	return {"vida": clampi(vida_curada(fraccion), 0, maxi(maxima - vida_actual(), 0)), "partes": partes_curadas(fraccion),
		"sangre": sangre, "trata": trata}


## Le falta vida o sangre, o tiene alguna parte herida o una infección.
func necesita_curarse() -> bool:
	return esta_herido() or sangre_perdida > 0.005 or not infecciones.is_empty() or not sangrados.is_empty()


## Parte de la vida (y de cada parte herida) que cura descansar una semana en el
## castillo, antes de Recuperación: más con la enfermería.
func cura_al_descansar() -> float:
	return DatosCiudad.CURA_DESCANSO + DatosCiudad.CURA_ENFERMERIA[nivel_edificio("enfermeria")]


## Cuántos objetos de ese tipo (ver DatosBotin.CONSUMIBLES) tiene.
func cantidad(tipo: String) -> int:
	var total := 0
	for objeto in inventario:
		if objeto["ranura"] == tipo:
			total += int(objeto.get("cantidad", 1))
	return total


func pociones() -> int:
	return cantidad("pocion")


## Saca uno de esos objetos del inventario (los que se usan en combate se gastan
## al terminarlo). false si no hay.
func gastar(tipo: String) -> bool:
	for i in inventario.size():
		var objeto: Dictionary = inventario[i]
		if objeto["ranura"] != tipo:
			continue
		if int(objeto.get("cantidad", 1)) > 1:
			objeto["cantidad"] = int(objeto["cantidad"]) - 1
		else:
			inventario.remove_at(i)
		return true
	return false


func gastar_pocion() -> bool:
	return gastar("pocion")


## Usar ese objeto ahora (fuera del combate) haría algo.
func sirve(tipo: String) -> bool:
	match tipo:
		"pocion":
			return esta_herido()
		"venda":
			return DatosHeridas.hay_sangrado(sangrados, "externo") or not _riesgo_sin_limpiar().is_empty()
		"torniquete":
			return DatosHeridas.hay_sangrado(sangrados, "externo", true)
		"medicina":
			return DatosHeridas.hay_sangrado(sangrados, "interno") or infecciones.any(
				func(infeccion: Dictionary) -> bool: return int(infeccion["etapa"]) == 1)
	return false


## Usa uno de esos objetos fuera del combate. Devuelve qué hizo ("" si no tenía o
## no servía: entonces no lo gasta).
func usar(tipo: String) -> String:
	if cantidad(tipo) <= 0 or not sirve(tipo):
		return ""
	gastar(tipo)
	match tipo:
		"pocion":
			curar(DatosBotin.POCION_VIDA, DatosBotin.POCION_PARTES)
			return "Tomas una poción de curación."
		"venda":
			var parte_id := DatosHeridas.vendar(sangrados)
			var efecto := "baja su riesgo de infección"
			if parte_id == "":
				parte_id = String(_riesgo_sin_limpiar()["parte"])
			else:
				var sigue := sangrados.any(func(sangrado: Dictionary) -> bool:
					return sangrado["parte"] == parte_id and sangrado["tipo"] == "externo")
				efecto = "sangra menos" if sigue else "deja de sangrar"
			var infeccion := infeccion_de(parte_id)
			if not infeccion.is_empty() and int(infeccion["etapa"]) == 0:
				infeccion["limpia"] = true
			return "Limpias y vendas %s: %s." % [DatosCuerpo.con_articulo(parte_id), efecto]
		"torniquete":
			return "Pones un torniquete en %s: deja de sangrar." % DatosCuerpo.con_articulo(DatosHeridas.poner_torniquete(sangrados))
		"medicina":
			var efectos: PackedStringArray = []
			if DatosHeridas.parar(sangrados, "interno") > 0:
				efectos.append("dejas de sangrar por dentro")
			var leves := infecciones.filter(func(infeccion: Dictionary) -> bool: return int(infeccion["etapa"]) == 1).size()
			if leves > 0:
				efectos.append("se cura la infección leve" if leves == 1 else "se curan las infecciones leves")
			curar_infecciones_leves()
			return "Tomas una medicina: %s." % " y ".join(efectos)
	return ""


## Herida en riesgo de infección que todavía no se limpió (la de más riesgo), o
## vacío.
func _riesgo_sin_limpiar() -> Dictionary:
	var elegida := {}
	for infeccion in infecciones:
		if int(infeccion["etapa"]) == 0 and not infeccion["limpia"] \
				and (elegida.is_empty() or DatosHeridas.prob_avance(infeccion) > DatosHeridas.prob_avance(elegida)):
			elegida = infeccion
	return elegida


## La medicina cura las infecciones leves.
func curar_infecciones_leves() -> void:
	infecciones.assign(infecciones.filter(func(infeccion: Dictionary) -> bool: return int(infeccion["etapa"]) != 1))


## Toma una poción fuera del combate. false si no hay o si el rey está sano.
func usar_pocion() -> bool:
	return usar("pocion") != ""


# --- Características, experiencia y niveles ---

## Valor de una principal: la base más los puntos que recibió.
func valor_principal(car_id: String, pendientes := {}) -> float:
	return DatosEstadisticas.BASE + int(veces.get(car_id, 0)) + int(pendientes.get(car_id, 0))


## Valor de una sub: la base, +1 por cada punto en su principal, sus propios
## puntos y lo que suma el Amuleto. "pendientes_*" permite ver cómo quedaría
## antes de confirmar (puntos aún no aplicados).
func valor_sub(sub_id: String, pendientes_principal := {}, pendientes_sub := {}) -> float:
	var car_id := DatosEstadisticas.caracteristica_de(sub_id)
	var valor := valor_principal(car_id, pendientes_principal)
	valor += int(extra.get(sub_id, 0)) + int(pendientes_sub.get(sub_id, 0))
	if sub_id != "amuleto":
		var amuleto := valor_sub("amuleto", pendientes_principal, pendientes_sub)
		valor += DatosEstadisticas.AMULETO_POR_PUNTO * DatosEstadisticas.puntos_utiles(amuleto)
	return valor


## Puntos de una sub por encima de la base, como mucho el tope (de esto dependen
## los efectos).
func puntos_de(sub_id: String) -> float:
	return DatosEstadisticas.puntos_utiles(valor_sub(sub_id))


## Todas las subs con su valor, para el combate.
func estadisticas() -> Dictionary:
	var todas := {}
	for sub_id in DatosEstadisticas.todas_las_subs():
		todas[sub_id] = valor_sub(sub_id)
	return todas


## Puntos para las subs de una principal, contando los que darían los puntos
## principales "pendientes" (aún sin confirmar).
func puntos_sub_de(car_id: String, pendientes_principal := {}) -> int:
	return int(puntos_sub.get(car_id, 0)) \
		+ DatosEstadisticas.PUNTOS_SUB_POR_PRINCIPAL * int(pendientes_principal.get(car_id, 0))


## Todos los puntos para subs sin repartir (de todas las principales).
func total_puntos_sub() -> int:
	var total := 0
	for car_id in puntos_sub:
		total += int(puntos_sub[car_id])
	return total


## Aplica puntos repartidos: {principal: n} y {sub: n}. Los puntos de una sub
## salen de su principal, incluidos los que dan los puntos principales de esta
## misma vez. Devuelve false (sin aplicar nada) si no alcanzan los puntos o hay
## alguna clave inválida.
func aplicar_puntos(principales: Dictionary, subs: Dictionary) -> bool:
	var total_principales := 0
	for car_id in principales:
		if not DatosEstadisticas.CARACTERISTICAS.has(car_id) or int(principales[car_id]) < 0:
			return false
		total_principales += int(principales[car_id])
	if total_principales > puntos_principales:
		return false
	var gastados := {}
	for sub_id in subs:
		if not DatosEstadisticas.SUBS.has(sub_id) or int(subs[sub_id]) < 0:
			return false
		var car_id := DatosEstadisticas.caracteristica_de(sub_id)
		gastados[car_id] = int(gastados.get(car_id, 0)) + int(subs[sub_id])
	for car_id in gastados:
		if gastados[car_id] > puntos_sub_de(car_id, principales):
			return false
	for car_id in DatosEstadisticas.ORDEN:
		var restantes := puntos_sub_de(car_id, principales) - int(gastados.get(car_id, 0))
		if restantes > 0:
			puntos_sub[car_id] = restantes
		else:
			puntos_sub.erase(car_id)
	for car_id in principales:
		veces[car_id] = int(veces.get(car_id, 0)) + int(principales[car_id])
	for sub_id in subs:
		extra[sub_id] = int(extra.get(sub_id, 0)) + int(subs[sub_id])
	puntos_principales -= total_principales
	return true


func xp_para_subir() -> int:
	return DatosEstadisticas.xp_para_subir(nivel)


## Suma experiencia (con el extra de Estudio) y sube de nivel las veces que haga
## falta. Devuelve {"xp": ganada, "niveles": cuántos subió}.
func ganar_xp(cantidad: int) -> Dictionary:
	var ganada := roundi(cantidad * DatosEstadisticas.aumento(puntos_de("estudio"), DatosEstadisticas.XP_POR_ESTUDIO))
	xp += ganada
	var niveles := 0
	while xp >= xp_para_subir():
		xp -= xp_para_subir()
		nivel += 1
		niveles += 1
		puntos_principales += DatosEstadisticas.PUNTOS_PRINCIPAL_POR_NIVEL
	return {"xp": ganada, "niveles": niveles}


## Texto corto de la experiencia ganada para los mensajes ("+20 de experiencia").
func texto_xp(resultado_xp: Dictionary) -> String:
	var texto := "+%d de experiencia" % resultado_xp["xp"]
	if int(resultado_xp["niveles"]) > 0:
		texto += ". ¡Subiste al nivel %d! Reparte tus puntos en la pestaña Rey" % nivel
	return texto


# --- Efectos de las características fuera del combate ---

## Estrés de caminar: un paso en la mazmorra o un día de marcha en una zona
## (Cardio lo baja; la fiebre de una infección grave lo sube).
func estres_de_paso(base: float) -> float:
	return base * DatosEstadisticas.reduccion(puntos_de("cardio"), DatosEstadisticas.PASO_POR_CARDIO) \
		* DatosHeridas.ESTRES_FIEBRE[peor_infeccion()]


## Estrés de combates, trampas y trabajos (Compostura lo baja).
func estres_mental(base: float) -> float:
	return base * DatosEstadisticas.reduccion(puntos_de("compostura"), DatosEstadisticas.ESTRES_POR_COMPOSTURA)


## Oro de cofres y enemigos (Buen ojo lo sube).
func oro_hallado(base: int) -> int:
	return roundi(base * DatosEstadisticas.aumento(puntos_de("buen_ojo"), DatosEstadisticas.ORO_POR_BUEN_OJO))


## Probabilidad de que un enemigo vencido suelte un objeto (Buen ojo la sube).
func prob_botin_enemigo() -> float:
	return minf(DatosAventura.PROB_BOTIN_ENEMIGO * DatosEstadisticas.aumento(puntos_de("buen_ojo"),
		DatosEstadisticas.OBJETOS_POR_BUEN_OJO), 1.0)


## Multiplicador de las calidades raras o mejores del botín (Buen ojo).
func bonus_calidad() -> float:
	return DatosEstadisticas.aumento(puntos_de("buen_ojo"), DatosEstadisticas.CALIDAD_POR_BUEN_OJO)


## Lo que pagan por un objeto (Negociación lo sube).
func precio_venta(objeto: Dictionary) -> int:
	return roundi(int(objeto["precio"]) * DatosEstadisticas.aumento(puntos_de("negociacion"), DatosEstadisticas.VENTA_POR_NEGOCIACION))


## Multiplicador del pago de ese trabajo: lo suben sus tres partes (ver DatosTrabajos).
func multiplicador_pago(oficio_id: String) -> float:
	var puntos := {}
	for sub_id in DatosTrabajos.OFICIOS[oficio_id]["partes"]:
		puntos[sub_id] = puntos_de(sub_id)
	return DatosTrabajos.multiplicador(oficio_id, puntos)


## Oro por día que paga ese trabajo ahora.
func pago_trabajo(oficio_id: String) -> int:
	return DatosTrabajos.pago_dia(oficio_id, multiplicador_pago(oficio_id))


# --- Botín ---

## Recompensa por vencer a un enemigo en un lugar de ese nivel: oro, experiencia
## y, a veces, un objeto (ya guardado). El objeto es del nivel del lugar, y el
## oro del enemigo se ajusta a ese nivel (un matón, de nivel 2, da más en un
## lugar de nivel 3). Buen ojo mejora el oro, la calidad y lo seguido que sueltan
## objetos. Devuelve {"oro", "objeto" (o vacío), "xp", "niveles"}.
func recompensa_enemigo(enemigo_id: String, nivel_lugar: int) -> Dictionary:
	var datos := DatosRivales.rival(enemigo_id)
	var rango: Array = datos.get("oro", [3, 8])
	var escala := float(nivel_lugar) / float(datos.get("nivel", 1))
	var ganado := oro_hallado(roundi(rng.randi_range(rango[0], rango[1]) * escala))
	oro += ganado
	var objeto := {}
	if rng.randf() < prob_botin_enemigo():
		objeto = agregar(DatosBotin.generar_botin(nivel_lugar, rng, bonus_calidad()))
	var resultado := ganar_xp(DatosAventura.XP_POR_VICTORIA * nivel_lugar)
	resultado["oro"] = ganado
	resultado["objeto"] = objeto
	return resultado


## Un cofre siempre trae un objeto (a veces una poción), algo de oro y un poco
## de experiencia.
func abrir_cofre(nivel_lugar: int) -> Dictionary:
	var ganado := oro_hallado(rng.randi_range(5, 15) * nivel_lugar)
	oro += ganado
	var resultado := ganar_xp(DatosAventura.XP_POR_COFRE * nivel_lugar)
	resultado["oro"] = ganado
	resultado["objeto"] = agregar(DatosBotin.generar_botin(nivel_lugar, rng, bonus_calidad()))
	return resultado


# --- Trabajo ---

func puede_trabajar() -> bool:
	return estres < DatosTrabajos.ESTRES_MAXIMO


## true si el rey tiene lo que pide ese trabajo para entrar (ver DatosTrabajos).
func cumple_requisito(oficio_id: String) -> bool:
	var puntos := {}
	for sub_id in DatosTrabajos.requisito(oficio_id):
		puntos[sub_id] = puntos_de(sub_id)
	return DatosTrabajos.cumple_requisito(oficio_id, puntos)


## Trabaja la semana entera en ese oficio y pasa la semana (antes hay que mirar
## puede_trabajar y cumple_requisito). Las partes del trabajo suben el pago y
## Compostura baja el estrés.
func trabajar(oficio_id: String) -> Dictionary:
	var resultado := DatosTrabajos.trabajar_semana(oficio_id, multiplicador_pago(oficio_id))
	resultado["estres"] = estres_mental(resultado["estres"])
	oro += int(resultado["oro"])
	sumar_estres(resultado["estres"])
	pasar_semana()
	return resultado


# --- Ciudad ---

func nivel_edificio(edificio_id: String) -> int:
	return int(edificios.get(edificio_id, 0))


## Por qué no se puede mejorar ese edificio ahora ("" si se puede).
func motivo_sin_mejora(edificio_id: String) -> String:
	var nivel_actual := nivel_edificio(edificio_id)
	if nivel_actual >= DatosCiudad.NIVEL_MAXIMO:
		return "Ya está al nivel máximo."
	if edificio_id != "castillo" and nivel_actual >= nivel_edificio("castillo"):
		return "Primero mejora el castillo."
	if oro < DatosCiudad.costo_mejora(edificio_id, nivel_actual):
		return "No te alcanza el oro."
	return ""


## Reconstruye (desde las ruinas) o sube un nivel un edificio, pagando el oro.
func mejorar_edificio(edificio_id: String) -> bool:
	if not DatosCiudad.EDIFICIOS.has(edificio_id) or motivo_sin_mejora(edificio_id) != "":
		return false
	var nivel_actual := nivel_edificio(edificio_id)
	oro -= DatosCiudad.costo_mejora(edificio_id, nivel_actual)
	edificios[edificio_id] = nivel_actual + 1
	# Con más nivel el mercado vende más y mejores objetos desde ya.
	if edificio_id == "mercado":
		_renovar_mercado()
	return true


func soldados_maximos() -> int:
	return DatosCiudad.SOLDADOS_MAXIMOS[nivel_edificio("barracas")]


func puede_reclutar() -> bool:
	return soldados < soldados_maximos() and oro >= DatosCiudad.COSTO_SOLDADO


func reclutar() -> bool:
	if not puede_reclutar():
		return false
	oro -= DatosCiudad.COSTO_SOLDADO
	soldados += 1
	return true


## Moral de los soldados: Liderazgo la sube.
func moral() -> float:
	return DatosEstadisticas.aumento(puntos_de("liderazgo"), DatosEstadisticas.MORAL_POR_LIDERAZGO)


## Defensa de la ciudad: los soldados (con el equipo de la herrería y su moral)
## más las murallas del castillo.
func defensa_ciudad() -> float:
	var por_soldado: float = DatosCiudad.EQUIPO_SOLDADOS[nivel_edificio("herreria")] * moral()
	return soldados * por_soldado + DatosCiudad.MURALLAS[nivel_edificio("castillo")]


## Cuánto cambia el peligro en una semana con la defensa de ahora (negativo = baja).
func cambio_peligro() -> float:
	return DatosCiudad.PELIGRO_POR_SEMANA - DatosCiudad.PELIGRO_POR_DEFENSA * defensa_ciudad()


## Soldados que se irán al terminar esta semana por falta de comida.
func desertores_previstos() -> int:
	var resto := comida + produccion_comida() - consumo_comida()
	if resto >= 0:
		return 0
	return mini(ceili(-resto / float(DatosCiudad.COMIDA_POR_SOLDADO)), soldados)


## Cuánto cambiará el peligro al terminar esta semana: como cambio_peligro, pero
## sin los soldados que se irán por falta de comida (semana_ciudad los quita antes).
func cambio_peligro_previsto() -> float:
	var antes := soldados
	soldados -= desertores_previstos()
	var cambio := cambio_peligro()
	soldados = antes
	return cambio


## Peligro al terminar esta semana, que es también la probabilidad (%) de ataque.
func peligro_previsto() -> float:
	return clampf(peligro + cambio_peligro_previsto(), 0.0, 100.0)


func produccion_comida() -> int:
	return DatosCiudad.COMIDA_GRANJA[nivel_edificio("granja")]


func consumo_comida() -> int:
	return soldados * DatosCiudad.COMIDA_POR_SOLDADO


func impuestos() -> int:
	return DatosCiudad.IMPUESTOS[nivel_edificio("mercado")]


## La ciudad vive sola la semana que termina: la granja produce y los soldados
## comen (sin comida, algunos se van), el mercado cobra impuestos y cambia lo que
## vende, y el peligro sube o baja según la defensa. Con ese peligro (en %) hay
## probabilidad de un ataque, que defienden los soldados y las murallas sin el
## rey. Devuelve el informe y lo guarda en informe_ciudad.
func semana_ciudad() -> Dictionary:
	var informe := {"semana": semana, "nuevo": true}
	var producida := produccion_comida()
	var consumida := consumo_comida()
	comida += producida - consumida
	var desertores := 0
	if comida < 0:
		desertores = mini(ceili(-comida / float(DatosCiudad.COMIDA_POR_SOLDADO)), soldados)
		soldados -= desertores
		comida = 0
	informe["comida_producida"] = producida
	informe["comida_consumida"] = consumida
	informe["desertores"] = desertores
	var cobrado := impuestos()
	oro += cobrado
	informe["impuestos"] = cobrado
	var antes := peligro
	peligro = clampf(peligro + cambio_peligro(), 0.0, 100.0)
	informe["peligro_antes"] = antes
	informe["peligro_despues"] = peligro
	if rng.randf() * 100.0 < peligro:
		informe["ataque"] = _ataque_ciudad()
	informe["peligro_final"] = peligro
	_renovar_mercado()
	informe_ciudad = informe
	return informe


## Un ataque a la ciudad: fuerza del enemigo (crece con las semanas) contra la
## defensa, las dos con algo de azar.
func _ataque_ciudad() -> Dictionary:
	var fuerza := (DatosCiudad.FUERZA_BASE + DatosCiudad.FUERZA_POR_SEMANA * semana) \
		* rng.randf_range(DatosCiudad.AZAR_ATAQUE.x, DatosCiudad.AZAR_ATAQUE.y)
	var defensa := defensa_ciudad() * rng.randf_range(DatosCiudad.AZAR_DEFENSA.x, DatosCiudad.AZAR_DEFENSA.y)
	var ataque := {"fuerza": fuerza, "defensa": defensa, "ganado": defensa >= fuerza, "soldados": soldados}
	var soldados_antes := soldados
	if ataque["ganado"]:
		soldados -= rng.randi_range(0, floori(soldados * DatosCiudad.BAJAS_VICTORIA))
		ataque["bajas"] = soldados_antes - soldados
		peligro = maxf(peligro - DatosCiudad.PELIGRO_VICTORIA, 0.0)
		return ataque
	var oro_perdido := roundi(oro * DatosCiudad.SAQUEO_ORO)
	var comida_perdida := roundi(comida * DatosCiudad.SAQUEO_COMIDA)
	oro -= oro_perdido
	comida -= comida_perdida
	soldados -= ceili(soldados * DatosCiudad.BAJAS_DERROTA)
	# Un edificio en pie (no el castillo) queda dañado: baja un nivel.
	var en_pie: Array[String] = []
	for edificio_id in DatosCiudad.ORDEN:
		if edificio_id != "castillo" and nivel_edificio(edificio_id) > 0:
			en_pie.append(edificio_id)
	var danado := ""
	if not en_pie.is_empty():
		danado = en_pie[rng.randi() % en_pie.size()]
		edificios[danado] = nivel_edificio(danado) - 1
		soldados = mini(soldados, soldados_maximos())
	peligro = maxf(peligro - DatosCiudad.PELIGRO_DERROTA, 0.0)
	# Las bajas incluyen a los que se van porque las barracas dañadas ya no tienen sitio.
	ataque.merge({"oro": oro_perdido, "comida": comida_perdida, "bajas": soldados_antes - soldados, "danado": danado})
	return ataque


## Una línea con lo importante de una semana de la ciudad ("" si no pasó nada
## grave): ataques, soldados que se fueron por falta de comida y lo que pasó con
## las infecciones del rey.
func texto_informe(informe: Dictionary) -> String:
	var partes: PackedStringArray = []
	if informe.get("salud", "") != "":
		partes.append(informe["salud"])
	if informe.has("ataque"):
		var ataque: Dictionary = informe["ataque"]
		var bajas := int(ataque["bajas"])
		if ataque["ganado"]:
			if int(ataque["soldados"]) == 0:
				partes.append("Atacaron la ciudad y las murallas la defendieron.")
			elif bajas == 0:
				partes.append("Atacaron la ciudad y los soldados la defendieron sin bajas.")
			else:
				partes.append("Atacaron la ciudad y los soldados la defendieron (%s)." % _cantidad(bajas, "baja", "bajas"))
		else:
			# Solo lo que de verdad se perdió.
			var perdidas: PackedStringArray = []
			if int(ataque["oro"]) > 0:
				perdidas.append("−%d de oro" % ataque["oro"])
			if int(ataque["comida"]) > 0:
				perdidas.append("−%d de comida" % ataque["comida"])
			if bajas > 0:
				perdidas.append("−" + _cantidad(bajas, "soldado", "soldados"))
			if ataque["danado"] != "":
				perdidas.append("dañaron %s" % DatosCiudad.edificio(ataque["danado"])["articulo"])
			var texto := "Atacaron la ciudad y la saquearon"
			if not perdidas.is_empty():
				var ultima := perdidas[perdidas.size() - 1]
				perdidas.remove_at(perdidas.size() - 1)
				texto += ": " + (", ".join(perdidas) + " y " + ultima if not perdidas.is_empty() else ultima)
			partes.append(texto + ".")
	var desertores := int(informe.get("desertores", 0))
	if desertores > 0:
		partes.append("Faltó comida: %s %s." % ["se fue" if desertores == 1 else "se fueron", _cantidad(desertores, "soldado", "soldados")])
	return " ".join(partes)


## "1 soldado" o "3 soldados".
static func _cantidad(n: int, singular: String, plural: String) -> String:
	return "%d %s" % [n, singular if n == 1 else plural]


## Lo que vende el mercado esta semana: objetos al azar y unas pilas de
## pociones, vendas, torniquetes y medicinas.
func _renovar_mercado() -> void:
	mercado = []
	var nivel_mercado := nivel_edificio("mercado")
	for i in DatosCiudad.OBJETOS_MERCADO[nivel_mercado]:
		mercado.append(DatosBotin.generar(nivel_mercado, rng))
	for tipo in DatosBotin.ORDEN_CONSUMIBLES:
		var en_venta: int = DatosCiudad.CONSUMIBLES_MERCADO[tipo][nivel_mercado]
		if en_venta > 0:
			mercado.append(DatosBotin.crear_consumible(tipo, en_venta))


## Lo que cuesta comprar un objeto en el mercado (Negociación lo baja; por
## seguridad, nunca queda por debajo de lo que te pagarían al venderlo).
func precio_compra(objeto: Dictionary) -> int:
	var rebaja := DatosEstadisticas.reduccion(puntos_de("negociacion"), DatosEstadisticas.COMPRA_POR_NEGOCIACION)
	return maxi(roundi(int(objeto["precio"]) * DatosCiudad.MARGEN_MERCADO * rebaja), precio_venta(objeto) + 1)


## Compra el objeto "indice" del mercado (de una pila, uno) y lo guarda en el
## inventario.
func comprar(indice: int) -> bool:
	if indice < 0 or indice >= mercado.size():
		return false
	var objeto: Dictionary = mercado[indice]
	var precio := precio_compra(objeto)
	if oro < precio:
		return false
	oro -= precio
	if DatosBotin.es_consumible(objeto) and int(objeto.get("cantidad", 1)) > 1:
		objeto["cantidad"] = int(objeto["cantidad"]) - 1
		agregar(DatosBotin.crear_consumible(objeto["ranura"]))
	else:
		agregar(objeto)
		mercado.remove_at(indice)
	return true


## Calidad a la que la herrería puede subir ese objeto ("" si no puede: la
## herrería está en ruinas, el objeto ya tiene la calidad máxima que ella da).
func calidad_siguiente(objeto: Dictionary) -> String:
	var maxima: String = DatosCiudad.CALIDAD_MAXIMA_HERRERIA[nivel_edificio("herreria")]
	var actual := DatosBotin.CALIDADES.find(objeto["calidad"])
	if maxima == "" or actual < 0 or actual + 1 > DatosBotin.CALIDADES.find(maxima):
		return ""
	return DatosBotin.CALIDADES[actual + 1]


## Oro que cuesta mejorar ese objeto en la herrería (-1 si no se puede).
func costo_herreria(objeto: Dictionary) -> int:
	var siguiente := calidad_siguiente(objeto)
	if siguiente == "":
		return -1
	return roundi(DatosBotin.precio_venta({"calidad": siguiente, "nivel": objeto["nivel"]}) * DatosCiudad.COSTO_HERRERIA)


## Sube una calidad el objeto equipado en esa ranura.
func mejorar_en_herreria(ranura: String) -> bool:
	if not equipo.has(ranura):
		return false
	var objeto: Dictionary = equipo[ranura]
	var costo := costo_herreria(objeto)
	if costo < 0 or oro < costo:
		return false
	oro -= costo
	equipo[ranura] = DatosBotin.con_calidad(objeto, calidad_siguiente(objeto))
	return true
