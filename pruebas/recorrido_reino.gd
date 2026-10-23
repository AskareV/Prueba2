extends SceneTree
## Recorre el reino sin ventana, pulsando lo mismo que el jugador, para detectar
## errores en el flujo entre pantallas:
##   godot --headless --script res://pruebas/recorrido_reino.gd
## Menú -> reino (todas las pestañas; repartir los puntos del rey) -> mazmorra
## (pelear, abrir cofres y salir por la H) -> zona de siete días -> inventario
## (equipar y vender) -> trabajo -> ciudad (edificios, descanso y un ataque) ->
## salud (pociones en el inventario, la mazmorra y el combate; enfermería y
## descanso; un día agotado en una zona) -> sangrado (una venda en la
## mazmorra, desangrarse por el camino y una venda en un combate) -> un combate
## contra un chamán (magia de los enemigos) -> seguir la partida desde el menú
## (también tras guardarla y cargarla del disco).

const MENU := "res://escenas/menu_principal.tscn"
const PREPARACION := "res://escenas/preparacion.tscn"
## Archivo de prueba: el recorrido no toca la partida guardada de verdad.
const ARCHIVO_PRUEBA := "user://recorrido.save"
const REINO := "res://escenas/reino.tscn"
const MAZMORRA := "res://escenas/mazmorra.tscn"
const EXPEDICION := "res://escenas/expedicion.tscn"
const COMBATE := "res://escenas/combate.tscn"
const MAX_CUADROS := 6000
# Valores del enum Estado de combate.gd.
const ACCIONES := 1
const ZONA := 2
const PARTE := 3
const FIN := 5
const MAGIA := 6
const OBJETO := 7

var _rng := RandomNumberGenerator.new()
var _fallos: Array[String] = []
var _juego: EstadoReino


func _initialize() -> void:
	_rng.seed = 5
	Engine.time_scale = 30.0
	await process_frame
	_juego = root.get_node("Juego") as EstadoReino
	# Sin guardado automático: el recorrido no debe pisar la partida guardada.
	_juego.set("_guardado_automatico", false)
	_juego.nueva_partida(true)
	_juego.rng.seed = 5
	# Mazmorras fijas: el recorrido es siempre igual.
	_juego.semilla = 1
	for paso in [_recorrer_menu_y_pestanas, _recorrer_mazmorra, _recorrer_estres_maximo, _recorrer_zona,
			_recorrer_inventario, _recorrer_trabajo, _recorrer_ciudad, _recorrer_salud, _recorrer_agotado,
			_recorrer_sangre, _recorrer_magia_enemiga, _recorrer_continuar]:
		await paso.call()
		# Tras un fallo se corta: los pasos siguientes dependen de la pantalla.
		if not _fallos.is_empty():
			break
	if _fallos.is_empty():
		print("Recorrido del reino: todo bien (semana %d, %d de oro, %d objetos)" % [
			_juego.semana, _juego.oro, _juego.inventario.size()])
	else:
		for fallo in _fallos:
			print("  FALLA  %s" % fallo)
	quit(0 if _fallos.is_empty() else 1)


func _verificar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos.append(mensaje)


## Espera a que la escena actual sea esa. Devuelve la escena o null.
func _esperar_escena(ruta: String) -> Node:
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == ruta and current_scene.is_node_ready():
			return current_scene
	_fallos.append("No se abrió %s" % ruta.get_file())
	return null


func _recorrer_menu_y_pestanas() -> void:
	change_scene_to_file(MENU)
	var menu := await _esperar_escena(MENU)
	if menu == null:
		return
	menu.call("_al_continuar")
	var reino := await _esperar_escena(REINO)
	if reino == null:
		return
	for pestana in ["rey", "inventario", "ciudad", "aventura", "trabajo"]:
		reino.call("_mostrar_pestana", pestana)
		await process_frame
	await _repartir_puntos(reino)
	reino.call("_mostrar_pestana", "aventura")
	for lugar_id in DatosAventura.ORDEN_MAZMORRAS + DatosAventura.ORDEN_ZONAS:
		reino.call("_al_elegir_lugar", lugar_id)
		await process_frame
		reino.call("_cerrar_lugar")
		await process_frame


