extends CharacterBody2D

signal inventory_updated

@export var move_speed: float = 100.0

# Preload the InventoryComponent script
const InventoryComponentScript = preload("res://Scripts/inventory_component.gd")

# Component references
var health_component
var hitbox_component
var state_machine
var sprite
var inventory_component
var action_hitbox

# Last direction for animation purposes
var facing_direction = "front"
var last_animation = ""

# Action state
var is_performing_action = false
var action_timer = 0.0
var action_duration = 0.6  # Duration of action animations in seconds
var action_cooldown = 0.0  # Cooldown for repeating actions like chopping

func _ready():
	# Add self to Player group
	add_to_group("Player")
	
	# Get references to components
	health_component = $HealthComponent if has_node("HealthComponent") else null
	hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
	sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
	action_hitbox = $ActionHitbox if has_node("ActionHitbox") else null
	
	# Initialize action hitbox if it exists
	if action_hitbox:
		action_hitbox.monitoring = false  # Disable until needed
		
		# Make sure it has a CollisionShape2D
		var shape = action_hitbox.get_node_or_null("CollisionShape2D")
		if shape:
			shape.disabled = true
			
		# Connect to area detection signal
		if action_hitbox.has_signal("area_entered"):
			action_hitbox.area_entered.connect(_on_action_hitbox_area_entered)

	# Create or get inventory component
	inventory_component = $InventoryComponent if has_node("InventoryComponent") else null
	if !inventory_component:
		# Create a new instance of InventoryComponent using the preloaded script
		inventory_component = InventoryComponentScript.new()
		inventory_component.name = "InventoryComponent"
		add_child(inventory_component)
		print("DEBUG: Created new InventoryComponent for player")
	
	# Connect inventory component's signal to forward it
	if inventory_component:
		inventory_component.inventory_updated.connect(_on_inventory_updated)
	
	# Get state machine
	state_machine = $StateMachine if has_node("StateMachine") else null
	print("Player: StateMachine reference found? ", state_machine != null)
	
	# Initialize state machine with explicit self reference
	if state_machine:
		# Make sure to pass self explicitly
		state_machine.initialize(self)
	else:
		push_error("StateMachine not found on Player - make sure to add it as a child node")
	
	# Set up collision mask to detect pickups (Layer 3)
	collision_mask |= 4  # Add Layer 3 (pickup layer) to collision mask

func _physics_process(delta):
	# Handle cooldown timer
	if action_cooldown > 0:
		action_cooldown -= delta
	
	# Handle action timing
	if is_performing_action:
		action_timer += delta
		if action_timer >= action_duration:
			is_performing_action = false
			action_timer = 0.0
			# Disable the action hitbox when action is completed
			if action_hitbox:
				action_hitbox.monitoring = false
				var shape = action_hitbox.get_node_or_null("CollisionShape2D")
				if shape:
					shape.disabled = true
			# Return to previous animation state
			if state_machine and state_machine.current_state:
				var state_name = state_machine.current_state.name.to_lower()
				if state_name.begins_with("idle"):
					play_animation("idle")
				elif state_name.begins_with("move"):
					play_animation("walk")
	
	# Let the state machine handle most of the logic if not performing an action
	if state_machine != null and not is_performing_action:
		# State machine handles movement
		pass
	elif state_machine == null and not is_performing_action:
		# Fallback if no state machine is present
		handle_movement()

