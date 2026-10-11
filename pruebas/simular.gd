extends SceneTree
## Simula muchos combates automáticos (el rey también lo maneja la máquina)
## para revisar el equilibrio de los números provisionales:
##   godot --headless --script res://pruebas/simular.gd

const COMBATES := 2000
const MAX_TURNOS := 200


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	print("Arma    Rival     Victorias  Turnos  Desmayos  Desarmes  Vida final del rey")
	for arma_id in DatosArmas.ELEGIBLES:
		for rival_id in DatosRivales.ORDEN:
			var victorias := 0
			var turnos := 0
			var desmayos := 0
			var desarmes := 0
			var vida_rey := 0
			for i in COMBATES:
				var resultado := _combatir(arma_id, rival_id, i % 2 == 0, rng)
				victorias += 1 if resultado["gana_rey"] else 0
				turnos += resultado["turnos"]
				desmayos += 1 if resultado["desmayo"] else 0
				desarmes += resultado["desarmes"]
				vida_rey += resultado["vida_rey"]
			print("%-7s %-9s %6.1f%%  %6.1f  %7.1f%%  %8.2f  %10.1f" % [
				arma_id, rival_id, 100.0 * victorias / COMBATES, float(turnos) / COMBATES,
				100.0 * desmayos / COMBATES, float(desarmes) / COMBATES, float(vida_rey) / COMBATES])
	quit()


func _combatir(arma_id: String, rival_id: String, diestro: bool, rng: RandomNumberGenerator) -> Dictionary:
	var rey := DatosRivales.crear_rey(diestro, arma_id)
	var rival := DatosRivales.crear_rival(rival_id)
	var turno := 0
	var desarmes := 0
	while turno < MAX_TURNOS:
		turno += 1
		desarmes += _actuar(rey, rival, rng, turno)
		if rival.fuera_de_combate():
			break
		desarmes += _actuar(rival, rey, rng, turno)
		if rey.fuera_de_combate():
			break
	return {
		"gana_rey": rival.fuera_de_combate() and not rey.fuera_de_combate(),
		"turnos": turno,
		"desmayo": rey.desmayado or rival.desmayado,
		"desarmes": desarmes,
		"vida_rey": rey.vida,
	}


## Hace actuar a un luchador como en la escena de combate. Devuelve 1 si desarmó.
func _actuar(yo: Luchador, otro: Luchador, rng: RandomNumberGenerator, turno: int) -> int:
	yo.defendiendo = false
	if yo.aturdido:
		yo.aturdido = false
		return 0
	var decision := IAEnemigo.decidir(yo, otro, rng)
	match decision["accion"]:
		"recoger":
			yo.empunar()
		"defender":
			yo.defendiendo = true
		"atacar":
			var resultado := MotorCombate.resolver_ataque(yo, otro, decision["parte"], rng, turno)
			return 1 if resultado["desarme"] else 0
	return 0