## Reparte los puntos del rey en la pestaña Rey (con deshacer y confirmar).
func _repartir_puntos(reino: Node) -> void:
	reino.call("_mostrar_pestana", "rey")
	await process_frame
	var principales: int = _juego.puntos_principales
	var por_principal := DatosEstadisticas.PUNTOS_SUB_POR_PRINCIPAL
	var fuerza_antes: float = _juego.valor_sub("fuerza_maxima")
	reino.call("_al_sumar_principal", "fuerza")
	_verificar(int(reino.call("_puntos_principales_libres")) == principales - 1, "El + deja el punto pendiente")
	_verificar(int(reino.call("_puntos_sub_libres", "fuerza")) == por_principal
		and int(reino.call("_puntos_sub_libres", "destreza")) == 0, "El punto en Fuerza da puntos solo para sus partes")
	_verificar(_mas_de_partes(reino, "fuerza") == 3 and _mas_de_partes(reino, "destreza") == 0,
		"Solo la tarjeta con puntos muestra los + de sus partes")
	reino.call("_al_sumar_sub", "velocidad")
	_verificar(not Dictionary(reino.get("_pend_sub")).has("velocidad"), "Sin puntos de Destreza, Velocidad no sube")
	reino.call("_al_sumar_sub", "fuerza_maxima")
	_verificar(int(reino.call("_puntos_sub_libres", "fuerza")) == por_principal - 1, "Fuerza máxima gasta un punto de Fuerza")
	reino.call("_al_deshacer_puntos")
	_verificar(not reino.call("_hay_pendientes") and int(reino.call("_puntos_principales_libres")) == principales
		and int(reino.call("_puntos_sub_libres", "fuerza")) == 0, "Deshacer devuelve los puntos")
	_verificar(_juego.valor_sub("fuerza_maxima") == fuerza_antes, "Deshacer no aplica los puntos")
	for i in principales:
		reino.call("_al_sumar_principal", DatosEstadisticas.ORDEN[i % DatosEstadisticas.ORDEN.size()])
		await process_frame
	# Todos los puntos de las partes de Fuerza, a Fuerza máxima.
	var de_fuerza: int = reino.call("_puntos_sub_libres", "fuerza")
	for i in de_fuerza:
		reino.call("_al_sumar_sub", "fuerza_maxima")
	await process_frame
	reino.call("_al_elegir_estadistica", "amuleto")
	await process_frame
	reino.call("_al_confirmar_puntos")
	await process_frame
	_verificar(_juego.puntos_principales == 0, "Se reparten todos los puntos principales")
	_verificar(_juego.valor_sub("fuerza_maxima") > fuerza_antes, "Un punto en Fuerza sube sus partes")
	_verificar(is_equal_approx(_juego.valor_sub("fuerza_maxima"), _juego.valor_sub("fuerza_explosiva") + de_fuerza),
		"Los puntos de Fuerza fueron a Fuerza máxima")
	_verificar(_juego.puntos_sub_de("fuerza") == 0 and _juego.total_puntos_sub() == principales * por_principal - de_fuerza,
		"Quedan los puntos de las otras características")
	# Subir un nivel da un punto principal: a Destreza, y uno de sus puntos a Velocidad.
	var de_partes := _juego.total_puntos_sub()
	_juego.ganar_xp(_juego.xp_para_subir())
	_verificar(_juego.puntos_principales == 1 and _juego.total_puntos_sub() == de_partes, "Subir de nivel da un punto principal")
	reino.call("_mostrar_pestana", "rey")
	await process_frame
	var velocidad_antes: float = _juego.valor_sub("velocidad")
	var de_destreza := _juego.puntos_sub_de("destreza")
	reino.call("_al_sumar_principal", "destreza")
	reino.call("_al_sumar_sub", "velocidad")
	reino.call("_al_confirmar_puntos")
	await process_frame
	_verificar(is_equal_approx(_juego.valor_sub("velocidad"), velocidad_antes + 2.0), "Destreza y un punto propio suben Velocidad")
	_verificar(_juego.puntos_sub_de("destreza") == de_destreza + por_principal - 1, "Al confirmar quedan los demás puntos de Destreza")


## Cuántos botones + de partes tiene la tarjeta de una característica (-1 si no está).
func _mas_de_partes(reino: Node, car_id: String) -> int:
	var nombre: String = DatosEstadisticas.CARACTERISTICAS[car_id]["nombre"]
	for tarjeta in (reino.get("_contenido") as Node).get_children():
		if tarjeta.is_queued_for_deletion() or tarjeta.get_child_count() == 0:
			continue
		var columna := tarjeta.get_child(0)
		if not columna is VBoxContainer or columna.get_child_count() == 0:
			continue
		var cabecera := columna.get_child(0)
		if not cabecera is HBoxContainer or not cabecera.get_child(0) is Button \
				or (cabecera.get_child(0) as Button).text != nombre:
			continue
		var total := 0
		for fila in columna.get_children().slice(1):
			for hijo in fila.get_children():
				if hijo is Button and (hijo as Button).text == "+":
					total += 1
		return total
	return -1


