extends Control

signal stop_pressed

func clickable_input(viewport:Node, event:InputEvent, shape_idx:int):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		emit_signal("stop_pressed")

# Called when the node enters the scene tree for the first time.
func _ready():
	$ClickableArea.connect("input_event", self, "clickable_input")

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
