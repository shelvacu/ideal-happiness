extends Node2D

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func on_state_change(changed_var, new_state, expected_var):
	if expected_var != changed_var:
		return
	if new_state:
		$AnimatedSprite.animation = "solid"
	else:
		$AnimatedSprite.animation = "not-solid"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
