extends "res://pruebas/base_prueba.gd"
## Salud del rey en el reino: las heridas duran entre combates, se curan al
## caminar, al descansar (más con la enfermería y Recuperación) y con pociones;
## y la partida se guarda y se carga.

const ARCHIVO_PRUEBA := "user://prueba_partida.save"


func _juego_nuevo() -> EstadoReino:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	return juego


## El rey sale de un combate con heridas: vida perdida, una pierna rota y maná gastado.
func _herir(juego: EstadoReino) -> Luchador:
	var rey := juego.crear_rey()
	rey.vida -= 40
	rey.mana -= 10.0
	rey.integridad["muslo_der"] = 30.0
	rey.fracturas["muslo_der"] = true
	rey.integridad["mano_izq"] = 90.0
	rey.heridas.append({"parte": "muslo_der", "tipo": "Fractura", "danio": 8, "turno": 3})
	rey.heridas.append({"parte": "mano_izq", "tipo": "Corte", "danio": 2, "turno": 4})
	juego.guardar_salud(rey)
	return rey


func prueba_las_heridas_pasan_al_siguiente_combate() -> void:
	var juego := _juego_nuevo()
	verificar(not juego.esta_herido(), "Empieza sano")
	_herir(juego)
	verificar(juego.esta_herido(), "Después del combate sigue herido")
	var rey := juego.crear_rey()
	verificar_igual(rey.vida, rey.vida_max - 40, "Le sigue faltando la vida")
	verificar_cerca(rey.mana, rey.mana_max - 10.0, "Y el maná que gastó")
	verificar_cerca(rey.integridad["muslo_der"], 30.0, "La pierna sigue herida")
	verificar(rey.fracturas.has("muslo_der"), "Y rota")
	verificar_igual(rey.heridas.size(), 2, "Recuerda los golpes de las partes heridas")
	verificar_cerca(rey.integridad["craneo"], 100.0, "Lo demás, sano")
	verificar_igual(juego.vida_actual(), rey.vida, "La vida fuera del combate es la misma")
	# Aunque pierda un combate, vuelve con al menos 1 de vida.
	rey.vida = 0
	juego.guardar_salud(rey)
	verificar_igual(juego.crear_rey().vida, 1, "Tras una derrota vuelve con 1 de vida")
	verificar_igual(juego.vida_actual(), 1, "Y así se ve en el reino")
	juego.free()


func prueba_caminar_cura_un_poco_todo_a_la_vez() -> void:
	var juego := _juego_nuevo()
	_herir(juego)
	var perdida := juego.vida_perdida
	var mana := juego.mana_perdido
	juego.curar_al_caminar()
	verificar_igual(juego.vida_perdida, perdida - maxi(roundi(juego.vida_maxima() * DatosAventura.CURA_POR_PASO), 1),
		"Cada paso cura un poco de vida")
	verificar_cerca(juego.integridad["muslo_der"], 30.0 + 100.0 * DatosAventura.CURA_POR_PASO, "Y todas las partes a la vez")
	verificar_cerca(juego.integridad["mano_izq"], 90.0 + 100.0 * DatosAventura.CURA_POR_PASO, "Todas")
	verificar_cerca(juego.mana_perdido, mana - DatosAventura.MANA_POR_PASO, "Y el maná")
	# Un día de marcha en una zona cura como varios pasos.
	var otro := _juego_nuevo()
	_herir(otro)
	otro.curar_al_caminar(DatosAventura.PASOS_POR_DIA)
	verificar(otro.vida_perdida < juego.vida_perdida, "Un día cura más que un paso")
	# Una parte que se cura del todo deja de estar rota y olvida sus golpes.
	for i in 200:
		juego.curar_al_caminar()
	verificar(not juego.esta_herido(), "Caminando mucho se cura del todo")
	verificar(juego.fracturas.is_empty(), "Sin fracturas")
	verificar(juego.heridas.is_empty(), "Sin golpes guardados")
	verificar_cerca(juego.mana_perdido, 0.0, "Con el maná lleno")
	juego.free()
	otro.free()


func prueba_recuperacion_cura_mas() -> void:
	var normal := _juego_nuevo()
	var rapido := _juego_nuevo()
	rapido.extra["recuperacion"] = 10
	verificar(rapido.multiplicador_curacion() > 1.0, "Recuperación sube la curación")
	for juego in [normal, rapido]:
		_herir(juego)
		juego.curar_al_caminar(5.0)
	verificar(rapido.vida_perdida < normal.vida_perdida, "Con Recuperación se cura más vida")
	verificar(rapido.integridad["muslo_der"] > normal.integridad["muslo_der"], "Y más las partes")
	normal.free()
	rapido.free()


