extends Node2D

var visual_offset_y = 0
		
func pre_render_frame(the_grid, me):
	### Gives an opportunity to update the icon by querying state about the
	### grid at large.
	### `me` is the GameNode corresponding to this tile
	if the_grid.is_player_on_node(me):
		$Tile.set_icon("button-pressed")
	else:
		$Tile.set_icon("button-depressed")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
