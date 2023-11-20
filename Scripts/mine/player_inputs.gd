#extends Node
#
#
## Called when the node enters the scene tree for the first time.
#func _ready():
#	pass # Replace with function body.
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
class_name player_inputs

var timeStamp:int = 0
var a = false
var b = false
var c = false
var d = false
var joystick = 5

func printToLog():
	var outputString = str(joystick)
	if(a):
		outputString += "A"
	if(b):
		outputString += "B"
	if(c):
		outputString += "C"
	if(d):
		outputString += "D"
	print(outputString)