func prueba_descansar_cura_y_la_enfermeria_cura_mas() -> void:
	var juego := _juego_nuevo()
	verificar_cerca(juego.cura_al_descansar(), DatosCiudad.CURA_DESCANSO, "Sin enfermería, la cura del descanso")
	_herir(juego)
	juego.descansar()
	verificar_cerca(juego.integridad["muslo_der"], 30.0 + 100.0 * DatosCiudad.CURA_DESCANSO, "Descansar cura las partes")
	verificar_igual(juego.vida_perdida, maxi(40 - roundi(juego.vida_maxima() * DatosCiudad.CURA_DESCANSO), 0), "Y la vida")
	verificar_cerca(juego.mana_perdido, 0.0, "Al pasar la semana se llena el maná")
	# Con la enfermería al máximo, descansar cura todo.
	var con_enfermeria := _juego_nuevo()
	con_enfermeria.oro = 100000
	for edificio_id in ["castillo", "castillo", "enfermeria", "enfermeria", "enfermeria"]:
		verificar(con_enfermeria.mejorar_edificio(edificio_id), "Mejora %s" % edificio_id)
	verificar_cerca(con_enfermeria.cura_al_descansar(), DatosCiudad.CURA_DESCANSO + DatosCiudad.CURA_ENFERMERIA[3],
		"La enfermería suma a la cura del descanso")
	_herir(con_enfermeria)
	con_enfermeria.descansar()
	verificar(not con_enfermeria.esta_herido(), "Con la enfermería en nivel 3, una semana de descanso lo cura todo")
	# Trabajar no cura.
	var trabajador := _juego_nuevo()
	_herir(trabajador)
	trabajador.trabajar("audiencias")
	verificar_igual(trabajador.vida_perdida, 40, "Trabajar una semana no cura las heridas")
	verificar_cerca(trabajador.mana_perdido, 0.0, "Pero el maná se llena")
	juego.free()
	con_enfermeria.free()
	trabajador.free()


func prueba_la_enfermeria_empieza_en_ruinas() -> void:
	var juego := _juego_nuevo()
	verificar(DatosCiudad.ORDEN.has("enfermeria"), "La enfermería es un edificio de la ciudad")
	verificar_igual(juego.nivel_edificio("enfermeria"), 0, "Empieza en ruinas")
	verificar_igual(juego.motivo_sin_mejora("enfermeria"), "No te alcanza el oro.", "Se reconstruye con oro")
	juego.oro = 1000
	verificar(juego.mejorar_edificio("enfermeria"), "Se reconstruye")
	verificar_igual(juego.motivo_sin_mejora("enfermeria"), "Primero mejora el castillo.", "No supera al castillo")
	verificar(DatosCiudad.efecto("enfermeria", 1).contains("%"), "Dice cuánto cura")
	juego.free()


func prueba_las_pociones_se_apilan_y_curan() -> void:
	var juego := _juego_nuevo()
	verificar_igual(juego.pociones(), 0, "Sin pociones al empezar")
	var primera := juego.agregar(DatosBotin.crear_pocion())
	juego.agregar(DatosBotin.crear_pocion(2))
	verificar_igual(juego.pociones(), 3, "Tres pociones")
	verificar_igual(juego.inventario.size(), 1, "En un solo pila")
	verificar(not juego.equipar(primera["id"]), "Una poción no se equipa")
	verificar(not juego.usar_pocion(), "Sano, no se toma")
	verificar_igual(juego.pociones(), 3, "Y no se gasta")
	_herir(juego)
	verificar(juego.usar_pocion(), "Herido, sí")
	verificar_igual(juego.pociones(), 2, "Gasta una")
	verificar_igual(juego.vida_perdida, 0, "Cura la vida")
	verificar_cerca(juego.integridad["muslo_der"], 30.0 + DatosBotin.POCION_PARTES, "Y todas las partes")
	var oro := juego.oro
	verificar_igual(juego.vender(primera["id"]), DatosBotin.PRECIO_POCION, "Se venden de a una")
	verificar_igual(juego.oro, oro + DatosBotin.PRECIO_POCION, "Suma el oro")
	verificar_igual(juego.pociones(), 1, "Queda una")
	verificar(juego.gastar_pocion(), "En combate se saca del inventario")
	verificar_igual(juego.inventario.size(), 0, "Sin pociones, el pila desaparece")
	verificar(not juego.gastar_pocion(), "Sin pociones no se puede")
	juego.free()


func prueba_en_combate_la_pocion_cura_al_luchador() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	verificar(not rey.esta_herido(), "Sano")
	rey.vida -= 60
	rey.integridad["brazo_der"] = 50.0
	rey.integridad["pie_izq"] = 90.0
	rey.fracturas["pie_izq"] = true
	var curado := rey.curar(DatosBotin.POCION_VIDA, DatosBotin.POCION_PARTES)
	verificar_igual(curado, DatosBotin.POCION_VIDA, "Recupera la vida de la poción")
	verificar_cerca(rey.integridad["brazo_der"], 50.0 + DatosBotin.POCION_PARTES, "Y las partes")
	verificar_cerca(rey.integridad["pie_izq"], 100.0, "Sin pasarse de 100")
	verificar(not rey.fracturas.has("pie_izq"), "La parte curada del todo deja de estar rota")
	verificar_igual(rey.curar(1000, 0.0), 20, "No pasa de la vida máxima")


