extends Node
class_name StateMachine

signal state_changed(state_name)

@export var initial_state: NodePath

var states = {}
var current_state = null
var player = null

func _ready():
	# Try to automatically find the player if it's a parent
	if get_parent() is CharacterBody2D:
		initialize(get_parent())
	else:
		print("StateMachine: Parent is not a CharacterBody2D, waiting for manual initialization")

func initialize(player_node):
	print("StateMachine initializing with player: ", player_node.name if player_node else "null")
	player = player_node
	
	if player == null:
		push_error("StateMachine: Failed to initialize - player reference is null")
		return
	
	# Register all child nodes as states
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.player = player
			print("StateMachine: Registered state: ", child.name)
	
	print("StateMachine: Found ", states.size(), " states")
	
	# Set initial state
	if initial_state and states.size() > 0:
		var initial_state_node = get_node_or_null(initial_state)
		if initial_state_node:
			print("StateMachine: Setting initial state to ", initial_state_node.name)
			change_state(initial_state_node.name)
		else:
			push_error("StateMachine: Initial state path is invalid: " + str(initial_state))
	else:
		push_error("StateMachine: No initial state set or no states found")

func _process(delta):
	if current_state:
		current_state.process_state(delta)

func _physics_process(delta):
	if current_state:
		current_state.physics_process_state(delta)

func change_state(state_name):
	if state_name in states:
		if current_state:
			current_state.exit()
			
		current_state = states[state_name]
		current_state.enter()
		emit_signal("state_changed", state_name)
	else:
		push_error("State '" + state_name + "' not found in StateMachine")
