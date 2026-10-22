extends SceneTree
## Juega combates completos sin ventana, pulsando los mismos botones que el
## jugador (atacar por zona y parte, tocar el cuerpo, defender, magia, cambiar o
## recoger el arma, huir, abrir el estado), para detectar errores en el flujo:
##   godot --headless --script res://pruebas/partida_automatica.gd

const ESCENA := "res://escenas/combate.tscn"
const COMBATES_POR_COMBINACION := 2
const MAX_CUADROS := 6000
# Valores del enum Estado de combate.gd.
const ACCIONES := 1
const ZONA := 2
const PARTE := 3
const ARMA := 4
const FIN := 5
const MAGIA := 6

var _rng := RandomNumberGenerator.new()
## Parte que el bot planea atacar (elegida como la IA de los rivales).
var _plan := ""


func _initialize() -> void:
	_rng.seed = 99
	Engine.time_scale = 30.0
	await process_frame
	var partida: Node = root.get_node("Partida")
	# Siempre la demo, aunque la partida guardada tenga un combate pendiente.
	partida.set("en_demo", true)
	var terminados := 0
	var total := 0
	var resultados := {}
	for rival_id in DatosRivales.ORDEN:
		for arma_id in DatosArmas.ELEGIBLES:
			for i in COMBATES_POR_COMBINACION:
				partida.set("rival", rival_id)
				partida.set("arma", arma_id)
				partida.set("diestro", i % 2 == 0)
				var final := await _jugar_un_combate()
				total += 1
				if final != "":
					terminados += 1
					resultados[final] = int(resultados.get(final, 0)) + 1
				else:
					print("  NO TERMINÓ: %s con %s" % [rival_id, arma_id])
	print("Combates terminados: %d de %d %s" % [terminados, total, str(resultados)])
	var victorias: int = resultados.get("¡Victoria!", 0)
	if victorias == 0:
		print("  NINGUNA VICTORIA: el final con victoria no se probó")
	quit(0 if terminados == total and victorias > 0 else 1)


## Devuelve el título del resultado ("¡Victoria!", "Derrota", "Escapaste") o "" si no terminó.
func _jugar_un_combate() -> String:
	var escena: Control = load(ESCENA).instantiate()
	root.add_child(escena)
	var cuadros := 0
	while int(escena.get("_estado")) != FIN and cuadros < MAX_CUADROS:
		await process_frame
		cuadros += 1
		match int(escena.get("_estado")):
			ACCIONES:
				_elegir_accion(escena)
			ZONA:
				_elegir_zona(escena)
			PARTE:
				_elegir_parte(escena)
			ARMA:
				_elegir_arma(escena)
			MAGIA:
				_elegir_hechizo(escena)
	# Esperar a que aparezca la ventana del resultado.
	for espera in 120:
		if escena.get("_ventana") != null:
			break
		await process_frame
	var titulo := ""
	if int(escena.get("_estado")) == FIN:
		titulo = escena.get("_etiqueta_turno").text
	escena.queue_free()
	await process_frame
	return titulo


func _elegir_accion(escena: Control) -> void:
	var jugador: Luchador = escena.get("_jugador")
	var tirada := _rng.randf()
	if tirada < 0.04:
		escena.call("_mostrar_estado")
		escena.call("_cerrar_ventana")
		return
	var boton_arma: Button = escena.get("_boton_arma")
	if tirada < 0.1:
		escena.call("_al_pulsar_defender")
	elif (tirada < 0.15 or jugador.desarmado) and not boton_arma.disabled:
		# Desarmado y sin manos útiles el botón está deshabilitado: ataca (puños o patadas).
		escena.call("_al_pulsar_arma")
	elif tirada < 0.17:
		escena.call("_al_pulsar_huir")
	elif tirada < 0.25 and jugador.usa_mana:
		escena.call("_al_pulsar_magia")
	else:
		escena.call("_al_pulsar_atacar")


## En el menú de magia: lanza un hechizo que alcance, o vuelve atrás.
func _elegir_hechizo(escena: Control) -> void:
	var posibles := DatosHechizos.ORDEN.filter(func(h: String) -> bool: return escena.call("_hechizo_disponible", h))
	if posibles.is_empty() or _rng.randf() < 0.15:
		escena.call("_volver_atras")
		return
	escena.call("_al_elegir_hechizo", posibles[_rng.randi() % posibles.size()])


## En el menú de armas: casi siempre cambia de arma; a veces vuelve atrás.
func _elegir_arma(escena: Control) -> void:
	if _rng.randf() < 0.2:
		escena.call("_volver_atras")
		return
	var jugador: Luchador = escena.get("_jugador")
	var otras := DatosArmas.ELEGIBLES.filter(func(a: String) -> bool: return a != jugador.arma)
	escena.call("_al_elegir_arma", otras[_rng.randi() % otras.size()])


## Casi siempre ataca con un plan, como la IA de los rivales; a veces al azar.
func _elegir_zona(escena: Control) -> void:
	var zonas := DatosCuerpo.ZONAS.keys()
	var zona_id: String = zonas[_rng.randi() % zonas.size()]
	_plan = ""
	if _rng.randf() < 0.75:
		_plan = IAEnemigo.elegir_parte(escena.get("_jugador"), escena.get("_enemigo"), _rng)
		zona_id = DatosCuerpo.zona_de(_plan)
	if _rng.randf() < 0.1:
		escena.call("_volver_atras")
		return
	escena.call("_al_elegir_zona", zona_id)


## A veces pulsa el botón de la parte y a veces toca el cuerpo del rival.
func _elegir_parte(escena: Control) -> void:
	var zona_id: String = escena.get("_zona")
	var partes := DatosCuerpo.partes_de(zona_id)
	var parte_id: String = _plan if partes.has(_plan) else partes[_rng.randi() % partes.size()]
	if _rng.randf() < 0.5:
		escena.call("_al_elegir_parte", parte_id)
		return
	var figura: Figura = escena.get("_figura_enemigo")
	var toque := InputEventScreenTouch.new()
	toque.pressed = false
	toque.position = figura.posicion_global_de(parte_id)
	escena.call("_unhandled_input", toque)