func prueba_las_pociones_salen_en_el_botin_y_en_el_mercado() -> void:
	var rng := rng_fijo(8)
	var pociones := 0
	for i in 400:
		var objeto := DatosBotin.generar_botin(2, rng)
		if DatosBotin.es_pocion(objeto):
			pociones += 1
			verificar_igual(objeto["nivel"], 2, "Del nivel del lugar")
	verificar(pociones > 60 and pociones < 140, "Más o menos una de cada cuatro (%d de 400)" % pociones)
	var juego := _juego_nuevo()
	juego.oro = 100000
	juego.mejorar_edificio("mercado")
	var indice := juego.mercado.size() - 1
	var pila: Dictionary = juego.mercado[indice]
	verificar(DatosBotin.es_pocion(pila), "El mercado vende pociones")
	var cantidad := int(pila["cantidad"])
	verificar(juego.comprar(indice), "Se compra una")
	verificar_igual(juego.pociones(), 1, "Va al inventario")
	verificar_igual(int(juego.mercado[indice]["cantidad"]), cantidad - 1, "Quedan menos a la venta")
	for i in cantidad - 1:
		verificar(juego.comprar(juego.mercado.size() - 1), "Se compran todas")
	verificar_igual(juego.pociones(), cantidad, "Todas en un pila")
	verificar(juego.mercado.is_empty() or not DatosBotin.es_pocion(juego.mercado[-1]), "Ya no quedan a la venta")
	juego.free()


func prueba_la_partida_se_guarda_y_se_carga() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000
	juego.mejorar_edificio("castillo")
	juego.oro = 1234
	juego.semana = 7
	juego.estres = 33.5
	juego.agregar(DatosBotin.crear_pocion(2))
	juego.agregar(DatosBotin.crear_arma("maza", 2, "raro"))
	juego.aplicar_puntos({"fuerza": 2}, {"fuerza_maxima": 3})
	_herir(juego)
	juego.mazmorra = {"id": "madriguera_goblin"}
	juego.mazmorra["plano"] = GeneradorMazmorra.generar("madriguera_goblin", 7, juego.semilla)
	juego.mazmorra["pos"] = Vector2i(3, 2)
	juego.rng.randi()
	verificar(juego.guardar(ARCHIVO_PRUEBA), "Se guarda")
	var esperado := juego.rng.randi()
	var cargado := EstadoReino.new()
	verificar(cargado.cargar(ARCHIVO_PRUEBA), "Se carga")
	verificar(cargado.en_curso, "Hay partida en curso")
	verificar_igual(cargado.oro, 1234, "El oro")
	verificar_igual(cargado.semana, 7, "La semana")
	verificar_cerca(cargado.estres, 33.5, "El estrés")
	verificar_igual(cargado.pociones(), 2, "Las pociones")
	verificar_igual(cargado.inventario.size(), juego.inventario.size(), "El inventario")
	verificar_cerca(cargado.valor_sub("fuerza_maxima"), juego.valor_sub("fuerza_maxima"), "Las características")
	verificar_igual(cargado.nivel_edificio("castillo"), 2, "La ciudad")
	verificar_igual(cargado.vida_perdida, juego.vida_perdida, "Las heridas")
	verificar(cargado.fracturas.has("muslo_der"), "Las fracturas")
	verificar_igual(cargado.mazmorra["pos"], Vector2i(3, 2), "La mazmorra en curso")
	verificar_igual(cargado.mazmorra["plano"]["enemigos"], juego.mazmorra["plano"]["enemigos"], "Con su plano")
	verificar_igual(cargado.semilla, juego.semilla, "La semilla de sus mazmorras")
	verificar_igual(cargado.rng.randi(), esperado, "El azar sigue igual que sin cerrar el juego")
	var ids := [cargado.equipo["arma"]["id"]]
	for objeto in cargado.inventario:
		ids.append(objeto["id"])
	verificar(not ids.has(cargado.agregar(DatosBotin.crear_arma("lanza", 1, "normal"))["id"]), "Los objetos nuevos no repiten id")
	# Un archivo de otra versión no se carga.
	var archivo := FileAccess.open(ARCHIVO_PRUEBA, FileAccess.WRITE)
	archivo.store_string(var_to_str({"version": EstadoReino.VERSION_GUARDADO + 1, "oro": 5}))
	archivo.close()
	var viejo := EstadoReino.new()
	verificar(not viejo.cargar(ARCHIVO_PRUEBA), "Otra versión no se carga")
	verificar(not viejo.en_curso, "Y no queda partida")
	DirAccess.remove_absolute(ARCHIVO_PRUEBA)
	verificar(not viejo.cargar(ARCHIVO_PRUEBA), "Sin archivo no hay nada que cargar")
	juego.free()
	cargado.free()
	viejo.free()
