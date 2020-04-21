extends Node2D

# See Tile.gd
var visual_offset_y:int = 1

func on_state_change(changed_var, new_state, expected_var):
	if expected_var != changed_var:
		return
	if new_state:
		$Tile.set_icon("bridge-nofall")
	else:
		$Tile.set_icon("bridge-fall")
		
func pre_render_frame(the_grid, me):
	### Gives an opportunity to update the icon by querying state about the
	### grid at large.
	### `me` is the GameNode corresponding to this tile
	pass

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
