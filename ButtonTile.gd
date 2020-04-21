extends "res://Tile.gd"
		
func pre_render_frame(the_grid, me):
	### Gives an opportunity to update the icon by querying state about the
	### grid at large.
	### `me` is the GameNode corresponding to this tile
	if the_grid.is_player_on_node(me):
		set_icon("button-pressed")
	else:
		set_icon("button-depressed")
