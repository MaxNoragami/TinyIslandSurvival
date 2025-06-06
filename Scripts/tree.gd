extends Node2D

@export var max_health: int = 5
@export var current_health: int = 5
@export var wood_drop_min: int = 2
@export var wood_drop_max: int = 4
@export var regrowth_time: float = 20.0

var tree_crown
var tree_base
var tree_trunk
var hitbox_component
var static_body
var trunk_collision
var health_component

var is_cut_down = false
var regrowth_timer = 0.0

func _ready():
	add_to_group("Trees")
	tree_crown = $TreeCrown if has_node("TreeCrown") else null
	tree_base = $TreeBase if has_node("TreeBase") else null
	tree_trunk = $TreeTrunk if has_node("TreeTrunk") else null
	hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
	static_body = $StaticBody2D if has_node("StaticBody2D") else null
	trunk_collision = $TrunkCollision if has_node("TrunkCollision") else null
	health_component = $HealthComponent if has_node("HealthComponent") else null

	if health_component:
		current_health = health_component.current_health
		max_health = health_component.max_health
		if not health_component.health_depleted.is_connected(cut_down_tree):
			health_component.health_depleted.connect(cut_down_tree)

	if tree_trunk:
		tree_trunk.visible = false

	print("TREE DEBUG: Tree ", self.name, " initialized at position ", global_position)

func _process(delta):
	if is_cut_down:
		regrowth_timer += delta
		if regrowth_timer >= regrowth_time:
			regrow_tree()

func take_damage(damage_amount: int = 1, damager = null):
	print("TREE DEBUG: take_damage called on ", self.name)
	print("TREE DEBUG: - damage_amount: ", damage_amount)
	print("TREE DEBUG: - damager: ", damager.name if damager else "null")

	if is_cut_down:
		print("TREE DEBUG: Tree already cut down")
		return

	# Get the player if damager is null
	if damager == null:
		damager = get_tree().get_first_node_in_group("Player")
		print("TREE DEBUG: Found player from group: ", damager.name if damager else "null")

	if damager == null:
		print("TREE DEBUG: No damager found")
		return

	if not damager.is_in_group("Player"):
		print("TREE DEBUG: Damager is not a player")
		return

	# Check if player is actually performing an action
	print("TREE DEBUG: Player is_performing_action: ", damager.is_performing_action)
	if not damager.is_performing_action:
		print("TREE DEBUG: Player not performing action - no damage applied")
		return

	# Check distance to player
	var distance = damager.global_position.distance_to(global_position)
	print("TREE DEBUG: Distance to player: ", distance)
	if distance > 30.0:
		print("TREE DEBUG: Player too far away: ", distance)
		return

	# Check if player is using an axe
	var equipped_item = damager.get_equipped_item()
	print("TREE DEBUG: Player equipped item: '", equipped_item, "'")
	if not equipped_item.ends_with("Axe"):
		print("TREE DEBUG: Not being chopped with an axe")
		_show_wrong_tool_effect()
		return

	print("TREE DEBUG: ✓ All checks passed! Applying ", damage_amount, " damage from ", equipped_item)

	if health_component:
		health_component.take_damage(damage_amount)
		print("TREE DEBUG: Health component health: ", health_component.current_health, "/", health_component.max_health)
		if health_component.current_health <= 0 and not is_cut_down:
			cut_down_tree()
	else:
		current_health -= damage_amount
		print("TREE DEBUG: Direct health: ", current_health, "/", max_health)
		if current_health <= 0 and not is_cut_down:
			cut_down_tree()

	if current_health > 0:
		_show_damage_effect()

func cut_down_tree():
	if is_cut_down:
		return

	print("TREE DEBUG: *** TREE BEING CUT DOWN! ***")
	is_cut_down = true
	regrowth_timer = 0.0

	if tree_crown:
		tree_crown.visible = false
	if tree_base:
		tree_base.visible = false
	if tree_trunk:
		tree_trunk.visible = true

	if static_body:
		static_body.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
		for child in static_body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)

	if hitbox_component:
		hitbox_component.set_deferred("monitoring", false)
		hitbox_component.set_deferred("monitorable", false)
		hitbox_component.set_deferred("collision_layer", 0)
		hitbox_component.set_deferred("collision_mask", 0)
		for child in hitbox_component.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)

	if trunk_collision:
		trunk_collision.set_deferred("collision_layer", 1)
		for child in trunk_collision.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)

	call_deferred("_drop_resources")

func regrow_tree():
	print("Tree regrowing...")

	is_cut_down = false
	regrowth_timer = 0.0

	current_health = max_health
	if health_component:
		health_component.current_health = health_component.max_health
		health_component.emit_signal("health_changed", health_component.current_health)

	if tree_crown:
		tree_crown.visible = true
	if tree_base:
		tree_base.visible = true
	if tree_trunk:
		tree_trunk.visible = false

	if static_body:
		static_body.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		for child in static_body.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)

	if hitbox_component:
		hitbox_component.set_deferred("monitoring", true)
		hitbox_component.set_deferred("monitorable", true)
		hitbox_component.set_deferred("collision_layer", 2)
		hitbox_component.set_deferred("collision_mask", 2)
		for child in hitbox_component.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", false)

	if trunk_collision:
		trunk_collision.set_deferred("collision_layer", 1)
		trunk_collision.set_deferred("collision_mask", 1)
		for child in trunk_collision.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", true)

	_show_regrowth_effect()
	print("Tree regrown!")

func _drop_resources():
	# Play the tree chopped sound effect when destroyed
	var chopped_sound = get_node_or_null("Chopped")
	if chopped_sound:
		chopped_sound.play()

	var wood_count = randi_range(wood_drop_min, wood_drop_max)
	var wood_scene = load("res://Scenes/wood.tscn")
	if not wood_scene:
		print("Failed to load wood scene")
		return

	for i in range(wood_count):
		var wood = wood_scene.instantiate()
		var offset = Vector2(cos(randf() * TAU), sin(randf() * TAU)) * randf_range(10, 20)
		wood.global_position = global_position + offset
		var parent = get_parent().get_node_or_null("PickableItems/WoodItems")
		if parent:
			parent.add_child(wood)
		else:
			get_parent().add_child(wood)

func _show_damage_effect():
	print("TREE DEBUG: Showing damage effect")
	
	# Play wood chopping sound effect
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var equipped_item = player.get_equipped_item()
		if equipped_item.ends_with("Axe"):
			var wood_chop_sound = player.get_node_or_null("Sounds/WoodChop")
			if wood_chop_sound:
				wood_chop_sound.play()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

func _show_wrong_tool_effect():
	print("TREE DEBUG: Showing wrong tool effect")
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 0.5, 1), 0.1)
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

func _show_regrowth_effect():
	scale = Vector2(0.5, 0.5)
	modulate = Color(0.7, 1.0, 0.7, 0.7)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_ELASTIC)
	tween.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5)
