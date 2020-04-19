extends Node2D

onready var tileScene = preload("res://Tile.tscn")

# We won't allow solutions which have the actor travel past these time bounds
const MIN_TIME = -10
const MAX_TIME = 10

enum Determination { NONE, LOSE, WIN }
class Reaction:
	### When the player interacts with a tile, it can trigger new knowledge,
	### or a win/loss condition
	var new_facts:Array = [] # of Statement
	var determination:int = Determination.NONE
	
class Tile:
	func possible_states() -> Array: # of Opaque
		### Enumerate all the possible "states" a tile could be in.
		### Each state corresponds to one branch along a fork when the player
		### encounters this tile. So, stateless objects should return a
		### one-element array
		### N.B. the first element of this array is assumed to be the initial
		### state of the tile at t=-infinity
		return [null]
	func react(_time:int, _system:ConstraintSystem) -> Reaction:
		### called when the player enters this tile
		return Reaction.new()
		
class GoalTile:
	extends Tile
	var tile_name = "goal"
	var ascii = "F"
	func react(_time:int, _system:ConstraintSystem) -> Reaction:
		var reaction = Reaction.new()
		reaction.determination = Determination.WIN
		return reaction
		
class EmptyTile:
	extends Tile
	var tile_name = "empty"
	var ascii = " "

class ButtonTile:
	extends Tile
	var tile_name = "button-depressed"
	var ascii = "n"
	var attached: BridgeTile
	func _init(attached_: BridgeTile):
		attached = attached_
		
	func react(time:int, system:ConstraintSystem) -> Reaction:
		# find the last known state of the bridge:
		var last_state = system.value_at(time - 1, attached)
		# announce a new state for the bridge:
		var new_fact = null
		if last_state == BridgeState.SOLID:
			new_fact = Statement.new(attached, BridgeState.NOT_SOLID, time)
		if last_state == BridgeState.NOT_SOLID:
			new_fact = Statement.new(attached, BridgeState.SOLID, time)
		var reaction = Reaction.new()
		reaction.new_facts = [new_fact]
		return reaction

enum BridgeState { NOT_SOLID, SOLID };
class BridgeTile:
	extends Tile
	var tile_name = "bridge-nofall"
	var ascii = "|"
	var default_not_solid:bool
	func _init(default_not_solid_:bool = true):
		default_not_solid = default_not_solid_
	func possible_states() -> Array:
		if default_not_solid:
			return [BridgeState.NOT_SOLID, BridgeState.SOLID]
		else:
			return [BridgeState.SOLID, BridgeState.NOT_SOLID]
	func react(time:int, system:ConstraintSystem) -> Reaction:
		### If the bridge is NOT_SOLID, trigger a lose condition
		var reaction = Reaction.new()
		var state = system.value_at(time, self)
		if state == BridgeState.NOT_SOLID:
			reaction.determination = Determination.LOSE
		return reaction

enum Direction {LEFT, RIGHT}
class Player:
	var direction:int = Direction.RIGHT
	var x:int = 0
	var y:int = 0
	func step():
		if direction == Direction.LEFT:
			x -= 1
		if direction == Direction.RIGHT:
			x += 1
	
	func duplicate():
		var c = Player.new()
		c.direction = direction
		c.x = x
		c.y = y
		return c
		
class Portal:
	var x:int
	var y:int
	var time_delta:int # probably negative
	var ascii = "@"
	func _init(x_:int, y_:int, time_delta_:int):
		x = x_
		y = y_
		time_delta = time_delta_

class Grid:
	var grid := [] # Tile
	var width:int
	var height:int
	func _init(width_: int, height_: int):
		### Initialize with Empty Tiles
		width = width_
		height = height_
		for _a in range(height):
			var row := []
			for _b in range(width):
				row.append(EmptyTile.new())
			grid.append(row)
	func at(x: int, y: int) -> Tile:
		return grid[y][x]
	func insert(x: int, y: int, el: Tile) -> void:
		grid[y][x] = el
	func ascii() -> String:
		var res := ""
		for line in self.grid:
			for el in line:
				res = res + el.ascii
			res = res + "\n"
		return res

class Statement:
	### A statement claims that the "value" (state) of the provided tile is as
	### provided, at the given time.
	### We assume that between any two statements about a tile, its value doesn't
	### change
	var tile: Tile
	var value # Opaque. It comes from Tile.possible_states
	var time:int
	func _init(tile_:Tile, value_, time_:int):
		tile = tile_
		value = value_
		time = time_
	func ascii() -> String:
		return tile.ascii + "=" + String(value) + "@" + String(time)
		
