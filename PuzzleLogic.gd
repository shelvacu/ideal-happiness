extends Object

# We won't allow solutions which have the actor travel past these time bounds
const MIN_TIME = -10
const MAX_TIME = 15

enum Direction { LEFT, RIGHT }
enum WinState { UNKNOWN, WIN }

class Variable:
	# Variable uses pointer comparison.
	var _unused := "Variable" # empty classes aren't allowed, so dummy data
	
class Branch:
	var new_direction:int  # from Direction enum
	var new_node:GameNode
	var constraints:Array # of Constraint
	var new_facts:Array # of Statement
	
	func _init(new_node_:GameNode, new_direction_:int, constraints_:Array=[], new_facts_:Array=[]):
		new_direction = new_direction_
		new_node = new_node_
		constraints = constraints_
		new_facts = new_facts_
	
class GameNode:
	func constraints_to_enter(_time:int) -> Array: # of Constraint
		### Return whatever things must be satisfied for the robot to be allowed
		### onto this node at the given time
		return []
	func on_enter(_time:int) -> Array: # of Statement
		### Return whatever new facts we know by having the robot occupy this
		### node at this time.
		return []
	func on_exit(_time:int, _player_direction:int) -> Array: # of Branch
		### Return all possible branches that a robot could take to leave this
		### node. If empty, that terminates the simulation (i.e. the robot just
		### idles here indefinitely)
		assert(false)
		return []
		
class LinearNode:
	 ### Node which has a Left and/or a Right node adjacent to it
	extends GameNode
	var left:GameNode # or null, if at the edge of the map
	var right:GameNode # or null, if at the edge of the map
	func _init(left_:GameNode=null, right_:GameNode=null):
		left = left_
		right = right_
	func on_exit(_time:int, player_direction:int) -> Array:
		if player_direction == Direction.RIGHT and right != null:
			return [Branch.new(right, Direction.RIGHT)]
		if player_direction == Direction.LEFT and left != null:
			return [Branch.new(left, Direction.RIGHT)]
		return [] 
		
class GoalNode:
	extends LinearNode
	var node_name = "goal"
	var ascii = "F"
	var win_var:Variable
	func _init(win_var_:Variable):
		self.win_var = win_var_
	func on_enter(time:int) -> Array:
		return [Statement.new(win_var, StatementValue.new(WinState.WIN), time)] 

class EmptyNode:
	extends LinearNode
	var node_name = "empty"
	var ascii = " "

class ButtonNode:
	extends LinearNode
	var node_name = "button-depressed"
	var ascii = "n"
	var attached:Variable
	func _init(attached_:Variable):
		attached = attached_
		
	func on_enter(time:int) -> Array:
		# cause the state of the attached bridge to toggle
		return [Statement.new(attached, StatementToggle.new(), time)]

enum BridgeState { NOT_SOLID, SOLID };
class BridgeNode:
	extends LinearNode
	var node_name = "bridge-nofall"
	var ascii = "|"
	var bridge_var:Variable
	func _init(bridge_var_:Variable):
		bridge_var = bridge_var_
	func constraints_to_enter(time:int) -> Array:
		 return [Constraint.new(self.bridge_var, BridgeState.SOLID, time)] 
		
class ElevatorNode:
	### Represents the elevator "receptacle", for lack of a better word.
	### An elevator which travels between two floors will have two ElevatorNodes.
	### These two nodes will share the same elevator_var. The state associated
	### with that elevator_var is a pointer to whichever ElevatorNode houses
	### the elevator.
	extends LinearNode
	var node_name = "bridge-nofall"  # TODO colin
	var ascii = "+"
	var elevator_var:Variable
	var linked:Array # of ElevatorNode
	func _init(elevator_var_:Variable):
		elevator_var = elevator_var_
		linked = []
	func add_links(links:Array): # of ElevatorNode
		linked += links
	func on_exit(time:int, player_direction:int) -> Array: # of Branch
		# We can either go left or right,
		# OR, if the elevator is on this node, then we can go to another
		# ElevatorNode
		var adjacent_branches := .on_exit(time, player_direction)
		var constraint = Constraint.new(elevator_var, self, time)
		var traveling_branches := []
		for node in linked:
			var fact = Statement.new(elevator_var, StatementValue.new(self), time+1)
			traveling_branches.append(Branch.new(node, player_direction, [constraint], [fact]))
		return adjacent_branches + traveling_branches

