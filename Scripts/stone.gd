# iron_ore.gd - Fixed version with all pickaxe types support

extends Node2D

# Resource properties for iron ore
@export var max_health: int = 3
@export var current_health: int = 3
@export var stone_drop_min: int = 1
@export var stone_drop_max: int = 2  # Reduced maximum to prevent too many drops
@export var respawn_time: float = 30.0

# References to components
var sprite
var hitbox_component
var static_body
var health_component

# State tracking
var is_mined = false
var resources_dropped = false  # Flag to prevent multiple drops
var respawn_timer = 0.0
var player_in_range = false
var player_ref = null

# Get references to all nodes on ready
func _ready():
	add_to_group("Ores")
	add_to_group("StoneOres")
	sprite = $Sprite2D if has_node("Sprite2D") else null
	hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
	static_body = $StaticBody2D if has_node("StaticBody2D") else null
	health_component = $HealthComponent if has_node("HealthComponent") else null
	
	# If we have a health component, use its values and connect to its signal
	if health_component:
		current_health = health_component.current_health
		max_health = health_component.max_health
		if not health_component.health_depleted.is_connected(mine_ore):
			health_component.health_depleted.connect(mine_ore)
	
	# Connect hitbox signals
	if hitbox_component:
		# Connect signals
		if not hitbox_component.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox_component.body_entered.connect(_on_hitbox_body_entered)
		if not hitbox_component.body_exited.is_connected(_on_hitbox_body_exited):
			hitbox_component.body_exited.connect(_on_hitbox_body_exited)
		
		# Make sure hitbox is configured to detect player
		hitbox_component.collision_mask |= 1  # Layer 1 (player)
		print("Stone ore: Hitbox signals connected")

# Handle respawning over time
func _process(delta):
	if is_mined:
		respawn_timer += delta
		if respawn_timer >= respawn_time:
			respawn_ore()
	
	# Check for damage from the player's current action
	if player_in_range and player_ref and player_ref.is_performing_action:
		var equipped_item = player_ref.get_equipped_item()
		# FIXED: Check if it ends with "Pickaxe" instead of specific pickaxe type
		if equipped_item.ends_with("Pickaxe") and Global.player_current_attack:
			print("Stone ore detected pickaxe attack from global state with: " + equipped_item)
			
			# Calculate damage based on pickaxe type
			var damage = 1
			if equipped_item.begins_with("Iron"):
				damage = 2  # Iron pickaxe mines faster
			elif equipped_item.begins_with("Gold"):
				damage = 1  # Gold pickaxe same damage but faster cooldown (handled in player)
			
			take_damage(damage, player_ref)
			Global.player_current_attack = false  # Reset to prevent multiple hits

# Function to identify this as an ore for player's detection
func ore():
	pass

# Hitbox signal handlers
func _on_hitbox_body_entered(body):
	print("Stone ore: Body entered hitbox - " + body.name)
	if body.is_in_group("Player") or body.has_method("player"):
		player_in_range = true
		player_ref = body
		print("Stone ore: Player in range")

func _on_hitbox_body_exited(body):
	print("Stone ore: Body exited hitbox - " + body.name)
	if body.is_in_group("Player") or body.has_method("player"):
		player_in_range = false
		player_ref = null
		print("Stone ore: Player out of range")

# Handle damage when hit by a pickaxe
func take_damage(damage_amount: int = 1, damager = null):
	print("Stone ore take_damage called")
	
	if is_mined:
		print("Stone ore already mined")
		return
	
	# If no damager is provided, use the player_ref
	if damager == null:
		damager = player_ref
	
	# Check if we're being hit by a valid tool
	if damager == null or not (damager.is_in_group("Player") or damager.has_method("player")):
		print("Invalid damager")
		return
	
	# Check if the player is using a pickaxe - FIXED to accept any pickaxe type
	var equipped_item = damager.get_equipped_item()
	if not equipped_item.ends_with("Pickaxe"):
		print("Not being hit with a pickaxe, equipped item: " + str(equipped_item))
		# Give feedback that a pickaxe is needed
		_show_wrong_tool_effect()
		return
	
	print("Stone ore: Taking damage: " + str(damage_amount) + " from " + equipped_item)
	
	# Apply damage to the ore
	if health_component:
		health_component.take_damage(damage_amount)
		if health_component.current_health <= 0 and not is_mined:
			mine_ore()
	else:
		current_health -= damage_amount
		if current_health <= 0 and not is_mined:
			mine_ore()
	
	if current_health > 0:
		_show_damage_effect()

