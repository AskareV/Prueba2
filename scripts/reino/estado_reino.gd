class_name EstadoReino
extends Node
## Estado de la partida del reino (autoload "Juego"): semana, oro, estrés,
## inventario, equipo y lo que está en curso (mazmorra, zona o combate).
## Por ahora el juego no tiene fin: las semanas siguen sin límite.
## Todavía no se guarda en disco: al cerrar la aplicación se pierde.

## Estrés que baja al descansar una semana (provisional, hasta que exista el
## descanso de la ciudad).
const ESTRES_DESCANSO := 40.0

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
var dominio: Dictionary = {}
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


func nueva_partida(p_diestro: bool) -> void:
	en_curso = true
	semana = 1
	oro = 0
	estres = 0.0
	diestro = p_diestro
	inventario = []
	equipo = {}
	dominio = {}
	mazmorra = {}
	expedicion = {}
	combate = {}
	aviso = ""
	pestana = "rey"
	_siguiente_id = 1
	rng.randomize()
	equipo["arma"] = _con_id(DatosBotin.crear_arma("espada", 1, "normal"))
	nivel = 1
	xp = 0
	puntos_principales = DatosEstadisticas.PUNTOS_INICIALES
	puntos_sub = {}
	veces = {}
	extra = {}
	aviso = "Reparte tus %d puntos iniciales en la pestaña Rey." % DatosEstadisticas.PUNTOS_INICIALES


# --- Semanas y estrés ---

## Termina la semana: las mazmorras se reinician y empieza la siguiente.
func pasar_semana() -> void:
	semana += 1
	mazmorra = {}
	expedicion = {}
	combate = {}


func descansar() -> void:
	sumar_estres(-ESTRES_DESCANSO)
	pasar_semana()


func sumar_estres(cantidad: float) -> void:
	# Redondeado a centésimas: sumar 1,4 cincuenta veces debe dar 70 justo, no 69,999…
	estres = clampf(snappedf(estres + cantidad, 0.01), 0.0, 100.0)


# --- Inventario y equipo ---

func _con_id(objeto: Dictionary) -> Dictionary:
	objeto["id"] = _siguiente_id
	_siguiente_id += 1
	return objeto


## Guarda un objeto nuevo en el inventario y lo devuelve con su id.
func agregar(objeto: Dictionary) -> Dictionary:
	var guardado := _con_id(objeto)
	inventario.push_front(guardado)
	return guardado


func _indice(id: int) -> int:
	for i in inventario.size():
		if inventario[i]["id"] == id:
			return i
	return -1


## Vende un objeto del inventario. Devuelve el oro ganado (0 si no estaba).
func vender(id: int) -> int:
	var i := _indice(id)
	if i < 0:
		return 0
	var precio := precio_venta(inventario[i])
	inventario.remove_at(i)
	oro += precio
	return precio


## Equipa un objeto del inventario; lo que había en esa ranura vuelve al inventario.
func equipar(id: int) -> bool:
	var i := _indice(id)
	if i < 0:
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


## El rey listo para combatir, con su arma, su armadura y sus características.
func crear_rey() -> Luchador:
	var arma: Dictionary = equipo.get("arma", {})
	var rey := DatosRivales.crear_rey(diestro, arma.get("base", "espada"), estadisticas())
	rey.arma_objeto = arma
	rey.armadura = armadura_por_zona()
	return rey


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
		valor += DatosEstadisticas.AMULETO_POR_PUNTO * maxf(amuleto - DatosEstadisticas.BASE, 0.0)
	return valor


## Puntos de una sub por encima de la base (de esto dependen los efectos).
func puntos_de(sub_id: String) -> float:
	return maxf(valor_sub(sub_id) - DatosEstadisticas.BASE, 0.0)


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

## Estrés de un paso en la mazmorra (Cardio lo baja).
func estres_de_paso(base: float) -> float:
	return base * DatosEstadisticas.reduccion(puntos_de("cardio"), DatosEstadisticas.PASO_POR_CARDIO)


## Estrés de combates, trampas y trabajos (Compostura lo baja).
func estres_mental(base: float) -> float:
	return base * DatosEstadisticas.reduccion(puntos_de("compostura"), DatosEstadisticas.ESTRES_POR_COMPOSTURA)


## Oro de cofres y enemigos (Buen ojo lo sube).
func oro_hallado(base: int) -> int:
	return roundi(base * DatosEstadisticas.aumento(puntos_de("buen_ojo"), DatosEstadisticas.ORO_POR_BUEN_OJO))


## Multiplicador de las calidades raras o mejores del botín (Buen ojo).
func bonus_calidad() -> float:
	return DatosEstadisticas.aumento(puntos_de("buen_ojo"), DatosEstadisticas.CALIDAD_POR_BUEN_OJO)


## Lo que pagan por un objeto (Negociación lo sube).
func precio_venta(objeto: Dictionary) -> int:
	return roundi(int(objeto["precio"]) * DatosEstadisticas.aumento(puntos_de("negociacion"), DatosEstadisticas.VENTA_POR_NEGOCIACION))


## Multiplicador del pago de los trabajos (Presencia).
func multiplicador_pago() -> float:
	return DatosEstadisticas.aumento(puntos_de("presencia"), DatosEstadisticas.PAGO_POR_PRESENCIA)


# --- Botín ---

## Recompensa por vencer a un enemigo en un lugar de ese nivel: oro, experiencia
## y, a veces, un objeto (ya guardado). El objeto es del nivel del lugar; el oro,
## el del enemigo (o según el nivel del lugar si no tiene). Buen ojo mejora el
## oro y la calidad. Devuelve {"oro", "objeto" (o vacío), "xp", "niveles"}.
func recompensa_enemigo(enemigo_id: String, nivel_lugar: int) -> Dictionary:
	var datos := DatosRivales.rival(enemigo_id)
	var rango: Array = datos.get("oro", [3 * nivel_lugar, 8 * nivel_lugar])
	var ganado := oro_hallado(rng.randi_range(rango[0], rango[1]))
	oro += ganado
	var objeto := {}
	if rng.randf() < DatosAventura.PROB_BOTIN_ENEMIGO:
		objeto = agregar(DatosBotin.generar(nivel_lugar, rng, "", "", bonus_calidad()))
	var resultado := ganar_xp(DatosAventura.XP_POR_VICTORIA * nivel_lugar)
	resultado["oro"] = ganado
	resultado["objeto"] = objeto
	return resultado


## Un cofre siempre trae un objeto, algo de oro y un poco de experiencia.
func abrir_cofre(nivel_lugar: int) -> Dictionary:
	var ganado := oro_hallado(rng.randi_range(5, 15) * nivel_lugar)
	oro += ganado
	var resultado := ganar_xp(DatosAventura.XP_POR_COFRE * nivel_lugar)
	resultado["oro"] = ganado
	resultado["objeto"] = agregar(DatosBotin.generar(nivel_lugar, rng, "", "", bonus_calidad()))
	return resultado


# --- Trabajo ---

func puede_trabajar() -> bool:
	return estres < DatosTrabajos.ESTRES_MAXIMO


## Trabaja la semana entera en ese oficio y pasa la semana. Presencia sube el
## pago y Compostura baja el estrés.
func trabajar(oficio_id: String) -> Dictionary:
	var resultado := DatosTrabajos.trabajar_semana(oficio_id, dominio.get(oficio_id, 0.0), rng, multiplicador_pago())
	resultado["estres"] = estres_mental(resultado["estres"])
	oro += int(resultado["oro"])
	sumar_estres(resultado["estres"])
	dominio[oficio_id] = resultado["dominio"]
	pasar_semana()
	return resultado
