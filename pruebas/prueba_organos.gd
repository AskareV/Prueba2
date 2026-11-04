extends "res://pruebas/base_prueba.gd"
## Órganos: cuándo se dañan (arma, fuerza y armadura), qué hacen y cuánto duran.

const ARCHIVO_PRUEBA := "user://prueba_organos.save"


func _juego() -> EstadoReino:
	var juego := EstadoReino.new()
	juego.nueva_partida(true)
	return juego


## Probabilidad de dañar ese órgano con un golpe medio de ese atacante, como en
## MotorCombate._danar_organos.
func _prob(atacante: Luchador, defensor: Luchador, parte_id: String, organo_id: String) -> float:
	var arma := atacante.datos_arma()
	var base := (float(arma["danio_min"]) + float(arma["danio_max"])) / 2.0
	var fuerza := base * MotorCombate.multiplicador_golpe(atacante, defensor, parte_id) \
		* MotorCombate.compensacion(atacante, defensor, parte_id)
	var armadura := defensor.proteccion(DatosCuerpo.zona_de(parte_id), arma["tipo"])
	return DatosOrganos.probabilidad(organo_id, arma["tipo"], fuerza, false, armadura)


func prueba_datos_de_los_organos() -> void:
	for organo_id in DatosOrganos.ORDEN:
		verificar(DatosCuerpo.PARTES.has(DatosOrganos.parte_de(organo_id)), "%s está en una parte" % organo_id)
		verificar_cerca(DatosOrganos.probabilidad(organo_id, "arcano", 30.0), 0.0, "La magia no daña %s" % organo_id)
	verificar(DatosOrganos.organos_de("craneo").size() == 1 and DatosOrganos.organos_de("craneo")[0] == "cerebro",
		"En el cráneo está el cerebro")
	verificar(DatosOrganos.organos_de("torax_izq").has("corazon"), "El corazón, en el tórax izquierdo")
	verificar(DatosOrganos.organos_de("mano_der").is_empty(), "La mano no tiene órganos")
	verificar_igual(DatosOrganos.con_articulo("intestinos"), "los intestinos", "Con su artículo")
	# La fuerza: un golpe flojo no llega; con la de referencia, la de la tabla; más fuerte, hasta ×1,5.
	verificar_cerca(DatosOrganos.probabilidad("corazon", "punzante", 5.0), 0.0, "Un golpe flojo no llega al corazón")
	verificar_cerca(DatosOrganos.probabilidad("corazon", "punzante", 16.0), 0.06, "Con la fuerza de referencia, 6%")
	verificar_cerca(DatosOrganos.probabilidad("corazon", "punzante", 40.0), 0.09, "Muy fuerte, hasta ×1,5")
	verificar_cerca(DatosOrganos.probabilidad("pulmon_der", "cortante", 16.0, true), 0.1, "Con la costilla rota, el doble")
	# La armadura sube la fuerza que hace falta: cada punto, 0,25 más.
	verificar_cerca(DatosOrganos.probabilidad("corazon", "punzante", 16.0, false, 20.0), 0.03, "Con 20 de armadura, la mitad")
	verificar_cerca(DatosOrganos.probabilidad("corazon", "punzante", 16.0, false, 40.0), 0.0, "Con 40, no llega")


## Contra un corte, la malla casi no deja llegar a un órgano; contra un mazazo, sí.
func prueba_el_tipo_de_armadura_cambia_los_organos() -> void:
	var sin_armadura := DatosRivales.crear_rival("bandido")
	var con_malla := DatosRivales.crear_rival("bandido")
	con_malla.armadura = {"torso": {"fisica": 30, "magica": 0, "tipo": "malla"}}
	var con_acolchada := DatosRivales.crear_rival("bandido")
	con_acolchada.armadura = {"torso": {"fisica": 30, "magica": 0, "tipo": "acolchada"}}
	var espada := DatosRivales.crear_rey(true, "espada")
	var maza := DatosRivales.crear_rey(true, "maza")
	verificar(_prob(espada, sin_armadura, "abdomen", "intestinos") > 0.03, "Sin armadura, la espada llega a los intestinos")
	verificar_cerca(_prob(espada, con_malla, "abdomen", "intestinos"), 0.0, "Con malla, la espada no llega")
	verificar(_prob(maza, con_malla, "abdomen", "higado") > 0.01, "Con malla, la maza sí llega al hígado")
	verificar(_prob(maza, con_acolchada, "abdomen", "higado") < _prob(maza, con_malla, "abdomen", "higado"),
		"Lo acolchado frena mejor el mazazo")


## Con la lanza se dañan órganos del torso más seguido que con la espada; la magia nunca.
func prueba_el_arma_cambia_los_organos() -> void:
	var rng := rng_fijo(51)
	var veces := {}
	for arma_id in ["espada", "lanza", "baston"]:
		var conteo := 0
		var coinciden := true
		for i in 1500:
			var atacante := DatosRivales.crear_rey(true, arma_id)
			var defensor := DatosRivales.crear_rival("bandido")
			var resultado := MotorCombate.resolver_ataque(atacante, defensor, "torax_izq", rng, 1)
			coinciden = coinciden and (resultado["organos"] as Array).size() == defensor.organos.size()
			if not defensor.organos.is_empty():
				conteo += 1
		verificar(coinciden, "%s: el resultado cuenta los órganos dañados" % arma_id)
		veces[arma_id] = conteo
	verificar(veces["espada"] > 0, "La espada a veces llega a un órgano del tórax (%d de 1500)" % veces["espada"])
	verificar(veces["lanza"] > veces["espada"] * 2, "La lanza, mucho más (%d de 1500)" % veces["lanza"])
	verificar_igual(veces["baston"], 0, "La magia nunca")