## Entra a la madriguera, pelea con dos enemigos (el primero de verdad), abre
## los cofres que encuentre por el camino y sale por la H.
func _recorrer_mazmorra() -> void:
	var reino := current_scene
	_juego.estres = 0.0
	reino.call("_al_explorar", "madriguera_goblin")
	var mazmorra := await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	mazmorra.call("_ocultar_ayuda")
	var semana: int = _juego.semana
	var enemigos_al_entrar: int = _juego.mazmorra["plano"]["enemigos"].size()
	var victorias := 0
	var peleas := 0
	for pasos in 200:
		if victorias >= 2 or peleas >= 4 or not is_instance_valid(mazmorra) or _juego.mazmorra.is_empty():
			break
		var plano: Dictionary = _juego.mazmorra["plano"]
		if plano["enemigos"].is_empty():
			break
		var paso := _paso_hacia(plano, _juego.mazmorra["pos"], plano["enemigos"].keys())
		mazmorra.call("_mover", paso)
		await process_frame
		if _juego.combate.is_empty():
			continue
		peleas += 1
		var resultado := await _pelear(peleas == 1)
		if resultado == "victoria":
			victorias += 1
		if resultado == "derrota":
			# Perder saca al rey de la mazmorra y termina la semana.
			print("Mazmorra: derrota en la pelea %d" % peleas)
			if await _esperar_escena(REINO) != null:
				_verificar(_juego.semana == semana + 1 and _juego.mazmorra.is_empty(), "Perder termina la semana")
			return
		mazmorra = await _esperar_escena(MAZMORRA)
		if mazmorra == null:
			return
		mazmorra.call("_ocultar_ayuda")
	print("Mazmorra: %d peleas, %d victorias" % [peleas, victorias])
	if _juego.mazmorra.is_empty():
		_fallos.append("El rey salió de la mazmorra antes de tiempo")
		return
	_verificar(victorias > 0, "Ganar al menos un combate en la mazmorra")
	_verificar(_juego.mazmorra["plano"]["enemigos"].size() == enemigos_al_entrar - victorias,
		"Los enemigos vencidos desaparecen del plano")
	# Volver a la H.
	for i in 200:
		var plano: Dictionary = _juego.mazmorra["plano"]
		var paso := _paso_hacia(plano, _juego.mazmorra["pos"], [plano["entrada"]], true)
		mazmorra.call("_mover", paso)
		await process_frame
		if not is_instance_valid(mazmorra) or _juego.mazmorra.is_empty():
			break
		if not _juego.combate.is_empty():
			_fallos.append("Pelea inesperada al volver a la H")
			return
	var reino_nuevo := await _esperar_escena(REINO)
	if reino_nuevo == null:
		return
	_verificar(_juego.semana == semana + 1, "Salir de la mazmorra termina la semana")
	_verificar(_juego.nivel > 1 or _juego.xp > 0, "Ganar combates y abrir cofres da experiencia")
	_verificar(_juego.mazmorra.is_empty(), "La mazmorra se reinicia al salir")
	_verificar((reino_nuevo.get("_aviso") as Label).text != "", "Al volver hay un aviso")


## Con el estrés casi al máximo, el paso hacia un enemigo saca al rey de la
## mazmorra en vez de empezar la pelea.
func _recorrer_estres_maximo() -> void:
	var reino := current_scene
	_juego.estres = 0.0
	reino.call("_al_explorar", "guarida_bandidos")
	var mazmorra := await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	mazmorra.call("_ocultar_ayuda")
	var semana: int = _juego.semana
	var probado := false
	for pasos in 100:
		var plano: Dictionary = _juego.mazmorra["plano"]
		var paso := _paso_hacia(plano, _juego.mazmorra["pos"], plano["enemigos"].keys())
		var destino: Vector2i = _juego.mazmorra["pos"] + paso
		if plano["enemigos"].has(destino):
			_juego.estres = DatosAventura.ESTRES_MAXIMO - 0.5
			probado = true
		mazmorra.call("_mover", paso)
		await process_frame
		if _juego.mazmorra.is_empty() or not _juego.combate.is_empty():
			break
	_verificar(probado, "Llegar al lado de un enemigo")
	_verificar(_juego.combate.is_empty(), "Con el estrés al máximo no empieza la pelea")
	if await _esperar_escena(REINO) == null:
		return
	_verificar(_juego.semana == semana + 1, "Salir por estrés termina la semana")


## Primer paso del camino más corto hasta alguna de las metas. Con "esquivar",
## evita las casillas con enemigos.
func _paso_hacia(plano: Dictionary, desde: Vector2i, metas: Array, esquivar := false) -> Vector2i:
	var celdas: Array = plano["celdas"]
	var previo := {desde: desde}
	var cola: Array[Vector2i] = [desde]
	while not cola.is_empty():
		var actual: Vector2i = cola.pop_front()
		if metas.has(actual):
			var paso := actual
			while previo[paso] != desde:
				paso = previo[paso]
			return paso - desde
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var siguiente: Vector2i = actual + d
			if previo.has(siguiente) or not GeneradorMazmorra.es_suelo(celdas, siguiente):
				continue
			if esquivar and plano["enemigos"].has(siguiente) and not metas.has(siguiente):
				continue
			previo[siguiente] = actual
			cola.append(siguiente)
	_fallos.append("No hay camino desde %s" % desde)
	return Vector2i.ZERO


