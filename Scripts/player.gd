extends CharacterBody2D

@export var move_speed: float = 100.0

# Component references
var health_component
var hitbox_component
var state_machine
var sprite

# Last direction for animation purposes
var facing_direction = "front"
var last_animation = ""

# Inventory system
var inventory = {}
@export var max_stack_size: int = 99

func _ready():
    # Get references to components
    health_component = $HealthComponent if has_node("HealthComponent") else null
    hitbox_component = $HitboxComponent if has_node("HitboxComponent") else null
    sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
    
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

func _physics_process(delta):
    # Let the state machine handle most of the logic
    if state_machine == null:
        # Fallback if no state machine is present
        handle_movement()

# Movement logic that can be called from states
func handle_movement():
    var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    
    # Normalize to prevent faster diagonal movement
    if input_direction.length() > 0:
        input_direction = input_direction.normalized()
        update_facing_direction(input_direction)
    
    velocity = input_direction * move_speed
    move_and_slide()
    
    return input_direction.length() > 0
    
# Update the facing direction based on movement
func update_facing_direction(direction):
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
        if state_name.begins_with("idle"):
            play_animation("idle")
        elif state_name.begins_with("move"):
            play_animation("walk")

# Play animation based on state and direction
func play_animation(state_name):
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
func take_damage(amount):
    if health_component:
        health_component.take_damage(amount)
        if not health_component.is_alive():
            die()
    
# Handle healing
func heal(amount):
    if health_component:
        health_component.heal(amount)
        
# Handle death
func die():
    if sprite and sprite.sprite_frames.has_animation("death"):
        sprite.play("death")
    # Could add more death handling logic here
    
# Apply knockback when hit
func apply_knockback(direction):
    velocity = direction
    move_and_slide()

# Inventory management
func add_to_inventory(item_name: String, amount: int = 1):
    if item_name in inventory:
        inventory[item_name] = min(inventory[item_name] + amount, max_stack_size)
    else:
        inventory[item_name] = amount
    
    print("Added to inventory: ", item_name, " x", amount)
    print("Inventory: ", inventory)
    
    # You could emit a signal here for UI updates
    
func remove_from_inventory(item_name: String, amount: int = 1):
    if item_name in inventory:
        inventory[item_name] -= amount
        
        if inventory[item_name] <= 0:
            # Remove the item completely if amount is zero or negative
            inventory.erase(item_name)
        
        print("Removed from inventory: ", item_name, " x", amount)
        print("Inventory: ", inventory)
        return true
    return false

func has_item(item_name: String, amount: int = 1):
    return item_name in inventory and inventory[item_name] >= amount
    
func get_inventory():
    return inventory
