extends SceneTree
## Ejecuta todas las pruebas sin abrir ventana:
##   godot --headless --script res://pruebas/ejecutar.gd
## Termina con código 1 si alguna falla.

const ARCHIVOS := [
	"res://pruebas/prueba_cuerpo.gd",
	"res://pruebas/prueba_luchador.gd",
	"res://pruebas/prueba_motor.gd",
	"res://pruebas/prueba_ia.gd",
]


func _initialize() -> void:
	var total := 0
	var fallidas := 0
	for ruta in ARCHIVOS:
		var guion: GDScript = load(ruta)
		print(ruta.get_file())
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
