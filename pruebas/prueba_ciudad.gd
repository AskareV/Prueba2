extends "res://pruebas/base_prueba.gd"
## Ciudad: edificios, comida, soldados, mercado y herrería (ya no hay invasiones).


func _juego_nuevo() -> EstadoReino:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	juego.rng.seed = 77
	return juego


## Ciudad con castillo 3, barracas 1 y 5 soldados.
func _ciudad_segura(juego: EstadoReino) -> void:
	juego.oro += 100000
	dar_materiales(juego)
	juego.mejorar_edificio("castillo")
	juego.mejorar_edificio("castillo")
	juego.mejorar_edificio("barracas")
	for i in 5:
		juego.reclutar()


func prueba_la_ciudad_empieza_en_ruinas() -> void:
	var juego := _juego_nuevo()
	verificar_igual(juego.nivel_edificio("castillo"), 1, "El castillo empieza en pie")
	for edificio_id in ["herreria", "granja", "mercado", "barracas"]:
		verificar_igual(juego.nivel_edificio(edificio_id), 0, "%s empieza en ruinas" % edificio_id)
	verificar_igual(juego.comida, DatosCiudad.COMIDA_INICIAL, "Algo de comida guardada")
	verificar_igual(juego.soldados, 0, "Sin soldados")
	juego.free()


func prueba_reconstruir_y_mejorar_cuesta_oro_y_el_castillo_limita() -> void:
	var juego := _juego_nuevo()
	verificar(not juego.mejorar_edificio("granja"), "Sin oro no se reconstruye")
	verificar_igual(juego.motivo_sin_mejora("granja"), "Te faltan 100 de oro, 5 de madera y 2 de piedra.", "Dice qué falta")
	juego.oro = 1000
	verificar(not juego.mejorar_edificio("granja"), "Sin materiales tampoco")
	verificar_igual(juego.motivo_sin_mejora("granja"), "Te faltan 5 de madera y 2 de piedra.", "Dice qué materiales faltan")
	juego.sumar_material("madera", 7)
	juego.sumar_material("piedra", 1)
	verificar_igual(juego.motivo_sin_mejora("granja"), "Te falta 1 de piedra.", "Solo lo que falta")
	juego.sumar_material("piedra", 1)
	verificar(juego.mejorar_edificio("granja"), "Reconstruir la granja")
	verificar_igual(juego.material("madera"), 2, "Gasta la madera")
	verificar_igual(juego.material("piedra"), 0, "Y la piedra")
	dar_materiales(juego)
	verificar_igual(juego.oro, 1000 - DatosCiudad.costo_mejora("granja", 0), "Cobra la reconstrucción")
	verificar_igual(juego.nivel_edificio("granja"), 1, "La granja queda en nivel 1")
	verificar(not juego.mejorar_edificio("granja"), "No pasa del nivel del castillo")
	verificar_igual(juego.motivo_sin_mejora("granja"), "Primero mejora el castillo.", "Dice por qué")
	verificar(juego.mejorar_edificio("castillo"), "Mejorar el castillo")
	verificar(juego.mejorar_edificio("granja"), "Ahora sí, nivel 2")
	juego.oro = 100000
	juego.mejorar_edificio("castillo")
	juego.mejorar_edificio("granja")
	verificar_igual(juego.nivel_edificio("granja"), DatosCiudad.NIVEL_MAXIMO, "Nivel máximo")
	verificar(not juego.mejorar_edificio("granja"), "No pasa del máximo")
	verificar(not juego.mejorar_edificio("inventado"), "Un edificio inexistente no vale")
	juego.free()


func prueba_soldados_caben_en_las_barracas_y_cuestan_oro() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000
	dar_materiales(juego)
	verificar(not juego.reclutar(), "Sin barracas no hay soldados")
	juego.mejorar_edificio("barracas")
	var oro := juego.oro
	for i in 10:
		juego.reclutar()
	verificar_igual(juego.soldados, DatosCiudad.SOLDADOS_MAXIMOS[1], "Solo caben 5")
	verificar_igual(juego.oro, oro - 5 * DatosCiudad.COSTO_SOLDADO, "Cada uno cuesta oro")
	juego.free()


