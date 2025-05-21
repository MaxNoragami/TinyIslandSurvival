extends Node

# This is a simpler version of the debug helper that should avoid null reference errors

func _ready():
	add_to_group("DebugHelper")
	print("Simple DebugHelper initialized")
	print("DEBUG KEYS:")
	print("- 1: Force RuneStone to appear in inventory")
	print("- 2: Toggle time between day and night")
	print("- 3: Fix Crystal Cave")
	print("- F: Fix Crystal Cave interaction range")
	print("- G: Create and add Crystal directly to inventory")
	print("- T: Force spawn Crystal for T-key pickup")
	print("- X: Fix inventory display")
	print("- P: Fix all puzzles")
	
	# No immediate system check that could cause errors

func _input(event):
	# Simpler debug keys with safer implementations
	if event is InputEventKey and event.pressed:
		# 1: Force RuneStone to inventory
		if event.keycode == KEY_1:
			force_add_runestone()
			
		# 2: Toggle time
		elif event.keycode == KEY_2:
			toggle_time()
			
		# 3: Fix Crystal Cave
		elif event.keycode == KEY_3:
			fix_crystal_cave()
			
		# F: Fix Crystal Cave interaction
		elif event.keycode == KEY_F:
			fix_crystal_cave_interaction()
			
		# G: Give Crystal reward directly
		elif event.keycode == KEY_G:
			add_crystal_directly()
			
		# T: Force spawn Crystal for T key pickup
		elif event.keycode == KEY_T:
			spawn_physical_crystal()
			
		# X: Fix inventory display
		elif event.keycode == KEY_X:
			fix_inventory_display()
			
		# P: Fix all puzzles
		elif event.keycode == KEY_P:
			fix_all_puzzles()

func force_add_runestone():
	print("Adding RuneStone to inventory...")
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("add_to_inventory"):
		var success = player.add_to_inventory("RuneStone", 1)
		print("RuneStone added to inventory: " + str(success))
	else:
		print("Could not find player or player doesn't have add_to_inventory method")

func toggle_time():
	print("Toggling time of day...")
	var time_system = get_tree().get_first_node_in_group("TimeSystem")
	if time_system and time_system.has_method("set_time_of_day"):
		var current_time = time_system.current_time_of_day
		var new_time = "Night" if current_time != "Night" else "Day"
		time_system.set_time_of_day(new_time)
		print("Time changed to: " + new_time)
	else:
		print("Could not find TimeSystem or it doesn't have set_time_of_day method")

func fix_crystal_cave():
	print("Fixing Crystal Cave...")
	var cave = get_tree().get_first_node_in_group("HiddenLocations")
	if cave:
		# Force reveal the cave
		print("Revealing cave...")
		if cave.has_method("debug_reveal"):
			cave.debug_reveal()
		cave.is_revealed = true
		
		# Fix interaction area safely
		var interaction_area = cave.get_node_or_null("InteractionArea")
		if interaction_area and interaction_area is Area2D:
			print("Enlarging existing InteractionArea...")
			var shape = interaction_area.get_node_or_null("CollisionShape2D")
			if shape and shape.shape is CircleShape2D:
				shape.shape.radius = 150.0
				print("Increased collision radius to 150")
			else:
				create_collision_shape(interaction_area)
		else:
			print("Creating new InteractionArea...")
			create_interaction_area(cave)
	else:
		print("Could not find Crystal Cave!")

func create_interaction_area(parent):
	var area = Area2D.new()
	area.name = "InteractionArea"
	area.collision_layer = 4
	area.collision_mask = 1
	parent.add_child(area)
	create_collision_shape(area)
	
	# Connect signals safely
	if parent.has_method("_on_interaction_area_body_entered"):
		area.body_entered.connect(parent._on_interaction_area_body_entered)
	if parent.has_method("_on_interaction_area_body_exited"):
		area.body_exited.connect(parent._on_interaction_area_body_exited)
	
	print("Created new InteractionArea with large radius")

func create_collision_shape(parent):
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 150.0  # Very large radius to ensure interaction
	collision.shape = shape
	parent.add_child(collision)
	print("Created CollisionShape2D with radius 150")