class Player:
	var direction:int = Direction.RIGHT
	var node:GameNode
	var tick:int = 0
	
	func _init(node_:GameNode, direction_:int, tick_:int=0):
		node = node_
		direction = direction_
		tick = tick_
		
	func step():
		tick += 1
	
	func duplicate():
		return Player.new(node, direction, tick)
		
class Portal:
	var node:GameNode
	var time_delta:int # probably negative
	var ascii = "@"
	func _init(node_:GameNode, time_delta_:int):
		node = node_
		time_delta = time_delta_

class StatementValue:
	### Statement.operation option for `x = <value>` where `x` is a state
	var value # Opaque.
	func _init(value_):
		self.value = value_
	func ascii() -> String:
		if value is Object:
			return String(value.get_instance_id())
		else:
			return String(value)

class StatementToggle:
	### Statement.operation option for `x = !x`
	func ascii() -> String:
		return "Toggle"

class Statement:
	### A statement claims that the "value" (state) of the provided variable is
	### as provided, at the given time.
	### We assume that between any two statements about a variable, its value
	### doesn't change
	var time:int
	var variable:Variable
	var operation # Either StatementValue or StatementMap

	func _init(variable_:Variable, operation_, time_:int):
		variable = variable_
		operation = operation_
		time = time_
	func ascii() -> String:
		return String(variable.get_instance_id()) + "=" + operation.ascii() + "@" + String(time)
	
	static func var_defaults_to(variable_:Variable, value) -> Statement:
		### Create a statement indicating that the variable has the provided
		### value at level start
		return Statement.new(variable_, StatementValue.new(value), MIN_TIME) 
	
	static func is_earlier(a:Statement, b:Statement) -> bool:
		# N.B. must be deterministic
		if a.time < b.time:
			return true
		elif a.time > b.time:
			return false
		if a.variable < b.variable:
			return true
		elif a.variable > b.variable:
			return false
		return a.operation < b.operation
		# Blegh, should be able to do it like this:
		# return [a.time, a.variable, a.operation] < [b.time, b.variable, b.operation]
		
class Constraint:
	### A Constraint represents some condition which "must hold" but isn't
	### provable until the system terminates.
	var time:int
	var variable:Variable
	var value # Opaque
	func _init(variable_:Variable, value_, time_:int):
		variable = variable_
		value = value_
		time = time_
		
	func ascii() -> String:
		var v = "null"
		if value is Object:
			v = String(value.get_instance_id())
		elif value != null:
			v = String(value)
		return String(variable.get_instance_id()) + "=" + v + "@" + String(time)
		
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
	
	func value_at(time:int, variable:Variable): # -> opaque
		### Evaluate the facts about this Variable up through the provided time
		var state = null
		for fact in facts:
			if fact.time > time:
				break
			if fact.variable != variable:
				continue
			if fact.operation is StatementValue:
				state = fact.operation.value
			elif fact.operation is StatementToggle:
				assert(state == 0 or state == 1)
				state = 1 - state
			else:
				assert(false) # Unknown StatementOperation!
		return state
	func is_consistent() -> bool:
		for c in constraints: 
			var value = value_at(c.time, c.variable) 
			if c.value != value:
				return false 
		return true