func _input(event):
	# Handle tool actions (like axe) - Add this to fix the axe functionality
	if event.is_action_pressed("item_action") and not is_performing_action and action_cooldown <= 0:
		var equipped_item = get_equipped_item()
		if equipped_item == "StoneAxe":
			perform_action_with_item(equipped_item)
			return  # Stop processing after performing action
	
	# TESTING KEYS FOR CRYSTAL CAVE
	# IMPORTANT: Change this to use F1 instead of Space to avoid conflict
	# This is the core fix - using a different key for testing
	if event.is_action_pressed("ui_home"):  # F1 key instead of Space (ui_accept)
		print("DEBUG: ALL-IN-ONE CRYSTAL CAVE TEST")
		
		# 1. Add RuneStone to inventory
		add_to_inventory("RuneStone", 1)
		print("Added RuneStone to inventory")
		
		# 2. Add StoneAxe to inventory 
		add_to_inventory("StoneAxe", 1)
		print("Added StoneAxe to inventory")
		
		# 3. Notify ClueSystem
		var clue_system = get_tree().get_first_node_in_group("ClueSystem")
		if clue_system:
			print("Found ClueSystem, adding clue")
			if clue_system.has_method("give_hint_for_location"):
				clue_system.give_hint_for_location("cave_1")
				print("Gave hint for cave_1")
		
		# 4. Set time to night
		var time_system = get_tree().get_first_node_in_group("TimeSystem")
		if time_system:
			print("Found TimeSystem, setting to night")
			if time_system.has_method("set_time_of_day"):
				time_system.set_time_of_day("Night")
				print("Set time to Night")
		
		# 5. Show message
		var message_system = get_tree().get_first_node_in_group("MessageDisplay")
		if message_system and message_system.has_method("show_message"):
			message_system.show_message("ALL-IN-ONE TEST: Crystal Cave should now be visible!")

# Get the currently equipped item from the equip slot
func get_equipped_item():
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and inventory_ui.equip_slot:
		# Check if the equip slot is toggled (selected)
		var button = inventory_ui.equip_slot.get_node_or_null("Button")
		if not button or not button.button_pressed:
			return ""  # Equip slot is not toggled on
			
		var sprite = inventory_ui.equip_slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
		if sprite and sprite.texture:
			# Check if the currently equipped item is a Stone Axe
			var region_rect = sprite.region_rect
			# Match the StoneAxe region rect in the resource_data
			if region_rect.position.x == 240 and region_rect.position.y == 1456:
				return "StoneAxe"
	return ""

# Perform an action with the equipped item
func perform_action_with_item(item_name):
	if is_performing_action:
		return  # Already performing an action
		
	if item_name == "StoneAxe":
		# Play appropriate axe animation based on facing direction
		is_performing_action = true
		action_timer = 0.0
		action_cooldown = 0.2  # Add a slight cooldown to prevent spamming
		
		# Position and enable the action hitbox
		position_action_hitbox()
		
		var animation_name = "axe_" + facing_direction
		if sprite:
			sprite.play(animation_name)
			print("Playing animation: ", animation_name)
			
		# Add direct tree detection for better hit detection
		do_direct_action_check(item_name)

# New function to directly check for objects in front of the player
func do_direct_action_check(item_name):
	var hit_distance = 24.0  # Distance to check in front of player
	var hit_position = global_position
	
	# Determine direction vector based on facing direction
	var direction_vector = Vector2.ZERO
	if facing_direction == "front":
		direction_vector = Vector2(0, 1)
	elif facing_direction == "back":
		direction_vector = Vector2(0, -1)
	elif facing_direction == "right":
		direction_vector = Vector2(1 if not sprite.flip_h else -1, 0)
	
	# Calculate hit position
	hit_position += direction_vector * hit_distance
	
	# Debug visualization
	print("Checking direct hit at: ", hit_position)
	
	# Check what we're hitting with a larger radius to catch nearby objects
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 12.0  # Generous radius to catch objects
	
	query.set_shape(circle_shape)
	query.transform = Transform2D(0, hit_position)
	query.collision_mask = 2  # Layer 2 (hitboxes)
	
	var results = space_state.intersect_shape(query)
	print("Found ", results.size(), " potential targets")
	
	# Process hits
	for result in results:
		var collider = result["collider"]
		if collider is Area2D:
			var parent = collider.get_parent()
			
			# Skip self-collisions
			if parent == self:
				continue
				
			print("Direct hit detected on: ", parent.name)
			
			# Apply damage based on item
			if parent and parent.has_method("take_damage"):
				if item_name == "StoneAxe" and (parent.is_in_group("Trees") or parent.name.begins_with("Tree")):
					parent.take_damage(1, self)
					print("Direct tree damage applied!")

