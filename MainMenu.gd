extends Control

var time = 0.0

func _enter_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta):
	time += delta
	if time > 0.5:
		if Input.is_action_just_pressed("exit"):
			get_tree().quit()

func _on_JugarFacil_pressed():
	_on_Jugar_pressed(0)

func _on_JugarMedio_pressed():
	_on_Jugar_pressed(1)

func _on_JugarDificil_pressed():
	_on_Jugar_pressed(2)

func _on_JugarImposible_pressed():
	_on_Jugar_pressed(3)
	
func _on_Jugar_pressed(dificultad): # Rango [0, 3]
	# TODO: Autoload + leer dificultad en WorldGenerator
	get_tree().change_scene("res://World.tscn")



