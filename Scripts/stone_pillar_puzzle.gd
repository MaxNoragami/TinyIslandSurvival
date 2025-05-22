extends PuzzleMechanism
class_name StonePillarPuzzle

# Override puzzle configuration
@export var pillar_count: int = 4
@export var correct_sequence = [0, 2, 1, 3]  # Indices of pillars in correct activation order
@export var reset_if_wrong: bool = true  # Reset the whole puzzle on incorrect selection

# Pillar references
var pillars = []
var activated_pillars = []
var current_index = 0
var center_crystal = null

func _ready():
	super._ready()
	
	# Extend puzzle configuration
	puzzle_id = "stone_pillar_puzzle"
	solution_actions_ordered = true
	
	# Find all pillar nodes
	for i in range(pillar_count):
		var pillar = get_node_or_null("Pillar" + str(i+1))
		if pillar:
			pillars.append(pillar)
			
	# Set up interaction area for each pillar
	for i in range(pillars.size()):
		var area = pillars[i].get_node_or_null("InteractionArea")
		if area:
			# Use a lambda to capture the pillar index
			var pillar_index = i
			area.body_entered.connect(func(body): _on_pillar_area_entered(body, pillar_index))
	
	# Find or create center crystal
	center_crystal = get_node_or_null("Center")
	if not center_crystal:
		create_center_crystal()
	
	# Make sure center is initially hidden
	if center_crystal:
		center_crystal.visible = false

# Create center crystal if missing
func create_center_crystal():
	center_crystal = Sprite2D.new()
	center_crystal.name = "Center"
	
	# Try to load a crystal texture - adjust path as needed
	var texture = load("res://Assets/Icons/16x16.png")
	if texture:
		center_crystal.texture = texture
		center_crystal.region_enabled = true
		center_crystal.region_rect = Rect2(112, 1024, 16, 16)  # Crystal icon from your sprite sheet
	
	center_crystal.scale = Vector2(0.6, 0.6)  # Scaled down to 0.6 (30% of previous 2.0 scale)
	center_crystal.visible = false
	add_child(center_crystal)
	print("Created center crystal for puzzle with scale 0.6")

func get_puzzle_hint():
	return "Ancient stone pillars stand in a circle. They seem to react to your presence."

func _on_pillar_area_entered(body, pillar_index):
	if body.is_in_group("Player") and not is_solved:
		activate_pillar(pillar_index)

func activate_pillar(index):
	if is_solved or index >= pillars.size():
		return
		
	print("StonePillarPuzzle: Activating pillar " + str(index))
	
	# Activate visual effect on this pillar
	var pillar = pillars[index]
	var tween = create_tween()
	tween.tween_property(pillar, "modulate", Color(0, 1, 1), 0.2)
	
	# Add to activated sequence
	activated_pillars.append(index)
	
	# Check if this matches the correct sequence so far
	var is_correct = true
	for i in range(activated_pillars.size()):
		if i >= correct_sequence.size() or activated_pillars[i] != correct_sequence[i]:
			is_correct = false
			break
			
	if is_correct:
		# This is correct so far
		_show_action_feedback(true)
		
		# Update progress
		var progress = float(activated_pillars.size()) / float(correct_sequence.size())
		emit_signal("puzzle_progress_changed", progress)
		
		emit_signal("show_message", "The pillar glows with energy... " + 
		str(activated_pillars.size()) + "/" + str(correct_sequence.size()))
		
		# Check if complete
		if activated_pillars.size() == correct_sequence.size():
			await get_tree().create_timer(0.5).timeout
			solve_puzzle()
	else:
		# Wrong sequence, reset progress
		_show_action_feedback(false)
		emit_signal("show_message", "The energy fades from the pillars...")
		
		# Fade out all pillars
		for p in pillars:
			var fade_tween = create_tween()
			fade_tween.tween_property(p, "modulate", Color(1, 1, 1), 0.3)
		
		if reset_if_wrong:
			activated_pillars.clear()
			emit_signal("puzzle_reset")
		else:
			# Just remove the last incorrect activation
			activated_pillars.pop_back()

func _play_solution_effect():
	# Play a more elaborate effect for solving
	var delays = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
	
	# First flash all pillars
	for i in range(pillars.size()):
		var pillar = pillars[i]
		var tween = create_tween()
		tween.tween_property(pillar, "modulate", Color(1, 1, 0), 0.2)
		tween.tween_property(pillar, "modulate", Color(0, 1, 1), 0.2)
		tween.tween_property(pillar, "modulate", Color(1, 1, 0), 0.2)
		tween.tween_property(pillar, "modulate", Color(1, 1, 1), 0.3)
	
	# Then make crystal appear in the center
	if center_crystal:
		await get_tree().create_timer(1.2).timeout
		center_crystal.visible = true
		
		# Add crystal to the correct groups to ensure it can be properly picked up and removed
		center_crystal.add_to_group("Crystals")
		center_crystal.add_to_group("Pickable")
		
		var center_tween = create_tween()
		center_tween.tween_property(center_crystal, "scale", Vector2(0.9, 0.9), 0.3)  # Grow to 0.9 (30% of previous 3.0)
		center_tween.tween_property(center_crystal, "scale", Vector2(0.6, 0.6), 0.2)  # Settle at 0.6 (30% of previous 2.0)
		
		# Rotate the crystal for a cool effect
		center_tween = create_tween()
		center_tween.tween_property(center_crystal, "rotation", 2 * PI, 1.5)
	
	emit_signal("show_message", "The ancient stones align and a crystal appears in the center!")
	
	# Notify the cave that puzzle was solved
	emit_signal("puzzle_solved")
