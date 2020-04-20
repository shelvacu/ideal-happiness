extends Control

enum Graphic { Play, Pause }
var cur_graphic:int = Graphic.Play

func toggle():
	match cur_graphic:
		Graphic.Play:
			start_play()
		Graphic.Pause:
			end_play()
			
func start_play():
	cur_graphic = Graphic.Pause
	get_children()[0].animation = "pause"
	
func end_play():
	cur_graphic = Graphic.Play
	get_children()[0].animation = "play"

func _input(event:InputEvent):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		toggle()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
