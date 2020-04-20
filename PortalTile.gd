extends Node2D

signal on_time_delta_changed

var time_delta:int
var can_edit:bool = true

var is_hovering:bool = false
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
	update_visibility()
	var text:String
	if time_delta < 0:
		text = String(time_delta)
	else:
		text = "+" + String(time_delta)
	$Label.text = text
	emit_signal("on_time_delta_changed", time_delta)
	

func update_visibility():
	var show := true
	var full_opacity := true
	if time_delta == 0:
		show = is_editing or is_hovering
		full_opacity = false
	$Tile.visible = show
	$Label.visible = show
	if full_opacity:
		$Tile.set_icon("portal")
	else:
		$Tile.set_icon("portal-placing")

func clickable_input(viewport:Node, event:InputEvent, shape_idx:int):
	if not can_edit:
		return
	if event is InputEventMouseMotion:
		is_hovering = true
		update_visibility()
		get_tree().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.pressed and not event.doubleclick and event.button_index == BUTTON_LEFT:
			start_edit(event.position)
		get_tree().set_input_as_handled()

func start_edit(pos:Vector2):
	is_editing = true
	clicked_y = pos[1]
	time_delta_at_click = time_delta
	update_visibility()
	print("start_edit")
	
func end_edit():
	is_editing = false
	update_visibility()
	print("end_edit")
	
func update_edit(pos:Vector2):
	var delta_y = pos[1] - clicked_y
	set_time_delta(time_delta_at_click - delta_y / 20)
	print("update_edit: " + String(delta_y))
	
func _unhandled_input(event:InputEvent):
	if event is InputEventMouseMotion:
		is_hovering = false
		update_visibility()
		if is_editing and (event.button_mask & BUTTON_LEFT) != 0:
			update_edit(event.position)
	elif event is InputEventMouseButton:
		if is_editing and event.button_index == BUTTON_LEFT and not event.pressed:
			end_edit()

# Called when the node enters the scene tree for the first time.
func _ready():
	$ClickableArea.connect("input_event", self, "clickable_input")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
