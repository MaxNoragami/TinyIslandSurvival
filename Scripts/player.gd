extends CharacterBody2D

signal inventory_updated
signal game_over
@export var move_speed: float = 100.0
@onready var sprite = $AnimatedSprite2D


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
	
	var attack_reset_timer = Timer.new()
	attack_reset_timer.name = "AttackResetTimer"
	attack_reset_timer.wait_time = action_duration + 0.1
	attack_reset_timer.one_shot = true
	add_child(attack_reset_timer)
	attack_reset_timer.timeout.connect(_on_attack_reset_timeout)
	
	# Set up collision mask to detect pickups (Layer 3)
	collision_mask |= 4  # Add Layer 3 (pickup layer) to collision mask
	if sprite and not sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		sprite.animation_finished.connect(Callable(self, "_on_animation_finished"))
		
	# Make sure all action animations are set to not loop
	if sprite and sprite.sprite_frames:
		var animations = ["axe_front", "axe_back", "axe_right",
			"pickaxe_front", "pickaxe_back", "pickaxe_right",
			"slash_front", "slash_back", "slash_right"]
						  
		for anim in animations:
			if sprite.sprite_frames.has_animation(anim):
				sprite.sprite_frames.set_animation_loop(anim, false)
	
	# Ensure animation_finished signal is connected
	if sprite and not sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		sprite.animation_finished.connect(Callable(self, "_on_animation_finished"))

func _physics_process(delta):
	if not player_alive:
		return
	enemy_attack()
	# Removed attack() call here
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
		if equipped_item.ends_with("Axe") or equipped_item.ends_with("Sword") or equipped_item.ends_with("Pickaxe"):
			perform_action_with_item(equipped_item)
			return # Stop processing after performing action
	
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
# In player.gd, modify the get_equipped_item function to include StonePickaxe

# Update get_equipped_item function
func get_equipped_item():
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if inventory_ui and inventory_ui.equip_slot:
		# Check if the equip slot is toggled (selected)
		var button = inventory_ui.equip_slot.get_node_or_null("Button")
		if not button or not button.button_pressed:
			return ""  # Equip slot is not toggled on
			
		var sprite = inventory_ui.equip_slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
		if sprite and sprite.texture:
			# Check which item is equipped based on region_rect
			var region_rect = sprite.region_rect
			
			# Match the StoneAxe region rect
			if region_rect.position.x == 240 and region_rect.position.y == 1456:
				return "StoneAxe"
			
			# Match the StoneSword region rect
			if region_rect.position.x == 176 and region_rect.position.y == 1760:
				return "StoneSword"
				
			# Match the StonePickaxe region rect
			if region_rect.position.x == 16 and region_rect.position.y == 1456:
				return "StonePickaxe"
				
				# IRON TOOLS
			if region_rect.position.x == 240 and region_rect.position.y == 1616:

				return "IronAxe"
			if region_rect.position.x == 224 and region_rect.position.y == 1600:
				return "IronSword"
			if region_rect.position.x == 16 and region_rect.position.y == 1616:
				return "IronPickaxe"
				
			# GOLD TOOLS
			if region_rect.position.x == 240 and region_rect.position.y == 1536:
				return "GoldAxe"
			if region_rect.position.x == 224 and region_rect.position.y == 1520:
				return "GoldSword"
			if region_rect.position.x == 16 and region_rect.position.y == 1536:
				return "GoldPickaxe"
				
			print("DEBUG: Unknown equipped item with region: ", region_rect)
			
	print("DEBUG: No equipped item detected")
	return ""

