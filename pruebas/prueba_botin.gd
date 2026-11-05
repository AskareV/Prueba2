extends "res://pruebas/base_prueba.gd"
## Botín y precios: anillos, materiales de la ciudad, Negociación en la ciudad y
## Buen ojo en las zonas.


func _juego_nuevo(semilla := 77) -> EstadoReino:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	juego.rng.seed = semilla
	return juego


# --- Anillos ---

func prueba_cada_anillo_hace_mas_cuanto_mejor_es() -> void:
	for anillo_id in DatosBotin.ORDEN_ANILLOS:
		var anterior := 0.0
		var precio_anterior := 0
		for calidad in DatosBotin.CALIDADES:
			var anillo := DatosBotin.crear_anillo(anillo_id, 2, calidad)
			verificar_igual(anillo["ranura"], "anillo", "Es un anillo (%s)" % anillo_id)
			verificar(float(anillo["efecto"]) > anterior, "%s %s hace más" % [anillo_id, calidad])
			verificar(int(anillo["precio"]) > precio_anterior, "%s %s vale más" % [anillo_id, calidad])
			verificar(DatosBotin.texto_anillo(anillo) != "", "Dice lo que hace")
			anterior = float(anillo["efecto"])
			precio_anterior = int(anillo["precio"])
	var normal := DatosBotin.crear_anillo("vida", 1, "raro")
	var dificil := DatosBotin.crear_anillo("vida", 4, "raro")
	verificar_igual(dificil["efecto"], normal["efecto"], "Lo que hace depende solo de la calidad")
	verificar(int(dificil["precio"]) > int(normal["precio"]), "El nivel sube lo que pagan por él")
	verificar_igual(DatosBotin.texto_anillo(DatosBotin.crear_anillo("critico", 1, "raro")), "Crítico +6%", "Texto en porcentaje")
	verificar_igual(DatosBotin.texto_anillo(DatosBotin.crear_anillo("mana", 1, "epico")), "Maná +35", "Texto en puntos")
	verificar(DatosBotin.describir(normal).size() >= 3, "Se describe")


func prueba_los_anillos_salen_en_el_botin() -> void:
	var rng := rng_fijo(5)
	var cuantos := {}
	var anillos := 0
	var total := 4000
	for i in total:
		var objeto := DatosBotin.generar_botin(3, rng)
		if DatosBotin.es_anillo(objeto):
			anillos += 1
			cuantos[objeto["anillo"]] = int(cuantos.get(objeto["anillo"], 0)) + 1
			verificar_igual(objeto["nivel"], 3, "Del nivel del lugar")
	var esperado := total * (1.0 - DatosBotin.PROB_CONSUMIBLE) * DatosBotin.PROB_ANILLO
	verificar(anillos > esperado * 0.8 and anillos < esperado * 1.2, "Unos %d anillos de %d (salieron %d)" % [roundi(esperado), total, anillos])
	for anillo_id in DatosBotin.ORDEN_ANILLOS:
		verificar(int(cuantos.get(anillo_id, 0)) > 0, "Sale el de %s" % anillo_id)


func prueba_los_efectos_de_dos_anillos_se_juntan() -> void:
	var vida := DatosBotin.crear_anillo("vida", 1, "raro")
	var otra_vida := DatosBotin.crear_anillo("vida", 1, "normal")
	var calma := DatosBotin.crear_anillo("estres", 1, "legendario")
	var coagulante := DatosBotin.crear_anillo("sangrado", 1, "epico")
	var efectos := DatosBotin.efectos_anillos([])
	verificar_igual(efectos["vida"], 0, "Sin anillos no suma vida")
	verificar_cerca(efectos["sangrado"], 1.0, "Ni cambia el sangrado")
	efectos = DatosBotin.efectos_anillos([vida, otra_vida])
	verificar_igual(efectos["vida"], int(vida["efecto"]) + int(otra_vida["efecto"]), "Dos de vida se suman")
	efectos = DatosBotin.efectos_anillos([calma, DatosBotin.crear_anillo("estres", 1, "legendario")])
	verificar_cerca(efectos["estres"], (1.0 - float(calma["efecto"])) * (1.0 - float(calma["efecto"])),
		"Dos de calma: el segundo quita su parte de lo que queda")
	efectos = DatosBotin.efectos_anillos([coagulante, calma])
	verificar_cerca(efectos["sangrado"], 1.0 - float(coagulante["efecto"]), "El coagulante baja el sangrado")
	verificar_cerca(efectos["estres"], 1.0 - float(calma["efecto"]), "Y el de calma, el estrés")


