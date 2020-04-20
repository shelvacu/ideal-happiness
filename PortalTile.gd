extends Node2D

signal on_time_delta_changed

var time_delta:int
var can_edit:bool = true

var is_editing:bool = false
var clicked_y:int = 0
var time_delta_at_click:int = 0

func enable_edit():
	can_edit = true
	
func disable_edit():
	if is_editing:
		end_edit()
	can_edit = false

func set_time_delta(time_delta_:int):
	time_delta = time_delta_
	var text:String
	if time_delta < 0:
		text = String(time_delta)
	else:
		text = "+" + String(time_delta)
	find_node("Label").text = text
	emit_signal("on_time_delta_changed", time_delta)
	
func clickable_input(viewport:Node, event:InputEvent, shape_idx:int):
	if not can_edit:
		return
	if event.get("pressed") and not event.get("doubleclick") and event.get("button_index") == BUTTON_LEFT:
		start_edit(event.position)
		
func start_edit(pos:Vector2):
	is_editing = true
	clicked_y = pos[1]
	time_delta_at_click = time_delta
	print("start_edit")
	
func end_edit():
	is_editing = false
	print("end_edit")
	
func update_edit(pos:Vector2):
	var delta_y = pos[1] - clicked_y
	set_time_delta(time_delta_at_click - delta_y / 20)
	print("update_edit: " + String(delta_y))
	
func _input(event:InputEvent):
	if not is_editing:
		return
	if event is InputEventMouseMotion:
		if (event.button_mask & BUTTON_LEFT) == 0:
			return
		update_edit(event.position)
	elif event is InputEventMouseButton:
		if event.button_index != BUTTON_LEFT:
			return
		if event.pressed:
			return
		end_edit()
	else:
		return
	# TODO colin: mark event as handled

# Called when the node enters the scene tree for the first time.
func _ready():
	var area = find_node("ClickableArea", true, false)
	area.connect("input_event", self, "clickable_input")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
