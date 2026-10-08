extends CanvasLayer
## Global (autoload). El APK ya fuerza la orientación horizontal, pero el
## navegador no: si el celular está vertical, tapa la pantalla con un aviso
## para girarlo. En la web, al primer toque intenta pasar a pantalla completa
## horizontal (funciona en Android/Chrome; iPhone/Safari no lo permite).

const JS_PANTALLA_COMPLETA := """
try {
	var raiz = document.documentElement;
	if (raiz.requestFullscreen) {
		raiz.requestFullscreen().then(function () {
			if (screen.orientation && screen.orientation.lock) {
				return screen.orientation.lock('landscape');
			}
		}).catch(function () {});
	}
} catch (e) {}
"""

var _aviso: ColorRect
var _pidio_pantalla_completa := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_aviso()
	get_viewport().size_changed.connect(_actualizar_aviso)
	_actualizar_aviso()


func _input(event: InputEvent) -> void:
	if _pidio_pantalla_completa or not OS.has_feature("web"):
		return
	# Al soltar el dedo: el navegador solo permite pantalla completa tras un gesto completo.
	if event is InputEventScreenTouch and not event.pressed and DisplayServer.is_touchscreen_available():
		_pidio_pantalla_completa = true
		JavaScriptBridge.eval(JS_PANTALLA_COMPLETA, true)


func _crear_aviso() -> void:
	_aviso = ColorRect.new()
	_aviso.color = Color(0.07, 0.08, 0.18, 1)
	_aviso.mouse_filter = Control.MOUSE_FILTER_STOP
	_aviso.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_aviso)

	var texto := Label.new()
	texto.text = "Gira el teléfono\npara jugar en horizontal"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_font_size_override("font_size", 80)
	texto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aviso.add_child(texto)


func _actualizar_aviso() -> void:
	var tamano := get_viewport().get_visible_rect().size
	_aviso.visible = tamano.y > tamano.x
