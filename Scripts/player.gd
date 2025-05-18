extends CharacterBody2D

signal inventory_updated

@export var move_speed: float = 100.0

# Preload the InventoryComponent script
const InventoryComponentScript = preload("res://Scripts/inventory_component.gd")
var enemy_inattack_range = false
var enemy_attack_cooldown = true
var health = 200
var player_alive = true
var attack_ip = false
var knockback_velocity = Vector2.ZERO


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
	if sprite and not sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
		
func _physics_process(delta):
	if not player_alive:
		return 
	enemy_attack()
	attack()
	if health <= 0:
		die()
		
	if knockback_velocity.length() > 0.1:
		position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600 * delta)  # Adjust damping
	else:
		knockback_velocity = Vector2.ZERO
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
	if not player_alive:
		return  # Ignore input when dead

	if event.is_action_pressed("item_action") and not is_performing_action and action_cooldown <= 0:
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
		# Prevent interrupting a currently playing action animation
		var animation_name = "axe_" + facing_direction
		if sprite and sprite.is_playing() and sprite.animation == animation_name:
			return  # Already playing the animation; skip

		is_performing_action = true
		action_timer = 0.0
		action_cooldown = 0.2  # Add a slight cooldown to prevent spamming

		# Position and enable the action hitbox
		position_action_hitbox()
		
		# Play animation once
		if sprite:
			sprite.play(animation_name)
			print("Playing animation: ", animation_name)

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
	if is_performing_action or not player_alive:
		return false  # Don't allow movement if player is dead or busy

	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
		update_facing_direction(input_direction)
	
	velocity = input_direction * move_speed
	move_and_slide()

	return input_direction.length() > 0
	
# Update the facing direction based on movement
func update_facing_direction(direction):
	if not player_alive:
		return 
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
		if state_name.begins_with("idle") and attack_ip == false:
			play_animation("idle")
		elif state_name.begins_with("move"):
			play_animation("walk")

# Play animation based on state and direction
func play_animation(state_name):
	if is_performing_action or not player_alive:
		return  # Don't override if dead or doing something else

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
#func take_damage(amount):
	#if health_component:
		#health_component.take_damage(amount)
		#if not health_component.is_alive():
			#die()
	
# Handle healing
func heal(amount):
	if health_component:
		health_component.heal(amount)
		
# Handle death
func die():
	
	if not player_alive:
		return  # Prevent calling die twice
	Global.player_current_attack = false
	player_alive = false
	health = 0
	print("Player has died")

	# Stop movement
	velocity = Vector2.ZERO

	# Play death animation if available
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		# If no animation, just stop processing immediately
		set_physics_process(false)
	if state_machine:
		state_machine.set_process(false)  # Stop state updates


func _on_animation_finished(anim_name):
	if anim_name == "death":
		print("Death animation finished. Stopping physics.")
		set_physics_process(false)
		return

	if anim_name.begins_with("axe_"):
		print("Axe animation finished")
		is_performing_action = false  # Allow new actions

		# Restore idle or walk animation based on state
		if state_machine and state_machine.current_state:
			var state_name = state_machine.current_state.name.to_lower()
			if state_name.begins_with("idle"):
				play_animation("idle")
			elif state_name.begins_with("move"):
				play_animation("walk")

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


func _on_hitbox_component_body_entered(body):
	print("Body entered hitbox: ", body.name)
	if body.has_method("skeleton"):
		enemy_inattack_range = true
		var direction = (position - body.position).normalized()
		knockback_velocity = direction * 100  


func _on_hitbox_component_body_exited(body):
	print("Body exited hitbox: ", body.name)
	if body.has_method("skeleton"):
		enemy_inattack_range = false
		
func player():
	pass
	
func enemy_attack():
	if enemy_inattack_range and enemy_attack_cooldown == true and health > 0:
		health = health - 20
		# Tune force as needed
		enemy_attack_cooldown = false
		$attack_cooldown.start()
		print("Health - ", health)
	

func _on_attack_cooldown_timeout() -> void:
	enemy_attack_cooldown = true
	
func attack():
	if not has_item("StoneAxe", 1):  # Check inventory
		return  # Cannot attack without an axe

	var dir = facing_direction

	if Input.is_action_just_pressed("attack") and not is_performing_action:
		Global.player_current_attack = true
		attack_ip = true
		is_performing_action = true  # Block spam
		action_timer = 0.0  # Reset action timer

		if dir== "right":
			$AnimatedSprite2D.flip_h = false
			$AnimatedSprite2D.play("pickaxe_right")
			$deal_attack_timer.start()
		if dir== "front":
			$AnimatedSprite2D.play("pickaxe_front")
			$deal_attack_timer.start()
		if dir == "back":
			$AnimatedSprite2D.play("pickaxe_back")
			$deal_attack_timer.start()
		else:
			$AnimatedSprite2D.flip_h = true
			$AnimatedSprite2D.play("pickaxe_left")
			$deal_attack_timer.start()
		$deal_attack_timer.start()



func _on_deal_attack_timer_timeout() -> void:
	$deal_attack_timer.stop()
	Global.player_current_attack = false
	attack_ip = false
