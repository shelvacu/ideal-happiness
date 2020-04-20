extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const Messages := [
	"This is a thing",
	"This is another thing",
	"I'm saying so much stuff",
	"I mean look at all this stuff I'm saying",
	"I can even say things\non multiple lines!"
]
onready var textbox:RichTextLabel = self.find_node("DialogBoxText", true, false)

var text_idx := -1

# Called when the node enters the scene tree for the first time.
func _ready():
	textbox.text = "Click to see next text"
	pass # Replace with function body.

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_LEFT:
			text_idx += 1
			if text_idx < Messages.size():
				textbox.text = Messages[text_idx]

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