func prueba_la_granja_alimenta_y_sin_comida_se_van_soldados() -> void:
	var juego := _juego_nuevo()
	_ciudad_segura(juego)
	juego.comida = 4
	verificar_igual(juego.desertores_previstos(), 3, "Se puede prever cuántos se irán")
	var informe := juego.semana_ciudad()
	verificar_igual(informe["comida_consumida"], 10, "5 soldados comen 10")
	verificar_igual(informe["desertores"], 3, "Faltan 6 de comida: se van 3")
	verificar_igual(juego.soldados, 2, "Quedan 2")
	verificar_igual(juego.comida, 0, "La comida no queda negativa")
	verificar(juego.texto_informe(informe).contains("se fueron 3 soldados"), "Lo avisa")
	juego.mejorar_edificio("granja")
	juego.comida = 0
	informe = juego.semana_ciudad()
	verificar_igual(informe["desertores"], 0, "Con granja alcanza para los que quedan")
	verificar_igual(juego.comida, DatosCiudad.COMIDA_GRANJA[1] - 2 * DatosCiudad.COMIDA_POR_SOLDADO, "Sobra comida")
	juego.comida = 1
	juego.soldados = 3
	juego.edificios["granja"] = 0
	informe = juego.semana_ciudad()
	verificar(juego.texto_informe(informe).contains("se fueron 3 soldados") or juego.texto_informe(informe).contains("se fue 1 soldado"),
		"Singular o plural según cuántos se van")
	juego.free()


func prueba_el_mercado_cobra_impuestos_y_vende() -> void:
	var juego := _juego_nuevo()
	_ciudad_segura(juego)
	juego.mejorar_edificio("mercado")
	# Los objetos de su nivel y, aparte, una pila de pociones, vendas,
	# torniquetes y medicinas.
	var en_venta: int = DatosCiudad.OBJETOS_MERCADO[1] + DatosBotin.ORDEN_CONSUMIBLES.size()
	verificar_igual(juego.mercado.size(), en_venta, "Al reconstruirlo ya vende")
	for tipo in DatosBotin.ORDEN_CONSUMIBLES:
		var pila: Array = juego.mercado.filter(func(objeto: Dictionary) -> bool: return objeto["ranura"] == tipo)
		verificar_igual(pila.size(), 1, "Vende una pila de %s" % tipo)
		if pila.size() == 1:
			verificar_igual(pila[0]["cantidad"], DatosCiudad.CONSUMIBLES_MERCADO[tipo][1], "Las de su nivel (%s)" % tipo)
	var antes: Array[Dictionary] = juego.mercado.duplicate(true)
	var oro := juego.oro
	var informe := juego.semana_ciudad()
	verificar_igual(informe["impuestos"], DatosCiudad.IMPUESTOS[1], "Cobra los impuestos de su nivel")
	verificar_igual(juego.oro, oro + DatosCiudad.IMPUESTOS[1], "Suma el oro")
	verificar_igual(juego.mercado.size(), en_venta, "Siempre vende los de su nivel")
	verificar(juego.mercado != antes, "Cada semana cambia lo que vende")
	juego.oro = 10000
	var objeto: Dictionary = juego.mercado[0]
	var precio := juego.precio_compra(objeto)
	var en_inventario := juego.inventario.size()
	verificar(juego.comprar(0), "Comprar")
	verificar_igual(juego.oro, 10000 - precio, "Cobra el precio")
	verificar_igual(juego.inventario.size(), en_inventario + 1, "Va al inventario")
	verificar_igual(juego.mercado.size(), en_venta - 1, "Ya no está a la venta")
	verificar(not juego.comprar(99), "Un índice que no existe no vale")
	juego.oro = 0
	verificar(not juego.comprar(0), "Sin oro no se compra")
	juego.free()


func prueba_negociacion_baja_el_precio_pero_nunca_por_debajo_de_la_venta() -> void:
	var juego := _juego_nuevo()
	var objeto := DatosBotin.crear_arma("espada", 2, "raro")
	var normal := juego.precio_compra(objeto)
	verificar_igual(normal, roundi(objeto["precio"] * DatosCiudad.MARGEN_MERCADO), "Precio normal")
	juego.extra["negociacion"] = 27
	var tope := 1.0 - DatosEstadisticas.COMPRA_POR_NEGOCIACION * DatosEstadisticas.TOPE_PUNTOS
	verificar_igual(juego.precio_compra(objeto), roundi(objeto["precio"] * DatosCiudad.MARGEN_MERCADO * tope),
		"La rebaja tiene tope (el de los puntos)")
	var anterior := normal
	for puntos in [5, 10, 25, 30, 40, 120, 500]:
		juego.extra["negociacion"] = puntos
		var compra := juego.precio_compra(objeto)
		verificar(compra <= anterior, "Más Negociación nunca encarece la compra (%d)" % puntos)
		verificar(compra > juego.precio_venta(objeto), "Comprar sigue costando más que vender (%d)" % puntos)
		anterior = compra
	verificar_igual(juego.precio_venta(objeto), roundi(objeto["precio"]
		* (1.0 + DatosEstadisticas.VENTA_POR_NEGOCIACION * DatosEstadisticas.TOPE_PUNTOS)), "La venta tiene tope")
	juego.free()


