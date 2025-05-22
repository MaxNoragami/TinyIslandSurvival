extends Node2D

func _ready():
	add_to_group("Crystals")
	add_to_group("Pickable")
	print("Crystal with simplified script ready")
	
	# Set up visual effect
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		# Add a glow effect to the crystal
		sprite.modulate = Color(1.2, 1.2, 1.4)  # Slight blue-white glow
	
	# Make sure there's a PickupComponent
	var pickup = get_node_or_null("PickupComponent")
	if pickup:
		pickup.item_name = "Crystal"
		pickup.auto_pickup = false  # Require T key press
		pickup.can_be_picked_up = true
		
		# Connect to the item_picked_up signal to handle post-pickup cleanup
		if pickup.has_signal("item_picked_up"):
			pickup.item_picked_up.connect(_on_item_picked_up)
			
		print("Setup PickupComponent for Crystal")
	else:
		add_pickup_component()

func add_pickup_component():
	var pickup = Node.new()
	pickup.name = "PickupComponent"
	
	# Try to load the script
	var script = load("res://Scripts/pickup_component.gd")
	if script:
		pickup.set_script(script)
		add_child(pickup)
		
		# Configure it
		pickup.item_name = "Crystal"
		pickup.auto_pickup = false  # Require T key press
		pickup.can_be_picked_up = true
		
		# Connect to the item_picked_up signal
		if pickup.has_signal("item_picked_up"):
			pickup.item_picked_up.connect(_on_item_picked_up)
		
		print("Added PickupComponent to Crystal")
	else:
		push_error("Could not load pickup_component.gd script")

# Add shimmer effect
func _process(delta):
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		# Create a subtle shimmer effect
		var shimmer = 0.1 * sin(Time.get_ticks_msec() * 0.003)
		sprite.modulate = Color(1.0 + shimmer, 1.0 + shimmer, 1.2 + shimmer)

func _input(event):
	# T key will trigger pickup for testing
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		print("Crystal: Manual pickup triggered (T key)")
		
		var player = get_tree().get_first_node_in_group("Player")
		if not player:
			print("Player not found for manual pickup")
			return
			
		# Check if player has the required items without redeclaring variables
		if player.has_method("has_item"):
			# Direct check without storing in variables
			if not (player.has_item("StoneAxe") and player.has_item("RuneStone")):
				print("Player missing required items! Cannot pick up Crystal.")
				# Show a message to the player
				var message_system = get_tree().get_first_node_in_group("MessageDisplay")
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
		
		var pickup = get_node_or_null("PickupComponent")
		if pickup and pickup.has_method("trigger_pickup"):
			# Immediately hide the crystal when pickup is triggered
			visible = false
			
			pickup.trigger_pickup(player)
			print("Manually triggered Crystal pickup")
		else:
			print("PickupComponent not found or missing trigger_pickup method")

# Handle post-pickup cleanup
func _on_item_picked_up(item_data):
	print("Crystal picked up, cleaning up...")
	
	# Hide this crystal
	visible = false
	
	# Hide all other crystals too
	var all_crystals = get_tree().get_nodes_in_group("Crystals")
	for crystal in all_crystals:
		if crystal != self:
			crystal.visible = false
	
	# Hide reward sprites in hidden locations
	var locations = get_tree().get_nodes_in_group("HiddenLocations")
	for location in locations:
		var reward_sprite = location.get_node_or_null("RewardSprite")
		if reward_sprite:
			reward_sprite.visible = false
		
		var reward_sprite2 = location.get_node_or_null("RewardSprite2")
		if reward_sprite2:
			reward_sprite2.visible = false
	
	# Complete the crystal cave if it exists
	var debug_helper = get_tree().get_first_node_in_group("DebugHelper")
	if debug_helper and debug_helper.has_method("complete_crystal_cave"):
		debug_helper.complete_crystal_cave()