# Position the action hitbox in front of the player based on facing direction
func position_action_hitbox():
	if not action_hitbox:
		return
		
	var hitbox_offset = Vector2.ZERO
	
	# Position the hitbox based on facing direction
	if facing_direction == "front":
		hitbox_offset = Vector2(0, 16)  # Down
	elif facing_direction == "back":
		hitbox_offset = Vector2(0, -16)  # Up
	elif facing_direction == "right":
		if sprite and sprite.flip_h:
			hitbox_offset = Vector2(-16, 0)  # Left
		else:
			hitbox_offset = Vector2(16, 0)  # Right
	
	action_hitbox.position = hitbox_offset
	action_hitbox.monitoring = true  # Enable the hitbox
	
	# Enable the collision shape
	var shape = action_hitbox.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false

# Handle action hitbox collisions
func _on_action_hitbox_area_entered(area):
	var parent = area.get_parent()
	
	# Check if we're hitting a tree or other choppable object
	if parent and parent.has_method("take_damage"):
		# Check if parent is a tree (using group membership or specific check)
		if parent.is_in_group("Trees") or parent.name.begins_with("Tree"):
			parent.take_damage(1, self)
			print("Chopped tree!")

# Movement logic that can be called from states
func handle_movement():
	# Don't allow movement during actions
	if is_performing_action:
		return false
		
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Normalize to prevent faster diagonal movement
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
		update_facing_direction(input_direction)
	
	velocity = input_direction * move_speed
	move_and_slide()
	
	return input_direction.length() > 0
	
# Update the facing direction based on movement
func update_facing_direction(direction):
	var old_direction = facing_direction
	
	if abs(direction.x) > abs(direction.y):
		# Horizontal movement is stronger
		facing_direction = "right"
		if sprite:
			sprite.flip_h = (direction.x < 0)  # Flip for left movement
	else:
		# Vertical movement is stronger
		facing_direction = "front" if direction.y > 0 else "back"
		if sprite:
			sprite.flip_h = false
	
	# If direction changed, update animation
	if old_direction != facing_direction and state_machine and state_machine.current_state:
		var state_name = state_machine.current_state.name.to_lower()
		if state_name.begins_with("idle"):
			play_animation("idle")
		elif state_name.begins_with("move"):
			play_animation("walk")

# Play animation based on state and direction
func play_animation(state_name):
	# Don't override action animations
	if is_performing_action:
		return
		
	if sprite:
		var anim = state_name + "_" + facing_direction
		if sprite.sprite_frames.has_animation(anim):
			if anim != last_animation:
				print("Playing animation: ", anim)
				sprite.play(anim)
				last_animation = anim
		else:
			print("Animation not found: ", anim)

# Handle taking damage
func take_damage(amount):
	if health_component:
		health_component.take_damage(amount)
		if not health_component.is_alive():
			die()
	
# Handle healing
func heal(amount):
	if health_component:
		health_component.heal(amount)
		
# Handle death
func die():
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	# Could add more death handling logic here
	
# Apply knockback when hit
func apply_knockback(direction):
	velocity = direction
	move_and_slide()

# Inventory management delegate methods
func add_to_inventory(item_name: String, amount: int = 1):
	if inventory_component:
		return inventory_component.add_item(item_name, amount)
	else:
		push_error("Player: No inventory component available!")
		return false
	
func remove_from_inventory(item_name: String, amount: int = 1):
	if inventory_component:
		return inventory_component.remove_item(item_name, amount)
	return false

func has_item(item_name: String, amount: int = 1):
	if inventory_component:
		return inventory_component.has_item(item_name, amount)
	return false
	
func get_inventory():
	if inventory_component:
		return inventory_component.get_inventory()
	return {}

# Forward the inventory updated signal
func _on_inventory_updated():
	emit_signal("inventory_updated")

# Add this function to handle animation completion
func _on_animation_finished():
	# This will be called when an animation finishes playing
	if sprite and sprite.animation and sprite.animation.begins_with("axe_"):
		is_performing_action = false
		action_timer = 0.0
		
		# Disable the action hitbox
		if action_hitbox:
			action_hitbox.monitoring = false
			var shape = action_hitbox.get_node_or_null("CollisionShape2D")
			if shape:
				shape.disabled = true
				
		# Return to idle or walk animation
		if state_machine and state_machine.current_state:
			var state_name = state_machine.current_state.name.to_lower()
			if state_name.begins_with("idle"):
				play_animation("idle")
			elif state_name.begins_with("move"):
				play_animation("walk")
