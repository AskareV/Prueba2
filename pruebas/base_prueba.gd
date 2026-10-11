extends RefCounted
## Base de las pruebas: cada método que empieza con "prueba_" es una prueba.

var fallos: Array[String] = []
var verificaciones := 0


func verificar(condicion: bool, mensaje: String) -> void:
	verificaciones += 1
	if not condicion:
		fallos.append(mensaje)


func verificar_igual(obtenido: Variant, esperado: Variant, mensaje: String) -> void:
	verificaciones += 1
	if obtenido != esperado:
		fallos.append("%s (esperado: %s, obtenido: %s)" % [mensaje, str(esperado), str(obtenido)])


func verificar_cerca(obtenido: float, esperado: float, mensaje: String, tolerancia := 0.001) -> void:
	verificaciones += 1
	if absf(obtenido - esperado) > tolerancia:
		fallos.append("%s (esperado: %.4f, obtenido: %.4f)" % [mensaje, esperado, obtenido])


## Generador de números con semilla fija para que las pruebas sean repetibles.
func rng_fijo(semilla := 1234) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	return rng
