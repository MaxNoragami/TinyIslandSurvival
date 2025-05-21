extends Node
class_name PuzzleMechanism

# Puzzle configuration
@export var puzzle_id: String = "stone_puzzle"
@export var required_items = []  # Items needed to solve the puzzle
@export var required_actions = []  # Actions needed (in order)
@export var puzzle_solved_reward: String = ""  # Item to grant when puzzle is solved
@export var puzzle_solved_reward_amount: int = 1
@export var solution_actions_ordered: bool = true  # Whether actions must be in order
@export var solution_items_consumed: bool = true  # Whether items are consumed when solving

# State tracking
var is_solved: bool = false
var player_in_range: bool = false
var player_ref = null
var puzzle_active: bool = false

# For sequence puzzles
var current_action_index: int = 0
var performed_actions = []

# Signals
signal puzzle_solved
signal puzzle_reset
signal puzzle_progress_changed(progress)
signal show_message(text)

func _ready():
	# Add to group for easy access
	add_to_group("Puzzles")
	
	print("PuzzleMechanism initializing: " + puzzle_id)
	
	# Set up interaction area
	var area = $InteractionArea if has_node("InteractionArea") else null
	if area:
		print("InteractionArea found ✓")
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		
		# Ensure proper collision settings
		area.collision_layer = 4  # Interaction layer
		area.collision_mask = 1   # Player layer
		
		# Check for collision shape
		var shape = area.get_node_or_null("CollisionShape2D")
		if shape:
			print("InteractionArea has CollisionShape2D ✓")
			if shape.disabled:
				shape.disabled = false
				print("Enabled previously disabled collision shape")
		else:
			push_error("PuzzleMechanism: InteractionArea has no CollisionShape2D! Adding one...")
			_create_interaction_shape(area)
	else:
		push_error("PuzzleMechanism: No InteractionArea found. Creating one...")
		_create_interaction_area()
	
	# Find the player reference
	find_player()

func _create_interaction_area():
	var area = Area2D.new()
	area.name = "InteractionArea"
	area.collision_layer = 4  # Interaction layer
	area.collision_mask = 1   # Player layer
	
	_create_interaction_shape(area)
	
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	print("Created new InteractionArea for PuzzleMechanism")

func _create_interaction_shape(area):
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 60.0  # Large interaction radius
	collision.shape = shape
	area.add_child(collision)
	print("Created new CollisionShape2D with radius 60.0")

func find_player():
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("Player")
	if player_ref:
		print("PuzzleMechanism found player reference ✓")
	else:
		push_warning("PuzzleMechanism: Player not found, will try again later")

func _on_body_entered(body):
	print("PuzzleMechanism: Body entered: " + body.name)
	print("Is in Player group: " + str(body.is_in_group("Player")))
	
	if body.is_in_group("Player"):
		player_ref = body
		player_in_range = true
		
		print("PuzzleMechanism: Player entered puzzle range")
		
		# Show puzzle hint if not solved
		if not is_solved:
			emit_signal("show_message", get_puzzle_hint())

func _on_body_exited(body):
	if body.is_in_group("Player"):
		print("PuzzleMechanism: Player exited puzzle range")
		player_in_range = false
		reset_puzzle_progress()

func _input(event):
	if not player_in_range or is_solved:
		return
	
	# Debug key to directly solve puzzle (for testing)
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		print("PuzzleMechanism: Debug solution triggered with P key")
		solve_puzzle()
		return
		
	# Handle generic interaction to activate puzzle
	if event.is_action_pressed("interact") and not puzzle_active:
		activate_puzzle()
	
	# Check for puzzle-specific inputs
	check_puzzle_inputs(event)

func activate_puzzle():
	if puzzle_active:
		return
		
	puzzle_active = true
	print("PuzzleMechanism: Puzzle activated")
	emit_signal("show_message", "Puzzle activated. " + get_puzzle_hint())

