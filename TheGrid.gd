extends Node2D

const Width = 10
const Height = 10

onready var init_tiles = [
	[0, 1, TileBlock.new()],
	[1, 1, TileBlock.new()],
	[2, 1, TileBlock.new()],
	[3, 1, TileBridge.new()],
	[4, 1, TileBlock.new()],
	[5, 1, TileBlock.new()],
	[0, 0, TileEnd.new()],
	[1, 0, TileButton.new()],
	[2, 0, TilePortal.new(-5)],
	[9, 9, TileBlock.new()]
]

const InitConnections = [
	[1, 0, 3, 1]
]

const InitPlayerPos = [0, 5]

var tiles = []

onready var tileScene = preload("res://Tile.tscn")

enum Action { NONE, MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT }

class Util:
	static func cartesian_product(of:Array) -> Array:
		if of.size() == 0:
			return []
		elif of.size() == 1:
			var res := []
			for el in of[0]:
				res.append([el])
			return res
		else:
			var sub_problem := of.slice(1,-1)
			var sub_res := cartesian_product(sub_problem)
			var res := []
			for el in of[0]:
				res.append([el] + sub_res)
			return res

class ProcessResult:
	var isFail := false
	var isTrigger := false
	var action:int = Action.NONE

class TileActor: #<T>
	func _init():
		pass
	func process(_x:int, _y:int, _isActive:bool, _grid) -> ProcessResult:
		return ProcessResult.new()
	func is_solid(_state) -> bool:
		return false
	func tile_name() -> String:
		assert(false)
		return "unreachable"
	func states() -> Array: #Array<T>
		return [null]
	func state(): #-> T
		return null
	func signal_out() -> bool:
		return false
	func duplicate() -> TileActor:
		return TileActor.new()

class TileBlock:
	extends TileActor
	func is_solid(_state) -> bool:
		return true
	func tile_name() -> String:
		return "block"
	func duplicate() -> TileActor:
		return TileBlock.new()

class TileButton:
	extends TileActor
	var pressed := false
	func process(x:int, y:int, _isActive:bool, grid) -> ProcessResult:
		if grid.playerHere(x, y):
			pressed = true
		var res := ProcessResult.new()
		res.isTrigger = pressed
		return res
	func signal_out() -> bool:
		return pressed
	func tile_name() -> String:
		if pressed:
			return "button-pressed"
		else:
			return "button-depressed"
	func duplicate() -> TileActor:
		var t = TileButton.new()
		t.pressed = pressed
		return t

class TileBridge:
	extends TileActor
	var fall := false
	func process(_x:int, _y:int, isActive:bool, _grid) -> ProcessResult:
		fall = !isActive
		return ProcessResult.new()
	func is_solid(state:bool) -> bool:
		return !state
	func tile_name() -> String:
		if fall:
			return "bridge-fall"
		else:
			return "bridge-nofall"
	func states() -> Array:
		return [false, true]
	func state():
		return fall
	func duplicate() -> TileActor:
		var t = TileBridge.new()
		t.fall = fall
		return t

class TilePortal:
	extends TileActor
	var steps:int
	func _init(steps_:int):
		steps = steps_
	func tile_name() -> String:
		return "portal"
	func duplicate() -> TileActor:
		return TilePortal.new(steps)

class TileEnd:
	extends TileActor
	func tile_name() -> String:
		return "end"
	func duplicate() -> TileActor:
		return TileEnd.new()

#class TilePlayer:
#	extends TileActor
#	var alive := true
#	var age := 0
#	func tile_name() -> String:
#		if alive:
#			return "noodly-alive"
#		else:
#			return "noodly-dead"
#	func is_solid() -> bool:
#		return false
#	func duplicate() -> TileActor:
#		var t = TilePlayer.new()
#		t.alive = alive
#		t.age = age
#		return t
#	#todo

