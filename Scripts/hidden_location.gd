extends Node
class_name HiddenLocation

# Configuration
@export var location_name: String = "Cave"
@export var location_id: String = "cave_1"
@export var required_time_of_day: String = "" # Changed from Night to empty (no time requirement)
@export var required_item_1: String = "StoneAxe" # First required item
@export var required_item_2: String = "RuneStone" # Second required item
@export var required_puzzle_item: String = "" # Item needed to solve puzzle inside
@export var reward_item: String = "Crystal" # Changed from MagicCompass to Crystal
@export var reward_amount: int = 1
@export var clue_message: String = "A strange rock formation... seems to have a crack in it."
@export var enter_message: String = "You discovered a hidden cave! You need both a RuneStone and StoneAxe to enter."
@export var puzzle_message: String = "Ancient stone pillars form a circle in the center of the cave."
@export var completion_message: String = "The cave rumbles and reveals a hidden crystal!"

# Node references
@onready var entrance_sprite = $EntranceSprite
@onready var entrance_col = $EntranceCollision
@onready var interaction_area = $InteractionArea
@onready var puzzle_area = $PuzzleArea
@onready var reward_sprite = $RewardSprite

# State tracking
var player_ref = null
var is_revealed: bool = false
var is_entered: bool = false
var is_puzzle_active: bool = false
var is_completed: bool = false
var has_given_clue: bool = false
var has_given_puzzle_clue: bool = false
var puzzle_solved: bool = false # New variable to track if the puzzle is solved

# Signal for UI and game state updates
signal location_discovered(location_id, name)
signal location_completed(location_id, name)
signal show_message(text)

func _ready():
	# Add to HiddenLocations group for easy access
	add_to_group("HiddenLocations")
	
	print("=== HIDDEN LOCATION SETUP: " + location_name + " ===")
	print("Location ID: " + location_id)
	print("Required items: " + required_item_1 + " and " + required_item_2)
	
	# Hide entrance initially
	if entrance_sprite:
		entrance_sprite.modulate.a = 0.0  # Make transparent
		print("EntranceSprite found and set to transparent ✓")
	else:
		push_error("No EntranceSprite found!")
	
	if entrance_col:
		entrance_col.disabled = true
		print("EntranceCollision found and disabled ✓")
	else:
		push_error("No EntranceCollision found!")
	
	# Set up interaction area with robust error checking
	if interaction_area:
		if interaction_area is Area2D:
			print("InteractionArea found ✓")
			
			# Connect signals - use deferred if needed to avoid errors
			if !interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
				interaction_area.body_entered.connect(_on_interaction_area_body_entered)
			if !interaction_area.body_exited.is_connected(_on_interaction_area_body_exited):
				interaction_area.body_exited.connect(_on_interaction_area_body_exited)
			
			# Ensure collision is set up correctly
			interaction_area.collision_layer = 4  # Set to your interaction layer
			interaction_area.collision_mask = 1   # Set to detect player
			print("InteractionArea collision layer: ", interaction_area.collision_layer)
			print("InteractionArea collision mask: ", interaction_area.collision_mask)
			
			# Verify collision shape
			var shape = interaction_area.get_node_or_null("CollisionShape2D")
			if shape:
				print("InteractionArea has CollisionShape2D ✓")
				print("CollisionShape2D disabled: ", shape.disabled)
				# Ensure the shape is enabled
				shape.disabled = false
			else:
				push_error("InteractionArea has no CollisionShape2D! Add one as a child.")
		else:
			push_error("InteractionArea is not an Area2D! This must be fixed.")
	else:
		# Add missing interaction area
		push_error("No InteractionArea found! Creating one...")
		_create_interaction_area()
	
	# Set up puzzle area
	if puzzle_area:
		if puzzle_area is Area2D:
			print("PuzzleArea found ✓")
			if !puzzle_area.body_entered.is_connected(_on_puzzle_area_body_entered):
				puzzle_area.body_entered.connect(_on_puzzle_area_body_entered)
			
			# Ensure collision is set up correctly
			puzzle_area.collision_layer = 4  # Set to your interaction layer
			puzzle_area.collision_mask = 1   # Set to detect player
		else:
			push_error("PuzzleArea is not an Area2D! This must be fixed.")
	else:
		push_error("No PuzzleArea found! Creating one...")
		_create_puzzle_area()
	
	# Hide reward initially
	if reward_sprite:
		reward_sprite.visible = false
		print("RewardSprite found and hidden ✓")
	else:
		push_warning("No RewardSprite found. The reward won't be visible when solving the puzzle.")
	
	# Find stone pillar puzzle and connect to it
	connect_to_puzzle()
	
	# Find player
	find_player()
	print("=== HIDDEN LOCATION SETUP COMPLETE ===")

