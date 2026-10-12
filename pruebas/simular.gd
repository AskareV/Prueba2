extends SceneTree
## Simula muchos combates automáticos para revisar el equilibrio de los números
## provisionales. El rival lo maneja la IA; el rey sigue distintas estrategias
## (ver simulacion.gd) para comparar si conviene herir brazos y piernas antes de
## ir al cuerpo:
##   godot --headless --script res://pruebas/simular.gd
## Para simular solo algunas estrategias, un arma o menos combates:
##   godot --headless --script res://pruebas/simular.gd -- brazos abdomen arma=maza combates=200

const Simulacion := preload("res://pruebas/simulacion.gd")
const COMBATES := 600


func _initialize() -> void:
	var estrategias: Array = []
	var armas: Array = DatosArmas.ELEGIBLES
	var combates := COMBATES
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("arma="):
			armas = [argumento.substr(5)]
		elif argumento.begins_with("combates="):
			combates = argumento.substr(9).to_int()
		else:
			estrategias.append(argumento)
	if estrategias.is_empty():
		estrategias = Simulacion.ESTRATEGIAS
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	print("Arma    Rival     Estrategia  Victorias  Turnos  Acierto rey  Acierto rival  Desmayos  Vida rey")
	for arma_id in armas:
		for rival_id in DatosRivales.ORDEN:
			for estrategia in estrategias:
				var t := {"victorias": 0, "turnos": 0, "desmayos": 0, "vida_rey": 0,
					"ataques_rey": 0, "aciertos_rey": 0, "ataques_rival": 0, "aciertos_rival": 0}
				for i in combates:
					var r := Simulacion.combatir(arma_id, rival_id, estrategia, i % 2 == 0, rng)
					for clave in r:
						t[clave] += r[clave]
				print("%-7s %-9s %-10s %7.1f%%  %6.1f  %9.1f%%  %11.1f%%  %6.1f%%  %8.1f" % [
					arma_id, rival_id, estrategia, 100.0 * t["victorias"] / combates,
					float(t["turnos"]) / combates,
					100.0 * t["aciertos_rey"] / maxi(t["ataques_rey"], 1),
					100.0 * t["aciertos_rival"] / maxi(t["ataques_rival"], 1),
					100.0 * t["desmayos"] / combates, float(t["vida_rey"]) / combates])
	quit()
