extends Node2D

func set_time_delta(time_delta:int):
	var text:String
	if time_delta < 0:
		text = String(time_delta)
	else:
		text = "+" + String(time_delta)
	find_node("Label").text = text

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