class SolutionQuery:
	### A SolutionQuery considers one way the level could unfold. We don't know
	### if it's consistent or not until `is_terminated()` returns true
	## The `tick` is the time "as experienced by the robot". It increases monotonically
	var tick:int
	var time:int
	var player_states: Dictionary # maps int (tick) to Player (state at that tick)
	var portals: Dictionary # from Portal to null (if unsolved) or int (tick entered, if solved)
	var win_var:Variable # Takes on value of WinVar.WIN if the player has won
	var constraints: ConstraintSystem
	func _init(player:Player, win_var_:Variable, constraints_:ConstraintSystem):
		tick = 0
		time = 0
		player_states[0] = player
		win_var = win_var_
		constraints = constraints_
		portals = {}
		
	static func new_from_facts(player:Player, win_var_:Variable, facts:Array) -> SolutionQuery:
		# add default facts: at MIN_TIME, we know we haven't won
		var default_facts := [Statement.new(win_var_, StatementValue.new(WinState.UNKNOWN), MIN_TIME)]
		var constraints_ := ConstraintSystem.new([], facts + default_facts)
		var query := SolutionQuery.new(player, win_var_, constraints_)
		return query 

	func ascii() -> String:
		var res := "t:" + String(tick)
		var c
		if is_consistent():
			c = "y"
		else:
			c = "n"
		res = res + " c:" + c + " " + constraints.ascii()
		return res
	
	func duplicate() -> SolutionQuery:
		var me := SolutionQuery.new(null, win_var, constraints.duplicate())
		me.tick = tick
		me.time = time
		me.player_states = player_states.duplicate()
		me.portals = portals.duplicate()
		return me
		
	func add_portal(p: Portal):
		self.portals[p] = null
		
	func is_terminated() -> bool:
		return time > MAX_TIME or time < MIN_TIME or is_win()
	
	func is_consistent() -> bool:
		return constraints.is_consistent()
	
	func is_win() -> bool:
		return is_consistent() and constraints.value_at(time, win_var) == WinState.WIN
	
	func player() -> Player:
		return player_states[tick]
	
	func _node() -> GameNode:
		return player().node
	
	func _check_enter_portal() -> Portal:
		### If the player encounters an unused portal, associate it with a time
		### entered, and yield it
		var player = player()
		for p in portals:
			if p.node == player.node and portals[p] == null:
				portals[p] = tick
				return p
		return null
		
	func portal_at_tick(tick:int) -> Portal:
		### If a portal was entered at this tick, yield it
		for p in portals:
			if portals[p] == tick:
				return p
		return null
		
	func player_at_tick(tick:int) -> Player:
		return player_states[tick]
	
	func advance() -> Array: # of SolutionQuery
		var portal := _check_enter_portal()
		if portal != null:
			time += portal.time_delta
		
		# add forks for every branch we _could_ fork into
		var new_queries := []
		for branch in _node().on_exit(time, player().direction):
			var new_query = self.duplicate()
			new_query.tick += 1
			new_query.time += 1
			new_query.player_states[tick+1] = Player.new(branch.new_node, branch.new_direction, new_query.tick)
			
			for constraint in branch.constraints:
				new_query.constraints.append_constraint(constraint)
				
			for fact in branch.new_facts:
				new_query.constraints.append_fact(fact)
			
			for constraint in branch.new_node.constraints_to_enter(time):
				new_query.constraints.append_constraint(constraint)
			
			for fact in branch.new_node.on_enter(time):
				new_query.constraints.append_fact(fact)
			
			new_queries.append(new_query)
		return new_queries
	
	static func drive_queries(queries:Array, fallback:SolutionQuery) -> Solution:
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
			if sol.end_frame() < best_sol.end_frame():
				best_sol = sol
		if best_sol == null and fallback.is_consistent():
			# neither a win nor loss condition was met. We dead-ended.
			best_sol = Solution.new(fallback)
		return best_sol
		
	func drive() -> Solution:
		print(ascii())
		### drive to completion, returning the "best" solution
		if is_terminated():
			if is_consistent():
				return Solution.new(self)
			return null
		# Advance once, then drive all the forks to completion
		return SolutionQuery.drive_queries(self.advance(), self)
		
class Solution:
	### A Solution provides a set of operations which can be used to render the
	### state of the world at any specific FRAME
	### It takes the one timeline provided by the SolutionQuery, and splits it
	### into parallel timelines ready to be displayed
	var query:SolutionQuery  # The SolutionQuery which this Solution is based on
	var earliest_time:int  # Used if a player wraps before t=0
	var latest_time:int
	var player_states:Dictionary # int (time, ABSOLUTE) to [Player]
	func _init(query_:SolutionQuery):
		# build a map from `time` to player state
		query = query_
		earliest_time = 0
		latest_time = 0
		player_states = {}
		var time = 0

		for tick in range(query_.tick + 1):
			var states_at_this_time = player_states.get(time, [])
			states_at_this_time.append(query_.player_at_tick(tick))
			player_states[time] = states_at_this_time
			var portal = query_.portal_at_tick(tick)
			if portal != null:
				time += portal.time_delta
			time += 1
			earliest_time = min(time, earliest_time)
			latest_time = max(time, latest_time)
			
	func end_frame() -> int:
		### Return the index of the last frame of the solution (i.e. length - 1)
		return latest_time - earliest_time
		
	func is_win() -> bool:
		return query.is_win()
			
	func player_states_at_frame(frame:int) -> Array: # of Player
		return player_states.get(frame + earliest_time, [])
	
	func state_at_frame(frame:int, variable:Variable):
		return query.constraints.value_at(frame + earliest_time, variable)