# Perform an action with the equipped item
# Modify the perform_action_with_item function in player.gd
# Perform an action with the equipped item
func perform_action_with_item(item_name):
	if is_performing_action:
		return
	
	# Determine tool type and set damage/speed based on material
	var tool_type = ""
	var damage = 1
	var cooldown = 0.2
	
	if item_name.ends_with("Axe"):
		tool_type = "axe"
		if item_name.begins_with("Stone"):
			damage = 1
			cooldown = 0.2
		elif item_name.begins_with("Iron"):
			damage = 2  # Iron tools are stronger
			cooldown = 0.15  # And faster
		elif item_name.begins_with("Gold"):
			damage = 1  # Gold tools are fast but not stronger
			cooldown = 0.1  # Very fast
			
	elif item_name.ends_with("Sword"):
		tool_type = "slash"
		if item_name.begins_with("Stone"):
			damage = 35
			cooldown = 0.3
		elif item_name.begins_with("Iron"):
			damage = 50  # Much stronger
			cooldown = 0.25
		elif item_name.begins_with("Gold"):
			damage = 40  # Good damage
			cooldown = 0.2  # Faster
			
	elif item_name.ends_with("Pickaxe"):
		tool_type = "pickaxe"
		if item_name.begins_with("Stone"):
			damage = 1
			cooldown = 0.25
		elif item_name.begins_with("Iron"):
			damage = 2  # Mines faster
			cooldown = 0.2
		elif item_name.begins_with("Gold"):
			damage = 1  # Same damage as stone
			cooldown = 0.15  # But much faster
	
	# Prevent interrupting a currently playing action animation
	var animation_name = tool_type + "_" + facing_direction
	if sprite and sprite.is_playing() and sprite.animation == animation_name:
		return  # Already playing the animation; skip

	is_performing_action = true
	Global.player_current_attack = true  # Set attack flag for damage detection
	action_timer = 0.0
	action_cooldown = cooldown  # Use the calculated cooldown

	# Play animation once (not looping)
	if sprite:
		sprite.play(animation_name)
		print("Playing animation: ", animation_name, " with ", item_name)
		
		# Ensure animation doesn't loop
		if sprite.sprite_frames.has_animation(animation_name):
			sprite.sprite_frames.set_animation_loop(animation_name, false)
		
	# Position and enable the action hitbox
	position_action_hitbox()
	
	# Directly do a raycast to find what we're hitting
	do_direct_action_check(item_name, damage)

# Do a direct raycast check to find what we're hitting
# Update do_direct_action_check function to handle pickaxe
func do_direct_action_check(item_name, damage = 1):
	print("do_direct_action_check called with: ", item_name, " damage: ", damage)
	
	var hit_distance = 32.0
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
	
	print("Checking direct hit at: ", hit_position, " from player at: ", global_position)
	
	# Try shape collision detection
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 20.0
	
	query.set_shape(circle_shape)
	query.transform = Transform2D(0, hit_position)
	query.collision_mask = 7  # Check layers 1, 2, and 3
	
	var results = space_state.intersect_shape(query)
	print("Shape query found ", results.size(), " potential targets")
	
	# Process collision results
	for result in results:
		var collider = result["collider"]
		
		if not collider:
			continue
			
		print("Collider found: ", collider.name if collider else "null", " type: ", collider.get_class())
		
		var target = null
		
		# FIXED: Handle different collider types
		if collider is Area2D:
			# This is probably a HitboxComponent - get its parent
			target = collider.get_parent()
			print("Area2D collider - checking parent: ", target.name if target else "null")
		elif collider is StaticBody2D or collider is CharacterBody2D:
			# This is probably a tree's StaticBody2D - get its parent  
			target = collider.get_parent()
			print("Body collider - checking parent: ", target.name if target else "null")
		else:
			# Direct node collision
			target = collider
			print("Direct collider")
		
		# Skip self-collisions
		if target == self:
			print("Skipping self-collision")
			continue
			
		if not target:
			print("No valid target found")
			continue
			
		print("Final target: ", target.name, " groups: ", target.get_groups())
		
		# Apply damage based on item type
		if target.has_method("take_damage"):
			print("Target has take_damage method")
			
			if item_name.ends_with("Axe") and (target.is_in_group("Trees") or target.name.begins_with("Tree")):
				print("CALLING tree.take_damage with damage: ", damage)
				target.take_damage(damage, self)
				print("Tree damage call completed")
				return
				
			elif item_name.ends_with("Sword") and target.has_method("skeleton"):
				print("CALLING skeleton.take_damage with damage: ", damage)
				target.take_damage(damage, self)
				print("Skeleton damage call completed")
				return
				
			elif item_name.ends_with("Pickaxe"):
				# Check if it's an ore
				if target.is_in_group("Ores") or target.name.begins_with("Iron") or target.name.begins_with("Stone") or target.name.begins_with("Gold"):
					print("CALLING ore.take_damage with damage: ", damage)
					target.take_damage(damage, self)
					print("Ore damage call completed")
					return
		else:
			print("Target does not have take_damage method")
	
	print("No valid targets found to damage")

