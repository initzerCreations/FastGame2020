extends Control

var textToFill
var time = 0.0
var startOffset = 0
var lastLetra = 0
var curTimeSkip = 0.05

func _enter_tree():
	textToFill = $RichTextLabel.text
	$RichTextLabel.text = ""
	$AudioStreamPlayer.play()

func _process(delta):
	time += delta
	if time > lastLetra + curTimeSkip:
		if curTimeSkip == 1.0:
			$RichTextLabel.text = ""
			$AudioStreamPlayer.play()
		curTimeSkip = 0.05
		lastLetra = time
		var nextCharIndex = startOffset + $RichTextLabel.text.length()
		if nextCharIndex < 0:
			var _ign = get_tree().change_scene("res://MainMenu.tscn")
		elif nextCharIndex == textToFill.length():
			$AudioStreamPlayer.stop()
			curTimeSkip = 1.0
			startOffset = -2
		else:
			var nextChar = textToFill[nextCharIndex]
			if nextChar == '\n':
				$AudioStreamPlayer.stop()
				startOffset = nextCharIndex+1
				curTimeSkip = 1.0
			else:
				$RichTextLabel.text = $RichTextLabel.text + nextChar

func _input(event):
	if event.is_action("exit") or event.is_action("use_object"):
		var _ign = get_tree().change_scene("res://MainMenu.tscn")
