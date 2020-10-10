extends Control

var textToFill
var time = 0.0
var startOffset = 0
var lastLetra = 0

func _enter_tree():
	textToFill = $RichTextLabel.text
	$RichTextLabel.text = ""
	$AudioStreamPlayer.play()

func _process(delta):
	time += delta
	if time > lastLetra + 0.05:
		lastLetra = time
		var nextCharIndex = startOffset + $RichTextLabel.text.length()
		if nextCharIndex == textToFill.length():
			$AudioStreamPlayer.stop()
			yield(get_tree().create_timer(1.0), "timeout")
			get_tree().change_scene("res://MainMenu.tscn")
		else:
			var nextChar = textToFill[nextCharIndex]
			if nextChar == '\n':
				$AudioStreamPlayer.stop()
				yield(get_tree().create_timer(1.0), "timeout")
				startOffset = nextCharIndex+1
				$RichTextLabel.text = ""
				$AudioStreamPlayer.play()
			else:
				$RichTextLabel.text = $RichTextLabel.text + nextChar

func _input(event):
	if event.is_action("exit") or event.is_action("use_object"):
		get_tree().change_scene("res://MainMenu.tscn")
