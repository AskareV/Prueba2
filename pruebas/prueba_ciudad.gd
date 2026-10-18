extends "res://pruebas/base_prueba.gd"
## Ciudad: edificios, comida, soldados, peligro, ataques, mercado y herrería.


func _juego_nuevo() -> EstadoReino:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	juego.rng.seed = 77
	return juego


func prueba_la_ciudad_empieza_en_ruinas() -> void:
	var juego := _juego_nuevo()
	verificar_igual(juego.nivel_edificio("castillo"), 1, "El castillo empieza en pie")
	for edificio_id in ["herreria", "granja", "mercado", "barracas"]:
		verificar_igual(juego.nivel_edificio(edificio_id), 0, "%s empieza en ruinas" % edificio_id)
	verificar_igual(juego.comida, DatosCiudad.COMIDA_INICIAL, "Algo de comida guardada")
	verificar_igual(juego.soldados, 0, "Sin soldados")
	verificar_cerca(juego.peligro, 0.0, "Sin peligro al empezar")
	verificar_cerca(juego.defensa_ciudad(), float(DatosCiudad.MURALLAS[1]), "Solo las murallas del castillo")
	juego.free()


func prueba_reconstruir_y_mejorar_cuesta_oro_y_el_castillo_limita() -> void:
	var juego := _juego_nuevo()
	verificar(not juego.mejorar_edificio("granja"), "Sin oro no se reconstruye")
	verificar_igual(juego.motivo_sin_mejora("granja"), "No te alcanza el oro.", "Dice por qué")
	juego.oro = 1000
	verificar(juego.mejorar_edificio("granja"), "Reconstruir la granja")
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
	verificar(not juego.reclutar(), "Sin barracas no hay soldados")
	juego.mejorar_edificio("barracas")
	var oro := juego.oro
	for i in 10:
		juego.reclutar()
	verificar_igual(juego.soldados, DatosCiudad.SOLDADOS_MAXIMOS[1], "Solo caben 5")
	verificar_igual(juego.oro, oro - 5 * DatosCiudad.COSTO_SOLDADO, "Cada uno cuesta oro")
	verificar_cerca(juego.defensa_ciudad(), 5.0 + DatosCiudad.MURALLAS[1], "Cada soldado defiende 1")
	juego.free()


func prueba_herreria_y_liderazgo_suben_la_defensa() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000
	juego.mejorar_edificio("barracas")
	for i in 5:
		juego.reclutar()
	var sin := juego.defensa_ciudad()
	juego.mejorar_edificio("herreria")
	verificar(juego.defensa_ciudad() > sin, "Con herrería, los soldados defienden más")
	var con_herreria := juego.defensa_ciudad()
	juego.extra["liderazgo"] = 10
	verificar(juego.defensa_ciudad() > con_herreria, "Liderazgo sube la moral y la defensa")
	verificar(juego.cambio_peligro() < DatosCiudad.PELIGRO_POR_SEMANA, "La defensa frena el peligro")
	juego.free()


func prueba_sin_defensa_el_peligro_sube_cada_semana() -> void:
	var juego := _juego_nuevo()
	var esperado := DatosCiudad.PELIGRO_POR_SEMANA - DatosCiudad.PELIGRO_POR_DEFENSA * DatosCiudad.MURALLAS[1]
	verificar_cerca(juego.cambio_peligro(), esperado, "Sube lo que no frenan las murallas")
	juego.rng.seed = 1
	var informe := juego.semana_ciudad()
	verificar_cerca(informe["peligro_despues"], esperado, "Tras una semana")
	for i in 30:
		juego.semana_ciudad()
		juego.semana += 1
	verificar(juego.peligro <= 100.0 and juego.peligro >= 0.0, "El peligro queda entre 0 y 100")
	juego.free()


func prueba_bien_defendida_el_peligro_baja_y_no_atacan() -> void:
	var juego := _juego_nuevo()
	juego.oro = 100000
	for edificio_id in ["castillo", "castillo", "barracas", "barracas", "barracas", "granja", "granja", "granja", "herreria", "herreria", "herreria"]:
		juego.mejorar_edificio(edificio_id)
	while juego.reclutar():
		pass
	juego.peligro = 50.0
	verificar(juego.cambio_peligro() < 0.0, "Con buena defensa el peligro baja")
	for i in 10:
		juego.semana_ciudad()
		juego.semana += 1
	verificar_cerca(juego.peligro, 0.0, "Llega a 0")
	var ataques := 0
	for i in 20:
		if juego.semana_ciudad().has("ataque"):
			ataques += 1
	verificar_igual(ataques, 0, "Con peligro 0 no hay ataques")
	juego.free()


func prueba_la_granja_alimenta_y_sin_comida_se_van_soldados() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000
	juego.mejorar_edificio("barracas")
	for i in 5:
		juego.reclutar()
	juego.comida = 4
	var informe := juego.semana_ciudad()
	verificar_igual(informe["comida_consumida"], 10, "5 soldados comen 10")
	verificar_igual(informe["desertores"], 3, "Faltan 6 de comida: se van 3")
	verificar_igual(juego.comida, 0, "La comida no queda negativa")
	verificar(juego.texto_informe(informe).contains("se fueron 3 soldados"), "Lo avisa")
	juego.mejorar_edificio("granja")
	juego.comida = 0
	informe = juego.semana_ciudad()
	verificar_igual(informe["desertores"], 0, "Con granja alcanza para los que quedan")
	verificar_igual(juego.comida, DatosCiudad.COMIDA_GRANJA[1] - 2 * DatosCiudad.COMIDA_POR_SOLDADO, "Sobra comida")
	juego.free()


