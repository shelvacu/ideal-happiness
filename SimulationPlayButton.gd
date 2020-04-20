extends Control

enum Graphic { Play, Pause }
var cur_graphic:int = Graphic.Play

# Emitted when the game ought to Play, and Pause, respectively
signal play_pressed
signal pause_pressed

func toggle():
	match cur_graphic:
		Graphic.Play:
			set_pause()
			emit_signal("play_pressed")
		Graphic.Pause:
			set_play()
			emit_signal("pause_pressed")
			
func set_pause():
	cur_graphic = Graphic.Pause
	get_children()[0].animation = "pause"
	
func set_play():
	cur_graphic = Graphic.Play
	get_children()[0].animation = "play"

func clickable_input(viewport:Node, event:InputEvent, shape_idx:int):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		toggle()

# Called when the node enters the scene tree for the first time.
func _ready():
	$ClickableArea.connect("input_event", self, "clickable_input")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
