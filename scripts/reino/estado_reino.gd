class_name EstadoReino
extends Node
## Estado de la partida del reino (autoload "Juego"): semana, oro, estrés,
## inventario, equipo, la ciudad y lo que está en curso (mazmorra, zona o combate).
## Por ahora el juego no tiene fin: las semanas siguen sin límite.
## Todavía no se guarda en disco: al cerrar la aplicación se pierde.

## Estrés que baja al descansar una semana en el castillo (provisional).
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

## Ciudad (ver DatosCiudad): nivel de cada edificio (0 = en ruinas), comida,
## soldados, peligro (0 a 100), lo que vende el mercado esta semana y el informe
## de la última semana.
var edificios: Dictionary = {}
var comida := 0
var soldados := 0
var peligro := 0.0
var mercado: Array[Dictionary] = []
var informe_ciudad: Dictionary = {}


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
	edificios = DatosCiudad.NIVEL_INICIAL.duplicate()
	comida = DatosCiudad.COMIDA_INICIAL
	soldados = 0
	peligro = 0.0
	mercado = []
	informe_ciudad = {}
	aviso = "Reparte tus %d puntos iniciales en la pestaña Rey." % DatosEstadisticas.PUNTOS_INICIALES


# --- Semanas y estrés ---

## Termina la semana: la ciudad vive su semana (ver semana_ciudad), las
## mazmorras se reinician y empieza la siguiente.
func pasar_semana() -> void:
	semana_ciudad()
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


## Lo que pagan por un objeto (Negociación lo sube, hasta VENTA_MAXIMA_NEGOCIACION).
func precio_venta(objeto: Dictionary) -> int:
	var aumento := minf(DatosEstadisticas.aumento(puntos_de("negociacion"), DatosEstadisticas.VENTA_POR_NEGOCIACION),
		DatosEstadisticas.VENTA_MAXIMA_NEGOCIACION)
	return roundi(int(objeto["precio"]) * aumento)


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
## grave): ataques y soldados que se fueron por falta de comida.
func texto_informe(informe: Dictionary) -> String:
	var partes: PackedStringArray = []
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


func _renovar_mercado() -> void:
	mercado = []
	var nivel_mercado := nivel_edificio("mercado")
	for i in DatosCiudad.OBJETOS_MERCADO[nivel_mercado]:
		mercado.append(DatosBotin.generar(nivel_mercado, rng))


## Lo que cuesta comprar un objeto en el mercado (Negociación lo baja hasta la
## mitad; por seguridad, nunca queda por debajo de lo que te pagarían al venderlo).
func precio_compra(objeto: Dictionary) -> int:
	var rebaja := maxf(1.0 - DatosEstadisticas.COMPRA_POR_NEGOCIACION * puntos_de("negociacion"), DatosCiudad.PRECIO_MINIMO)
	return maxi(roundi(int(objeto["precio"]) * DatosCiudad.MARGEN_MERCADO * rebaja), precio_venta(objeto) + 1)


## Compra el objeto "indice" del mercado y lo guarda en el inventario.
func comprar(indice: int) -> bool:
	if indice < 0 or indice >= mercado.size():
		return false
	var precio := precio_compra(mercado[indice])
	if oro < precio:
		return false
	oro -= precio
	agregar(mercado[indice])
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
