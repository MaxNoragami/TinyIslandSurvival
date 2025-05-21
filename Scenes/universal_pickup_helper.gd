extends Node

# Global pickup helper with improved error handling

func _ready():
	print("Universal Pickup Helper ready")
	print("Press T to pickup any nearby item")
	add_to_group("PickupHelper")

func _input(event):
	# T key to pick up the closest item
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		# Only check for is_echo(), not is_handled() which doesn't exist
		if event.is_echo():
			return
			
		pickup_nearest_item()

# Check if an item is a crystal
func is_crystal(item):
	# Check if an item is a crystal
	if item.is_in_group("Crystals"):
		return true
	# Also check name, since some crystals might not be in the group yet
	if "crystal" in item.name.to_lower():
		return true
	return false

func pickup_nearest_item():
	print("Looking for nearby items to pick up...")
	
	# Get tree once and reuse it
	var tree = get_tree()
	
	# Find player once and reuse
	var player = tree.get_first_node_in_group("Player")
	if player == null:
		print("Player not found!")
		return
		
	# Get player position once
	var player_pos = player.global_position
	
	# First check specifically for crystals
	var crystals_group = tree.get_nodes_in_group("Crystals")
	print("Found " + str(crystals_group.size()) + " crystals")
	
	# Check if any crystal is close enough to pick up
	var found_crystal = null
	var found_crystal_distance = 100.0  # Search within 100 pixels
	
	for crystal in crystals_group:
		if crystal.visible:  # Only consider visible crystals
			var distance = crystal.global_position.distance_to(player_pos)
			if distance < found_crystal_distance:
				found_crystal = crystal
				found_crystal_distance = distance
	
	# If we found a crystal nearby, pick it up
	if found_crystal != null:
		print("Found crystal at distance " + str(found_crystal_distance))
		
		# Check if player has the required items before allowing pickup
		if player.has_method("has_item"):
			# Check directly without storing in variables
			if not (player.has_item("StoneAxe") and player.has_item("RuneStone")):
				print("Player missing required items! Cannot pick up Crystal.")
				# Show a message to the player
				var message_system = tree.get_first_node_in_group("MessageDisplay")
				if message_system and message_system.has_method("show_message"):
					message_system.show_message("You need a Stone Axe and a Rune Stone to collect the Crystal.")
				return
				
			# Consume the required items before picking up the crystal
			if player.has_method("remove_from_inventory"):
				var removed_axe = player.remove_from_inventory("StoneAxe", 1)
				var removed_rune = player.remove_from_inventory("RuneStone", 1)
				if removed_axe and removed_rune:
					print("Consumed StoneAxe and RuneStone to pick up Crystal")
				else:
					print("Failed to consume required items")
					return
		
		# IMMEDIATELY hide the crystal before any other processing
		found_crystal.visible = false
		
		# IMPORTANT: Use the PickupComponent if it exists
		var pickup_comp = found_crystal.get_node_or_null("PickupComponent")
		if pickup_comp and pickup_comp.has_method("trigger_pickup"):
			print("Triggering pickup via PickupComponent...")
			pickup_comp.trigger_pickup(player)
			
			# Hide and remove ALL other crystals in the world
			for other_crystal in crystals_group:
				if other_crystal != found_crystal:
					other_crystal.visible = false
					# Make sure to queue_free() to completely remove from scene
					other_crystal.queue_free()
			
			# Also hide reward sprite in hidden locations
			var locations = tree.get_nodes_in_group("HiddenLocations")
			for location in locations:
				var reward_sprite = location.get_node_or_null("RewardSprite")
				if reward_sprite:
					reward_sprite.visible = false
				var reward_sprite2 = location.get_node_or_null("RewardSprite2")
				if reward_sprite2:
					reward_sprite2.visible = false
			
			# Make sure to queue_free the crystal too after a short delay
			# This ensures the pickup component can finish its work first
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(found_crystal):
				found_crystal.queue_free()
				
			return
		else:
			# If no PickupComponent, handle directly
			print("No PickupComponent found, handling directly...")
			
			# Add to inventory
			if player.has_method("add_to_inventory"):
				var success = player.add_to_inventory("Crystal", 1)
				print("Added Crystal to inventory: " + str(success))
			
			# Queue free the crystal
			found_crystal.queue_free()
			
			# Hide and remove any other crystals too
			for other_crystal in crystals_group:
				if other_crystal != found_crystal:
					other_crystal.visible = false
					other_crystal.queue_free()
			
			# Also hide reward sprite in hidden locations
			var locations = tree.get_nodes_in_group("HiddenLocations")
			for location in locations:
				var reward_sprite = location.get_node_or_null("RewardSprite")
				if reward_sprite:
					reward_sprite.visible = false
				var reward_sprite2 = location.get_node_or_null("RewardSprite2")
				if reward_sprite2:
					reward_sprite2.visible = false
			
			return
	
	# If no crystals found, look for other items
	var all_items = []
	
	# Check Pickable group
	var pickable_items = tree.get_nodes_in_group("Pickable")
	
	# Filter out crystals - they're handled separately
	for item in pickable_items:
		if not is_crystal(item):
			all_items.append(item)
			
	# Check RuneStones group specifically
	var runestones = tree.get_nodes_in_group("RuneStones")
	for item in runestones:
		all_items.append(item)
	
	print("Found " + str(all_items.size()) + " potential items")
	
	# Remove duplicates (items may be in multiple groups)
	var unique_items = []
	for item in all_items:
		if not unique_items.has(item):
			unique_items.append(item)
	
	print("Found " + str(unique_items.size()) + " unique items")
	
	# Find closest item
	var closest_item = null
	var closest_distance = 100.0  # Search within 100 pixels
	
	for item in unique_items:
		var distance = item.global_position.distance_to(player_pos)
		if distance < closest_distance:
			closest_item = item
			closest_distance = distance
			
	if closest_item != null:
		print("Found closest item: " + closest_item.name + " at distance " + str(closest_distance))
		
		# Try different methods to pick up the item
		
		# Method 1: Try PickupComponent
		var pickup_comp = closest_item.get_node_or_null("PickupComponent")
		if pickup_comp and pickup_comp.has_method("trigger_pickup"):
			print("Triggering pickup via PickupComponent...")
			pickup_comp.trigger_pickup(player)
			return
			
		# Method 2: Try direct pickup method
		if closest_item.has_method("pickup") or closest_item.has_method("collect"):
			print("Triggering direct pickup method...")
			if closest_item.has_method("pickup"):
				closest_item.pickup(player)
			elif closest_item.has_method("collect"):
				closest_item.collect(player)
			return
			
		# Method 3: Add item directly to inventory as last resort
		print("No pickup method found, trying direct inventory addition...")
		if player.has_method("add_to_inventory"):
			# Try to guess the item name
			var item_name = "Unknown"
			
			# Check if item has a name property or method
			if closest_item.has_method("get_item_name"):
				item_name = closest_item.get_item_name()
			elif closest_item.has_meta("item_name"):
				item_name = closest_item.get_meta("item_name")
			elif "resource_name" in closest_item:
				item_name = closest_item.resource_name
			elif closest_item.is_in_group("RuneStones"):
				item_name = "RuneStone"
			
			print("Adding " + item_name + " to inventory directly")
			var success = player.add_to_inventory(item_name, 1)
			
			if success:
				# Remove the item from the scene
				closest_item.queue_free()
				print("Item added to inventory and removed from scene")
			else:
				print("Failed to add item to inventory")
		else:
			print("Player has no add_to_inventory method!")
	else:
		print("No items found within range")
