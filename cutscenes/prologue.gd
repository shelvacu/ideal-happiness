extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

class Event:
	func do():
		pass

class MessageEvent:
	var name:String
	var text:String
	func _init(name_:String, text_:String):
		name = name_
		text = text_
	func do(thing:Node):
		var textbox:RichTextLabel = thing.find_node("DialogBoxText", true, false)
		textbox.text = text
		var av:AnimatedSprite = thing.find_node("CharacterAvatar", true, false)
		av.animation = name
		var namebox:Label = thing.find_node("CharacterName", true, false)
		namebox.text = name.capitalize()

onready var messages := [
	MessageEvent.new("robot", "I am a robot!"),
	MessageEvent.new("trish", "You are! Mr. State-the-obvious...")
]

var text_idx := -1

# Called when the node enters the scene tree for the first time.
func _ready():
	var textbox:RichTextLabel = self.find_node("DialogBoxText", true, false)
	textbox.text = "Click to see next text"
	pass # Replace with function body.

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_LEFT:
			text_idx += 1
			if text_idx < messages.size():
				messages[text_idx].do(self)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