## Juega el combate que está por abrirse. "de_verdad": ataca hasta que termine;
## si no, gana en el acto. Pulsa "Continuar" y devuelve el resultado.
func _pelear(de_verdad: bool) -> String:
	var escena := await _esperar_escena(COMBATE)
	if escena == null:
		return ""
	# Semilla fija: el combate de prueba termina siempre igual (con victoria).
	(escena.get("_rng") as RandomNumberGenerator).seed = 11
	if de_verdad:
		var cuadros := 0
		var magia_usada := false
		while int(escena.get("_estado")) != FIN and cuadros < MAX_CUADROS:
			await process_frame
			cuadros += 1
			# Solo elige cuando el combate acepta toques, para no gastar números al azar.
			if not escena.call("_entrada_libre"):
				continue
			match int(escena.get("_estado")):
				ACCIONES:
					# Una vez, un hechizo (Ralentizar); después, ataques.
					if not magia_usada:
						escena.call("_al_pulsar_magia")
					else:
						escena.call("_al_pulsar_atacar")
				MAGIA:
					magia_usada = true
					escena.call("_al_elegir_hechizo", "ralentizar")
				ZONA:
					var zonas := DatosCuerpo.ZONAS.keys()
					escena.call("_al_elegir_zona", zonas[_rng.randi() % zonas.size()])
				PARTE:
					var partes := DatosCuerpo.partes_de(escena.get("_zona"))
					escena.call("_al_elegir_parte", partes[_rng.randi() % partes.size()])
		_verificar(int(escena.get("_estado")) == FIN, "El combate del reino termina")
	if int(escena.get("_estado")) != FIN:
		escena.call("_mostrar_fin", "victoria")
	# Al terminar, el resultado aparece tras una pausa.
	for i in 240:
		if escena.get("_resultado") != "" and escena.call("_entrada_libre"):
			break
		await process_frame
	var resultado: String = escena.get("_resultado")
	_verificar(resultado != "", "El combate muestra su resultado")
	escena.call("_al_pulsar_menu")
	return resultado


## Sale a la zona más fácil y avanza día por día hasta terminar o volver.
func _recorrer_zona() -> void:
	var reino := current_scene
	_juego.estres = 0.0
	reino.call("_al_explorar", "bosque_sombrio")
	var zona := await _esperar_escena(EXPEDICION)
	if zona == null:
		return
	var semana: int = _juego.semana
	for i in 30:
		var dias: Array = _juego.expedicion["dias"]
		if dias.size() >= DatosAventura.DIAS_ZONA or _juego.expedicion.get("derrota", false) \
				or _juego.expedicion.get("agotado", false):
			break
		zona.call("_al_pulsar_dia", dias.size())
		await process_frame
		if not _juego.combate.is_empty():
			await _pelear(false)
			zona = await _esperar_escena(EXPEDICION)
			if zona == null:
				return
	_verificar(_juego.expedicion["dias"].size() > 0, "La salida registra los días")
	zona.call("_al_volver")
	if await _esperar_escena(REINO) == null:
		return
	_verificar(_juego.semana == semana + 1, "Volver de la zona termina la semana")
	_verificar(_juego.expedicion.is_empty(), "La salida se cierra al volver")


## Equipa el primer objeto de la mochila y vende otro (con la confirmación).
func _recorrer_inventario() -> void:
	var reino := current_scene
	_juego.agregar(DatosBotin.generar(2, _juego.rng, "peto", "epico"))
	_juego.agregar(DatosBotin.generar(1, _juego.rng, "casco", "normal"))
	reino.call("_mostrar_pestana", "inventario")
	await process_frame
	var peto: Dictionary = _juego.inventario[1]
	reino.call("_al_elegir_mochila", peto["id"])
	await process_frame
	reino.call("_al_equipar")
	await process_frame
	_verificar(_juego.equipo.get("peto", {}).get("id", -1) == peto["id"], "Equipar el peto")
	var casco: Dictionary = _juego.inventario[0]
	var oro: int = _juego.oro
	var precio: int = _juego.precio_venta(casco)
	reino.call("_al_elegir_mochila", casco["id"])
	await process_frame
	reino.call("_al_vender")
	_verificar(_juego.oro == oro, "Vender pide confirmación")
	await process_frame
	reino.call("_al_vender")
	await process_frame
	_verificar(_juego.oro == oro + precio, "Vender suma el oro (con Negociación)")


## Trabaja una semana y espera a que se muestren los siete días.
func _recorrer_trabajo() -> void:
	var reino := current_scene
	_juego.estres = 0.0
	var semana: int = _juego.semana
	reino.call("_mostrar_pestana", "trabajo")
	await process_frame
	reino.call("_al_elegir_oficio", "tribunal")
	await process_frame
	reino.call("_al_trabajar")
	for i in 600:
		await process_frame
		if not reino.get("_ocupado"):
			break
	_verificar(not reino.get("_ocupado"), "La semana de trabajo termina")
	_verificar(_juego.semana == semana + 1, "Trabajar termina la semana")
	reino.call("_al_terminar_trabajo")
	await process_frame
	reino.call("_al_elegir_oficio", "audiencias")
	await process_frame


