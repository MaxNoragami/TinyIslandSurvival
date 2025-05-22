extends Node

# This script will handle all crystal-related operations

func _ready():
	# Do not connect to the T key press event directly - let universal_pickup_helper handle it
	pass

func _input(event):
	# We no longer handle the T key directly here
	# This is to avoid conflicts with universal_pickup_helper.gd
	pass

func handle_crystal_pickup():
	# This function is kept for backward compatibility with any code that might call it
	# But the actual implementation is in universal_pickup_helper.gd
	print("Crystal manager's handle_crystal_pickup called")
	
	# Get player
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
	
	# Get universal pickup helper
	var pickup_helper = get_tree().get_first_node_in_group("PickupHelper")
	if pickup_helper and pickup_helper.has_method("pickup_nearest_item"):
		pickup_helper.pickup_nearest_item()
		return
		
	# Fallback implementation if pickup helper not found
	var crystals = get_tree().get_nodes_in_group("Crystals")
	var closest_crystal = null
	var min_distance = 100.0
	
	for crystal in crystals:
		var distance = crystal.global_position.distance_to(player.global_position)
		if distance < min_distance:
			closest_crystal = crystal
			min_distance = distance
	
	if closest_crystal:
		# Hide the crystal
		closest_crystal.visible = false
		
		# Add to inventory
		if player.has_method("add_to_inventory"):
			player.add_to_inventory("Crystal", 1)
			
		# Remove from scene
		closest_crystal.queue_free()
		
		# Hide any reward sprites in hidden locations
		var locations = get_tree().get_nodes_in_group("HiddenLocations")
		for location in locations:
			var reward_sprite = location.get_node_or_null("RewardSprite")
			if reward_sprite:
				reward_sprite.visible = false
