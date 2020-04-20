extends Node2D

# These aren't really intended to be public, but they give us a good way to
# re-enable edit mode, and to have the button images update when the sim ends,
# etc.
signal pre_simulation_start
signal post_simulation_end
# Emitted with the Variable, and its state, whenever we calculate a value for a
# variable
signal any_variable_changed

onready var bridge_scene = preload("res://BridgeTile.tscn")
onready var tile_scene = preload("res://Tile.tscn")
onready var portal_scene = preload("res://PortalTile.tscn")
const PuzzleLogic = preload("PuzzleLogic.gd")

# How many seconds to spend on each frame of the solution.
const STEP_TIME := 0.6
const ANIM_TIME := STEP_TIME * 0.9

var grid:Grid
var sol:SolvedGrid
# time, in seconds, since the start of the scene
var time_elapsed:float = 0.0
# These are the players visible on screen. We add or remove them over time
var player_nodes:Array = []

func empty_input(viewport:Node, event:InputEvent, shape_idx:int, x:int, y:int):
	pass
	# print(String(x) + "," + String(y) + " " + event.as_text())

class Grid:
	var grid := [] # of GameNode
	var width:int
	var height:int
	var portals:Array = []  # of Portal
	var facts:Array = [] # of Statement
	var win_var # Variable
	var player_x:int
	var player_y:int
	func _init(width_: int, height_: int):
		### Initialize with Empty Nodes
		width = width_
		height = height_
		for _a in range(height):
			var row := []
			for _b in range(width):
				row.append(PuzzleLogic.EmptyNode.new())
			grid.append(row)
		win_var = PuzzleLogic.Variable.new()
	func link():
		### Link adjacent tiles together
		for y in range(height):
			for x in range(width):
				if x != 0:
					at(x, y).left = at(x-1, y)
					at(x-1, y).right = at(x, y)
	func find(tile) -> Array: # of [x, y]
		for y in range(height):
			for x in range(width):
				if at(x, y) == tile:
					return [x, y]
		assert(false)  # no such Node!
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
		
	func solve() -> SolvedGrid:
		var player := PuzzleLogic.Player.new(at(player_x, player_y), PuzzleLogic.Direction.RIGHT)
		var query := PuzzleLogic.SolutionQuery.new_from_facts(player, win_var, facts)
	
		for portal in portals:
			if portal.time_delta != 0:
				# optimization (esp for debuggability)
				query.add_portal(portal)
		var solved := query.drive()
		return SolvedGrid.new(self, solved)

class SolvedGrid:
	var grid:Grid
	var solution
	func _init(grid_:Grid, solution_):
		grid = grid_
		solution = solution_ 

static func grid_from_ascii(level:String, connections:Array, portal_times:Array) -> Grid:
	var grid := Grid.new(20, 5)
	
	# Pre-generate some bridge vars to simplify code
	var bridge_vars := []
	for i in range(10):
		bridge_vars.append(PuzzleLogic.Variable.new())
	var bridge_tiles := []
	var btn_idx := 0
	
	var elevator_var := PuzzleLogic.Variable.new()
	var elevator_tiles := []
	
	var tile_x = -1
	var tile_y = 0
	for c in level:
		tile_x += 1
		var tile = null
		match c:
			"p":
				grid.player_x = tile_x
				grid.player_y = tile_y
			" ":
				pass
			".": # Godot converts adjacent spaces to tabs
				pass
			"|":
				var bridge_var = bridge_vars[bridge_tiles.size()]
				var bridge_state = PuzzleLogic.BridgeState.NOT_SOLID
				tile = PuzzleLogic.BridgeNode.new(bridge_var)
				bridge_tiles.append(tile)
				grid.facts.append(PuzzleLogic.Statement.var_defaults_to(bridge_var, bridge_state))
			"-":
				var bridge_var = bridge_vars[bridge_tiles.size()]
				var bridge_state = PuzzleLogic.BridgeState.SOLID
				tile = PuzzleLogic.BridgeNode.new(bridge_var)
				bridge_tiles.append(tile)
				grid.facts.append(PuzzleLogic.Statement.var_defaults_to(bridge_var, bridge_state))
			"n":
				tile = PuzzleLogic.ButtonNode.new(bridge_vars[connections[btn_idx]])
				btn_idx += 1
			"F":
				tile = PuzzleLogic.GoalNode.new(grid.win_var)
			"@":
				var idx = grid.portals.size()
				var portal_time:int
				if portal_times.size() > idx:
					portal_time = portal_times[idx]
				else:
					portal_time = 0
				grid.portals.append(PuzzleLogic.Portal.new(grid.at(tile_x, tile_y), portal_time))
			"E":
				tile = PuzzleLogic.ElevatorNode.new(elevator_var)
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
		grid.facts.append(PuzzleLogic.Statement.var_defaults_to(elevator_var, elevator_tiles[0]))
	grid.link()  ## DON'T MUTATE GRID AFTER THIS
	
	return grid

