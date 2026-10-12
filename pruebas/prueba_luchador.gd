extends "res://pruebas/base_prueba.gd"
## Estado del luchador: vida, lateralidad y funciones de supervivencia (B.2).


func prueba_rey_empieza_sano_con_100_de_vida() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	verificar_igual(rey.vida, 100, "Vida inicial del rey")
	for funcion_id in DatosCuerpo.FUNCIONES:
		verificar_cerca(rey.funcion(funcion_id), 1.0, "Función %s al empezar" % funcion_id)
	verificar(not rey.fuera_de_combate(), "Empieza en combate")


func prueba_lateralidad() -> void:
	var diestro := DatosRivales.crear_rey(true, "espada")
	var zurdo := DatosRivales.crear_rey(false, "espada")
	verificar_igual(diestro.mano_arma(), "mano_der", "El diestro lleva el arma en la derecha")
	verificar_igual(zurdo.mano_arma(), "mano_izq", "El zurdo lleva el arma en la izquierda")
	verificar_igual(DatosRivales.crear_rival("orco").mano_arma(), "mano_izq", "El orco es zurdo")


func prueba_vision_con_un_ojo_y_sin_ojos() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	rey.integridad["ojo_der"] = 0.0
	verificar_cerca(rey.vision(), 0.7, "Visión con un solo ojo")
	rey.integridad["ojo_izq"] = 0.0
	verificar_cerca(rey.vision(), 0.0, "Visión sin ojos")


func prueba_brazo_depende_de_su_peor_parte() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	rey.integridad["mano_der"] = 40.0
	verificar_cerca(rey.mov_brazo("der"), 0.4, "El brazo vale lo que su parte más dañada")
	verificar_cerca(rey.mov_brazo("izq"), 1.0, "El otro brazo no cambia")


func prueba_cuello_inutilizado_afecta_brazos_y_piernas() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	rey.integridad["cuello"] = 10.0
	verificar(rey.mov_brazo("der") < 0.5, "La columna afecta los brazos")
	verificar(rey.mov_piernas() < 0.5, "La columna afecta las piernas")
	verificar(rey.respiracion() <= 0.1, "El cuello afecta la respiración")


func prueba_empunar_con_la_otra_mano() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	rey.desarmado = true
	rey.integridad["mano_der"] = 5.0
	verificar(rey.empunar(), "Puede tomar el arma con la mano izquierda")
	verificar(rey.mano_torpe, "Usa la mano torpe")
	verificar_igual(rey.lado_arma(), "izq", "El arma queda en la izquierda")
	rey.desarmado = true
	rey.integridad["mano_izq"] = 5.0
	verificar(not rey.empunar(), "Sin manos útiles no puede empuñar")
	verificar(rey.desarmado, "Sigue desarmado")


func prueba_niveles_de_herida() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var esperado := {100.0: 0, 85.0: 1, 50.0: 2, 20.0: 3, 10.0: 4}
	for valor in esperado:
		rey.integridad["abdomen"] = valor
		verificar_igual(rey.nivel("abdomen"), esperado[valor], "Nivel con integridad %s" % valor)


func prueba_recibir_golpe() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	var antes := rey.recibir_golpe("mano_der", 10, 30.0, "Corte", 1)
	verificar_cerca(antes, 100.0, "Devuelve la integridad previa")
	verificar_igual(rey.vida, 90, "Resta la vida indicada")
	verificar_cerca(rey.integridad["mano_der"], 70.0, "La mano pierde el desgaste indicado")
	verificar_igual(rey.heridas_de("mano_der"), {"Corte": 1}, "Registra la herida")
	rey.recibir_golpe("abdomen", 500, 50.0, "Corte", 2)
	verificar_igual(rey.vida, 0, "La vida no baja de 0")
	verificar(rey.fuera_de_combate(), "Sin vida queda fuera de combate")


func prueba_estado_concuerda_en_genero() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	rey.integridad["mano_der"] = 5.0
	rey.integridad["hombro_der"] = 5.0
	verificar_igual(rey.estado("mano_der"), "Inutilizada", "La mano es femenina")
	verificar_igual(rey.estado("hombro_der"), "Inutilizado", "El hombro es masculino")
	rey.integridad["espinilla_izq"] = 50.0
	rey.integridad["muslo_izq"] = 50.0
	verificar_igual(rey.estado("espinilla_izq"), "Herida", "La espinilla está herida")
	verificar_igual(rey.estado("muslo_izq"), "Herido", "El muslo está herido")
	verificar_igual(rey.estado("abdomen"), "Sano", "Sano en masculino")


func prueba_cobertura_baja_al_inutilizar_brazos_y_piernas() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	verificar_cerca(rey.cobertura(), Luchador.cobertura_maxima(), "Sano cubre al máximo")
	rey.integridad["mano_izq"] = 40.0
	verificar_cerca(rey.cobertura(), Luchador.cobertura_maxima(), "Un brazo herido pero útil sigue cubriendo")
	rey.integridad["mano_izq"] = 10.0
	verificar_cerca(rey.cobertura(), Luchador.cobertura_maxima() - Luchador.COBERTURA_POR_BRAZO,
		"Un brazo inutilizado deja de cubrir")
	rey.integridad["pie_der"] = 10.0
	verificar_cerca(rey.cobertura(),
		Luchador.cobertura_maxima() - Luchador.COBERTURA_POR_BRAZO - Luchador.COBERTURA_POR_PIERNA,
		"Una pierna inutilizada deja de cubrir")


func prueba_defensa_por_zona() -> void:
	var rey := DatosRivales.crear_rey(true, "espada")
	verificar_cerca(rey.defensa("brazo_der"), 0.0, "Los brazos van delante: no esquivan")
	verificar_cerca(rey.defensa("pierna_izq"), rey.esquiva(), "Las piernas solo esquivan")
	verificar_cerca(rey.defensa("torso"), rey.esquiva() + rey.cobertura(), "El torso esquiva y está cubierto")
	verificar_cerca(rey.defensa("cabeza"), rey.defensa("torso"), "La cabeza se cubre igual que el torso")
	rey.defendiendo = true
	verificar_cerca(rey.defensa("brazo_der"), Luchador.DEFENSA_GUARDIA, "En guardia también protege los brazos")


func prueba_sin_brazos_pelea_a_patadas() -> void:
	var rey := DatosRivales.crear_rey(true, "maza")
	rey.desarmado = true
	verificar_igual(rey.arma_actual(), "punos", "Desarmado con brazos útiles: puños")
	rey.integridad["mano_der"] = 5.0
	verificar_igual(rey.arma_actual(), "punos", "Con un brazo útil todavía usa los puños")
	rey.integridad["antebrazo_izq"] = 5.0
	verificar_igual(rey.arma_actual(), "patadas", "Sin brazos útiles, a patadas")
	verificar_cerca(rey.fuerza_ataque(), rey.mov_piernas(), "Las patadas dependen de las piernas")
