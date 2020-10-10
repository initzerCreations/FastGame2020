extends Control

var time = 0.0

func _process(delta):
	time += delta
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if time > 0.5:
		if Input.is_action_just_pressed("exit"):
			get_tree().quit()
		if Input.is_action_just_pressed("use_object"):
			get_tree().change_scene("res://World.tscn")