class Player:
	var direction:int = Action.MOVE_RIGHT
	var lifetime:int = 0
	var x:int
	var y:int
	var dead := false
	func _init(x_:int, y_:int):
		x = x_
		y = y_
	func duplicate():
		var d = Player.new(x, y)
		d.direction = direction
		d.lifetime = lifetime
		d.dead = dead
		return d

class Grid:
	var grid := [] #Array<Array<TileActor|null>>
	var width:int
	var height:int
	var players := [] #Player
	var connections := [] #x1,y1,x2,y2
	func _init(width_: int, height_: int):
		width = width_
		height = height_
		for _a in range(height):
			var row := []
			for _b in range(width):
				row.append(null)
			grid.append(row)
	func at(x: int, y: int): #-> TileActor|null
		return grid[y][x]
	func add(x: int, y: int, el: TileActor) -> void:
		assert(grid[y][x] == null)
		grid[y][x] = el
	func duplicate() -> Grid:
		var dup = Grid.new(width, height)
		for y in range(height):
			for x in range(width):
				dup.add(x,y,grid[y][x].duplicate())
		for p in players:
			dup.players.append(p.duplicate())
		for c in connections:
			dup.connections.append(c + [])
		return dup

#class TimelineNode:
#	var step:int #0: inital setup, 1: noodly appears, hasn't moved yet
#	var grid:Grid
#	var next_nodes := []

enum NodeState {Continue, Dead, End}