func prueba_el_rey_lleva_dos_anillos() -> void:
	var juego := _juego_nuevo()
	var vida := juego.agregar(DatosBotin.crear_anillo("vida", 1, "normal"))
	var mana := juego.agregar(DatosBotin.crear_anillo("mana", 1, "normal"))
	var critico := juego.agregar(DatosBotin.crear_anillo("critico", 1, "normal"))
	verificar(juego.equipar(vida["id"]), "Equipa el primero")
	verificar_igual(juego.ranura_equipada(vida["id"]), "anillo_der", "En la mano derecha")
	verificar(juego.equipar(mana["id"]), "Equipa el segundo")
	verificar_igual(juego.ranura_equipada(mana["id"]), "anillo_izq", "En la izquierda, que estaba libre")
	verificar(not juego.equipar(critico["id"], "casco"), "Un anillo no va en el casco")
	verificar(juego.equipar(critico["id"], "anillo_izq"), "Cambia el de la izquierda")
	verificar_igual(juego.ranura_equipada(critico["id"]), "anillo_izq", "Ahora está ahí")
	verificar_igual(juego.ranura_equipada(mana["id"]), "", "El de maná ya no está puesto")
	verificar(juego.inventario.any(func(objeto: Dictionary) -> bool: return objeto["id"] == mana["id"]), "Vuelve a la mochila")
	verificar(juego.quitar("anillo_der"), "Se puede quitar un anillo")
	verificar(not juego.equipo.has("anillo_der"), "Esa mano queda libre")
	var casco := juego.agregar(DatosBotin.crear_pieza("casco", "cuero", 1, "normal"))
	verificar(not juego.equipar(casco["id"], "anillo_der"), "Un casco no va en una mano")
	juego.free()


func prueba_los_anillos_cambian_al_rey() -> void:
	var juego := _juego_nuevo()
	var sin_anillos := juego.crear_rey()
	var vida_antes := juego.vida_maxima_sana()
	for anillo_id in ["vida", "mana"]:
		juego.equipar(juego.agregar(DatosBotin.crear_anillo(anillo_id, 1, "epico"))["id"])
	var efecto: int = DatosBotin.ANILLOS["vida"]["efecto"][2]
	verificar_igual(juego.vida_maxima_sana(), vida_antes + efecto, "Más vida máxima")
	var rey := juego.crear_rey()
	verificar_igual(rey.vida_max_sana, sin_anillos.vida_max_sana + efecto, "En combate también")
	verificar_igual(rey.vida, rey.vida_max, "Empieza con toda la vida")
	verificar_cerca(rey.mana_max, sin_anillos.mana_max + float(DatosBotin.ANILLOS["mana"]["efecto"][2]), "Más maná máximo")
	# Si se lo quita herido, pierde esa vida de más (pero no muere).
	juego.vida_perdida = 30
	juego.quitar("anillo_der")
	verificar_igual(juego.vida_actual(), vida_antes - 30, "Sin el anillo, menos vida")
	juego.quitar("anillo_izq")
	juego.equipar(juego.agregar(DatosBotin.crear_anillo("critico", 1, "legendario"))["id"])
	verificar_cerca(juego.crear_rey().prob_critico(), sin_anillos.prob_critico() + 0.15, "Más crítico")
	juego.free()


func prueba_el_anillo_coagulante_hace_perder_menos_sangre() -> void:
	var normal := _juego_nuevo()
	var con_anillo := _juego_nuevo()
	con_anillo.equipar(con_anillo.agregar(DatosBotin.crear_anillo("sangrado", 1, "legendario"))["id"])
	for juego in [normal, con_anillo]:
		DatosHeridas.sumar_sangrado(juego.sangrados, "muslo_der", "externo", 3)
		juego.integridad["muslo_der"] = 40.0
		juego.curar_al_caminar(1.0)
	verificar(normal.sangre_perdida > 0.0, "Sin anillo pierde sangre al caminar")
	verificar(con_anillo.sangre_perdida < normal.sangre_perdida, "Con el anillo, menos")
	# En combate, igual.
	var rey_normal := normal.crear_rey()
	var rey_anillo := con_anillo.crear_rey()
	var perdida_normal := rey_normal.sangrar(1)
	var perdida_anillo := rey_anillo.sangrar(1)
	verificar_cerca(perdida_anillo, perdida_normal * 0.5, "En combate pierde la mitad (legendario)")
	normal.free()
	con_anillo.free()


func prueba_el_anillo_de_calma_baja_todo_el_estres() -> void:
	var juego := _juego_nuevo()
	var paso := juego.estres_de_paso(10.0)
	var mental := juego.estres_mental(10.0)
	juego.equipar(juego.agregar(DatosBotin.crear_anillo("estres", 1, "raro"))["id"])
	var factor := 1.0 - float(DatosBotin.ANILLOS["estres"]["efecto"][1])
	verificar_cerca(juego.estres_de_paso(10.0), paso * factor, "Al caminar")
	verificar_cerca(juego.estres_mental(10.0), mental * factor, "En combates, trampas y trabajos")
	juego.free()


