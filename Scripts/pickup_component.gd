extends Node
class_name PickupComponent

signal item_picked_up(item_data)

@export var item_name: String = ""  # If empty, uses parent's name
@export var item_quantity: int = 1
@export var auto_pickup: bool = false  # If true, picks up on contact
@export var pickup_sound_path: String = ""
@export_flags("Layer 1", "Layer 2", "Layer 3", "Layer 4") var pickup_layer = 4  # Layer for pickup detection

var can_be_picked_up: bool = true
var parent_object

func _ready():
	parent_object = get_parent()
	
	# If auto pickup and parent has a hitbox, connect to it
	if auto_pickup:
		var hitbox = parent_object.get_node_or_null("HitboxComponent")
		if hitbox:
			# Use the hitbox for pickup detection
			hitbox.body_entered.connect(_on_body_entered)
			# Make sure hitbox can detect player (Layer 1)
			hitbox.collision_mask |= 1
	
	# You can also create your own Area2D for pickup detection
	# This is useful if you want separate collision shapes for hitbox and pickup
	if not has_node("PickupArea") and pickup_layer > 0:
		var pickup_area = Area2D.new()
		pickup_area.name = "PickupArea"
		# Set to Pickup layer (Layer 3)
		pickup_area.collision_layer = 4  # 2^2 = 4 (Layer 3)
		pickup_area.collision_mask = 1   # Detect Player (Layer 1)
		
		# Copy the collision shape from parent if possible
		var parent_hitbox = parent_object.get_node_or_null("HitboxComponent")
		if parent_hitbox:
			for child in parent_hitbox.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					var shape_copy = child.duplicate()
					pickup_area.add_child(shape_copy)
		
		add_child(pickup_area)
		pickup_area.body_entered.connect(_on_body_entered)
		print("Created pickup area with Layer 3")
	
	# If parent is ResourceType, use its values if not specified
	if parent_object is ResourceType and item_name == "":
		item_name = parent_object.resource_name
		item_quantity = parent_object.amount

func _on_body_entered(body):
	if auto_pickup and body.name == "Player" and can_be_picked_up:
		trigger_pickup(body)

# Call this to trigger the pickup
func trigger_pickup(collector = null):
	if not can_be_picked_up:
		print("DEBUG: Item cannot be picked up")
		return
		
	# Special check for Crystal to ensure required items are consumed
	if item_name == "Crystal" and collector and collector.has_method("has_item"):
		var has_axe = collector.has_item("StoneAxe")
		var has_rune = collector.has_item("RuneStone")
		
		if not (has_axe and has_rune):
			print("DEBUG: Required items missing for Crystal pickup")
			# Show a message to the player
			var message_system = get_tree().get_first_node_in_group("MessageDisplay")
			if message_system and message_system.has_method("show_message"):
				message_system.show_message("You need a Stone Axe and a Rune Stone to collect the Crystal.")
			return
			
		# Consume the required items
		if collector.has_method("remove_from_inventory"):
			collector.remove_from_inventory("StoneAxe", 1)
			collector.remove_from_inventory("RuneStone", 1)
			print("DEBUG: Consumed StoneAxe and RuneStone for Crystal pickup")
	
	# Immediately hide the parent object
	if parent_object:
		parent_object.visible = false
		
	# Prepare the item data - THIS IS THE EXISTING CODE, KEEP AS IS
	var item_data = {
		"name": item_name if item_name != "" else parent_object.name,
		"quantity": item_quantity
	}
	
	print("DEBUG: PickupComponent trigger_pickup - Item: ", item_data.name, " Qty: ", item_data.quantity)
	
	# Play pickup sound if specified
	if pickup_sound_path != "":
		var sound = load(pickup_sound_path)
		if sound and collector:
			var audio = AudioStreamPlayer.new()
			audio.stream = sound
			collector.add_child(audio)
			audio.play()
			audio.finished.connect(func(): audio.queue_free())
	
	# If collector has inventory function, call it directly
	if collector and collector.has_method("add_to_inventory"):
		print("DEBUG: Found collector with add_to_inventory method: ", collector.name)
		print("DEBUG: Adding to collector's inventory: ", item_data.name)
		var success = collector.add_to_inventory(item_data.name, item_data.quantity)
		print("DEBUG: Item added successfully: ", success)
	else:
		print("DEBUG: Collector does not have add_to_inventory method or is null")
		if collector:
			print("DEBUG: Collector type: ", collector.get_class())
			print("DEBUG: Collector methods: ", collector.get_method_list())
	
	# Emit signal for inventory system to handle
	emit_signal("item_picked_up", item_data)
	print("Item picked up: ", item_data.name, " x", item_data.quantity)
	
	# Special handling for Crystal items
	if item_data.name == "Crystal":
		# Hide any reward sprites in hidden locations
		var locations = get_tree().get_nodes_in_group("HiddenLocations")
		for location in locations:
			var reward_sprite = location.get_node_or_null("RewardSprite")
			if reward_sprite:
				reward_sprite.visible = false
			var reward_sprite2 = location.get_node_or_null("RewardSprite2")
			if reward_sprite2:
				reward_sprite2.visible = false
	
	# Free the parent object (actual cleanup happens in the Resource script)
	if parent_object and parent_object != get_tree().get_root():
		parent_object.queue_free()

# Use this for manual pickup checks
func is_in_range(player_position, pickup_range: float = 20.0):
	if parent_object:
		return parent_object.global_position.distance_to(player_position) <= pickup_range
	return false

func disable_pickup():
	can_be_picked_up = false

func enable_pickup():
	can_be_picked_up = true