# Called when the ore is fully mined
func mine_ore():
	if is_mined:
		return
	
	print("Stone ore has been mined!")
	is_mined = true
	respawn_timer = 0.0
	resources_dropped = false  # Reset this flag
	
	# Show mining effect - make the ore appear broken
	if sprite:
		# Reduce opacity to show it's mined
		sprite.modulate.a = 0.3
	
	# Disable hitbox and collision
	if hitbox_component:
		hitbox_component.set_deferred("monitoring", false)
		hitbox_component.set_deferred("monitorable", false)
		hitbox_component.set_deferred("collision_layer", 0)
		hitbox_component.set_deferred("collision_mask", 0)
		for child in hitbox_component.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
	
	if static_body:
		static_body.set_deferred("collision_layer", 0)
		for child in static_body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
	
	# Drop resources - only do this once
	if not resources_dropped:
		call_deferred("_drop_resources")

# Respawn the ore after the respawn timer
func respawn_ore():
	print("Stone ore respawning...")
	
	is_mined = false
	respawn_timer = 0.0
	
	# Reset health
	current_health = max_health
	if health_component:
		health_component.current_health = health_component.max_health
		health_component.emit_signal("health_changed", health_component.current_health)
	
	# Restore visuals
	if sprite:
		sprite.modulate.a = 1.0
	
	# Re-enable hitbox and collision
	if hitbox_component:
		hitbox_component.set_deferred("monitoring", true)
		hitbox_component.set_deferred("monitorable", true)
		hitbox_component.set_deferred("collision_layer", 2)
		hitbox_component.set_deferred("collision_mask", 3)  # Layer 1 (player) + 2 (hitbox)
		for child in hitbox_component.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)
	
	if static_body:
		static_body.set_deferred("collision_layer", 1)
		for child in static_body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)
	
	_show_respawn_effect()
	print("Stone ore respawned!")

# Drop iron resources when mined - FIXED VERSION
func _drop_resources():
	# Safety check to prevent multiple calls
	if resources_dropped:
		print("Resources already dropped, skipping")
		return
	
	resources_dropped = true  # Set flag to prevent multiple drops
	
	var drop_count = randi_range(stone_drop_min, stone_drop_max)
	
	# Load the rock.tscn as a base template
	var rock_scene = load("res://Scenes/rock.tscn")
	
	if not rock_scene:
		print("Failed to load rock scene")
		return
	
	print("Dropping " + str(drop_count) + " Stone resources")
	
	# Find the game root
	var game_root = get_tree().root.get_node_or_null("Game")
	if not game_root:
		print("Could not find Game root node")
		return
	
	# Find the pickable items container
	var pickable_items = game_root.get_node_or_null("PickableItems")
	if not pickable_items:
		print("Could not find PickableItems container")
		return
	
	# Find the appropriate category
	var target_container = pickable_items.get_node_or_null("OtherItems")
	if not target_container:
		print("Could not find OtherItems container, using PickableItems instead")
		target_container = pickable_items
	
	# Spawn the Iron resources
	for i in range(drop_count):
		var resource = rock_scene.instantiate()
		
		# Update the sprite to show iron texture
		var sprite_node = resource.get_node_or_null("Sprite2D")
		if sprite_node:
			# Use the iron texture from Outdoor_Decor_Free.png
			var texture = load("res://Assets/Icons/16x16.png")
			if texture:
				sprite_node.texture = texture
				sprite_node.region_enabled = true
				sprite_node.region_rect = Rect2(160, 304, 16, 16)  # Iron texture region
		
		# IMPORTANT FIX: Set up the pickup component to drop "Iron" items
		var pickup = resource.get_node_or_null("PickupComponent")
		if pickup:
			pickup.item_name = "Stone"  # This makes it drop as "Iron" instead of "Rock"
			pickup.item_quantity = 1
		
		# FIXED: Safer way to update resource properties
		if resource.has_method("set") and "resource_name" in resource:
			resource.resource_name = "Stone"
		
		# Generate a random offset from the ore position
		var angle = randf() * TAU  # Random angle in radians
		var distance = randf_range(10, 20)  # Random distance between 10-20 pixels
		var offset = Vector2(cos(angle), sin(angle)) * distance
		
		# Set the position
		resource.global_position = global_position + offset
		
		# Add to the container
		target_container.add_child(resource)
		print("Dropped Stone resource " + str(i+1) + " of " + str(drop_count))

# Visual effects for feedback
func _show_damage_effect():
	# Play stone mining sound effect
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var equipped_item = player.get_equipped_item()
		if equipped_item.ends_with("Pickaxe"):
			var stone_mine_sound = player.get_node_or_null("Sounds/StoneMine")
			if stone_mine_sound:
				stone_mine_sound.play()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

func _show_wrong_tool_effect():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 0.5, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

func _show_respawn_effect():
	scale = Vector2(0.5, 0.5)
	modulate = Color(0.7, 1.0, 0.7, 0.7)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)
