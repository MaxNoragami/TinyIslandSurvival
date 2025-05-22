extends Node2D

# Simplified RuneStone script that avoids modifying constants

func _ready():
	# Add to appropriate groups for easier finding
	add_to_group("Pickable")
	add_to_group("RuneStones")
	
	print("RuneStone script loaded - simplified version")
	
	# Make sure there's a proper Sprite2D with texture
	setup_sprite()
	
	# Make sure there's a CollisionShape2D
	var collision = get_node_or_null("CollisionShape2D")
	if not collision:
		var new_collision = CollisionShape2D.new()
		new_collision.name = "CollisionShape2D"
		var shape = CircleShape2D.new()
		shape.radius = 12.0
		new_collision.shape = shape
		add_child(new_collision)
		print("Added CollisionShape2D to RuneStone")
	
	# Make sure there's a PickupComponent
	var pickup = get_node_or_null("PickupComponent")
	if pickup:
		pickup.item_name = "RuneStone"
		pickup.auto_pickup = true
		pickup.can_be_picked_up = true
		print("Setup PickupComponent for RuneStone")
	else:
		add_pickup_component()

func setup_sprite():
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	# Try loading the texture - first try exact path from inventory
	var texture = load("res://Assets/Outdoor decoration/ancient_tablet.png")
	
	# If that fails, try alternatives
	if not texture:
		print("Failed to load primary RuneStone texture, trying alternatives...")
		var alt_paths = [
			"res://Assets/Outdoor_decoration/ancient_tablet.png",
			"res://Assets/outdoor_decoration/ancient_tablet.png",
			"res://Assets/ancient_tablet.png"
		]
		
		for path in alt_paths:
			texture = load(path)
			if texture:
				print("Found RuneStone texture at: " + path)
				break
	
	if texture:
		sprite.texture = texture
		print("Set RuneStone texture successfully")
	else:
		print("ERROR: Could not load any RuneStone texture!")

func add_pickup_component():
	var pickup = Node.new()
	pickup.name = "PickupComponent"
	
	# Try to load the script
	var script = load("res://Scripts/pickup_component.gd")
	if script:
		pickup.set_script(script)
		add_child(pickup)
		
		# Configure it
		pickup.item_name = "RuneStone"
		pickup.auto_pickup = true
		pickup.can_be_picked_up = true
		
		print("Added PickupComponent to RuneStone")
	else:
		push_error("Could not load pickup_component.gd script")

func _input(event):
	# T key will trigger pickup for testing
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		print("RuneStone: Manual pickup triggered (T key)")
		var pickup = get_node_or_null("PickupComponent")
		if pickup and pickup.has_method("trigger_pickup"):
			var player = get_tree().get_first_node_in_group("Player")
			if player:
				pickup.trigger_pickup(player)
				print("Manually triggered RuneStone pickup")
			else:
				print("Player not found for manual pickup")
		else:
			print("PickupComponent not found or missing trigger_pickup method")