## Ciudad: abre cada edificio, reconstruye, recluta, compra (con doble toque),
## mejora en la herrería y descansa en el castillo. Después fuerza un ataque que
## la ciudad pierde, para ver las noticias.
func _recorrer_ciudad() -> void:
	var reino := current_scene
	_juego.oro = 5000
	_juego.estres = 30.0
	reino.call("_mostrar_pestana", "ciudad")
	await process_frame
	for edificio_id in DatosCiudad.ORDEN:
		reino.call("_abrir_edificio", edificio_id)
		await process_frame
		_verificar(reino.get("_ventana_lugar") != null, "Se abre la ventana de %s" % edificio_id)
		reino.call("_cerrar_lugar")
		await process_frame
	for edificio_id in ["barracas", "granja", "mercado", "herreria"]:
		reino.call("_abrir_edificio", edificio_id)
		await process_frame
		reino.call("_al_mejorar_edificio")
		await process_frame
		_verificar(_juego.nivel_edificio(edificio_id) == 1, "Reconstruir %s desde su ventana" % edificio_id)
		_verificar(reino.get("_ventana_lugar") != null, "La ventana de %s sigue abierta" % edificio_id)
		match edificio_id:
			"barracas":
				var soldados: int = _juego.soldados
				reino.call("_al_reclutar")
				await process_frame
				_verificar(_juego.soldados == soldados + 1, "Reclutar un soldado")
			"mercado":
				var en_venta: int = _juego.mercado.size()
				var oro: int = _juego.oro
				reino.call("_al_comprar", 0)
				await process_frame
				_verificar(_juego.mercado.size() == en_venta and _juego.oro == oro, "Comprar pide un segundo toque")
				reino.call("_al_comprar", 0)
				await process_frame
				_verificar(_juego.mercado.size() == en_venta - 1 and _juego.oro < oro, "Comprar con el segundo toque")
			"herreria":
				var arma: Dictionary = _juego.equipo["arma"]
				var siguiente: String = _juego.calidad_siguiente(arma)
				reino.call("_al_mejorar_objeto", "arma")
				await process_frame
				if siguiente != "":
					_verificar(_juego.equipo["arma"]["calidad"] == siguiente, "Mejorar el arma en la herrería")
		reino.call("_cerrar_lugar")
		await process_frame
	# Descansar en el castillo pasa la semana.
	var semana: int = _juego.semana
	reino.call("_abrir_edificio", "castillo")
	await process_frame
	reino.call("_al_descansar")
	await process_frame
	_verificar(_juego.semana == semana + 1, "Descansar en el castillo pasa la semana")
	_verificar(_juego.estres < 30.0, "Descansar baja el estrés")
	if reino.get("_ventana_lugar") != null:
		reino.call("_cerrar_lugar")
		await process_frame
	# Un ataque perdido: sin soldados, con todo el peligro y muy avanzada la partida.
	_juego.soldados = 0
	_juego.peligro = 100.0
	_juego.semana = 60
	reino.call("_abrir_edificio", "castillo")
	await process_frame
	reino.call("_al_descansar")
	await process_frame
	var informe: Dictionary = _juego.informe_ciudad
	_verificar(informe.has("ataque") and not informe["ataque"]["ganado"], "Sin defensa, la ciudad pierde el ataque")
	_verificar(reino.get("_ventana_lugar") != null, "Se muestran las noticias del ataque")
	reino.call("_cerrar_lugar")
	await process_frame
	reino.call("_mostrar_pestana", "ciudad")
	await process_frame
	reino.call("_abrir_edificio", "castillo")
	await process_frame
	_verificar(reino.get("_ventana_lugar") != null, "El castillo muestra el informe de la semana")
	reino.call("_cerrar_lugar")
	await process_frame


## Hiere al rey (le falta vida y tiene una pierna rota) y le da dos pociones.
func _herir_rey() -> void:
	_juego.vida_perdida = 60
	_juego.integridad = {"muslo_der": 40.0}
	_juego.fracturas = {"muslo_der": true}
	_juego.agregar(DatosBotin.crear_pocion(2))


