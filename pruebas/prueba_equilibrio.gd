extends "res://pruebas/base_prueba.gd"
## Metas del diseño comprobadas con combates simulados (semilla fija):
## combates largos y que inutilizar brazos rinda más que ir directo al abdomen.

const Simulacion := preload("res://pruebas/simulacion.gd")
const COMBATES := 120
## Para comparar estrategias contra cada rival basta con menos combates.
const COMBATES_POR_RIVAL := 80


func _victorias_y_turnos(arma_id: String, rival_id: String, estrategia: String, semilla: int,
		combates := COMBATES) -> Vector2:
	var rng := rng_fijo(semilla)
	var victorias := 0
	var turnos := 0
	for i in combates:
		var r := Simulacion.combatir(arma_id, rival_id, estrategia, i % 2 == 0, rng)
		victorias += r["victorias"]
		turnos += r["turnos"]
	return Vector2(100.0 * victorias / combates, float(turnos) / combates)


func prueba_combates_largos() -> void:
	var resultado := _victorias_y_turnos("espada", "bandido", "ia", 5)
	verificar(resultado.y >= 17.0, "Un combate dura al menos 17 turnos en promedio (dura %.1f)" % resultado.y)


func prueba_inutilizar_el_brazo_del_arma_rinde_mas_que_el_abdomen() -> void:
	for arma_id in DatosArmas.ELEGIBLES:
		var brazo := _victorias_y_turnos(arma_id, "orco", "brazo_arma", 6)
		var abdomen := _victorias_y_turnos(arma_id, "orco", "abdomen", 6)
		verificar(brazo.x >= abdomen.x + 15.0, "Con %s, inutilizar el brazo del arma gana bastante más que ir al abdomen (%.0f%% contra %.0f%%)" % [arma_id, brazo.x, abdomen.x])


## Pedido: fallar menos seguido. Pocas peleas con rachas de 4 o más fallos.
func prueba_pocas_rachas_largas_de_fallos() -> void:
	var rng := rng_fijo(8)
	var rachas := {"rey": 0, "rival": 0}
	for i in COMBATES:
		var r := Simulacion.combatir("espada", "lancero", "torso", i % 2 == 0, rng)
		rachas["rey"] += r["rachas_rey"]
		rachas["rival"] += r["rachas_rival"]
	for quien in rachas:
		var porcentaje: float = 100.0 * rachas[quien] / COMBATES
		verificar(porcentaje <= 30.0, "Rachas de %d fallos del %s en %.0f%% de los combates" % [Simulacion.RACHA_LARGA, quien, porcentaje])


## Contra cada rival, atacar siempre la misma parte rinde menos que abrir la guardia.
func prueba_atacar_siempre_la_misma_parte_rinde_menos() -> void:
	for rival_id in DatosRivales.ORDEN:
		var tactica := _victorias_y_turnos("lanza", rival_id, "brazo_arma", 7, COMBATES_POR_RIVAL)
		for estrategia in ["abdomen", "craneo", "cuello"]:
			var resultado := _victorias_y_turnos("lanza", rival_id, estrategia, 7, COMBATES_POR_RIVAL)
			verificar(resultado.x < tactica.x, "Contra el %s, atacar siempre %s gana menos que abrir la guardia (%.0f%% contra %.0f%%)" % [rival_id, estrategia, resultado.x, tactica.x])
