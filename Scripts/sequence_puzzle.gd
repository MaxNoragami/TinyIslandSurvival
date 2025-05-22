extends PuzzleMechanism
class_name SequencePuzzle

# The sequence to input
@export var correct_sequence = ["up", "up", "down", "left", "right", "action"]
@export var display_input_feedback: bool = true
@export var feedback_duration: float = 0.5
@export var max_sequence_length: int = 10  # Prevent too many inputs

# State tracking
var input_sequence = []
var feedback_sprites = []
var feedback_container = null

func _ready():
	super._ready()
	
	# Set puzzle properties
	puzzle_id = "sequence_puzzle"
	
	# Find feedback container if display_input_feedback is enabled
	if display_input_feedback:
		feedback_container = get_node_or_null("FeedbackContainer")
		
		# Create feedback sprites if container exists
		if feedback_container:
			for i in range(correct_sequence.size()):
				var sprite = Sprite2D.new()
				sprite.texture = preload("res://Assets/Icons/16x16.png")  # Use your own texture
				sprite.region_enabled = true
				sprite.region_rect = Rect2(16, 16, 16, 16)  # Default empty square
				sprite.position = Vector2(i * 20, 0)  # Space them out
				sprite.modulate.a = 0.5  # Semi-transparent
				feedback_container.add_child(sprite)
				feedback_sprites.append(sprite)

func _input(event):
	if not puzzle_active or is_solved:
		return
		
	# Prevent too many inputs
	if input_sequence.size() >= max_sequence_length:
		return
		
	# Track directional inputs
	var input_type = ""
	if event.is_action_pressed("move_up"):
		input_type = "up"
	elif event.is_action_pressed("move_down"):
		input_type = "down"
	elif event.is_action_pressed("move_left"):
		input_type = "left"
	elif event.is_action_pressed("move_right"):
		input_type = "right"
	elif event.is_action_pressed("item_action"):
		input_type = "action"
		
	# If we have a valid input, process it
	if input_type != "":
		input_sequence.append(input_type)
		_show_input_feedback(input_type, input_sequence.size() - 1)
		check_sequence()

func check_sequence():
	# Check if current sequence matches the correct sequence so far
	var is_correct = true
	for i in range(input_sequence.size()):
		if i >= correct_sequence.size() or input_sequence[i] != correct_sequence[i]:
			is_correct = false
			break
			
	if is_correct:
		# Still correct so far
		_show_action_feedback(true)
		
		# Update progress
		var progress = float(input_sequence.size()) / float(correct_sequence.size())
		emit_signal("puzzle_progress_changed", progress)
		
		# Check if complete
		if input_sequence.size() == correct_sequence.size():
			await get_tree().create_timer(0.5).timeout
			solve_puzzle()
	else:
		# Wrong sequence
		_show_action_feedback(false)
		emit_signal("show_message", "That's not right... Try again.")
		
		# Show incorrect feedback briefly before resetting
		if display_input_feedback and feedback_container:
			await get_tree().create_timer(feedback_duration).timeout
		
		input_sequence.clear()
		_clear_feedback_sprites()
		emit_signal("puzzle_reset")

func _show_input_feedback(input_type, index):
	if not display_input_feedback or not feedback_container or index >= feedback_sprites.size():
		return
		
	var sprite = feedback_sprites[index]
	
	# Set region based on input type
	match input_type:
		"up":
			sprite.region_rect = Rect2(48, 16, 16, 16)  # Up arrow icon
		"down":
			sprite.region_rect = Rect2(64, 16, 16, 16)  # Down arrow icon
		"left":
			sprite.region_rect = Rect2(80, 16, 16, 16)  # Left arrow icon
		"right":
			sprite.region_rect = Rect2(96, 16, 16, 16)  # Right arrow icon
		"action":
			sprite.region_rect = Rect2(112, 16, 16, 16)  # Action icon
	
	# Make fully visible
	sprite.modulate.a = 1.0

func _clear_feedback_sprites():
	if not display_input_feedback or not feedback_container:
		return
		
	for sprite in feedback_sprites:
		sprite.region_rect = Rect2(16, 16, 16, 16)  # Empty square
		sprite.modulate.a = 0.5  # Semi-transparent

func get_puzzle_hint():
	return "There seems to be a specific pattern needed..."

func _play_solution_effect():
	# Play a successful animation
	
	# First, flash the feedback sprites if we have them
	if display_input_feedback and feedback_container:
		for sprite in feedback_sprites:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(0, 1, 0, 1.0), 0.2)
			tween.tween_property(sprite, "modulate", Color(1, 1, 0, 1.0), 0.2)
	
	# Then show reward effect
	var reward = get_node_or_null("Reward")
	if reward:
		await get_tree().create_timer(0.8).timeout
		reward.visible = true
		var reward_tween = create_tween()
		reward_tween.tween_property(reward, "scale", Vector2(1.5, 1.5), 0.3)
		reward_tween.tween_property(reward, "scale", Vector2(1.0, 1.0), 0.2)
	
	emit_signal("show_message", "Success! The mechanism unlocks!")
