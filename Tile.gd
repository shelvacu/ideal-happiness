extends Node2D

# For things like Bridges, set this to e.g. 1 if you want the tile rendered
# at an offset from its "real position"
var visual_offset_y:int = 0

func set_icon(icon:String):
	$AnimatedSprite.animation = icon


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
