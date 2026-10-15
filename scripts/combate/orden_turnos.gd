class_name OrdenTurnos
extends RefCounted
## Barra de turnos por velocidad (como la de Champions of Chaos): cada luchador
## avanza según su rapidez y actúa el que llega primero al final. Quien es
## bastante más rápido actúa dos veces seguidas, nunca más de MAX_SEGUIDOS.
## Con la misma rapidez se alternan, empezando por el primero (el jugador).

## Lo que hay que avanzar para actuar (100 = un turno).
const META := 100.0
const MAX_SEGUIDOS := 2
## Un retraso nunca deja a alguien más atrás que esto.
const RETRASO_MINIMO := -50.0

var luchadores: Array[Luchador] = []
var progreso: Array[float] = [0.0, 0.0]
var _ultimo := -1
var _seguidos := 0


func _init(primero: Luchador, segundo: Luchador) -> void:
	luchadores = [primero, segundo]


## Avanza la barra hasta el siguiente que actúa y lo devuelve.
func siguiente() -> Luchador:
	var i := _elegir()
	var tiempo := _tiempo(i)
	for j in 2:
		progreso[j] = minf(progreso[j] + tiempo * luchadores[j].rapidez_efectiva(), META)
	progreso[i] = 0.0
	if i == _ultimo:
		_seguidos += 1
	else:
		_ultimo = i
		_seguidos = 1
	return luchadores[i]


## Retrasa a un luchador en la barra ("cantidad" sobre META, ej. 35 = un tercio de turno).
func retrasar(luchador: Luchador, cantidad: float) -> void:
	var i := luchadores.find(luchador)
	if i >= 0:
		progreso[i] = maxf(progreso[i] - cantidad, RETRASO_MINIMO)


## Los próximos "cantidad" turnos, sin cambiar la barra.
func vista_previa(cantidad: int) -> Array[Luchador]:
	var copia := OrdenTurnos.new(luchadores[0], luchadores[1])
	copia.progreso = progreso.duplicate()
	copia._ultimo = _ultimo
	copia._seguidos = _seguidos
	var lista: Array[Luchador] = []
	for k in cantidad:
		lista.append(copia.siguiente())
	return lista


## Cuánto avanzó cada uno hacia su próximo turno (0 a 1), para dibujar la barra.
func avance(luchador: Luchador) -> float:
	var i := luchadores.find(luchador)
	return clampf(progreso[i] / META, 0.0, 1.0) if i >= 0 else 0.0


func _tiempo(i: int) -> float:
	return maxf(META - progreso[i], 0.0) / luchadores[i].rapidez_efectiva()


func _elegir() -> int:
	var t0 := _tiempo(0)
	var t1 := _tiempo(1)
	var i := 0 if t0 <= t1 + 0.000001 else 1
	if i == _ultimo and _seguidos >= MAX_SEGUIDOS:
		i = 1 - i
	return i
