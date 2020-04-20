extends Node2D

onready var tile_scene = preload("res://Tile.tscn")
const PuzzleLogic = preload("PuzzleLogic.gd")

# How many seconds to spend on each frame of the solution.
const STEP_TIME:float = 1.0
const ANIM_TIME:float = 0.9

var sol:PuzzleLogic.Solution
# time, in seconds, since the start of the scene
var time_elapsed:float = 0.0
# These are the players visible on screen. We add or remove them over time
var player_nodes:Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	print("_ready")
	#012345678901234
	#P |||@n@n@nF
	var query = PuzzleLogic.query_from_ascii(".p |@n n@- F.", [0,1], [-2,-3])
	
	# Demo query: Change [-2] (portal time delta) to [-1], and game will lose
	#var query = PuzzleLogic.query_from_ascii(".p  |@n  F.", [0], [-2])
	
	sol = query.drive()
	print(sol)
	var rowIdx := 0
	for row in query.grid.grid:
		var cellIdx := 0
		for tile in row:
			var tile_node:Node2D = tile_scene.instance()
			tile_node.get_children()[0].animation = tile.tile_name
			tile_node.position.x = cellIdx * 50
			tile_node.position.y = rowIdx * 50
			self.add_child(tile_node)
			cellIdx += 1
		rowIdx += 1
	for portal in query.portals:
		var tile_node:Node2D = tile_scene.instance()
		tile_node.get_children()[0].animation = "portal"
		tile_node.position.x = portal.x * 50
		tile_node.position.y = portal.y * 50
		self.add_child(tile_node)

var last_frame = -1
var player_tick_to_nodes := {}
onready var tween = $Tween
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta:float):
	time_elapsed += delta
	var frame = int(time_elapsed / STEP_TIME)
	if frame == last_frame: return
	last_frame = frame

	print(" ")
	var new_player_tick_to_nodes := {}
	for player in sol.player_states_at_frame(frame):
		print(
			"player tick " + 
			String(player.tick) + 
			" at " + 
			String(player.x) + 
			"," + 
			String(player.y)
		)
		var player_node:Node2D = player_tick_to_nodes.get(player.tick - 1)
		if player_node != null:
			tween.interpolate_property(player_node, "position",
				player_node.position, Vector2(player.x * 50, player.y * 50),
				ANIM_TIME, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
			)
			player_tick_to_nodes.erase(player.tick - 1)
		else:
			player_node = tile_scene.instance()
			player_node.get_children()[0].animation = "noodly-alive"
			player_node.position.x = player.x * 50
			player_node.position.y = player.y * 50
			tween.interpolate_property(player_node, "scale",
				Vector2(0.0,0.0), Vector2(1.0,1.0),
				ANIM_TIME, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
			)
			self.add_child(player_node)
		new_player_tick_to_nodes[player.tick] = player_node

	for node in player_tick_to_nodes.values():
		self.remove_child(node)
	player_tick_to_nodes = new_player_tick_to_nodes
	tween.start()
