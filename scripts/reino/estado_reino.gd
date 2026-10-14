class_name EstadoReino
extends Node
## Estado de la partida del reino (autoload "Juego"): semana, oro, estrés,
## inventario, equipo y lo que está en curso (mazmorra, zona o combate).
## Por ahora el juego no tiene fin: las semanas siguen sin límite.
## Todavía no se guarda en disco: al cerrar la aplicación se pierde.

## Estrés que baja al descansar una semana (provisional, hasta que exista el
## descanso de la ciudad).
const ESTRES_DESCANSO := 40.0

var en_curso := false
var semana := 1
var oro := 0
var estres := 0.0
var diestro := true
## Objetos guardados (los más nuevos primero). Cada uno tiene un "id" único.
var inventario: Array[Dictionary] = []
## Objeto equipado en cada ranura (ver DatosBotin.RANURAS).
var equipo: Dictionary = {}
## Dominio (0 a 100) de cada trabajo del rey.
var dominio: Dictionary = {}
## Mazmorra en curso (ver mazmorra.gd) o vacío.
var mazmorra: Dictionary = {}
## Salida a una zona en curso (ver expedicion.gd) o vacío.
var expedicion: Dictionary = {}
## Combate del reino: {"origen", "escena", "rival", "resultado"} o vacío.
var combate: Dictionary = {}
## Mensaje para mostrar al volver a la pantalla principal del reino.
var aviso := ""
## Pestaña que abre la pantalla del reino al volver (ej. "aventura").
var pestana := "rey"
var rng := RandomNumberGenerator.new()
var _siguiente_id := 1


func nueva_partida(p_diestro: bool) -> void:
	en_curso = true
	semana = 1
	oro = 0
	estres = 0.0
	diestro = p_diestro
	inventario = []
	equipo = {}
	dominio = {}
	mazmorra = {}
	expedicion = {}
	combate = {}
	aviso = ""
	pestana = "rey"
	_siguiente_id = 1
	rng.randomize()
	equipo["arma"] = _con_id(DatosBotin.crear_arma("espada", 1, "normal"))


# --- Semanas y estrés ---

## Termina la semana: las mazmorras se reinician y empieza la siguiente.
func pasar_semana() -> void:
	semana += 1
	mazmorra = {}
	expedicion = {}
	combate = {}


func descansar() -> void:
	sumar_estres(-ESTRES_DESCANSO)
	pasar_semana()


func sumar_estres(cantidad: float) -> void:
	estres = clampf(estres + cantidad, 0.0, 100.0)


# --- Inventario y equipo ---

func _con_id(objeto: Dictionary) -> Dictionary:
	objeto["id"] = _siguiente_id
	_siguiente_id += 1
	return objeto


## Guarda un objeto nuevo en el inventario y lo devuelve con su id.
func agregar(objeto: Dictionary) -> Dictionary:
	var guardado := _con_id(objeto)
	inventario.push_front(guardado)
	return guardado


func _indice(id: int) -> int:
	for i in inventario.size():
		if inventario[i]["id"] == id:
			return i
	return -1


## Vende un objeto del inventario. Devuelve el oro ganado (0 si no estaba).
func vender(id: int) -> int:
	var i := _indice(id)
	if i < 0:
		return 0
	var precio: int = inventario[i]["precio"]
	inventario.remove_at(i)
	oro += precio
	return precio


## Equipa un objeto del inventario; lo que había en esa ranura vuelve al inventario.
func equipar(id: int) -> bool:
	var i := _indice(id)
	if i < 0:
		return false
	var objeto: Dictionary = inventario[i]
	inventario.remove_at(i)
	var ranura: String = objeto["ranura"]
	if equipo.has(ranura):
		inventario.push_front(equipo[ranura])
	equipo[ranura] = objeto
	return true


## Guarda en el inventario lo que hay en esa ranura. El arma no se puede quitar
## (se cambia equipando otra).
func quitar(ranura: String) -> bool:
	if ranura == "arma" or not equipo.has(ranura):
		return false
	inventario.push_front(equipo[ranura])
	equipo.erase(ranura)
	return true


## Armadura total por zona del cuerpo: zona -> {"fisica": n, "magica": n}.
func armadura_por_zona() -> Dictionary:
	var total := {}
	for ranura in DatosBotin.PIEZAS:
		if not equipo.has(ranura):
			continue
		var pieza: Dictionary = equipo[ranura]
		for zona_id in DatosBotin.RANURAS[ranura]["zonas"]:
			var actual: Dictionary = total.get(zona_id, {"fisica": 0, "magica": 0})
			actual["fisica"] += int(pieza["armadura"])
			actual["magica"] += int(pieza["resistencia_magica"])
			total[zona_id] = actual
	return total


## El rey listo para combatir, con su arma y su armadura.
func crear_rey() -> Luchador:
	var arma: Dictionary = equipo.get("arma", {})
	var rey := DatosRivales.crear_rey(diestro, arma.get("base", "espada"))
	rey.arma_objeto = arma
	rey.armadura = armadura_por_zona()
	return rey


# --- Botín ---

## Recompensa por vencer a un enemigo: oro y, a veces, un objeto (ya guardado).
## Devuelve {"oro": n, "objeto": objeto o vacío}.
func recompensa_enemigo(enemigo_id: String) -> Dictionary:
	var datos := DatosRivales.rival(enemigo_id)
	var rango: Array = datos.get("oro", [2, 6])
	var ganado := rng.randi_range(rango[0], rango[1])
	oro += ganado
	var objeto := {}
	if rng.randf() < DatosAventura.PROB_BOTIN_ENEMIGO:
		objeto = agregar(DatosBotin.generar(datos.get("nivel", 1), rng))
	return {"oro": ganado, "objeto": objeto}


## Un cofre siempre trae un objeto y algo de oro.
func abrir_cofre(nivel: int) -> Dictionary:
	var ganado := rng.randi_range(5, 15) * nivel
	oro += ganado
	return {"oro": ganado, "objeto": agregar(DatosBotin.generar(nivel, rng))}


# --- Trabajo ---

func puede_trabajar() -> bool:
	return estres < DatosTrabajos.ESTRES_MAXIMO


## Trabaja la semana entera en ese oficio y pasa la semana.
func trabajar(oficio_id: String) -> Dictionary:
	var resultado := DatosTrabajos.trabajar_semana(oficio_id, dominio.get(oficio_id, 0.0), rng)
	oro += int(resultado["oro"])
	sumar_estres(resultado["estres"])
	dominio[oficio_id] = resultado["dominio"]
	pasar_semana()
	return resultado