class Timeline:
	var root:Dictionary
	var start_position:Array
	func _init(root_grid:Grid, start_position_:Array):
		start_position = start_position_
		root = {
			time_step = 0,
			player_step = 0,
			grid = root_grid,
			next_nodes = [],
			constraints = [], #Array<(x,y,state)>
			player_parent = null,
			time_parent = null,
			state = NodeState.Continue
		}
		#var grid_one = root_grid.duplicate()
		#var player = TilePlayer.new()
		#grid_one.add(player_position[0], player_position[1], player)
		#var next = {
		#	step = 1,
		#	grid = grid_one,
		#	next_nodes = [],
		#	parent = root
		#}
		#root.next_nodes.append(next)
	func get_parent(node:Dictionary) -> Dictionary:
		if node.parent == null:
			var new_root = {
				time_step = root.time_step - 1,
				player_step = root.player_step - 1,
				grid = root.grid.duplicate(),
				next_nodes = [root],
				constraints = [],
				player_parent = null,
				time_parent = null
			}
			var old_root = root
			root = new_root
			old_root.player_parent = new_root
			old_root.time_parent = new_root
			return new_root
		else:
			return node.parent
	func next_step(node:Dictionary) -> void: #result is in node.next_nodes
		#assuming tile at x,y has state state, move player at playeridx by the vector vx,vy
		var assumption_moves := [] #Array<Array<(Array<(x,y,state)>,playeridx,vx:int|null,vy:int|null)
		for pi in range(node.grid.players.size()):
			assumption_moves.append([])
			var p:Player = node.grid.players[pi]
			var vector_x := 0
			var vector_y := 0
			match p.direction:
				Action.NONE:
					pass
				Action.MOVE_LEFT:
					vector_x = -1
				Action.MOVE_RIGHT:
					vector_x = +1
				Action.MOVE_UP:
					vector_y = -1
				Action.MOVE_DOWN:
					vector_y = +1
				_:
					assert(false)
			var destx := p.x + vector_x
			var desty := p.y + vector_y
			if destx < 0 or destx >= node.grid.width or desty < 0 or desty >= node.grid.height - 1:
				assumption_moves[-1].append(
					[
						[], #no assumptions, no matter what
						pi,
						null, #they ded
						null
					]
				)
			else:
				var moving_to_tile = node.grid.get(destx, desty)
				var under_moving_tile = node.grid.get(destx, desty + 1)
				for moving_state in moving_to_tile.states():
					var moving_solid = moving_state.is_solid(moving_state)
					if moving_solid:
						assumption_moves[-1].append(
							[
								[
									[destx, desty, moving_state]
								],
								pi,
								0,
								0
							]
						)
					else:
						for under_state in under_moving_tile.states():
							var assumptions = [
								[destx, desty, moving_state],
								[destx, desty+1, under_state]
							]
							var under_solid = under_moving_tile.is_solid(under_state)
							if under_solid:
								assumption_moves[-1].append([
									assumptions,
									pi,
									vector_x,
									vector_y
								])
							else:
								assumption_moves[-1].append([
									assumptions,
									pi,
									null, #they ded yo
									null
								])
		for move_assumption_set in Util.cartesian_product(assumption_moves):
			var new_grid = node.grid.duplicate()
			var constraints = []
			for move_assumption in move_assumption_set:
				for assumption in move_assumption[0]:
					constraints.append(assumption)
			var new_node = {
				time_step = node.time_step + 1,
				player_step = node.player_step + 1,
				grid = new_grid,
				next_nodes = [],
				constraints = constraints,
				player_parent = node,
				time_parent = node,
				state = NodeState.Continue
			}
			for move_assumption in move_assumption_set:
				var pi = move_assumption[1]
				var vx = move_assumption[2]
				var vy = move_assumption[3]
				var p = new_grid.players[pi]
				if vx == null:
					new_node.state = NodeState.Dead
					p.dead = true
				else:
					p.x += vx
					p.y += vy
			for y in range(new_grid.height):
				for x in range(new_grid.width):
					var is_active := false
					for conn in new_grid.connections:
						if conn[2] == x and conn[3] == y and node.grid.get(conn[0],conn[1]).signal_out():
							is_active = true
					new_grid.get(x,y).process(x,y,is_active,new_grid)
			if node.time_step == 0:
				new_grid.players.push_front(Player.new(start_position[0], start_position[1]))
			if new_grid.players.size() > 0:
				var last_player = new_grid.players[-1]
				var block = new_grid.get(last_player.x, last_player.y)
				if block != null and block is TilePortal:
					assert(block.steps < 0)
					var time_template = node
					for _i in range(-block.steps):
						time_template = time_template.time_parent
					var new_new_grid = time_template.grid.duplicate()
					new_new_grid.players.append(last_player.duplicate())
					var time_parent = time_template.time_parent
					new_node.time_step = time_template.time_step
					new_node.grid = new_new_grid
					new_node.time_parent = time_parent
				elif block != null and block is TileEnd:
					new_node.state = NodeState.End
			node.children.append(new_node)
		
		#var new_node = {
		#	time_step = node.time_step + 1,
		#	player_step = node.player_step + 1,
		#	grid = new_grid,
		#	next_nodes = [],
		#	constraints = [],
		#	player_parent = node,
		#	time_parent = node
		#}
		
		return 
	func make_tree(node:Dictionary):
		if node.state != NodeState.Continue: return
		next_step(node)
		for child_node in node.next_nodes:
			make_tree(child_node)
	func do_stuff():
		pass

# Called when the node enters the scene tree for the first time.
func _ready():
	var root_grid = Grid.new(Width, Height)
	for tilespec in init_tiles:
		match tilespec:
# warning-ignore:unassigned_variable
# warning-ignore:unassigned_variable
# warning-ignore:unassigned_variable
			[var x, var y, var tile]:
				root_grid.add(x, y, tile)
			_:
				assert(false)
	var timeline = Timeline.new(root_grid, InitPlayerPos)
	timeline.make_tree(timeline.root)
	print(timeline)
	assert(false)
	#var rowIdx := 0
	#for row in tiles:
	#	var cellIdx := 0
	#	for cell in row:
	#		for tileName in cell:
	#			var tileNode:Node2D = tileScene.instance()
	#			tileNode.get_children()[0].animation = tileName
	#			tileNode.position.x = cellIdx * 50
	#			tileNode.position.y = rowIdx * 50
	#			self.add_child(tileNode)
	#		cellIdx += 1
	#	rowIdx += 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
