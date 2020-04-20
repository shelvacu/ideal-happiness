extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

class StoryEvent:
	func do(thing:Node):
		pass

class MessageEvent:
	extends StoryEvent
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
class ChangeScene:
	extends StoryEvent
	var path:String
	func _init(path_:String):
		path = path_
	func do(thing:Node):
		thing.get_tree().change_scene(path)
class ShowHide:
	extends StoryEvent
	var to_hide:CanvasItem
	var visibility:bool
	func _init(thing_:CanvasItem, visibility_:bool):
		to_hide = thing_
		visibility = visibility_
	func do(thing:Node):
		if visibility:
			to_hide.show()
		else:
			to_hide.hide()
class Combined:
	extends StoryEvent
	var events:Array
	func _init(events_:Array):
		events = events_
	func do(thing:Node):
		for ev in events:
			ev.do(thing)
onready var messages := [
	MessageEvent.new("trish", "Hopeless! There's no way we can stop this asteroid from striking Earth!"),
	MessageEvent.new("robot", "*Inquisitive beeping*"),
	MessageEvent.new("trish", "No, Robot, a nuclear explosion would just shatter it."),
	MessageEvent.new("trish", "Without a way to destroy the asteroid, we're doomed."),
	MessageEvent.new("robot", "*Contemplative beeping*"),
	MessageEvent.new("trish", "No, no, we couldn't divert it's path this close."),
	MessageEvent.new("robot", "*Pensive beeping*"),
	MessageEvent.new("trish", "As cool as that would be, I have never seen a bubble blower that large."),
	MessageEvent.new("robot", "*Concerned beeping*"),
	MessageEvent.new("trish", "Impact in fifteen minutes."),
	MessageEvent.new("robot", "*Acquiescent beeping*"),
	MessageEvent.new("trish", "It was good knowing you too, Robot."),
	ShowHide.new($Dialog, false),
	ShowHide.new($Portal, true),
	Combined.new([
		ShowHide.new($TimeMachine, true),
		ShowHide.new($Blueprint, true)
	]),
	Combined.new([
		MessageEvent.new("trish", "What's this!?"),
		ShowHide.new($Dialog, true)
	]),
	MessageEvent.new("robot", "*Suspicious beeping*"),
	ShowHide.new($Dialog, false),
	ShowHide.new($Blueprint, false),
	ShowHide.new($TimeMachine, false),
	Combined.new([
		MessageEvent.new("trish", "It appears to be a handheld time machine and blueprints for an anti-matter bomb that will completely destroy the asteroid!"),
		ShowHide.new($Dialog, true)
	]),
	MessageEvent.new("robot", "*Excited beeping*"),
	MessageEvent.new("trish", "Quick, Robot. We need to go acquire: Nuclear Control Rod, Annihilium, Anti-Matter, and Deus Ex Mechanism."),
	MessageEvent.new("robot", "*Exhortative beeping*"),
	MessageEvent.new("trish", "Ah, you are right. We should probably travel back a few years to buy some time."),
	Combined.new([
		ShowHide.new($Trish, false),
		ShowHide.new($Robot, false)
	]),
	ChangeScene.new("res://cutscenes/title.tscn")
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
