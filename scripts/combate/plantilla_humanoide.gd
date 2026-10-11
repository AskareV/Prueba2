class_name PlantillaHumanoide
extends RefCounted
## Formas de las 21 partes del cuerpo en vista frontal, en píxeles, con el
## origen entre los pies. El personaje mira a la cámara: su lado derecho queda
## a la izquierda de la pantalla (x negativa).

## Orden de dibujo, de atrás hacia adelante.
const ORDEN := [
	"pie_der", "pie_izq", "espinilla_der", "espinilla_izq", "muslo_der", "muslo_izq",
	"abdomen", "cuello", "torax_der", "torax_izq", "hombro_der", "hombro_izq",
	"brazo_der", "brazo_izq", "antebrazo_der", "antebrazo_izq", "mano_der", "mano_izq",
	"craneo", "ojo_der", "ojo_izq",
]

## Altura total aproximada del cuerpo sin accesorios.
const ALTURA := 384.0


## Devuelve {"partes": parte -> Array[PackedVector2Array], "anclas": nombre -> Vector2}.
## ancho y alto deforman el cuerpo; lado_arma levanta el antebrazo que sostiene el arma.
static func crear(ancho: float, alto: float, lado_arma: String) -> Dictionary:
	var partes := {}
	var anclas := {}
	for lado in ["der", "izq"]:
		var s := -1.0 if lado == "der" else 1.0
		var con_arma: bool = lado == lado_arma
		# Piernas
		var cadera := Vector2(23 * s, -186)
		var rodilla := Vector2(27 * s, -104)
		var tobillo := Vector2(29 * s, -24)
		partes["muslo_" + lado] = [capsula(cadera, rodilla, 18, 14)]
		partes["espinilla_" + lado] = [capsula(rodilla, tobillo, 13, 10)]
		partes["pie_" + lado] = [elipse(Vector2(33 * s, -10), 19, 10)]
		# Hombro y trapecio: una franja desde el cuello más la cabeza del hombro.
		var trapecio := PackedVector2Array([
			Vector2(8 * s, -321), Vector2(30 * s, -310), Vector2(48 * s, -301),
			Vector2(51 * s, -291), Vector2(30 * s, -298), Vector2(10 * s, -306)])
		partes["hombro_" + lado] = [trapecio, elipse(Vector2(53 * s, -290), 15, 14)]
		# Brazo, antebrazo y mano. El brazo del arma la sostiene a la altura de la cintura.
		var hombro := Vector2(55 * s, -284)
		var codo := Vector2(64 * s, -230)
		var muneca := Vector2(58 * s, -198) if con_arma else Vector2(70 * s, -176)
		var mano := muneca + (Vector2(-1 * s, 11) if con_arma else Vector2(2 * s, 11))
		partes["brazo_" + lado] = [capsula(hombro, codo, 12, 10)]
		partes["antebrazo_" + lado] = [capsula(codo, muneca, 10, 8)]
		partes["mano_" + lado] = [elipse(mano, 10, 11)]
		anclas["mano_" + lado] = mano
		anclas["hombro_" + lado] = Vector2(48 * s, -300)
	partes["abdomen"] = [PackedVector2Array([
		Vector2(-42, -244), Vector2(42, -244), Vector2(40, -222), Vector2(45, -196),
		Vector2(37, -182), Vector2(-37, -182), Vector2(-45, -196), Vector2(-40, -222)])]
	partes["torax_der"] = [PackedVector2Array([
		Vector2(0, -306), Vector2(-30, -306), Vector2(-48, -296), Vector2(-50, -270),
		Vector2(-45, -244), Vector2(0, -244)])]
	partes["torax_izq"] = [PackedVector2Array([
		Vector2(0, -306), Vector2(0, -244), Vector2(45, -244), Vector2(50, -270),
		Vector2(48, -296), Vector2(30, -306)])]
	partes["cuello"] = [capsula(Vector2(0, -298), Vector2(0, -324), 10, 10)]
	partes["craneo"] = [elipse(Vector2(0, -352), 27, 31)]
	partes["ojo_der"] = [elipse(Vector2(-10, -354), 6.5, 5.5)]
	partes["ojo_izq"] = [elipse(Vector2(10, -354), 6.5, 5.5)]
	anclas["cabeza"] = Vector2(0, -352)
	anclas["ojo_der"] = Vector2(-10, -354)
	anclas["ojo_izq"] = Vector2(10, -354)
	anclas["boca"] = Vector2(0, -335)
	anclas["cintura"] = Vector2(0, -191)

	# Deformar según las proporciones del personaje.
	var escala := Vector2(ancho, alto)
	for parte_id in partes:
		var formas: Array = partes[parte_id]
		for i in formas.size():
			formas[i] = escalar(formas[i], escala)
	for nombre in anclas:
		anclas[nombre] = anclas[nombre] * escala
	anclas["radio_cabeza"] = Vector2(27, 31) * escala
	return {"partes": partes, "anclas": anclas}


static func elipse(centro: Vector2, rx: float, ry: float, segmentos := 28) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for i in segmentos:
		var angulo := TAU * i / segmentos
		puntos.append(centro + Vector2(cos(angulo) * rx, sin(angulo) * ry))
	return puntos


## Arco de elipse entre dos ángulos (en radianes; -PI/2 es arriba).
static func arco(centro: Vector2, rx: float, ry: float, desde: float, hasta: float, segmentos := 16) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for i in segmentos + 1:
		var angulo := lerpf(desde, hasta, float(i) / segmentos)
		puntos.append(centro + Vector2(cos(angulo) * rx, sin(angulo) * ry))
	return puntos


## Cápsula entre a y b con radios distintos en cada extremo (brazos, piernas).
static func capsula(a: Vector2, b: Vector2, radio_a: float, radio_b: float, segmentos := 8) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	var angulo := (b - a).angle()
	for i in segmentos + 1:
		var t := angulo - PI / 2.0 + PI * i / segmentos
		puntos.append(b + Vector2.from_angle(t) * radio_b)
	for i in segmentos + 1:
		var t := angulo + PI / 2.0 + PI * i / segmentos
		puntos.append(a + Vector2.from_angle(t) * radio_a)
	return puntos


static func escalar(puntos: PackedVector2Array, escala: Vector2) -> PackedVector2Array:
	var resultado := PackedVector2Array()
	resultado.resize(puntos.size())
	for i in puntos.size():
		resultado[i] = puntos[i] * escala
	return resultado


## Centro aproximado de una forma (promedio de sus puntos).
static func centro(puntos: PackedVector2Array) -> Vector2:
	var suma := Vector2.ZERO
	for punto in puntos:
		suma += punto
	return suma / maxf(puntos.size(), 1)