## Pociones en el inventario, la enfermería y el descanso que cura, y en la
## mazmorra: caminar cura, una poción entre combates y otra en el combate (botón
## Objeto); las heridas siguen después del combate.
func _recorrer_salud() -> void:
	var reino := current_scene
	_herir_rey()
	var pociones: int = _juego.pociones()
	reino.call("_mostrar_pestana", "inventario")
	await process_frame
	var pila: Dictionary = {}
	for objeto in _juego.inventario:
		if DatosBotin.es_pocion(objeto):
			pila = objeto
	reino.call("_al_elegir_mochila", pila["id"])
	await process_frame
	var vida: int = _juego.vida_actual()
	reino.call("_al_usar_objeto")
	await process_frame
	_verificar(_juego.pociones() == pociones - 1 and _juego.vida_actual() > vida, "Tomar una poción en el inventario")
	# La enfermería: se reconstruye y hace que descansar cure más.
	_juego.oro = 5000
	reino.call("_mostrar_pestana", "ciudad")
	await process_frame
	reino.call("_abrir_edificio", "enfermeria")
	await process_frame
	reino.call("_al_mejorar_edificio")
	await process_frame
	_verificar(_juego.nivel_edificio("enfermeria") == 1, "Reconstruir la enfermería")
	reino.call("_cerrar_lugar")
	await process_frame
	_herir_rey()
	reino.call("_abrir_edificio", "castillo")
	await process_frame
	reino.call("_al_descansar")
	await process_frame
	_verificar(_juego.vida_perdida < 60 and float(_juego.integridad.get("muslo_der", 100.0)) > 40.0, "Descansar cura")
	if reino.get("_ventana_lugar") != null:
		reino.call("_cerrar_lugar")
		await process_frame
	# En la mazmorra: un paso cura un poco y se puede tomar una poción.
	_herir_rey()
	_juego.estres = 0.0
	reino.call("_al_explorar", "madriguera_goblin")
	var mazmorra := await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	mazmorra.call("_ocultar_ayuda")
	var perdida: int = _juego.vida_perdida
	var plano: Dictionary = _juego.mazmorra["plano"]
	mazmorra.call("_mover", _paso_hacia(plano, _juego.mazmorra["pos"], plano["enemigos"].keys()))
	await process_frame
	_verificar(_juego.vida_perdida < perdida, "Cada paso en la mazmorra cura un poco")
	pociones = _juego.pociones()
	mazmorra.call("_al_pulsar_objetos")
	await process_frame
	mazmorra.call("_al_usar_objeto", "pocion")
	await process_frame
	_verificar(_juego.pociones() == pociones - 1, "Tomar una poción entre combates")
	# Hasta el primer enemigo, para tomar la última poción en el combate (con la
	# pierna rota otra vez: así sigue rota al terminar).
	_juego.vida_perdida = 60
	_juego.integridad = {"muslo_der": 40.0}
	_juego.fracturas = {"muslo_der": true}
	for pasos in 200:
		if not _juego.combate.is_empty() or _juego.mazmorra.is_empty():
			break
		plano = _juego.mazmorra["plano"]
		mazmorra.call("_mover", _paso_hacia(plano, _juego.mazmorra["pos"], plano["enemigos"].keys()))
		await process_frame
	if _juego.combate.is_empty():
		_fallos.append("No empezó un combate en la mazmorra")
		return
	var escena := await _esperar_escena(COMBATE)
	if escena == null:
		return
	pociones = _juego.pociones()
	for i in 600:
		await process_frame
		if int(escena.get("_estado")) == ACCIONES and escena.call("_entrada_libre"):
			break
	_verificar((escena.get("_jugador") as Luchador).vida < (escena.get("_jugador") as Luchador).vida_max,
		"El rey entra herido al combate")
	var boton_objeto: Button = escena.get("_boton_objeto")
	_verificar(boton_objeto.visible and not boton_objeto.disabled, "En el reino se ve el botón Objeto")
	boton_objeto.pressed.emit()
	for i in 60:
		await process_frame
		if escena.call("_entrada_libre"):
			break
	_verificar(int(escena.get("_estado")) == OBJETO, "El botón Objeto abre los objetos")
	escena.call("_al_usar_objeto", "pocion")
	await process_frame
	_verificar(int(escena.call("_disponibles", "pocion")) == pociones - 1, "Tomar una poción en combate")
	_verificar(_juego.pociones() == pociones, "La poción se gasta al terminar el combate (no antes)")
	escena.call("_mostrar_fin", "victoria")
	await process_frame
	_verificar(_juego.pociones() == pociones - 1, "Al terminar el combate se gasta la poción")
	var jugador: Luchador = escena.get("_jugador")
	_verificar(_juego.vida_perdida == jugador.vida_max_sana - jugador.vida and _juego.fracturas.has("muslo_der"),
		"Al terminar se guarda cómo quedó el rey (con su pierna rota)")
	_verificar(_juego.combate.get("resultado", "") == "victoria", "El resultado queda guardado en la partida")
	for i in 240:
		if escena.call("_entrada_libre"):
			break
		await process_frame
	escena.call("_al_pulsar_menu")
	mazmorra = await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	# Salir de la mazmorra (termina la semana).
	mazmorra.call("_salir", "Prueba.")
	await _esperar_escena(REINO)


## En una zona, si caminar un día llega al estrés máximo, ese día no hay suceso
## (ni combate) y el rey vuelve a casa.
func _recorrer_agotado() -> void:
	var reino := current_scene
	_juego.estres = 0.0
	reino.call("_al_explorar", "bosque_sombrio")
	var zona := await _esperar_escena(EXPEDICION)
	if zona == null:
		return
	_juego.estres = DatosAventura.ESTRES_MAXIMO - 0.5
	zona.call("_al_pulsar_dia", 0)
	await process_frame
	_verificar(_juego.combate.is_empty(), "Agotado, ese día no empieza un combate")
	_verificar(_juego.expedicion.get("agotado", false), "La salida se corta por el estrés")
	_verificar(String(_juego.expedicion["dias"][0]["corto"]) == "Agotado", "El día queda como agotado")
	zona.call("_al_volver")
	await _esperar_escena(REINO)