class ConstraintSystem:
	### A ConstraintSystem encodes some things we _assume_ to be true (but have
	### not proven), i.e. the constraints, and some "facts" which we dereive 
	### from the constraints as we evaluate a level. These facts could
	### contradict the constraints, in which case the system is "inconsistent"
	var constraints:Array # of Statement
	var facts:Array # of Statement
	func _init(constraints_, facts_):
		constraints = constraints_
		facts = facts_
		
	func ascii() -> String:
		var res := "cn:["
		for con in constraints:
			res = res + con.ascii() + ","
		res = res + "] f:["
		for fact in facts:
			res = res + fact.ascii() + ","
		res = res + "]"
		return res
	
	func duplicate():
		return ConstraintSystem.new([] + constraints, [] + facts)
	
	func append_fact(fact: Statement):
		facts.append(fact)
	
	func append_constraint(fact: Statement):
		constraints.append(fact)
	
	func _value_at(time:int, tile:Tile, consider:Array): # -> opaque
		### find the most recent Statement which is <= time, for the given tile
		var best_state = null
		for stmt in consider:
			if stmt.tile == tile and stmt.time <= time:
				if best_state == null or stmt.time > best_state.time:
					best_state = stmt
		if best_state == null:
			return null
		return best_state.value
	
	func value_at(time:int, tile:Tile):
		return _value_at(time, tile, facts + constraints)
	
	func is_consistent():
		### Ensure that all the constraints line up with the facts derived from
		### them
		for c in constraints:
			if _value_at(c.time, c.tile, facts) != c.value:
				return false
		return true

class SolutionQuery:
	### A SolutionQuery considers one way the level could unfold. We don't know
	### if it's consistent or not until `is_terminated()` returns true
	var grid: Grid # reference to the grid. Immutable
	var time:int
	var player: Player
	var portals: Array # of Portal
	var constraints: ConstraintSystem
	func _init(grid_:Grid, player_:Player):
		grid = grid_
		time = 0
		player = player_
		constraints = ConstraintSystem.new([], [])
		portals = []

	func ascii() -> String:
		var res := grid.ascii()
		for y in range(grid.height):
			for x in range(grid.width):
				var c = " "
				for p in portals:
					if p.x == x and p.y == y: c = "@"
				if player.x == x and player.y == y: c = "p"
				res = res + c
			res = res + "\nt:" + String(time)
			var c
			if is_consistent():
				c = "y"
			else:
				c = "n"
			res = res + " c:" + c + " " + constraints.ascii()
		return res

	static func new_from(other:SolutionQuery):
		### duplicate other, but be smart and don't deep-copy the immutable grid
		var me = SolutionQuery.new(other.grid, other.player.duplicate())
		me.time = other.time
		me.portals = [] + other.portals
		return me
		
	func is_terminated():
		return time > MAX_TIME or time < MIN_TIME or _determination() != Determination.NONE
	
	func is_consistent():
		return constraints.is_consistent()
	
	func _determination():
		return _tile().react(time, constraints).determination
	
	func is_win():
		return _determination() == Determination.WIN
	
	func _tile():
		return grid.at(player.x, player.y)
	
	func _check_portal() -> Portal:
		### If the player encounters a portal, REMOVE IT, and yield it
		for p in portals:
			if p.x == player.x and p.y == player.y:
				portals.erase(p)
				return p
		return null
	
	func advance() -> Array: # of SolutionQuery
		### Advance a tick and return all possible branches
		time += 1
		player.step()
		
		var portal = _check_portal()
		if portal != null:
			time += portal.time_delta
		
		# Now add forks for every state this tile could be in
		var tile = _tile()
		var new_queries = []
		for state in tile.possible_states():
			var new_constraints = constraints.duplicate()
			if state != null: # ignore trivial (always-true) constraints
				new_constraints.append_constraint(Statement.new(tile, state, time))
				
			for fact in tile.react(time, new_constraints).new_facts:
				new_constraints.append_fact(fact)
			
			var new_query = SolutionQuery.new_from(self)
			new_query.constraints = new_constraints
			new_queries.append(new_query)
		return new_queries
	
	static func drive_sols(queries: Array) -> SolutionQuery:
		### Drive all provided forks, and reduce to the best solution
		var sols = []
		for q in queries:
			var sol = q.drive();
			if sol:
				sols.append(sol)
		
		# reduce to the best solution
		var best_sol = null
		for sol in sols:
			if best_sol == null:
				best_sol = sol
			if best_sol.is_win() and not sol.is_win():
				continue
			if sol.is_win() and not best_sol.is_win():
				best_sol = sol
			if sol.time < best_sol.time:
				best_sol = sol  # TODO: should be ELAPSED time.
		return best_sol
		
	func drive() -> SolutionQuery:
		print(ascii())
		### drive to completion, returning the "best" solution
		if is_terminated():
			if is_consistent():
				return self
			return null
		# Advance once, then drive all the forks to completion
		return SolutionQuery.drive_sols(self.advance())
		
	func populate_default_constraints() -> void:
		### constrain that all tiles be in their default state at t=MIN_TIME
		for row in grid.grid:
			for tile in row:
				var default_state = tile.possible_states()[0]
				if default_state == null:
					continue
				self.constraints.append_fact(Statement.new(tile, default_state, 0))
		