# Add crystal directly to inventory
func add_crystal_directly():
	print("Adding Crystal directly to inventory...")
	# Get player
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		print("Player not found!")
		return
		
	# Check if player already has a crystal
	if player.has_method("has_item") and player.has_item("Crystal"):
		print("Player already has a Crystal!")
		return
		
	# Check if player has the required items
	if player.has_method("has_item"):
		# Check requirements directly
		if not (player.has_item("StoneAxe") and player.has_item("RuneStone")):
			print("Player missing required items! Cannot add Crystal.")
			# Show a message to the player
			var message_system = get_tree().get_first_node_in_group("MessageDisplay")
			if message_system and message_system.has_method("show_message"):
				message_system.show_message("You need a Stone Axe and a Rune Stone to collect the Crystal.")
			return
		
		print("Player has StoneAxe and RuneStone")
	
	# Consume required items
	if player.has_method("remove_from_inventory"):
		var removed_axe = player.remove_from_inventory("StoneAxe", 1)
		var removed_rune = player.remove_from_inventory("RuneStone", 1)
		print("Consumed StoneAxe: " + str(removed_axe) + ", RuneStone: " + str(removed_rune))
		
		if not (removed_axe and removed_rune):
			print("Failed to consume required items!")
			return
	
	# Fix inventory display first so Crystal is properly configured
	fix_inventory_display()
	
	# Add Crystal to inventory
	if player.has_method("add_to_inventory"):
		var success = player.add_to_inventory("Crystal", 1)
		print("Added Crystal directly to inventory: " + str(success))
		
		# Mark cave as completed
		complete_crystal_cave()
	else:
		print("Player has no add_to_inventory method!")

# Spawn physical crystal for T key pickup
func spawn_physical_crystal():
	print("Spawning physical crystal for T key pickup...")
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		print("Player not found!")
		return
	
	# If player already has a crystal, don't spawn another one
	if player.has_method("has_item") and player.has_item("Crystal"):
		print("Player already has a Crystal, not spawning another one")
		return
	
	# Check if any crystal is already in the scene - this is key for preventing duplicates
	var existing_crystals = get_tree().get_nodes_in_group("Crystals")
	if existing_crystals.size() > 0:
		print("Crystal already exists in the world, not spawning another one")
		# Make sure existing crystals are visible
		for crystal in existing_crystals:
			crystal.visible = true
		return
	
	# Check if player has the required items
	if player.has_method("has_item"):
		# Check directly without storing in variables
		if not (player.has_item("StoneAxe") and player.has_item("RuneStone")):
			print("Player missing required items! Cannot spawn Crystal.")
			# Show a message to the player
			var message_system = get_tree().get_first_node_in_group("MessageDisplay")
			if message_system and message_system.has_method("show_message"):
				message_system.show_message("You need a Stone Axe and a Rune Stone to collect the Crystal.")
			return
	
	# First remove any existing crystals to avoid duplicates
	remove_existing_crystals()
	
	# Remove any original reward crystal
	var cave = get_tree().get_first_node_in_group("HiddenLocations")
	if cave:
		var reward_sprite = cave.get_node_or_null("RewardSprite")
		if reward_sprite:
			reward_sprite.visible = false
	
	# Fix inventory display first so Crystal is properly configured
	fix_inventory_display()
	
	# NOTE: Do NOT consume items here. Items will be consumed when the player picks up
	# the crystal using the T key. This allows the player to see that the items are consumed
	# at the moment of pickup.
	
	# Create crystal at player location
	var crystal = Node2D.new()
	crystal.name = "Crystal"
	crystal.position = player.position + Vector2(30, 0)
	
	# Add to Pickable and Crystal groups
	crystal.add_to_group("Pickable")
	crystal.add_to_group("Crystals")
	
	# Add sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	var texture = load("res://Assets/Outdoor decoration/crystal.png")
	if not texture:
		# Fallback to the icon texture if the crystal texture fails to load
		texture = load("res://Assets/Icons/16x16.png")
		if texture:
			sprite.texture = texture
			sprite.region_enabled = true
			sprite.region_rect = Rect2(112, 1024, 16, 16)
			sprite.scale = Vector2(0.05, 0.05)
			print("Using fallback texture for Crystal with scale 0.05")
	else:
		sprite.texture = texture
		sprite.scale = Vector2(0.05, 0.05)
		print("Using crystal.png texture with scale 0.05")
		
	crystal.add_child(sprite)
	
	# Add crystal script to handle T key properly
	var script = load("res://Scripts/crystal.gd")
	if script:
		crystal.set_script(script)
	else:
		# Fallback to simplified embedded script
		script = GDScript.new()
		script.source_code = """
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
		pickup.auto_pickup = false
		pickup.can_be_picked_up = true
		print("Setup PickupComponent for Crystal")

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
			
		# Check if player has the required items
		if player.has_method("has_item"):
			if not (player.has_item("StoneAxe") and player.has_item("RuneStone")):
				print("Player missing required items! Cannot pick up Crystal.")
				# Show a message to the player
				var message_system = get_tree().get_first_node_in_group("MessageDisplay")
				if message_system and message_system.has_method("show_message"):
					message_system.show_message("You need a Stone Axe and a Rune Stone to collect the Crystal.")
				return
				
			# Consume the required items before picking up the crystal
			if player.has_method("remove_from_inventory"):
				player.remove_from_inventory("StoneAxe", 1)
				player.remove_from_inventory("RuneStone", 1)
				print("Consumed StoneAxe and RuneStone to pick up Crystal")
		
		var pickup = get_node_or_null("PickupComponent")
		if pickup and pickup.has_method("trigger_pickup"):
			# Immediately hide the crystal when pickup is triggered
			visible = false
			
			pickup.trigger_pickup(player)
			print("Manually triggered Crystal pickup")
		else:
			print("PickupComponent not found or missing trigger_pickup method")
"""
		script.reload()
		crystal.set_script(script)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	crystal.add_child(collision)
	
	# Add a pickup component for the T key functionality
	var pickup = Node.new()
	pickup.name = "PickupComponent"
	var pickup_script = load("res://Scripts/pickup_component.gd")
	if pickup_script:
		pickup.set_script(pickup_script)
		crystal.add_child(pickup)
		
		# Configure pickup component
		pickup.item_name = "Crystal"
		pickup.item_quantity = 1
		pickup.auto_pickup = false
		pickup.can_be_picked_up = true
		
		print("Configured crystal pickup component without auto pickup")
	else:
		print("ERROR: Could not load pickup_component script!")
	
	# Add to world
	player.get_parent().add_child(crystal)
	
	print("Created physical crystal at position: " + str(crystal.position))
	print("Press T near crystal to pick it up")

