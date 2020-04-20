extends Node2D

onready var tile_scene = preload("res://Tile.tscn")
const PuzzleLogic = preload("PuzzleLogic.gd")

# How many seconds to spend on each frame of the solution.
const STEP_TIME := 1.0
const ANIM_TIME := 0.9

var sol:SolvedGrid
# time, in seconds, since the start of the scene
var time_elapsed:float = 0.0
# These are the players visible on screen. We add or remove them over time
var player_nodes:Array = []


class Grid:
	var grid := [] # of Tile
	var width:int
	var height:int
	func _init(width_: int, height_: int):
		### Initialize with Empty Tiles
		width = width_
		height = height_
		for _a in range(height):
			var row := []
			for _b in range(width):
				row.append(PuzzleLogic.EmptyTile.new())
			grid.append(row)
	func link():
		### Link adjacent tiles together
		for y in range(height):
			for x in range(width):
				if x != 0:
					at(x, y).left_tile = at(x-1, y)
					at(x-1, y).right_tile = at(x, y)
	func find(tile) -> Array: # of [x, y]
		for y in range(height):
			for x in range(width):
				if at(x, y) == tile:
					return [x, y]
		assert(false)  # no such Tile!
		return []
	func find_x(tile) -> int:
		return find(tile)[0]
	func find_y(tile) -> int:
		return find(tile)[1]
	func at(x: int, y: int):
		return grid[y][x]
	func insert(x: int, y: int, el) -> void:
		grid[y][x] = el
	func ascii() -> String:
		var res := ""
		for line in self.grid:
			for el in line:
				res = res + el.ascii
			res = res + "\n"
		return res
		

class SolvedGrid:
	var grid:Grid
	var solution
	func _init(grid_:Grid, solution_):
		grid = grid_
		solution = solution_ 

static func query_from_ascii(level:String, connections:Array, portal_times:Array) -> SolvedGrid:
	var grid := Grid.new(20, 5)
	
	# Pre-generate some bridge vars to simplify code
	var bridge_vars := []
	for i in range(10):
		bridge_vars.append(PuzzleLogic.Variable.new())
	var bridge_tiles := []
	var btn_idx := 0
	
	var elevator_var := PuzzleLogic.Variable.new()
	var elevator_tiles := []
	
	var portals := []
	
	var win_var := PuzzleLogic.Variable.new()
	
	var player_x := 0
	var player_y := 0
	var facts := []
	var tile_x = -1
	var tile_y = 0
	for c in level:
		tile_x += 1
		var tile = null
		match c:
			"p":
				player_x = tile_x
				player_y = tile_y
			" ":
				pass
			"|":
				var bridge_var = bridge_vars[bridge_tiles.size()]
				var bridge_state = PuzzleLogic.BridgeState.NOT_SOLID
				tile = PuzzleLogic.BridgeTile.new(bridge_var)
				bridge_tiles.append(tile)
				facts.append(PuzzleLogic.Statement.var_defaults_to(bridge_var, bridge_state))
			"-":
				var bridge_var = bridge_vars[bridge_tiles.size()]
				var bridge_state = PuzzleLogic.BridgeState.SOLID
				tile = PuzzleLogic.BridgeTile.new(bridge_var)
				bridge_tiles.append(tile)
				facts.append(PuzzleLogic.Statement.var_defaults_to(bridge_var, bridge_state))
			"n":
				tile = PuzzleLogic.ButtonTile.new(bridge_vars[connections[btn_idx]])
				btn_idx += 1
			"F":
				tile = PuzzleLogic.GoalTile.new(win_var)
			"@":
				var idx = portals.size()
				portals.append(PuzzleLogic.Portal.new(grid.at(tile_x, tile_y), portal_times[idx]))
			"E":
				tile = PuzzleLogic.ElevatorTile.new(elevator_var)
				elevator_tiles.append(tile)
			"\n":
				tile_y += 1
				tile_x = 0
		if tile != null:
			grid.insert(tile_x, tile_y, tile)
			
	if elevator_tiles != []:
		for e in elevator_tiles:
			e.add_links(elevator_tiles)
		# Elevator starts at the FIRST provided location
		facts.append(PuzzleLogic.Statement.var_defaults_to(elevator_var, elevator_tiles[0]))
	grid.link()  ## DON'T MUTATE GRID AFTER THIS
	
	var player := PuzzleLogic.Player.new(grid.at(player_x, player_y), PuzzleLogic.Direction.RIGHT)
	var query := PuzzleLogic.SolutionQuery.new_from_facts(player, win_var, facts)

	for portal in portals:
		query.add_portal(portal)
	var solved := query.drive()
	return SolvedGrid.new(grid, solved)


# Called when the node enters the scene tree for the first time.
func _ready():
	print("_ready")
	#012345678901234
	#P |||@n@n@nF
	sol = query_from_ascii("p |@n n@- E\n         \n         E F", [0,1], [-2,-3])
	
	# Demo query: Change [-2] (portal time delta) to [-1], and game will lose
	#var query = PuzzleLogic.query_from_ascii(".p  |@n  F.", [0], [-2])
	
	print(sol)
	var rowIdx := 0
	for row in sol.grid.grid:
		var cellIdx := 0
		for tile in row:
			var tile_node:Node2D = tile_scene.instance()
			tile_node.get_children()[0].animation = tile.tile_name
			tile_node.position.x = cellIdx * 50
			tile_node.position.y = rowIdx * 50
			self.add_child(tile_node)
			cellIdx += 1
		rowIdx += 1
	for portal in sol.solution.query.portals:
		var tile_node:Node2D = tile_scene.instance()
		tile_node.get_children()[0].animation = "portal"
		var xy = sol.grid.find(portal.tile)
		tile_node.position.x = xy[0] * 50
		tile_node.position.y = xy[1] * 50
		self.add_child(tile_node)

var last_frame = -1
var player_tick_to_nodes := {}
onready var tween = $Tween
enum Mode {Edit, Play}
var current_mode = Mode.Edit
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta:float):
	time_elapsed += delta
	var frame = int(time_elapsed / STEP_TIME)
	if frame == last_frame: return
	last_frame = frame

	var new_player_tick_to_nodes := {}
	for player in sol.solution.player_states_at_frame(frame):
		var player_node:Node2D = player_tick_to_nodes.get(player.tick - 1)
		var xy := sol.grid.find(player.tile)
		var x = xy[0]
		var y = xy[1]
		if player_node != null:
			tween.interpolate_property(player_node, "position",
				player_node.position, Vector2(x * 50, y * 50),
				ANIM_TIME, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
			)
			player_tick_to_nodes.erase(player.tick - 1)
		else:
			player_node = tile_scene.instance()
			player_node.get_children()[0].animation = "noodly-alive"
			var to = Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(x*50,y*50))
			#var to = Transform2D.IDENTITY.translated(Vector2(x,y))
			#var from = to.translated(Vector2(25,25)).rotated((30/360)*TAU)
			#var from = to.translated(Vector2(25,25)).scaled(Vector2(0,0))
			var from = Transform2D(Vector2(0,0), Vector2(0,0), Vector2(x*50+25,y*50+25))
			tween.interpolate_property(player_node, "transform",
				from, to,
				ANIM_TIME, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
			)
			self.add_child(player_node)
		new_player_tick_to_nodes[player.tick] = player_node
	for node in player_tick_to_nodes.values():
		self.remove_child(node)
	player_tick_to_nodes = new_player_tick_to_nodes
	tween.start()
