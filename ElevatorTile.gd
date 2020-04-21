extends "res://Tile.gd"

func on_state_change(changed_var, elevator_location, expected_var, me_node):
	if expected_var != changed_var:
		return
	if elevator_location == me_node:
		set_icon("elevator_open")
	else:
		set_icon("elevator_closed") 
