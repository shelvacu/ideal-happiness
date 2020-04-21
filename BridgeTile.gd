extends "res://Tile.gd"

func visual_offset_y() -> int:
	### See Tile.gd
	return 1

func on_state_change(changed_var, new_state, expected_var):
	if expected_var != changed_var:
		return
	if new_state:
		set_icon("bridge-nofall")
	else:
		set_icon("bridge-fall")
		
