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
	func react(_time:int, _system:ConstraintSystem) -> Reaction:
		var reaction = Reaction.new()
		reaction.determination = Determination.WIN
		return reaction
		
class EmptyTile:
	extends Tile
	var tile_name = "empty"

class ButtonTile:
	extends Tile
	var tile_name = "button"
	var attached: BridgeTile
	func _init(attached_: BridgeTile):
		attached = attached_
		
	func react(time:int, system:ConstraintSystem) -> Reaction:
		# find the last known state of the bridge:
		var last_state = system.value_at(time, attached)
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
	var tile_name = "bridge"
	func possible_states() -> Array:
		return [BridgeState.NOT_SOLID, BridgeState.SOLID]
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
		

# Called when the node enters the scene tree for the first time.
func _ready():
	print("_ready")
	var grid = Grid.new(20, 1)
	grid.insert(9, 0, GoalTile.new())
	
	var bridge = BridgeTile.new()
	grid.insert(3, 0, bridge)
	
	var button = ButtonTile.new(bridge)
	grid.insert(5, 0, button)
	
	var player = Player.new()
	var query = SolutionQuery.new(grid, player)
	query.populate_default_constraints()
	query.portals.append(Portal.new(4, 0, -3))
	
	var sol = query.drive()
	print(sol)

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