func prueba_la_herreria_mejora_los_anillos() -> void:
	var juego := _juego_nuevo()
	juego.oro = 100000
	dar_materiales(juego)
	juego.mejorar_edificio("herreria")
	var anillo := juego.agregar(DatosBotin.crear_anillo("vida", 1, "normal"))
	juego.equipar(anillo["id"])
	verificar(juego.costo_herreria(anillo) > 0, "Tiene precio")
	verificar(juego.mejorar_en_herreria("anillo_der"), "Se mejora")
	var mejorado: Dictionary = juego.equipo["anillo_der"]
	verificar_igual(mejorado["calidad"], "raro", "Sube una calidad")
	verificar_igual(mejorado["anillo"], "vida", "Sigue siendo de vida")
	verificar_igual(mejorado["id"], anillo["id"], "Es el mismo")
	verificar(int(mejorado["efecto"]) > int(anillo["efecto"]), "Da más vida")
	juego.free()


# --- Materiales ---

func prueba_los_materiales_salen_segun_el_nivel() -> void:
	var rng := rng_fijo(9)
	for nivel in range(1, 5):
		var cuantos := {}
		for i in 3000:
			var hallazgo := DatosBotin.sortear_material(nivel, rng, DatosBotin.MATERIAL_COFRE)
			cuantos[hallazgo["material"]] = int(cuantos.get(hallazgo["material"], 0)) + 1
			var cantidad := int(hallazgo["cantidad"])
			verificar(cantidad >= DatosBotin.MATERIAL_COFRE[0] * nivel and cantidad <= DatosBotin.MATERIAL_COFRE[1] * nivel,
				"Cantidad según el nivel %d (%d)" % [nivel, cantidad])
		var tabla: Array = DatosBotin.PROB_MATERIAL[nivel]
		for i in DatosCiudad.ORDEN_MATERIALES.size():
			var material_id: String = DatosCiudad.ORDEN_MATERIALES[i]
			var esperado := 3000.0 * float(tabla[i]) / 100.0
			var salieron := int(cuantos.get(material_id, 0))
			verificar(salieron > esperado * 0.85 and salieron < esperado * 1.15,
				"Nivel %d, %s: unos %d de 3000 (salieron %d)" % [nivel, material_id, roundi(esperado), salieron])
	verificar(DatosBotin.PROB_MATERIAL[4][2] > DatosBotin.PROB_MATERIAL[1][2], "En los lugares difíciles sale más hierro")
	var doble := DatosBotin.sortear_material(1, rng, [2, 2], 2.0)
	verificar_igual(doble["cantidad"], 4, "El multiplicador (Buen ojo) da más")


func prueba_cofres_enemigos_y_zonas_dan_materiales() -> void:
	var juego := _juego_nuevo()
	var cofre := juego.abrir_cofre(2)
	verificar(not cofre["material"].is_empty(), "Un cofre siempre trae materiales")
	verificar_igual(juego.material(cofre["material"]["material"]), int(cofre["material"]["cantidad"]), "Y se guardan")
	verificar(juego.texto_botin(cofre).contains(DatosBotin.texto_material(cofre["material"])), "El mensaje los cuenta")
	var con_material := 0
	for i in 400:
		var botin := juego.recompensa_enemigo("goblin", 1)
		if not botin["material"].is_empty():
			con_material += 1
	verificar(con_material > 400 * DatosBotin.PROB_MATERIAL_ENEMIGO * 0.8 and con_material < 400 * DatosBotin.PROB_MATERIAL_ENEMIGO * 1.2,
		"Los enemigos los sueltan a veces (%d de 400)" % con_material)
	var antes := 0
	for material_id in DatosCiudad.ORDEN_MATERIALES:
		antes += juego.material(material_id)
	var suceso := juego.suceso_material(3)
	var despues := 0
	for material_id in DatosCiudad.ORDEN_MATERIALES:
		despues += juego.material(material_id)
	verificar_igual(despues - antes, int(suceso["cantidad"]), "El suceso de las zonas los guarda")
	verificar(int(suceso["cantidad"]) >= DatosBotin.MATERIAL_ZONA[0] * 3, "Y trae más que un cofre")
	verificar(DatosAventura.SUCESOS.has("materiales") and DatosAventura.SUCESOS_BUENOS.has("materiales"),
		"Es un suceso bueno de las zonas")
	for material_id in DatosCiudad.ORDEN_MATERIALES:
		verificar(DatosAventura.TEXTO_MATERIALES.has(material_id), "Tiene texto (%s)" % material_id)
	juego.free()