# Create a missing interaction area if needed
func _create_interaction_area():
	var new_area = Area2D.new()
	new_area.name = "InteractionArea"
	new_area.collision_layer = 4  # Interaction layer
	new_area.collision_mask = 1   # Player layer
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 40.0  # Default interaction range
	collision.shape = shape
	
	new_area.add_child(collision)
	interaction_area = new_area
	add_child(new_area)
	
	# Connect signals
	new_area.body_entered.connect(_on_interaction_area_body_entered)
	new_area.body_exited.connect(_on_interaction_area_body_exited)
	print("Created new InteractionArea with CircleShape2D")

# Create a missing puzzle area if needed
func _create_puzzle_area():
	var new_area = Area2D.new()
	new_area.name = "PuzzleArea"
	new_area.collision_layer = 4  # Interaction layer
	new_area.collision_mask = 1   # Player layer
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 80.0  # Default puzzle area range
	collision.shape = shape
	
	new_area.add_child(collision)
	puzzle_area = new_area
	add_child(new_area)
	
	# Connect signals
	new_area.body_entered.connect(_on_puzzle_area_body_entered)
	print("Created new PuzzleArea with CircleShape2D")

func connect_to_puzzle():
	# Find all puzzles in the cave
	var stone_puzzle = get_node_or_null("StonePillarPuzzle")
	if stone_puzzle:
		print("Found StonePillarPuzzle, connecting to puzzle_solved signal")
		# Connect to the puzzle_solved signal
		if !stone_puzzle.puzzle_solved.is_connected(_on_puzzle_solved):
			stone_puzzle.puzzle_solved.connect(_on_puzzle_solved)
	else:
		print("No StonePillarPuzzle found in " + location_name)

func _on_puzzle_solved():
	print("Stone Pillar Puzzle was solved!")
	puzzle_solved = true
	# Now reveal the cave entrance
	reveal_location()

func find_player():
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("Player")
	if player_ref:
		print("Player reference found ✓")
	else:
		push_warning("Player not found, will try again in _process...")

func _process(delta):
	# Check if we should reveal based on requirements
	if not is_revealed and puzzle_solved:
		check_reveal_conditions()
	
func check_reveal_conditions():
	if player_ref == null:
		find_player()
		return
	
	# Debug log every few seconds to avoid spamming
	if Engine.get_frames_drawn() % 120 == 0:  # Roughly every 2 seconds at 60 FPS
		print("Checking reveal conditions for " + location_name)
		
		# Check if puzzle was solved
		print("Puzzle solved: " + str(puzzle_solved))
	
	# Only reveal if the puzzle was solved
	if puzzle_solved:
		reveal_location()

func reveal_location():
	if is_revealed:
		return
		
	is_revealed = true
	print(location_name + " is now revealed!")
	
	# Make entrance visible with a nice fade effect
	if entrance_sprite:
		var tween = create_tween()
		tween.tween_property(entrance_sprite, "modulate:a", 1.0, 1.5)
	
	# Enable collision
	if entrance_col:
		entrance_col.disabled = false
	
	print("Hidden location revealed: " + location_name)

func _on_interaction_area_body_entered(body):
	print(location_name + ": Body entered interaction area: " + body.name)
	print("Is in Player group: " + str(body.is_in_group("Player")))
	print("Is location revealed: " + str(is_revealed))
	
	if not body.is_in_group("Player") or not is_revealed:
		return
	
	player_ref = body
	print(location_name + ": Player entered interaction range")
	
	# If this is the first time seeing this location, show clue
	if not has_given_clue:
		emit_signal("show_message", clue_message)
		has_given_clue = true
		print("Showing clue message: " + clue_message)

func _on_interaction_area_body_exited(body):
	if body.is_in_group("Player"):
		print(location_name + ": Player exited interaction range")
		player_ref = null

func _input(event):
	# Only process if player is in range and location is revealed
	if not player_ref or not is_revealed:
		return
	
	# Check for interaction key - with explicit fallback for when InputMap fails
	var interact_pressed = false
	
	# First try using the action
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		interact_pressed = true
		print(location_name + ": Interact action detected")
	
	# Fallback to checking for E key directly
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		interact_pressed = true
		print(location_name + ": E key pressed directly")
	
	if interact_pressed:
		print(location_name + ": Interaction attempted")
		# Explicitly check if player is in the area's bodies to avoid any issues
		var bodies = interaction_area.get_overlapping_bodies()
		var player_in_range = false
		for body in bodies:
			if body == player_ref:
				player_in_range = true
				break
		
		print("Player in interaction range: " + str(player_in_range))
		
		if player_in_range:
			if not is_entered:
				# Check if player has BOTH required items
				if has_required_items():
					print(location_name + ": Entering location")
					enter_location()
				else:
					emit_signal("show_message", "You need both a RuneStone and a StoneAxe to enter the cave.")
					print("Player missing required items to enter")
			elif is_puzzle_active and not is_completed:
				print(location_name + ": Attempting to solve puzzle")
				attempt_solve_puzzle()