## Sangrado: lo que sangra sigue sangrando al caminar y una venda lo para;
## desangrarse por el camino es como perder (vuelve al castillo y termina la
## semana); en un combate, una venda (botón Objeto) se gasta al terminarlo.
func _recorrer_sangre() -> void:
	var reino := current_scene
	_juego.estres = 0.0
	_juego.vida_perdida = 0
	_juego.integridad = {"muslo_der": 50.0, "cuello": 60.0}
	_juego.fracturas = {}
	_juego.sangre_perdida = 0.5
	_juego.sangrados.assign([{"parte": "muslo_der", "tipo": "externo", "nivel": 2, "turnos": 3}])
	_juego.agregar(DatosBotin.crear_consumible("venda", 3))
	reino.call("_al_explorar", "madriguera_goblin")
	var mazmorra := await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	mazmorra.call("_ocultar_ayuda")
	var plano: Dictionary = _juego.mazmorra["plano"]
	var antes: float = _juego.sangre_perdida
	mazmorra.call("_mover", _paso_hacia(plano, _juego.mazmorra["pos"], plano["enemigos"].keys(), true))
	await process_frame
	_verificar(_juego.sangre_perdida > antes, "Lo que sangra sigue sangrando al caminar")
	var vendas: int = _juego.cantidad("venda")
	mazmorra.call("_al_pulsar_objetos")
	await process_frame
	_verificar((mazmorra.get("_lista_objetos") as Control).visible, "El botón Objetos abre la lista")
	mazmorra.call("_al_usar_objeto", "venda")
	await process_frame
	_verificar(_juego.cantidad("venda") == vendas - 1 and _juego.sangrados.is_empty(), "Una venda para el sangrado entre combates")
	# Desangrarse por el camino: lo traen al castillo y termina la semana.
	_juego.sangre_perdida = DatosHeridas.SANGRE_MAX * 0.49
	_juego.sangrados.assign([{"parte": "cuello", "tipo": "externo", "nivel": 3, "turnos": 3}])
	var semana: int = _juego.semana
	plano = _juego.mazmorra["plano"]
	mazmorra.call("_mover", _paso_hacia(plano, _juego.mazmorra["pos"], plano["enemigos"].keys(), true))
	reino = await _esperar_escena(REINO)
	if reino == null:
		return
	_verificar(_juego.semana == semana + 1 and _juego.vida_actual() == 1 and _juego.sangrados.is_empty(),
		"Desangrarse por el camino es como perder")
	_verificar((reino.get("_aviso") as Label).text.contains("desangraste"), "Y se cuenta al volver")
	# En un combate: con el muslo sangrando, una venda con el botón Objeto.
	_juego.sangre_perdida = 0.0
	_juego.vida_perdida = 0
	_juego.integridad = {"muslo_der": 50.0}
	_juego.sangrados.assign([{"parte": "muslo_der", "tipo": "externo", "nivel": 2, "turnos": 3}])
	reino.call("_al_explorar", "paso_montana")
	if await _esperar_escena(EXPEDICION) == null:
		return
	_juego.combate = {"origen": "expedicion", "escena": EXPEDICION, "rival": "orco", "resultado": ""}
	change_scene_to_file(COMBATE)
	var escena := await _esperar_escena(COMBATE)
	if escena == null:
		return
	(escena.get("_rng") as RandomNumberGenerator).seed = 12
	for i in 600:
		await process_frame
		if int(escena.get("_estado")) == ACCIONES and escena.call("_entrada_libre"):
			break
	vendas = _juego.cantidad("venda")
	escena.call("_al_pulsar_objeto")
	for i in 60:
		await process_frame
		if escena.call("_entrada_libre"):
			break
	escena.call("_al_usar_objeto", "venda")
	await process_frame
	var jugador: Luchador = escena.get("_jugador")
	_verificar(not jugador.sangra_por_fuera() and int(escena.call("_disponibles", "venda")) == vendas - 1,
		"Una venda en combate para el sangrado")
	_verificar(_juego.cantidad("venda") == vendas, "La venda se gasta al terminar el combate (no antes)")
	escena.call("_mostrar_fin", "victoria")
	await process_frame
	# (Los mazazos del orco pueden hacerlo sangrar por dentro: eso no lo para una venda.)
	_verificar(_juego.cantidad("venda") == vendas - 1 and not DatosHeridas.hay_sangrado(_juego.sangrados, "externo"),
		"Al terminar se gasta y queda vendado")
	for i in 240:
		if escena.call("_entrada_libre"):
			break
		await process_frame
	escena.call("_al_pulsar_menu")
	var zona := await _esperar_escena(EXPEDICION)
	if zona == null:
		return
	zona.call("_al_volver")
	await _esperar_escena(REINO)


## Un combate de verdad contra un chamán orco, que sabe magia: lanza hechizos.
func _recorrer_magia_enemiga() -> void:
	var reino := current_scene
	_juego.estres = 0.0
	_juego.vida_perdida = 0
	_juego.integridad = {}
	_juego.fracturas = {}
	reino.call("_al_explorar", "paso_montana")
	if await _esperar_escena(EXPEDICION) == null:
		return
	_juego.combate = {"origen": "expedicion", "escena": EXPEDICION, "rival": "chaman_orco", "resultado": ""}
	change_scene_to_file(COMBATE)
	var escena := await _esperar_escena(COMBATE)
	if escena == null:
		return
	(escena.get("_rng") as RandomNumberGenerator).seed = 11
	var hechizos := 0
	var vistos := {}
	var cuadros := 0
	while int(escena.get("_estado")) != FIN and cuadros < MAX_CUADROS:
		await process_frame
		cuadros += 1
		for mensaje in escena.get("_mensajes"):
			if String(mensaje).begins_with("El Chamán orco lanza") and not vistos.has(mensaje):
				vistos[mensaje] = true
				hechizos += 1
		if not escena.call("_entrada_libre"):
			continue
		match int(escena.get("_estado")):
			ACCIONES:
				escena.call("_al_pulsar_atacar")
			ZONA:
				escena.call("_al_elegir_zona", "torso")
			PARTE:
				escena.call("_al_elegir_parte", "abdomen")
	_verificar(int(escena.get("_estado")) == FIN, "El combate contra el chamán termina")
	_verificar(hechizos > 0, "El chamán orco lanza hechizos")
	for i in 240:
		if escena.get("_resultado") != "" and escena.call("_entrada_libre"):
			break
		await process_frame
	escena.call("_al_pulsar_menu")
	var zona := await _esperar_escena(EXPEDICION)
	if zona == null:
		return
	_verificar(_juego.expedicion["dias"].size() == 1, "El combate cuenta como un día de la salida")
	zona.call("_al_volver")
	await _esperar_escena(REINO)


