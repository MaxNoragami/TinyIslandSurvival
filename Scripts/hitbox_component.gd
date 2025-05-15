extends Area2D
class_name HitboxComponent

@export var damage: float = 10.0
@export var knockback_force: float = 100.0

signal hit_landed(target)

func _ready():
    # Set up proper collision - only on Hitbox layer (2)
    # This should be done by default, but we'll set it explicitly
    collision_layer = 2  # Layer 2 (Hitbox)
    collision_mask = 2   # Only detect Layer 2 (Hitbox)
    
    # Connect signals to handle collisions
    area_entered.connect(_on_area_entered)
    body_entered.connect(_on_body_entered)

func _on_area_entered(area):
    if area.get_parent().has_method("take_damage"):
        area.get_parent().take_damage(damage)
        emit_signal("hit_landed", area.get_parent())
    
func _on_body_entered(body):
    if body.has_method("take_damage"):
        body.take_damage(damage)
        emit_signal("hit_landed", body)
        
func set_damage(new_damage):
    damage = new_damage

func apply_knockback(target, direction):
    if target is CharacterBody2D and target.has_method("apply_knockback"):
        target.apply_knockback(direction.normalized() * knockback_force)

# Call this if you need to change layers in code
func setup_collision(on_layer = 2, detect_layers = 2):
    collision_layer = on_layer
    collision_mask = detect_layers
