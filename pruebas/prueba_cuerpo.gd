extends "res://pruebas/base_prueba.gd"
## Estructura del cuerpo: 21 partes en 6 zonas (docs/diseno.md, punto A).


func prueba_hay_21_partes_y_6_zonas() -> void:
	verificar_igual(DatosCuerpo.PARTES.size(), 21, "Número de partes")
	verificar_igual(DatosCuerpo.ZONAS.size(), 6, "Número de zonas")


func prueba_zonas_en_el_orden_acordado() -> void:
	var esperado := ["cabeza", "torso", "brazo_der", "brazo_izq", "pierna_der", "pierna_izq"]
	verificar_igual(DatosCuerpo.ZONAS.keys(), esperado, "Orden de las zonas")


func prueba_cada_parte_esta_en_su_zona_una_vez() -> void:
	var vistas := {}
	for zona_id in DatosCuerpo.ZONAS:
		for parte_id in DatosCuerpo.partes_de(zona_id):
			verificar(not vistas.has(parte_id), "%s aparece en más de una zona" % parte_id)
			vistas[parte_id] = true
			verificar_igual(DatosCuerpo.zona_de(parte_id), zona_id, "Zona de %s" % parte_id)
	verificar_igual(vistas.size(), 21, "Partes repartidas en las zonas")


func prueba_partes_por_zona() -> void:
	verificar_igual(DatosCuerpo.partes_de("cabeza").size(), 4, "Partes de la cabeza")
	verificar_igual(DatosCuerpo.partes_de("torso").size(), 3, "Partes del torso")
	verificar_igual(DatosCuerpo.partes_de("brazo_der").size(), 4, "Partes del brazo derecho")
	verificar_igual(DatosCuerpo.partes_de("pierna_izq").size(), 3, "Partes de la pierna izquierda")
	verificar(DatosCuerpo.partes_de("cabeza").has("cuello"), "El cuello va en la zona Cabeza")
	verificar(DatosCuerpo.partes_de("brazo_der").has("hombro_der"), "El hombro va en la zona Brazo")
	verificar(DatosCuerpo.partes_de("torso").has("abdomen"), "El abdomen va en la zona Torso")


func prueba_todas_las_partes_tienen_sus_datos() -> void:
	var claves := ["nombre", "corto", "articulo", "texto", "zona", "tamano", "danio", "fragilidad", "hueso", "organos"]
	for parte_id in DatosCuerpo.PARTES:
		var datos: Dictionary = DatosCuerpo.PARTES[parte_id]
		for clave in claves:
			verificar(datos.has(clave), "%s no tiene '%s'" % [parte_id, clave])
		var tamano: float = datos["tamano"]
		verificar(tamano > 0.0 and tamano <= 1.0, "Tamaño de %s entre 0 y 1" % parte_id)


func prueba_textos_para_narrar() -> void:
	verificar_igual(DatosCuerpo.con_articulo("mano_der"), "la mano derecha", "Artículo de la mano")
	verificar_igual(DatosCuerpo.a_parte("cuello"), "al cuello", "Contracción 'al'")
	verificar_igual(DatosCuerpo.a_parte("espinilla_izq"), "a la espinilla izquierda", "'a la'")
	verificar_igual(DatosCuerpo.posesivo("craneo", "tu"), "tu cráneo", "Posesivo")
	verificar_igual(DatosCuerpo.base_de("antebrazo_izq"), "antebrazo", "Base sin lado")
	verificar_igual(DatosCuerpo.base_de("abdomen"), "abdomen", "Base de parte central")