## Desde el menú, "Continuar" sigue la partida donde quedó: en una mazmorra
## (también tras guardar y cargar la partida del disco), en un combate pendiente
## (que empieza de nuevo) o en uno ya terminado. La demo no toca el combate
## pendiente. "Atrás" pregunta antes de salir.
func _recorrer_continuar() -> void:
	_juego.estres = 0.0
	_juego.mazmorra = {"id": "madriguera_goblin"}
	# Guardar, borrar todo de la memoria y cargar del disco: Continuar sigue igual.
	var oro := _juego.oro
	_verificar(_juego.guardar(ARCHIVO_PRUEBA), "Se guarda la partida")
	_juego.nueva_partida(false)
	_verificar(_juego.cargar(ARCHIVO_PRUEBA), "Se carga la partida")
	DirAccess.remove_absolute(ARCHIVO_PRUEBA)
	_verificar(_juego.oro == oro and _juego.mazmorra.get("id", "") == "madriguera_goblin" and _juego.diestro,
		"La partida cargada es la misma")
	change_scene_to_file(MENU)
	var menu := await _esperar_escena(MENU)
	if menu == null:
		return
	menu.call("_notification", Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_verificar((menu.get("_salida") as Control).visible, "Atrás en el menú pregunta antes de salir")
	menu.call("_al_cancelar")
	_verificar(not (menu.get("_salida") as Control).visible, "Y se puede seguir jugando")
	menu.call("_al_continuar")
	var mazmorra := await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	_verificar(_juego.mazmorra.has("plano"), "Continuar vuelve a la mazmorra en curso")
	# Un combate pendiente (la aplicación se cerró a la mitad) empieza de nuevo.
	var plano: Dictionary = _juego.mazmorra["plano"]
	var celda: Vector2i = plano["enemigos"].keys()[0]
	_juego.combate = {"origen": "mazmorra", "escena": MAZMORRA, "rival": plano["enemigos"][celda], "celda": celda, "resultado": ""}
	change_scene_to_file(MENU)
	menu = await _esperar_escena(MENU)
	if menu == null:
		return
	menu.call("_al_continuar")
	var escena := await _esperar_escena(COMBATE)
	if escena == null:
		return
	_verificar(escena.get("_modo_reino"), "El combate pendiente es del reino")
	var resultado := await _pelear(false)
	_verificar(resultado == "victoria", "El combate pendiente se puede terminar")
	mazmorra = await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	_verificar(not _juego.mazmorra["plano"]["enemigos"].has(celda), "Y la mazmorra cuenta la victoria")
	# Un combate ya terminado (se cerró antes de tocar Continuar): vuelve a la
	# mazmorra y la mazmorra cuenta el resultado.
	plano = _juego.mazmorra["plano"]
	celda = plano["enemigos"].keys()[0]
	_juego.combate = {"origen": "mazmorra", "escena": MAZMORRA, "rival": plano["enemigos"][celda], "celda": celda,
		"resultado": "victoria"}
	change_scene_to_file(MENU)
	menu = await _esperar_escena(MENU)
	if menu == null:
		return
	menu.call("_al_continuar")
	mazmorra = await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	_verificar(_juego.combate.is_empty() and not _juego.mazmorra["plano"]["enemigos"].has(celda),
		"Un combate ya terminado se cuenta al volver")
	# La demo con un combate pendiente: no es del reino y no lo toca.
	celda = _juego.mazmorra["plano"]["enemigos"].keys()[0]
	var pendiente := {"origen": "mazmorra", "escena": MAZMORRA, "rival": _juego.mazmorra["plano"]["enemigos"][celda],
		"celda": celda, "resultado": ""}
	_juego.combate = pendiente.duplicate()
	change_scene_to_file(MENU)
	menu = await _esperar_escena(MENU)
	if menu == null:
		return
	menu.call("_al_pulsar_demo")
	var preparacion := await _esperar_escena(PREPARACION)
	if preparacion == null:
		return
	preparacion.call("_al_combatir")
	escena = await _esperar_escena(COMBATE)
	if escena == null:
		return
	_verificar(not escena.get("_modo_reino") and not (escena.get("_boton_objeto") as Button).visible,
		"La demo no es un combate del reino (sin Objeto)")
	_verificar(_juego.combate == pendiente, "La demo no toca el combate pendiente")
	change_scene_to_file(MENU)
	menu = await _esperar_escena(MENU)
	if menu == null:
		return
	menu.call("_al_continuar")
	escena = await _esperar_escena(COMBATE)
	if escena == null:
		return
	_verificar(escena.get("_modo_reino"), "Después, Continuar vuelve al combate pendiente del reino")
	await _pelear(false)
	mazmorra = await _esperar_escena(MAZMORRA)
	if mazmorra == null:
		return
	mazmorra.call("_salir", "Prueba.")
	await _esperar_escena(REINO)
