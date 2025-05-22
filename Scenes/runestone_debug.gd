extends Area2D

func _ready():
	# Set collision properties
	collision_layer = 4
	collision_mask = 1
	
	# Connect signal
	body_entered.connect(_on_body_entered)
	
	print("RuneStone ready at position: ", global_position)

func _on_body_entered(body):
	print("Body entered RuneStone collision: ", body.name)
	print("Body is in group Player: ", body.is_in_group("Player"))
	print("Body has method add_to_inventory: ", body.has_method("add_to_inventory"))
	
	# Check if this is actually the player
	if body.is_in_group("Player"):
		print("Player found RuneStone!")
		
		# Try different ways to interact with the player
		if body.has_method("add_to_inventory"):
			body.add_to_inventory("RuneStone", 1)
			print("Added RuneStone to inventory directly")
		
		# Show debug in console for clue system
		var clue_system = get_tree().get_first_node_in_group("ClueSystem")
		print("ClueSystem found: ", clue_system != null)
		if clue_system:
			print("ClueSystem has method give_hint_for_location: ", 	
			clue_system.has_method("give_hint_for_location"))
			
			if clue_system.has_method("give_hint_for_location"):
				clue_system.give_hint_for_location("cave_1")
				print("Called give_hint_for_location")
		
		# Skip message display for now, since it's causing issues
		
		# Remove the RuneStone
		print("Removing RuneStone from scene")
		queue_free()