func prueba_cada_mejora_pide_materiales() -> void:
	for edificio_id in DatosCiudad.ORDEN:
		for nivel in DatosCiudad.NIVEL_MAXIMO:
			var pedidos := DatosCiudad.materiales_mejora(edificio_id, nivel)
			var total := 0
			for material_id in pedidos:
				verificar(DatosCiudad.MATERIALES.has(material_id), "Material válido (%s)" % edificio_id)
				total += int(pedidos[material_id])
			if DatosCiudad.costo_mejora(edificio_id, nivel) > 0:
				verificar(total > 0, "%s a nivel %d pide materiales" % [edificio_id, nivel + 1])
		verificar(DatosCiudad.materiales_mejora(edificio_id, DatosCiudad.NIVEL_MAXIMO).is_empty(), "Al máximo no pide nada")
	verificar_igual(DatosCiudad.texto_materiales({"madera": 8, "hierro": 2, "piedra": 3}), "8 de madera, 3 de piedra y 2 de hierro",
		"Texto en orden")


# --- Negociación en la ciudad ---

func prueba_negociacion_abarata_edificios_soldados_y_herreria() -> void:
	var juego := _juego_nuevo()
	juego.oro = 100000
	dar_materiales(juego)
	var normal := juego.costo_edificio("granja")
	verificar_igual(normal, DatosCiudad.costo_mejora("granja", 0), "Sin Negociación, el precio de siempre")
	verificar_igual(juego.costo_soldado(), DatosCiudad.COSTO_SOLDADO, "Y el soldado también")
	juego.extra["negociacion"] = 10
	verificar_igual(juego.costo_edificio("granja"), roundi(normal * 0.8), "+10: 20% menos")
	juego.extra["negociacion"] = 50
	verificar_igual(juego.costo_edificio("granja"), roundi(normal * 0.6), "Como mucho 40% menos")
	verificar_igual(juego.costo_soldado(), roundi(DatosCiudad.COSTO_SOLDADO * 0.6), "El soldado, igual")
	var oro := juego.oro
	verificar(juego.mejorar_edificio("granja"), "Mejora")
	verificar_igual(juego.oro, oro - roundi(normal * 0.6), "Cobra con la rebaja")
	verificar_igual(juego.material("madera"), 100000 - 5, "Los materiales no se rebajan")
	juego.mejorar_edificio("herreria")
	var arma: Dictionary = juego.equipo["arma"]
	juego.extra["negociacion"] = 0
	var herreria := juego.costo_herreria(arma)
	juego.extra["negociacion"] = 50
	verificar(juego.costo_herreria(arma) < herreria, "La herrería cobra menos")
	verificar(juego.costo_herreria(arma) > juego.precio_venta(DatosBotin.con_calidad(arma, "raro")),
		"Pero más de lo que te pagarían por el arma mejorada")
	juego.mejorar_edificio("barracas")
	oro = juego.oro
	verificar(juego.reclutar(), "Recluta")
	verificar_igual(juego.oro, oro - juego.costo_soldado(), "Con la rebaja")
	juego.free()


# --- Buen ojo en las zonas ---

func prueba_buen_ojo_cuenta_en_las_zonas() -> void:
	var normal := _juego_nuevo(3)
	var con_ojo := _juego_nuevo(3)
	con_ojo.extra["buen_ojo"] = 20
	var oro_normal := normal.suceso_oro(2)
	var oro_ojo := con_ojo.suceso_oro(2)
	verificar_igual(oro_ojo, con_ojo.oro_hallado(oro_normal), "Más oro en las bolsas de las zonas")
	verificar(oro_ojo > oro_normal, "Bastante más con +20")
	verificar_igual(con_ojo.oro, oro_ojo, "Y se guarda")
	var material_normal := normal.suceso_material(2)
	var material_ojo := con_ojo.suceso_material(2)
	verificar(int(material_ojo["cantidad"]) > int(material_normal["cantidad"]), "Más materiales")
	# Mejor calidad en los objetos que se encuentran.
	var buenos := {"normal": 0, "ojo": 0}
	for i in 1500:
		for clave in buenos:
			var juego: EstadoReino = normal if clave == "normal" else con_ojo
			var objeto := juego.suceso_objeto(2)
			if not DatosBotin.es_consumible(objeto) and objeto["calidad"] != "normal":
				buenos[clave] += 1
	verificar(buenos["ojo"] > buenos["normal"] * 1.3, "Mejor calidad (%d contra %d)" % [buenos["ojo"], buenos["normal"]])
	normal.free()
	con_ojo.free()