#	func drive_from_start() -> SolutionQuery:
#		# need to consider ALL COMBINATIONS of constraints
#		# we end up with len(constraint_sets) for each solution query.
#		var constraint_sets = [];
#		for row in grid.grid:
#			for tile in row:
#				var states = tile.possible_states()
#				if states == [null]:
#					continue
#				var these_constraints = []
#				for state in states:
#					these_constraints.append(Statement.new(tile, state, 0))
#				constraint_sets.append(these_constraints)
#
#		# Now consider all combinations of constraints
#		var constraint_systems = [ConstraintSystem.new([], [])]
#		for set in constraint_sets:
#			var new_constraint_systems = []
#			for variant in set:
#				for sys in constraint_systems:
#					var new_sys = sys.duplicate()
#					new_sys.append_constraint(variant)
#					new_constraint_systems.append(new_sys)
#			constraint_systems = new_constraint_systems
#
#		var queries = []
#		for sys in constraint_systems:
#			var query = SolutionQuery.new(grid, player.duplicate());
#			query.constraints = sys
#			queries.append(query)
#		return drive_sols(queries)

func query_from_ascii(level:String, connections:Array, portals:Array):
	var grid = Grid.new(level.length(), 1)
	var bridge_tiles := []
	var player_x := 0
	var player_y := 0
	for idx in range(level.length()):
		var c = level[idx]
		var tile = null
		match c:
			"p":
				player_x = idx
			" ":
				pass
			"|":
				tile = BridgeTile.new(true)
				bridge_tiles.append(tile)
			"-":
				tile = BridgeTile.new(false)
				bridge_tiles.append(tile)
			"F":
				tile = GoalTile.new()
		if tile != null:
			grid.insert(idx, 0, tile)
	var btn_idx := 0
	for idx in range(level.length()):
		var c = level[idx]
		if c == "n":
			var tile = ButtonTile.new(bridge_tiles[connections[btn_idx]])
			grid.insert(idx, 0, tile)
			btn_idx += 1
	var player = Player.new()
	player.x = player_x
	player.y = player_y
	var query = SolutionQuery.new(grid, player)
	query.populate_default_constraints()
	var portal_idx := 0
	for idx in range(level.length()):
		var c = level[idx]
		if c == "@":
			query.portals.append(Portal.new(idx, 0, portals[portal_idx]))
			portal_idx += 1
	return query

# Called when the node enters the scene tree for the first time.
func _ready():
	print("_ready")
	#012345678901234
	#P |||@n@n@nF
	var query = query_from_ascii("p |||@n@n@nF", [0,1,2], [-4,-1,-1])
	
	var sol = query.drive()
	print(sol)
	var rowIdx := 0
	for row in sol.grid.grid:
		var cellIdx := 0
		for tile in row:
			var tileNode:Node2D = tileScene.instance()
			tileNode.get_children()[0].animation = tile.tile_name
			tileNode.position.x = cellIdx * 50
			tileNode.position.y = rowIdx * 50
			self.add_child(tileNode)
			cellIdx += 1
		rowIdx += 1
	for portal in sol.portals:
		var tile_node:Node2D = tileScene.instance()
		tile_node.get_children()[0].animation = "portal"
		tile_node.position.x = portal.x * 50
		tile_node.position.y = portal.y * 50
		self.add_child(tile_node)

	var tile_node:Node2D = tileScene.instance()
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
