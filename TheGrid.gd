extends Node2D

onready var tile_scene = preload("res://Tile.tscn")
const PuzzleLogic = preload("PuzzleLogic.gd")

# Called when the node enters the scene tree for the first time.
func _ready():
	print("_ready")
	#012345678901234
	#P |||@n@n@nF
	var query = PuzzleLogic.query_from_ascii(".p |@n n@- F.", [0,1], [-2,-3])
	
	# Demo query: Change [-2] (portal time delta) to [-1], and game will lose
	#var query = PuzzleLogic.query_from_ascii(".p  |@n  F.", [0], [-2])
	
	var sol = query.drive()
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
	for portal in sol.portals:
		var tile_node:Node2D = tile_scene.instance()
		tile_node.get_children()[0].animation = "portal"
		tile_node.position.x = portal.x * 50
		tile_node.position.y = portal.y * 50
		self.add_child(tile_node)

	var tile_node:Node2D = tile_scene.instance()
	tile_node.get_children()[0].animation = "noodly-alive"
	tile_node.position.x = sol.player.x * 50
	tile_node.position.y = sol.player.y * 50
	self.add_child(tile_node)
	

#func _ready():
#	for _a in range(Width):
#		var row := []
#		for _b in range(Height):
#			var cell := []
#			row.append(cell)
#		tiles.append(row)
#	for tilespec in InitTiles:
#		match tilespec:
## warning-ignore:unassigned_variable
## warning-ignore:unassigned_variable
## warning-ignore:unassigned_variable
#			[var x, var y, var name]:
#				print(name)
#				tiles[y][x].append(name)
#			_:
#				assert(false)
#	tiles[InitPlayerPos[0]][InitPlayerPos[1]].append("noodly-alive")
#	var rowIdx := 0
#	for row in tiles:
#		var cellIdx := 0
#		for cell in row:
#			for tileName in cell:
#				var tileNode:Node2D = tileScene.instance()
#				tileNode.get_children()[0].animation = tileName
#				tileNode.position.x = cellIdx * 50
#				tileNode.position.y = rowIdx * 50
#				self.add_child(tileNode)
#			cellIdx += 1
#		rowIdx += 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
