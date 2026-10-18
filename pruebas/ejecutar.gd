extends SceneTree
## Ejecuta todas las pruebas sin abrir ventana:
##   godot --headless --script res://pruebas/ejecutar.gd
## Termina con código 1 si alguna falla.

const ARCHIVOS := [
	"res://pruebas/prueba_cuerpo.gd",
	"res://pruebas/prueba_luchador.gd",
	"res://pruebas/prueba_motor.gd",
	"res://pruebas/prueba_ia.gd",
	"res://pruebas/prueba_equilibrio.gd",
	"res://pruebas/prueba_reino.gd",
	"res://pruebas/prueba_estadisticas.gd",
	"res://pruebas/prueba_ciudad.gd",
]


func _initialize() -> void:
	var total := 0
	var fallidas := 0
	for ruta in ARCHIVOS:
		var guion: GDScript = load(ruta)
		print(ruta.get_file())
		if guion == null or not guion.can_instantiate():
			total += 1
			fallidas += 1
			print("  FALLA  no se pudo cargar el archivo (¿error de sintaxis?)")
			continue
		for metodo in guion.get_script_method_list():
			var nombre: String = metodo["name"]
			if not nombre.begins_with("prueba_"):
				continue
			total += 1
			var instancia: RefCounted = guion.new()
			instancia.call(nombre)
			var fallos: Array[String] = instancia.get("fallos")
			var verificaciones: int = instancia.get("verificaciones")
			if verificaciones == 0:
				fallos.append("La prueba no llegó a verificar nada (¿error de ejecución?)")
			if fallos.is_empty():
				print("  ok     %s" % nombre)
			else:
				fallidas += 1
				print("  FALLA  %s" % nombre)
				for fallo in fallos:
					print("         - %s" % fallo)
	print("%d pruebas, %d fallidas" % [total, fallidas])
	quit(1 if fallidas > 0 else 0)
