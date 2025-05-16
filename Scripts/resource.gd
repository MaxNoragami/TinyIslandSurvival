extends Node
class_name ResourceType

@export var resource_name: String = "Wood"
@export var amount: int = 1
@export var health: int = 3  # How many hits it takes to harvest

var hitbox_component: HitboxComponent
var current_health: int

func _ready():
	# Find hitbox component automatically if it exists as a child
	hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
	current_health = health
	
	if hitbox_component:
		# Set up references and signals
		print("Resource found hitbox component")
		# Connect to the hitbox to detect when player touches it
		hitbox_component.body_entered.connect(_on_body_entered)
		
		# Make sure the hitbox can detect the player (layer 1)
		hitbox_component.collision_mask |= 1  # Add player layer to mask
	else:
		push_warning("Resource " + resource_name + " has no HitboxComponent - consider adding it as a child")
	
	# Make sure the PickupComponent has correct values
	var pickup = get_node_or_null("PickupComponent")
	if pickup:
		pickup.item_name = resource_name
		pickup.item_quantity = amount

# Called when the resource takes damage (e.g., from player's tool)
func take_damage(damage_amount: int = 1, damager = null):
	current_health -= damage_amount
	
	# Create a small visual effect to show damage
	_show_damage_effect()
	
	# Check if resource is depleted
	if current_health <= 0:
		collect(damager)  # Pass the damager as collector when depleted
		
# Called when a body (potentially the player) enters the hitbox
func _on_body_entered(body):
	print("DEBUG: Body entered: ", body.name, " is in group Player: ", body.is_in_group("Player"))
	
	# Check if it's the player
	if body.is_in_group("Player"):
		print("DEBUG: Player detected in hitbox")
		# Don't collect automatically, wait for player to interact
		# Uncomment the next line if you want automatic collection on contact
		# collect(body)

# Called when resource is destroyed/collected
func collect(collector = null):
	# This will be called when the resource is completely harvested
	print("Resource collected: ", resource_name, " x", amount)
	print("DEBUG: Collector is: ", collector.name if collector else "null")
	
	# Find the player if collector is null
	if collector == null:
		collector = get_tree().get_first_node_in_group("Player")
		print("DEBUG: Found player from group: ", collector.name if collector else "still null")
	
	# Create pickup effect
	_show_pickup_effect()
	
	# The PickupComponent handles the actual inventory integration
	var pickup = get_node_or_null("PickupComponent")
	if pickup:
		# Make sure the PickupComponent has the correct item information
		pickup.item_name = resource_name
		pickup.item_quantity = amount
		print("DEBUG: Calling trigger_pickup with collector: ", collector.name if collector else "null")
		pickup.trigger_pickup(collector)
		print("DEBUG: Using PickupComponent to add ", resource_name)
	else:
		# If the collector has an add_to_inventory method, call it directly
		if collector and collector.has_method("add_to_inventory"):
			print("DEBUG: Directly adding ", resource_name, " to inventory")
			var success = collector.add_to_inventory(resource_name, amount)
			print("DEBUG: Add to inventory success: ", success)
		else:
			print("DEBUG: No valid collector found to add item to inventory")
		# Destroy the resource
		queue_free()

func _show_damage_effect():
	# Simple visual feedback when resource is hit
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _show_pickup_effect():
	# Simple visual feedback when resource is picked up
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(self, "modulate:a", 0, 0.2)