# Remove any existing crystal objects
func remove_existing_crystals():
	print("Removing any existing crystal objects...")
	var crystals = get_tree().get_nodes_in_group("Crystals")
	for crystal in crystals:
		if is_instance_valid(crystal) and crystal.is_inside_tree():
			# First remove from tree, then queue_free for immediate effect
			var parent = crystal.get_parent()
			if parent:
				parent.remove_child(crystal)
			crystal.queue_free()
	print("Removed " + str(crystals.size()) + " existing crystals")
	
	# Also hide any reward sprites in hidden locations
	var location = get_tree().get_first_node_in_group("HiddenLocations")
	if location:
		var reward_sprite = location.get_node_or_null("RewardSprite")
		if reward_sprite:
			reward_sprite.visible = false
		var reward_sprite2 = location.get_node_or_null("RewardSprite2")
		if reward_sprite2:
			reward_sprite2.visible = false

# Fix inventory display issues
func fix_inventory_display():
	print("Fixing all inventory displays...")
	
	# Fix crystal display in inventory
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui:
		# Fix the resource_data dictionary
		print("Updating inventory resource_data...")
		
		# Update Crystal entry with correct texture and scale
		if "resource_data" in inventory_ui:
			inventory_ui.resource_data["Crystal"] = {
				"texture": "res://Assets/Outdoor decoration/crystal.png",
				"scale": Vector2(0.03, 0.03),  # Use 0.03 as requested for inventory
				"use_region": false
			}
			
			# Fallback in case the file doesn't exist
			var texture = load("res://Assets/Outdoor decoration/crystal.png")
			if not texture:
				inventory_ui.resource_data["Crystal"] = {
					"texture": "res://Assets/Icons/16x16.png",
					"region": Rect2(112, 1024, 16, 16),
					"scale": Vector2(0.03, 0.03),  # Use 0.03 as requested for inventory
					"use_region": true
				}
				print("Using fallback texture for Crystal in inventory with scale 0.03")
			
			# Force refresh
			if inventory_ui.has_method("_update_inventory_display"):
				inventory_ui._update_inventory_display()
				print("Fixed Crystal display in inventory")
		else:
			print("Could not access resource_data in inventory_ui!")
	else:
		print("Could not find InventoryUI!")

