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

# Last direction for animation purposes
var facing_direction = "front"
var last_animation = ""

# Action state
var is_performing_action = false
var action_timer = 0.0
var action_duration = 0.6  # Duration of action animations in seconds

func _ready():
	# Add self to Player group
	add_to_group("Player")
	
	# Get references to components
	health_component = $HealthComponent if has_node("HealthComponent") else null
	hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
	sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
	
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
	# Handle action timing
	if is_performing_action:
		action_timer += delta
		if action_timer >= action_duration:
			is_performing_action = false
			action_timer = 0.0
			# Return to previous animation state
			if state_machine.current_state:
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
	# Handle item action (using equipped item)
	if event.is_action_pressed("item_action") and not is_performing_action:
		var equipped_item = get_equipped_item()
		if equipped_item == "StoneAxe":
			perform_action_with_item(equipped_item)

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
	if item_name == "StoneAxe":
		# Play appropriate axe animation based on facing direction
		is_performing_action = true
		action_timer = 0.0
		
		var animation_name = "axe_" + facing_direction
		if sprite:
			sprite.play(animation_name)
			print("Playing animation: ", animation_name)

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
