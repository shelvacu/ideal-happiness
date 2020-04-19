extends Object

# We won't allow solutions which have the actor travel past these time bounds
const MIN_TIME = -10
const MAX_TIME = 20

enum Determination { INCONSISTENT, INCONCLUSIVE, LOSE, WIN }
class Reaction:
	### When the player interacts with a tile, it can trigger new knowledge,
	### or a win/loss condition
	var new_facts:Array = [] # of Statement
	var new_constraints:Array = [] # of Constraint
	var reverse_direction:bool # Have the player move in the opposite direction
	
class Tile:
	func possible_states() -> Array: # of Opaque
		### Enumerate all the possible "states" a tile could be in.
		### Each state corresponds to one branch along a fork when the player
		### encounters this tile. So, stateless objects should return a
		### one-element array
		### N.B. the first element of this array is assumed to be the initial
		### state of the tile at t=-infinity
		return [null]
	func react(_time:int) -> Reaction:
		### called when the player enters this tile
		return Reaction.new()
		
class GoalTile:
	extends Tile
	var tile_name = "goal"
	var ascii = "F"
	func react(time:int) -> Reaction:
		var reaction = Reaction.new()
		reaction.new_constraints = [Constraint.new(self, null, time, ConstraintType.WIN)]
		return reaction
		
class EdgeTile:
	### Placed at the edge of the level to prevent OOB accesses.
	extends Tile
	var tile_name = "empty"  # XXX colin: should be 'edge', maybe
	var ascii = "."
	func react(time:int) -> Reaction:
		var reaction = Reaction.new()
		reaction.reverse_direction = true
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
		
	func react(time:int) -> Reaction:
		# cause the state of the attached bridge to toggle
		var reaction = Reaction.new()
		reaction.new_facts = [Statement.new(attached, StatementToggle.new(), time)]
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
		# The first element is always the default state
		if default_not_solid:
			return [BridgeState.NOT_SOLID, BridgeState.SOLID]
		else:
			return [BridgeState.SOLID, BridgeState.NOT_SOLID]
	func react(time:int) -> Reaction:
		### If the bridge is NOT_SOLID, trigger a lose condition
		var reaction = Reaction.new()
		reaction.new_constraints = [Constraint.new(self, BridgeState.NOT_SOLID, time, ConstraintType.LOSE)]
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

class StatementValue:
	### Statement.operation option for `x = <value>` where `x` is a state
	var value # Opaque. It comes from Tile.possible_states
	func _init(value_):
		self.value = value_
	func ascii() -> String:
		return String(value)

class StatementToggle:
	### Statement.operation option for `x = !x`
	func ascii() -> String:
		return "Toggle"

class Statement:
	### A statement claims that the "value" (state) of the provided tile is as
	### provided, at the given time.
	### We assume that between any two statements about a tile, its value doesn't
	### change
	var time:int
	var tile: Tile
	var operation # Either StatementValue or StatementMap

	func _init(tile_:Tile, operation_, time_:int):
		tile = tile_
		operation = operation_
		time = time_
	func ascii() -> String:
		return tile.ascii + String(tile.get_instance_id()) + "=" + operation.ascii() + "@" + String(time)
	
	static func is_earlier(a:Statement, b:Statement) -> bool:
		# N.B. must be deterministic
		if a.time < b.time:
			return true
		elif a.time > b.time:
			return false
		if a.tile < b.tile:
			return true
		elif a.tile > b.tile:
			return false
		return a.operation < b.operation
		# Blegh, should be able to do it like this:
		# return [a.time, a.tile, a.operation] < [b.time, b.tile, b.operation]
		
enum ConstraintType { REQUIRED, WIN, LOSE }
class Constraint:
	### A Constraint represents some condition which "must hold" but isn't
	### provable until the system terminates.
	### The ConstraintType decsribes the consequence of meeting the constraint.
	### `REQUIRED` means that if the constraint _isn't_ met, the system is in an
	### inconsistent state.
	### `WIN` and `LOSE` mean that meeting the Constraint triggers termination
	### (as either a win or a lose).
	# XXX colin: maybe WIN and LOSE aren't really Constraints, but
	# would be better represented as "termination conditions"
	var time:int
	var tile:Tile
	var type:int # ConstraintType
	var value # Opaque
	func _init(tile_: Tile, value_, time_:int, type_:int):
		tile = tile_
		value = value_
		time = time_
		type = type_
		
	func ascii() -> String:
		var v = "null"
		if value != null:
			v = String(value)
		return tile.ascii + String(tile.get_instance_id()) + "=" + v + "@" + String(time)
		
class ConstraintSystem:
	### A ConstraintSystem encodes some things we _assume_ to be true (but have
	### not proven), i.e. the constraints, and some "facts" which we dereive 
	### from the constraints as we evaluate a level. These facts could
	### contradict the constraints, in which case the system is "inconsistent"
	var constraints:Array # of Constraint
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
	
	func append_constraint(constraint: Constraint):
		constraints.append(constraint)
	
	func value_at(time:int, tile:Tile): # -> opaque
		### Evaluate the facts about this tile up through the provided time
		var state = null
		for fact in facts:
			if fact.time > time:
				break
			if fact.tile != tile:
				continue
			if fact.operation is StatementValue:
				state = fact.operation.value
			elif fact.operation is StatementToggle:
				assert(state == 0 or state == 1)
				state = 1 - state
			else:
				assert(false) # Unknown StatementOperation!
		return state
	
	func determination() -> int: # returns Determination
		var is_win = false
		var is_lose = false
		for c in constraints:
			var value = value_at(c.time, c.tile)
			if c.type == ConstraintType.REQUIRED and c.value != value:
				return Determination.INCONSISTENT
			elif c.type == ConstraintType.WIN and c.value == value:
				is_win = true
			elif c.type == ConstraintType.LOSE and c.value == value:
				is_lose = true
		if is_win:
			return Determination.WIN
		elif is_lose:
			return Determination.LOSE
		else:
			return Determination.INCONCLUSIVE

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
		var det = _determination()
		return time > MAX_TIME or time < MIN_TIME or det == Determination.WIN or det == Determination.LOSE
	
	func is_consistent():
		return _determination() != Determination.INCONSISTENT
	
	func _determination():
		return constraints.determination()
	
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
				new_constraints.append_constraint(Constraint.new( \
					tile, state, time, ConstraintType.REQUIRED))
				
			var reaction = tile.react(time);
			for fact in reaction.new_facts:
				new_constraints.append_fact(fact)
			for constraint in reaction.new_constraints:
				new_constraints.append_constraint(constraint)
			if reaction.reverse_direction:
				self.player.direction = 1 - self.player.direction
			
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
				self.constraints.append_fact(Statement.new( \
					tile, StatementValue.new(default_state), MIN_TIME))
		
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

static func query_from_ascii(level:String, connections:Array, portals:Array):
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
			".":
				tile = EdgeTile.new()
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
