extends Node2D

onready var tile_scene = preload("res://Tile.tscn")
const PuzzleLogic = preload("PuzzleLogic.gd")

# How many seconds to spend on each frame of the solution.
const STEP_TIME:float = 1.0

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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta:float):
	time_elapsed += delta
	var frame = int(time_elapsed / STEP_TIME)
	var new_player_nodes = []
	for player in sol.player_states_at_frame(frame):
		var player_node:Node2D = tile_scene.instance()
		player_node.get_children()[0].animation = "noodly-alive"
		player_node.position.x = player.x * 50
		player_node.position.y = player.y * 50
		new_player_nodes.append(player_node)

	for node in player_nodes:
		self.remove_child(node)
	for node in new_player_nodes:
		self.add_child(node)
	player_nodes = new_player_nodes