# Check if player has both required items
func has_required_items():
	if player_ref:
		return player_ref.has_item(required_item_1) and player_ref.has_item(required_item_2)
	return false

func enter_location():
	if is_entered:
		return
	
	is_entered = true
	is_puzzle_active = true
	
	print(location_name + ": Location entered")
	
	# Show enter message
	emit_signal("show_message", enter_message)
	
	# Emit discovery signal for tracking
	emit_signal("location_discovered", location_id, location_name)
	
	# You could teleport the player inside, change camera, etc.
	# For now we'll just show the puzzle message after a delay
	await get_tree().create_timer(1.5).timeout
	
	if not has_given_puzzle_clue:
		emit_signal("show_message", puzzle_message)
		has_given_puzzle_clue = true
		print("Showing puzzle message: " + puzzle_message)

func _on_puzzle_area_body_entered(body):
	print(location_name + ": Body entered puzzle area: " + body.name)
	print("Is in Player group: " + str(body.is_in_group("Player")))
	print("Is location entered: " + str(is_entered))
	print("Is location completed: " + str(is_completed))
	
	if body.is_in_group("Player") and is_entered and not is_completed:
		# Remind player of the puzzle
		if not has_given_puzzle_clue:
			emit_signal("show_message", puzzle_message)
			has_given_puzzle_clue = true
			print("Showing puzzle message: " + puzzle_message)

func attempt_solve_puzzle():
	if is_completed:
		print(location_name + ": Puzzle already completed")
		return
		
	print(location_name + ": Attempting to solve puzzle")
	
	# Check if player has the required item to solve the puzzle
	if required_puzzle_item != "" and not player_ref.has_item(required_puzzle_item):
		emit_signal("show_message", "You feel like you need a specific item to solve this puzzle...")
		print("Missing required puzzle item: " + required_puzzle_item)
		return
	
	# If there's a required item, consume it for the puzzle
	if required_puzzle_item != "":
		player_ref.remove_from_inventory(required_puzzle_item, 1)
		print("Consumed puzzle item: " + required_puzzle_item)
	
	# Puzzle solved!
	complete_location()

# In hidden_location.gd - modify the complete_location function
func complete_location():
	if is_completed:
		return
		
	is_completed = true
	is_puzzle_active = false
	
	print(location_name + ": Puzzle completed!")
	
	# Show completion message
	emit_signal("show_message", completion_message)
	
	# Reveal reward with a nice effect
	if reward_sprite:
		reward_sprite.visible = true
		reward_sprite.add_to_group("Crystals")  # Add to Crystals group for pickup
		var tween = create_tween()
		tween.tween_property(reward_sprite, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(reward_sprite, "scale", Vector2(1.0, 1.0), 0.2)
		print("Showing reward sprite")
	
	# Give reward after a short delay
	await get_tree().create_timer(2.0).timeout
	# Don't automatically give reward - let player pick it up with T key
	
	# Emit completion signal for tracking
	emit_signal("location_completed", location_id, location_name)

func give_reward():
	if player_ref and reward_item != "":
		var success = player_ref.add_to_inventory(reward_item, reward_amount)
		print("Added reward to inventory: " + reward_item + " x" + str(reward_amount) + " (success: " + str(success) + ")")
		emit_signal("show_message", "You obtained: " + reward_item + " x" + str(reward_amount))
		
		# Add special effects here
		if reward_sprite:
			var tween = create_tween()
			tween.tween_property(reward_sprite, "scale", Vector2(0.1, 0.1), 0.5)
			tween.tween_property(reward_sprite, "modulate:a", 0.0, 0.3)
			tween.tween_callback(func(): reward_sprite.visible = false)

# Add method to force reveal the location for debugging
func debug_reveal():
	print("DEBUG: Force revealing " + location_name)
	puzzle_solved = true
	is_revealed = true
	if entrance_sprite:
		entrance_sprite.modulate.a = 1.0
	if entrance_col:
		entrance_col.disabled = false

# Save/load location state (would need to be integrated with your save system)
func _save_state():
	var save_data = {
		"location_id": location_id,
		"is_revealed": is_revealed,
		"is_entered": is_entered,
		"is_completed": is_completed,
		"has_given_clue": has_given_clue,
		"has_given_puzzle_clue": has_given_puzzle_clue,
		"puzzle_solved": puzzle_solved
	}
	return save_data

func _load_state():
	# Placeholder for loading state from save system
	pass