func prueba_ni_el_mercado_ni_la_herreria_dan_oro_gratis() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000000
	dar_materiales(juego)
	for edificio_id in ["castillo", "castillo", "herreria", "herreria", "herreria", "mercado", "mercado", "mercado"]:
		juego.mejorar_edificio(edificio_id)
	for puntos in [0, 30, 120, 500]:
		juego.extra["negociacion"] = puntos
		for calidad in DatosBotin.CALIDADES:
			for nivel in [1, 3]:
				var objeto := DatosBotin.generar(nivel, juego.rng, "peto" if nivel == 1 else "anillo", calidad)
				var gasto := juego.precio_compra(objeto)
				var mejorado := objeto
				while juego.calidad_siguiente(mejorado) != "":
					gasto += juego.costo_herreria(mejorado)
					mejorado = DatosBotin.con_calidad(mejorado, juego.calidad_siguiente(mejorado))
				verificar(juego.precio_venta(mejorado) < gasto,
					"Comprar, mejorar y vender pierde oro (%s nivel %d, Negociación %d)" % [calidad, nivel, puntos])
	juego.free()


func prueba_la_herreria_sube_la_calidad_hasta_su_nivel() -> void:
	var juego := _juego_nuevo()
	var arma: Dictionary = juego.equipo["arma"]
	verificar_igual(juego.calidad_siguiente(arma), "", "En ruinas no mejora")
	verificar(not juego.mejorar_en_herreria("arma"), "No se puede")
	juego.oro = 100000
	dar_materiales(juego)
	juego.mejorar_edificio("herreria")
	var costo := juego.costo_herreria(arma)
	verificar_igual(costo, roundi(DatosBotin.precio_venta({"calidad": "raro", "nivel": 1}) * DatosCiudad.COSTO_HERRERIA), "Cuesta según la calidad nueva")
	var oro := juego.oro
	verificar(juego.mejorar_en_herreria("arma"), "Mejorar la espada")
	var mejorada: Dictionary = juego.equipo["arma"]
	verificar_igual(mejorada["calidad"], "raro", "Ahora es rara")
	verificar_igual(mejorada["id"], arma["id"], "Es el mismo objeto")
	verificar_igual(mejorada["base"], "espada", "Sigue siendo una espada")
	verificar(int(mejorada["danio_max"]) > int(arma["danio_max"]), "Pega más")
	verificar_igual(juego.oro, oro - costo, "Cobra")
	verificar(not juego.mejorar_en_herreria("arma"), "Con herrería nivel 1 no pasa de rara")
	verificar(not juego.mejorar_en_herreria("casco"), "Sin casco no hay nada que mejorar")
	juego.mejorar_edificio("castillo")
	juego.mejorar_edificio("herreria")
	verificar(juego.mejorar_en_herreria("arma"), "Con nivel 2, a épica")
	verificar_igual(juego.equipo["arma"]["calidad"], "epico", "Épica")
	var pieza := juego.agregar(DatosBotin.generar(1, juego.rng, "peto", "normal"))
	juego.equipar(pieza["id"])
	verificar(juego.mejorar_en_herreria("peto"), "También las armaduras")
	verificar(int(juego.equipo["peto"]["armadura"]) > int(pieza["armadura"]) or int(juego.equipo["peto"]["resistencia_magica"]) > int(pieza["resistencia_magica"]),
		"La armadura protege más")
	juego.free()


func prueba_pasar_la_semana_hace_vivir_la_ciudad() -> void:
	var juego := _juego_nuevo()
	juego.pasar_semana()
	verificar_igual(juego.informe_ciudad["semana"], 1, "El informe es de la semana que terminó")
	verificar_igual(juego.semana, 2, "Empieza la siguiente")
	juego.free()

## Ya no hay invasiones: aunque la ciudad no tenga ni un soldado y pasen muchas
## semanas, nadie la ataca ni le quita oro, comida o edificios.
func prueba_ya_no_atacan_la_ciudad() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000
	dar_materiales(juego)
	juego.mejorar_edificio("granja")
	juego.mejorar_edificio("mercado")
	var niveles := juego.edificios.duplicate()
	var oro := juego.oro
	for i in 60:
		var informe := juego.semana_ciudad()
		juego.semana += 1
		verificar(not informe.has("ataque"), "Semana %d sin ataque" % i)
	verificar_igual(juego.oro, oro + 60 * DatosCiudad.IMPUESTOS[1], "Solo suman los impuestos")
	verificar_igual(juego.edificios, niveles, "Ningún edificio se daña")
	verificar(not juego.datos_guardado().has("peligro"), "Ya no se guarda el peligro")
	juego.free()