func prueba_efectos_de_los_organos() -> void:
	var luchador := DatosRivales.crear_rival("bandido")
	verificar_cerca(luchador.conciencia(), 1.0, "Sano, conciencia completa")
	luchador.organos["cerebro"] = true
	verificar_cerca(luchador.conciencia(), 0.7, "Con el cerebro dañado, 70%")
	verificar_cerca(luchador.respiracion(), 1.0, "Respira bien")
	luchador.organos["traquea"] = true
	verificar_cerca(luchador.respiracion(), 0.5, "La tráquea dañada, a la mitad")
	luchador.organos["pulmon_der"] = true
	verificar_cerca(luchador.respiracion(), 0.3, "Y con un pulmón, 30%")
	var rapidez := luchador.rapidez_efectiva()
	luchador.organos["columna"] = true
	verificar_cerca(luchador.mov_brazo("der"), 0.6, "La columna: brazos al 60%")
	verificar_cerca(luchador.mov_piernas(), 0.6, "Y piernas al 60%")
	verificar(luchador.rapidez_efectiva() < rapidez, "Más lento")
	# El corazón, la carótida, el hígado y el bazo sangran grave.
	var otro := DatosRivales.crear_rival("bandido")
	verificar_igual(MotorCombate.danar_organo(otro, "corazon"), 3, "El corazón sangra grave")
	verificar(DatosHeridas.hay_sangrado(otro.sangrados, "interno"), "Por dentro")
	verificar(not otro.sangra_por_fuera(), "No por fuera")
	verificar_igual(MotorCombate.danar_organo(otro, "carotida"), 3, "La carótida, también")
	verificar(otro.sangra_por_fuera(), "Por fuera")
	verificar_igual(MotorCombate.danar_organo(otro, "traquea"), 0, "La tráquea no sangra")
	verificar(otro.organos.has("traquea"), "Pero queda dañada")


## En un combate, una poción que cura del todo la parte sana sus órganos.
func prueba_la_pocion_sana_el_organo_si_cura_la_parte() -> void:
	var luchador := DatosRivales.crear_rival("bandido")
	luchador.integridad["abdomen"] = 90.0
	luchador.organos["higado"] = true
	luchador.curar(0, 5.0)
	verificar(luchador.organos.has("higado"), "Sin curar del todo la parte, sigue dañado")
	luchador.curar(0, 10.0)
	verificar(not luchador.organos.has("higado"), "Con la parte curada, sana")


## Un órgano dañado sigue de un combate al siguiente hasta que su parte se cura del todo.
func prueba_los_organos_duran_hasta_curar_la_parte() -> void:
	var juego := _juego()
	var rey := juego.crear_rey()
	rey.integridad["torax_izq"] = 50.0
	MotorCombate.danar_organo(rey, "pulmon_izq")
	juego.guardar_salud(rey)
	verificar(juego.organos.has("pulmon_izq"), "Queda guardado al terminar el combate")
	verificar(juego.crear_rey().organos.has("pulmon_izq"), "Y sigue en el combate siguiente")
	juego.curar(0, 30.0)
	verificar(juego.organos.has("pulmon_izq"), "Con la parte a medio curar sigue dañado")
	juego.curar(0, 30.0)
	verificar(juego.organos.is_empty(), "Al curarse del todo la parte, sana")
	juego.free()


func prueba_los_intestinos_danados_infectan() -> void:
	var juego := _juego()
	var rey := juego.crear_rey()
	rey.integridad["abdomen"] = 60.0
	MotorCombate.danar_organo(rey, "intestinos")
	juego.guardar_salud(rey)
	verificar_igual(int(juego.infeccion_de("abdomen").get("etapa", 0)), 1, "La herida del abdomen queda infectada")
	juego.free()


## Si se desmayó con el cerebro dañado, lo traen despierto igual.
func prueba_desmayado_con_el_cerebro_danado_vuelve_despierto() -> void:
	var juego := _juego()
	var rey := juego.crear_rey()
	rey.integridad["craneo"] = 5.0
	MotorCombate.danar_organo(rey, "cerebro")
	rey.desmayado = true
	juego.guardar_salud(rey)
	var nuevo := juego.crear_rey()
	verificar(nuevo.organos.has("cerebro"), "El cerebro sigue dañado")
	verificar(nuevo.conciencia() >= MotorCombate.umbral_desmayo(nuevo), "Pero empieza despierto")
	juego.free()


## Los órganos dañados se guardan con la partida, y las piezas de antes de los
## tipos de armadura se cargan con su tipo.
func prueba_los_organos_y_las_armaduras_se_guardan() -> void:
	var juego := _juego()
	juego.integridad = {"torax_der": 40.0}
	juego.organos = {"pulmon_der": true}
	juego.agregar(DatosBotin.crear_pieza("peto", "placas", 3, "raro"))
	var vieja := juego.agregar({"ranura": "casco", "calidad": "normal", "nivel": 1, "estilo": "metal",
		"nombre": "Casco de bronce", "armadura": 6, "resistencia_magica": 2, "precio": 8})
	verificar(juego.guardar(ARCHIVO_PRUEBA), "Se guarda")
	var cargado := EstadoReino.new()
	verificar(cargado.cargar(ARCHIVO_PRUEBA), "Se carga")
	verificar_igual(cargado.organos, {"pulmon_der": true}, "Los órganos dañados")
	var tipos := {}
	for objeto in cargado.inventario:
		tipos[objeto["id"]] = objeto.get("tipo", "")
	verificar_igual(tipos[vieja["id"]], "malla", "La pieza vieja de metal se carga de malla")
	verificar(tipos.values().has("placas"), "La de placas sigue de placas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO_PRUEBA))
	juego.free()
	cargado.free()