func prueba_el_mercado_cobra_impuestos_y_vende() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000
	juego.mejorar_edificio("mercado")
	verificar_igual(juego.mercado.size(), DatosCiudad.OBJETOS_MERCADO[1], "Al reconstruirlo ya vende")
	var oro := juego.oro
	juego.semana_ciudad()
	verificar(juego.oro >= oro + DatosCiudad.IMPUESTOS[1] - roundi((oro + DatosCiudad.IMPUESTOS[1]) * DatosCiudad.SAQUEO_ORO),
		"Cobra impuestos (salvo un saqueo)")
	verificar_igual(juego.mercado.size(), DatosCiudad.OBJETOS_MERCADO[1], "Cada semana cambia lo que vende")
	juego.oro = 10000
	var objeto: Dictionary = juego.mercado[0]
	var precio := juego.precio_compra(objeto)
	var en_inventario := juego.inventario.size()
	verificar(juego.comprar(0), "Comprar")
	verificar_igual(juego.oro, 10000 - precio, "Cobra el precio")
	verificar_igual(juego.inventario.size(), en_inventario + 1, "Va al inventario")
	verificar_igual(juego.mercado.size(), DatosCiudad.OBJETOS_MERCADO[1] - 1, "Ya no está a la venta")
	verificar(not juego.comprar(99), "Un índice que no existe no vale")
	juego.oro = 0
	verificar(not juego.comprar(0), "Sin oro no se compra")
	juego.free()


func prueba_negociacion_baja_el_precio_pero_nunca_por_debajo_de_la_venta() -> void:
	var juego := _juego_nuevo()
	var objeto := DatosBotin.crear_arma("espada", 2, "raro")
	var normal := juego.precio_compra(objeto)
	verificar_igual(normal, roundi(objeto["precio"] * DatosCiudad.MARGEN_MERCADO), "Precio normal")
	juego.extra["negociacion"] = 10
	verificar(juego.precio_compra(objeto) < normal, "Negociación lo baja")
	for puntos in [40, 120, 500]:
		juego.extra["negociacion"] = puntos
		verificar(juego.precio_compra(objeto) > juego.precio_venta(objeto), "Comprar sigue costando más que vender (Negociación %d)" % puntos)
	juego.free()


func prueba_la_herreria_sube_la_calidad_hasta_su_nivel() -> void:
	var juego := _juego_nuevo()
	var arma: Dictionary = juego.equipo["arma"]
	verificar_igual(juego.calidad_siguiente(arma), "", "En ruinas no mejora")
	verificar(not juego.mejorar_en_herreria("arma"), "No se puede")
	juego.oro = 100000
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


func prueba_perder_un_ataque_saquea_y_dania_un_edificio() -> void:
	var juego := _juego_nuevo()
	juego.oro = 1000
	juego.mejorar_edificio("granja")
	juego.mejorar_edificio("barracas")
	juego.reclutar()
	juego.semana = 30
	juego.peligro = 100.0
	var oro := juego.oro
	var comida := juego.comida
	var informe := {}
	for i in 20:
		informe = juego.semana_ciudad()
		if informe.has("ataque") and not informe["ataque"]["ganado"]:
			break
	verificar(informe.has("ataque") and not informe["ataque"]["ganado"], "Con poca defensa pierde")
	var ataque: Dictionary = informe["ataque"]
	verificar(int(ataque["oro"]) > 0 and juego.oro < oro + 100, "Se llevan oro")
	verificar(ataque["danado"] in ["granja", "barracas"], "Daña un edificio en pie (no el castillo)")
	verificar(juego.texto_informe(informe).contains("saquearon"), "Lo avisa")
	verificar(juego.soldados <= juego.soldados_maximos(), "No quedan más soldados de los que caben")
	verificar_igual(juego.nivel_edificio("castillo"), 1, "El castillo no se daña")
	verificar(comida >= 0 and juego.comida >= 0, "La comida no queda negativa")
	juego.free()


func prueba_ganar_un_ataque_baja_el_peligro() -> void:
	var juego := _juego_nuevo()
	juego.oro = 100000
	for edificio_id in ["castillo", "castillo", "barracas", "barracas", "barracas", "herreria", "herreria", "herreria"]:
		juego.mejorar_edificio(edificio_id)
	while juego.reclutar():
		pass
	juego.semana = 2
	juego.peligro = 100.0
	# Con defensa de sobra el peligro baja, pero puede atacar en esa semana.
	var informe := {}
	for i in 50:
		juego.peligro = 100.0
		informe = juego.semana_ciudad()
		if informe.has("ataque"):
			break
	verificar(informe.has("ataque") and informe["ataque"]["ganado"], "Con mucha defensa gana")
	verificar(juego.peligro < 100.0, "El peligro baja")
	verificar(juego.texto_informe(informe).contains("defendieron"), "Lo avisa")
	juego.free()


func prueba_pasar_la_semana_hace_vivir_la_ciudad() -> void:
	var juego := _juego_nuevo()
	juego.pasar_semana()
	verificar_igual(juego.informe_ciudad["semana"], 1, "El informe es de la semana que terminó")
	verificar_igual(juego.semana, 2, "Empieza la siguiente")
	verificar(juego.peligro > 0.0, "Sin defensa, el peligro subió")
	juego.free()
