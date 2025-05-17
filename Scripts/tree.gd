extends Node2D

@export var max_health: int = 5
@export var current_health: int = 5
@export var wood_drop_min: int = 2
@export var wood_drop_max: int = 4

# Component references
var tree_crown
var tree_base
var tree_trunk
var hitbox_component
var static_body
var trunk_collision
var health_component

# State tracking
var is_cut_down = false

func _ready():
	# Add self to Trees group for easy access
	add_to_group("Trees")
	
	# Get references to components
	tree_crown = $TreeCrown if has_node("TreeCrown") else null
	tree_base = $TreeBase if has_node("TreeBase") else null
	tree_trunk = $TreeTrunk if has_node("TreeTrunk") else null
	hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
	static_body = $StaticBody2D if has_node("StaticBody2D") else null
	trunk_collision = $TrunkCollision if has_node("TrunkCollision") else null
	health_component = $HealthComponent if has_node("HealthComponent") else null
	
	# Initialize health from health component if available
	if health_component:
		current_health = health_component.current_health
		max_health = health_component.max_health
		# Connect health depleted signal
		health_component.health_depleted.connect(cut_down_tree)
	
	# Make sure trunk is initially hidden
	if tree_trunk:
		tree_trunk.visible = false

# Handle taking damage (e.g., from player's axe)
func take_damage(damage_amount: int = 1, damager = null):
	# Debug print to verify function is called
	print("Tree taking damage: " + str(damage_amount) + ", current health: " + str(current_health))
	
	if is_cut_down:
		print("Tree already cut down, ignoring damage")
		return  # Already cut down
	
	# Only accept damage from valid sources (player with axe)
	if damager == null or not damager.is_in_group("Player"):
		print("Tree damage source invalid, ignoring")
		return # Ignore damage from non-player sources
		
	# Check if the damage is from a player's action (axe swing)
	if not damager.is_performing_action:
		print("Player not performing action, ignoring damage")
		return # Ignore damage when player isn't performing an action
	
	print("Tree taking valid damage, proceeding...")
	
	if health_component:
		health_component.take_damage(damage_amount)
		print("Health component health now: " + str(health_component.current_health))
		# Check if we need to cut down immediately due to 0 health
		if health_component.current_health <= 0 and not is_cut_down:
			print("Tree health depleted, cutting down tree")
			cut_down_tree()
	else:
		# Manual health tracking
		current_health -= damage_amount
		print("Tree health reduced to: " + str(current_health))
		if current_health <= 0:
			print("Tree health depleted, cutting down tree")
			cut_down_tree()
	
	# Visual feedback
	if current_health > 0:
		_show_damage_effect()

# Called when the tree is cut down
func cut_down_tree():
	print("Attempting to cut down tree, is_cut_down=" + str(is_cut_down))
	
	if is_cut_down:
		return  # Prevent multiple calls
	
	print("Cutting down tree!")
	is_cut_down = true
	
	# Update visuals: hide crown and base, show trunk
	if tree_crown:
		tree_crown.visible = false
	
	if tree_base:
		tree_base.visible = false
	
	if tree_trunk:
		tree_trunk.visible = true
	
	# Update collisions: disable regular collision, enable trunk collision
	if static_body and static_body.has_method("set_process"):
		# Using deferred calls to avoid physics errors
		static_body.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		
		# Disable all collision shapes
		for child in static_body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
	
	if hitbox_component:
		# Use deferred calls for physics properties
		hitbox_component.set_deferred("collision_mask", 0)
		hitbox_component.set_deferred("collision_layer", 0)
		hitbox_component.set_deferred("monitoring", false)
		hitbox_component.set_deferred("monitorable", false)
		
		# Disable all collision shapes
		for child in hitbox_component.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)
	
	# Make sure trunk collision is enabled
	if trunk_collision:
		trunk_collision.set_deferred("collision_layer", 1)  # Physical layer
		
		# Enable all collision shapes
		for child in trunk_collision.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)
	
	# Drop wood resources (use call_deferred to avoid physics errors)
	call_deferred("_drop_resources")

# Drop wood resources when tree is cut
func _drop_resources():
	var wood_count = randi_range(wood_drop_min, wood_drop_max)
	
	# Get the wood scene
	var wood_scene_path = "res://Scenes/wood.tscn"
	var wood_scene = load(wood_scene_path)
	
	if not wood_scene:
		print("Failed to load wood scene")
		return
	
	# Spawn the wood items
	for i in range(wood_count):
		var wood = wood_scene.instantiate()
		
		# Position randomly around the tree
		var random_angle = randf() * 2 * PI
		var random_distance = randf_range(10, 20)
		var offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
		wood.global_position = global_position + offset
		
		# Add to the world (using call_deferred)
		var world = get_parent()
		if world:
			# Try to find the WoodItems container
			var wood_items = world.get_node_or_null("PickableItems/WoodItems")
			if wood_items:
				wood_items.add_child(wood)
			else:
				# Fallback to direct parent
				world.call_deferred("add_child", wood)

# Visual feedback for damage
func _show_damage_effect():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)