func check_puzzle_inputs(event):
	if not puzzle_active:
		return
		
	# Example puzzle actions - override in subclasses
	if event.is_action_pressed("item_action"):
		perform_action("action")
	elif event.is_action_pressed("next_item"):
		perform_action("next")
	elif event.is_action_pressed("prev_item"):
		perform_action("prev")

func perform_action(action_name):
	if not puzzle_active or is_solved:
		return
		
	print("PuzzleMechanism: Action performed: " + action_name)
	
	# For sequence puzzles
	if solution_actions_ordered and required_actions.size() > 0:
		# Check if this is the next expected action
		if current_action_index < required_actions.size() and required_actions[current_action_index] == action_name:
			current_action_index += 1
			performed_actions.append(action_name)
			
			# Visual/audio feedback
			_show_action_feedback(true)
			
			# Update progress
			var progress = float(current_action_index) / float(required_actions.size())
			emit_signal("puzzle_progress_changed", progress)
			
			# Check if all actions completed
			if current_action_index >= required_actions.size():
				# Still need to check items
				if required_items.size() == 0 or check_required_items():
					solve_puzzle()
			
		else:
			# Wrong action, reset progress
			_show_action_feedback(false)
			reset_puzzle_progress()
			emit_signal("show_message", "That doesn't seem right...")
	else:
		# For non-sequence puzzles, just track the action
		performed_actions.append(action_name)
		
		# Check if we have performed all required actions (in any order)
		var all_actions_performed = true
		for req_action in required_actions:
			if performed_actions.find(req_action) == -1:
				all_actions_performed = false
				break
				
		if all_actions_performed:
			# Check items as well
			if required_items.size() == 0 or check_required_items():
				solve_puzzle()

func check_required_items():
	if not player_ref:
		print("PuzzleMechanism: No player reference to check items")
		return false
		
	# Check if player has all required items
	for item_name in required_items:
		if not player_ref.has_item(item_name):
			emit_signal("show_message", "You're missing something...")
			print("PuzzleMechanism: Player missing required item: " + item_name)
			return false
	
	print("PuzzleMechanism: Player has all required items")
	return true

func solve_puzzle():
	if is_solved:
		return
		
	is_solved = true
	puzzle_active = false
	
	print("PuzzleMechanism: Puzzle " + puzzle_id + " solved!")
	
	# Consume items if configured
	if solution_items_consumed and player_ref:
		for item_name in required_items:
			var success = player_ref.remove_from_inventory(item_name, 1)
			print("Consumed item " + item_name + ": " + str(success))
	
	# Give reward if any
	if puzzle_solved_reward != "" and player_ref:
		var success = player_ref.add_to_inventory(puzzle_solved_reward, puzzle_solved_reward_amount)
		print("Added reward " + puzzle_solved_reward + " x" + str(puzzle_solved_reward_amount) + ": " + str(success))
		emit_signal("show_message", "You received: " + puzzle_solved_reward + " x" + str(puzzle_solved_reward_amount))
	
	# Play solution animation or effect
	_play_solution_effect()
	
	# Emit solved signal
	emit_signal("puzzle_solved")

func reset_puzzle_progress():
	if is_solved:
		return
		
	current_action_index = 0
	performed_actions.clear()
	puzzle_active = false
	
	emit_signal("puzzle_progress_changed", 0.0)
	emit_signal("puzzle_reset")
	print("PuzzleMechanism: Puzzle progress reset")

func get_puzzle_hint():
	return "This mechanism seems to require something..."

func _show_action_feedback(is_correct):
	# Override in child classes to provide visual/audio feedback
	if is_correct:
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
		print("PuzzleMechanism: Correct action feedback")
	else:
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1, 0, 0), 0.1)
		tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
		print("PuzzleMechanism: Incorrect action feedback")

func _play_solution_effect():
	# Override in child classes for specific solution effects
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 0), 0.3)
	tween.tween_property(self, "modulate", Color(0, 1, 0), 0.3)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
	print("PuzzleMechanism: Playing solution effect")
