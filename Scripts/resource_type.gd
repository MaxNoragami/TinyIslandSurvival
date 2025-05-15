extends Node
class_name ResourceType

@export var resource_name: String = "Wood"
@export var amount: int = 1

var hitbox_component: HitboxComponent

func _ready():
    # Find hitbox component automatically if it exists as a child
    hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
    
    if hitbox_component:
        # Set up references and signals for pickup detection
        print("Resource found hitbox component")
        # Connect to the hitbox to detect when player touches it
        hitbox_component.body_entered.connect(_on_body_entered)
        
        # Make sure the hitbox can detect the player (layer 1)
        hitbox_component.collision_mask |= 1  # Add player layer to mask
    else:
        push_warning("Resource " + resource_name + " has no HitboxComponent - consider adding it as a child")

# Called when a body (potentially the player) enters the hitbox
func _on_body_entered(body):
    if body.name == "Player" or body.is_in_group("Player"):
        collect(body)
        
# Called when resource is collected by the player
func collect(collector = null):
    # This will be called when the resource is picked up
    print("Resource collected: ", resource_name, " x", amount)
    
    # Create pickup effect
    _show_pickup_effect()
    
    # The PickupComponent handles the actual inventory integration
    var pickup = get_node_or_null("PickupComponent")
    if pickup:
        pickup.trigger_pickup(collector)
    else:
        # If the collector has an add_to_inventory method, call it directly
        if collector and collector.has_method("add_to_inventory"):
            collector.add_to_inventory(resource_name, amount)
        # Destroy the resource
        queue_free()

func _show_pickup_effect():
    # Simple visual feedback when resource is picked up
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
    tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
    tween.tween_property(self, "modulate:a", 0, 0.2)
