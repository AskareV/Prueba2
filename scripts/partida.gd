extends Node
## Global (autoload "Partida"): lo elegido en la pantalla de preparación,
## que luego usa la escena de combate.

var diestro := true
var arma := "espada"
var rival := "bandido"
## true mientras se juega la demo: el combate no es del reino aunque la partida
## guardada tenga uno pendiente.
var en_demo := false
