extends Node2D

const Width = 10
const Height = 10

const InitTiles = [
	[0, 1, "block"],
	[1, 1, "block"],
	[2, 1, "block"],
	[3, 1, "bridge-fall"],
	[4, 1, "block"],
	[5, 1, "block"],
	[1, 0, "button-depressed"],
	[9, 9, "block"]
]

const InitConnections = [
	[1, 0, 3, 1]
]

const InitPlayerPos = [0, 5]

var tiles = []

onready var tileScene = preload("res://Tile.tscn")

enum Action { NONE, MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT }
class ProcessResult:
	var isFail := false
	var isTrigger := false
	var action:int = Action.NONE

class TileActor:
	func _init():
		pass
	func process(x:int, y:int, isActive:bool, grid) -> ProcessResult:
		return ProcessResult.new()
	func is_solid() -> bool:
		return false
	func tile_name() -> String:
		assert(false)
		return "unreachable"
	func duplicate() -> TileActor:
		return TileActor.new()

class TileBlock:
	extends TileActor
	func is_solid() -> bool:
		return true
	func tile_name() -> String:
		return "block"
	func duplicate() -> TileActor:
		return TileBlock.new()

class TileButton:
	extends TileActor
	var pressed := false
	func process(x:int, y:int, isActive:bool, grid) -> ProcessResult:
		if grid.playerHere(x, y):
			pressed = true
		var res := ProcessResult.new()
		res.isTrigger = pressed
		return res
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
	func process(x:int, y:int, isActive:bool, grid) -> ProcessResult:
		fall = !isActive
		return ProcessResult.new()
	func is_solid() -> bool:
		return !fall
	func tile_name() -> String:
		if fall:
			return "bridge-fall"
		else:
			return "bridge-nofall"
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
	func _init(x_:int, y_:int):
		x = x_
		y = y_

class Grid:
	var grid := []
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
				row.append([])
			grid.append(row)
	func at(x: int, y: int) -> Array:
		return grid[y][x]
	func add(x: int, y: int, el: TileActor) -> void:
		grid[y][x].append(el)
	func duplicate() -> Grid:
		var dup = Grid.new(width, height)
		for y in range(height):
			for x in range(width):
				for el in at(x,y):
					dup.add(x, y, el)
		return dup

#class TimelineNode:
#	var step:int #0: inital setup, 1: noodly appears, hasn't moved yet
#	var grid:Grid
#	var next_nodes := []

class Timeline:
	var root:Dictionary
	func _init(root_grid:Grid, player_position:Array):
		root = {
			time_step = 0,
			player_step = 0,
			grid = root_grid,
			next_nodes = [],
			player_parent = null,
			time_parent = null
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
	func do_next_step(node:Dictionary) -> Dictionary:
		pass
	func do_stuff():
		pass

# Called when the node enters the scene tree for the first time.
func _ready():
	for _a in range(Width):
		var row := []
		for _b in range(Height):
			var cell := []
			row.append(cell)
		tiles.append(row)
	for tilespec in InitTiles:
		match tilespec:
# warning-ignore:unassigned_variable
# warning-ignore:unassigned_variable
# warning-ignore:unassigned_variable
			[var x, var y, var name]:
				print(name)
				tiles[y][x].append(name)
			_:
				assert(false)
	tiles[InitPlayerPos[0]][InitPlayerPos[1]].append("noodly-alive")
	var rowIdx := 0
	for row in tiles:
		var cellIdx := 0
		for cell in row:
			for tileName in cell:
				var tileNode:Node2D = tileScene.instance()
				tileNode.get_children()[0].animation = tileName
				tileNode.position.x = cellIdx * 50
				tileNode.position.y = rowIdx * 50
				self.add_child(tileNode)
			cellIdx += 1
		rowIdx += 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