func fix_crystal_cave_interaction():
	print("Fixing Crystal Cave interaction...")
	var cave = get_tree().get_first_node_in_group("HiddenLocations")
	
	if cave:
		# Get the interaction area
		var interaction_area = cave.get_node_or_null("InteractionArea")
		
		if interaction_area and interaction_area is Area2D:
			# Get the collision shape
			var shape = interaction_area.get_node_or_null("CollisionShape2D")
			
			if shape and shape.shape is CircleShape2D:
				# Significantly increase the interaction radius
				shape.shape.radius = 250.0
				print("Increased interaction radius to 250 units")
				
				# Make sure it's enabled
				shape.disabled = false
				
				# Ensure proper collision settings
				interaction_area.collision_layer = 4  # Interaction layer
				interaction_area.collision_mask = 1   # Player layer
				
				print("Fixed interaction area settings")
			else:
				print("CollisionShape2D not found or not a CircleShape2D")
				create_collision_shape(interaction_area)
		else:
			print("InteractionArea not found or not an Area2D")
			create_interaction_area(cave)
			
		# Also fix the puzzle area
		var puzzle_area = cave.get_node_or_null("PuzzleArea")
		if puzzle_area and puzzle_area is Area2D:
			var shape = puzzle_area.get_node_or_null("CollisionShape2D")
			if shape and shape.shape is CircleShape2D:
				shape.shape.radius = 250.0
				shape.disabled = false
				print("Fixed PuzzleArea collision radius")
				
		# Make sure the entrance is visible
		var entrance_sprite = cave.get_node_or_null("EntranceSprite")
		if entrance_sprite:
			entrance_sprite.modulate.a = 1.0
			print("Made entrance sprite fully visible")
			
		# And enable collision
		var entrance_col = cave.get_node_or_null("EntranceCollision")
		if entrance_col:
			entrance_col.disabled = false
			print("Enabled entrance collision")
			
		# Make sure the cave is entered
		cave.is_revealed = true
		if !cave.is_entered:
			print("Forcing cave to entered state")
			if cave.has_method("enter_location"):
				cave.call_deferred("enter_location")
	else:
		print("Crystal Cave not found!")

# Force complete the crystal cave
func complete_crystal_cave():
	print("Marking Crystal Cave as completed...")
	var cave = get_tree().get_first_node_in_group("HiddenLocations")
	if cave and cave.has_method("complete_location") and !cave.is_completed:
		cave.call_deferred("complete_location")
		print("Cave completion triggered")
	
	# Also notify the HiddenLocationManager
	var manager = get_tree().get_first_node_in_group("HiddenLocationManager")
	if manager:
		if "completed_locations" in manager and not manager.completed_locations.has("cave_1"):
			manager.completed_locations.append("cave_1")
			if manager.has_signal("location_completed"):
				manager.emit_signal("location_completed", "cave_1", "Crystal Cave")
			print("Updated HiddenLocationManager completion status")

func fix_all_puzzles():
	print("Fixing all puzzle mechanisms...")
	
	var puzzles = get_tree().get_nodes_in_group("Puzzles")
	for puzzle in puzzles:
		print("Found puzzle: " + puzzle.name)
		
		# Check and fix interaction area
		var interaction_area = puzzle.get_node_or_null("InteractionArea")
		if not interaction_area or not (interaction_area is Area2D):
			print("Creating InteractionArea for " + puzzle.name)
			interaction_area = Area2D.new()
			interaction_area.name = "InteractionArea"
			interaction_area.collision_layer = 4
			interaction_area.collision_mask = 1
			puzzle.add_child(interaction_area)
			
			# Add collision shape
			var collision = CollisionShape2D.new()
			collision.name = "CollisionShape2D"
			var shape = CircleShape2D.new()
			shape.radius = 120.0  # Extra large radius
			collision.shape = shape
			interaction_area.add_child(collision)
			
			# Connect signals
			if puzzle.has_method("_on_interaction_area_body_entered"):
				interaction_area.body_entered.connect(puzzle._on_interaction_area_body_entered)
			if puzzle.has_method("_on_interaction_area_body_exited"):
				interaction_area.body_exited.connect(puzzle._on_interaction_area_body_exited)
		else:
			# Fix existing interaction area
			var shape = interaction_area.get_node_or_null("CollisionShape2D")
			if shape and shape.shape is CircleShape2D:
				shape.shape.radius = 120.0  # Extra large radius
				shape.disabled = false
				print("Fixed CollisionShape2D for " + puzzle.name)
		
		# If it's the stone pillar puzzle, fix all pillar interaction areas too
		if puzzle.name == "StonePillarPuzzle" or "StonePillar" in puzzle.name:
			for i in range(1, 5):  # Assumes 4 pillars
				var pillar = puzzle.get_node_or_null("Pillar" + str(i))
				if pillar:
					var pillar_area = pillar.get_node_or_null("InteractionArea")
					if pillar_area and pillar_area is Area2D:
						var pillar_shape = pillar_area.get_node_or_null("CollisionShape2D")
						if pillar_shape and pillar_shape.shape is CircleShape2D:
							pillar_shape.shape.radius = 60.0  # Large radius for pillars
							pillar_shape.disabled = false
							print("Fixed Pillar" + str(i) + " collision radius")
	
	print("All puzzles fixed!")