# Also add this helper function to player.gd for easier debugging:
func debug_nearby_objects():
	print("=== NEARBY OBJECTS DEBUG ===")
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 50.0
	
	query.set_shape(circle_shape)
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 7  # All layers
	
	var results = space_state.intersect_shape(query)
	print("Found ", results.size(), " nearby objects:")
	
	for i in range(results.size()):
		var result = results[i]
		var collider = result["collider"]
		var parent = collider.get_parent() if collider else null
		
		print("  ", i, ": ", collider.name if collider else "null",
			" (", collider.get_class() if collider else "null", ") parent: ",
			parent.name if parent else "null")

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
	
	# Set position first
	action_hitbox.position = hitbox_offset
	
	# Enable the collision shape
	var shape = action_hitbox.get_node_or_null("CollisionShape2D")
	if shape:
		shape.disabled = false
		
	# Enable the hitbox monitoring last
	action_hitbox.monitoring = true

# Handle action hitbox collisions
func _on_action_hitbox_area_entered(area):
	var parent = area.get_parent()
	print("Action hitbox area entered: ", parent.name if parent else "null")
	
	# Skip self-collisions
	if parent == self:
		return
	
	# Check if we're hitting a tree or other choppable object
	if parent and parent.has_method("take_damage"):
		var equipped_item = get_equipped_item()
		if equipped_item == "StoneAxe" and (parent.is_in_group("Trees") or parent.name.begins_with("Tree")):
			parent.take_damage(1, self)
			print("Chopped tree!")
		elif equipped_item == "StoneSword" and parent.has_method("skeleton"):
			parent.take_damage(35, self)  # Sword does more damage
			print("Attacked enemy with sword!")
			Global.player_current_attack = false

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
	game_over.emit()

# This is likely already done but check to make sure
func _on_animation_finished():
	var anim_name = sprite.animation
	if anim_name == "death":
		print("Death animation finished. Stopping physics.")
		set_physics_process(false)
		return

	# Check for any action animations (axe, pickaxe, or sword)
	if anim_name.begins_with("axe_") or anim_name.begins_with("slash_") or anim_name.begins_with("pickaxe_"):
		print("Action animation finished")
		is_performing_action = false
		Global.player_current_attack = false
		attack_ip = false

		if action_hitbox:
			action_hitbox.monitoring = false
			var shape = action_hitbox.get_node_or_null("CollisionShape2D")
			if shape:
				shape.disabled = true

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
	
	# Check for Crystal win condition
	if has_item("Crystal"):
		# Find the win system and trigger the win condition
		var win_system = get_tree().get_first_node_in_group("WinScreen")
		if win_system and win_system.has_method("_on_game_win"):
			win_system._on_game_win()

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
		_show_damage_effect()
		health = health - 20
		# Tune force as needed
		enemy_attack_cooldown = false
		$attack_cooldown.start()
		print("Health - ", health)
	

func _on_attack_cooldown_timeout() -> void:
	Global.player_current_attack = false
	enemy_attack_cooldown = true
	
func attack():
	# If we're using a weapon with item_action, don't duplicate the attack
	var equipped_item = get_equipped_item()
	if equipped_item == "StoneSword" or equipped_item == "StoneAxe":
		return  # Skip attacking if proper tool is equipped (now handled by item_action)
		
	# No special weapon equipped at this point, so use default attack
	var dir = facing_direction

	if Input.is_action_just_pressed("attack") and not is_performing_action:
		Global.player_current_attack = true
		attack_ip = true
		is_performing_action = true  # Block spam
		action_timer = 0.0  # Reset action timer

		if dir == "right":
			$AnimatedSprite2D.flip_h = false
			$AnimatedSprite2D.play("pickaxe_right")
			$deal_attack_timer.start()
		elif dir == "front":
			$AnimatedSprite2D.play("pickaxe_front")
			$deal_attack_timer.start()
		elif dir == "back":
			$AnimatedSprite2D.play("pickaxe_back")
			$deal_attack_timer.start()
		else:
			$AnimatedSprite2D.flip_h = true
			$AnimatedSprite2D.play("pickaxe_right")
			$deal_attack_timer.start()
		$deal_attack_timer.start()

func _show_damage_effect():
	if not sprite:
		return

	# Kill any existing tweens affecting modulate
	var existing_tweens = get_tree().get_nodes_in_group("PlayerTweens")
	for tween in existing_tweens:
		tween.kill()
		tween.queue_free()

	# Create a fresh tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)



# Add this at the bottom of your script
func _on_attack_reset_timeout():
	if Global.player_current_attack:
		print("[Timer Fallback] Resetting lingering attack state")
	Global.player_current_attack = false
	is_performing_action = false
	action_timer = 0.0
	attack_ip = false

	# Safely disable action hitbox in case it was left on
	if action_hitbox:
		action_hitbox.monitoring = false
		var shape = action_hitbox.get_node_or_null("CollisionShape2D")
		if shape:
			shape.disabled = true