var levels_ascii = [["""
p@@|@@n@@n@@-@@E@@
..................
...............E@F""",[0,1],[]],["""
p@|@n@@|@n@@F
""",[0,1],[]]
]

var curr_level = 0

func show_level():
	grid = grid_from_ascii(levels_ascii[curr_level][0], levels_ascii[curr_level][1], levels_ascii[curr_level][2])
	# Demo query: Change [-2] (portal time delta) to [-1], and game will lose
	#var query = PuzzleLogic.query_from_ascii(".p  |@n  F.", [0], [-2])
	
	#print(sol)
	var rowIdx := 0
	for row in grid.grid:
		var cellIdx := 0
		for tile in row:
			var tile_node
			if tile.node_name == "bridge-nofall":
				tile_node = bridge_scene.instance()
				connect("any_variable_changed", tile_node, "on_state_change", [tile.bridge_var])
			else:
				tile_node = tile_scene.instance()
				tile_node.get_children()[0].animation = tile.node_name
			tile_node.position.x = cellIdx * 50
			tile_node.position.y = rowIdx * 50
			if tile.node_name == "empty":
				var area = tile_node.find_node("ClickableArea", true, false)
				area.connect("input_event", self, 
					"empty_input", [cellIdx, rowIdx])
			$TileContainer.add_child(tile_node)
			cellIdx += 1
		rowIdx += 1
	for portal in grid.portals:
		var portal_tile = portal_scene.instance()
		portal_tile.set_time_delta(portal.time_delta)
		portal_tile.connect("on_time_delta_changed", portal, "set_time_delta")
		connect("pre_simulation_start", portal_tile, "disable_edit")
		connect("post_simulation_end", portal_tile, "enable_edit")
		
		var xy = grid.find(portal.node)
		portal_tile.position.x = xy[0] * 50
		portal_tile.position.y = xy[1] * 50
		$TileContainer.add_child(portal_tile)
		
	sol = grid.solve()
	render_frame(-1)

# Called when the node enters the scene tree for the first time.
func _ready():
	print("_ready")
	
	$SimulationPlayButton.connect("play_pressed", self, "start_simulation")
	$SimulationPlayButton.connect("pause_pressed", self, "pause_simulation")
	$SimulationStopButton.connect("stop_pressed", self, "stop_simulation")
	connect("post_simulation_end", $SimulationPlayButton, "set_play")
	show_level()

var prev_frame = -1
var player_tick_to_nodes := {}
onready var tween = $Tween
enum Mode {Edit, Play, Pause}
var current_mode = Mode.Edit
var play_start := 0

func update_tile_icons(frame:int):
	# Let all the tiles know their new states
	var variable_values = sol.solution.all_states_at_frame(frame)
	for vari in variable_values:
		emit_signal("any_variable_changed", vari, variable_values[vari])

func start_simulation():
	if current_mode == Mode.Edit:
		emit_signal("pre_simulation_start")
		sol = grid.solve()
		time_elapsed = 0
		render_frame(0)
	current_mode = Mode.Play
	
func pause_simulation():
	current_mode = Mode.Pause
	
func stop_simulation():
	current_mode = Mode.Edit
	render_frame(-1)
	emit_signal("post_simulation_end")

func _process(delta:float):
	if current_mode == Mode.Play:
		play_process(delta - play_start)

func play_process(delta:float):
	time_elapsed += delta
	var frame = int(time_elapsed / STEP_TIME)
	if frame >= sol.solution.end_frame():
		if sol.solution.is_win():
			$NextLevel.show()
		return
	if frame == prev_frame: return
	prev_frame = frame
	
	render_frame(frame)

func render_frame(frame:int):
	update_tile_icons(frame)
	var new_player_tick_to_nodes := {}
	for player in sol.solution.player_states_at_frame(frame):
		var player_node:Node2D = player_tick_to_nodes.get(player.tick - 1)
		var xy := sol.grid.find(player.node)
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
			$TileContainer.add_child(player_node)
		new_player_tick_to_nodes[player.tick] = player_node
	for node in player_tick_to_nodes.values():
		$TileContainer.remove_child(node)
	player_tick_to_nodes = new_player_tick_to_nodes
	tween.start()


func _on_NextLevelArea_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
		stop_simulation()
		curr_level += 1
		for c in $TileContainer.get_children():
			$TileContainer.remove_child(c)
		$NextLevel.hide()
		show_level()
