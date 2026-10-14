extends SceneTree
## Recorre el reino sin ventana, pulsando lo mismo que el jugador, para detectar
## errores en el flujo entre pantallas:
##   godot --headless --script res://pruebas/recorrido_reino.gd
## Menú -> reino (todas las pestañas) -> mazmorra (pelear, abrir cofres y salir
## por la H) -> zona de siete días -> inventario (equipar y vender) -> trabajo.

const MENU := "res://escenas/menu_principal.tscn"
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

var _rng := RandomNumberGenerator.new()
var _fallos: Array[String] = []
var _juego: EstadoReino


func _initialize() -> void:
	_rng.seed = 5
	Engine.time_scale = 30.0
	await process_frame
	_juego = root.get_node("Juego") as EstadoReino
	_juego.nueva_partida(true)
	_juego.rng.seed = 5
	for paso in [_recorrer_menu_y_pestanas, _recorrer_mazmorra, _recorrer_estres_maximo, _recorrer_zona,
			_recorrer_inventario, _recorrer_trabajo]:
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
	reino.call("_mostrar_pestana", "aventura")
	for lugar_id in DatosAventura.ORDEN_MAZMORRAS + DatosAventura.ORDEN_ZONAS:
		reino.call("_al_elegir_lugar", lugar_id)
		await process_frame
		reino.call("_cerrar_lugar")
		await process_frame


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
		while int(escena.get("_estado")) != FIN and cuadros < MAX_CUADROS:
			await process_frame
			cuadros += 1
			# Solo elige cuando el combate acepta toques, para no gastar números al azar.
			if not escena.call("_entrada_libre"):
				continue
			match int(escena.get("_estado")):
				ACCIONES:
					escena.call("_al_pulsar_atacar")
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
	reino.call("_al_elegir_mochila", casco["id"])
	await process_frame
	reino.call("_al_vender")
	_verificar(_juego.oro == oro, "Vender pide confirmación")
	await process_frame
	reino.call("_al_vender")
	await process_frame
	_verificar(_juego.oro == oro + int(casco["precio"]), "Vender suma el oro")


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
