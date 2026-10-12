extends "res://pruebas/base_prueba.gd"
## Metas del diseño comprobadas con combates simulados (semilla fija):
## combates largos y que inutilizar brazos rinda más que ir directo al abdomen.

const Simulacion := preload("res://pruebas/simulacion.gd")
const COMBATES := 120


func _victorias_y_turnos(arma_id: String, rival_id: String, estrategia: String, semilla: int) -> Vector2:
	var rng := rng_fijo(semilla)
	var victorias := 0
	var turnos := 0
	for i in COMBATES:
		var r := Simulacion.combatir(arma_id, rival_id, estrategia, i % 2 == 0, rng)
		victorias += r["victorias"]
		turnos += r["turnos"]
	return Vector2(100.0 * victorias / COMBATES, float(turnos) / COMBATES)


func prueba_combates_largos() -> void:
	var resultado := _victorias_y_turnos("espada", "bandido", "ia", 5)
	verificar(resultado.y >= 15.0, "Un combate dura al menos 15 turnos en promedio (dura %.1f)" % resultado.y)


func prueba_inutilizar_el_brazo_del_arma_rinde_mas_que_el_abdomen() -> void:
	var brazo := _victorias_y_turnos("espada", "lancero", "brazo_arma", 6)
	var abdomen := _victorias_y_turnos("espada", "lancero", "abdomen", 6)
	verificar(brazo.x >= abdomen.x + 15.0,
		"Inutilizar el brazo del arma gana bastante más que ir al abdomen (%.0f%% contra %.0f%%)" % [brazo.x, abdomen.x])


func prueba_ninguna_parte_sola_gana_siempre() -> void:
	for estrategia in ["abdomen", "craneo", "cuello"]:
		var resultado := _victorias_y_turnos("maza", "orco", estrategia, 7)
		verificar(resultado.x < 70.0, "Atacar siempre %s no gana siempre al orco (%.0f%%)" % [estrategia, resultado.x])
