extends State
class_name MoveState

func enter():
    # Set movement animation
    print("Entering move state with direction: " + player.facing_direction)
    player.play_animation("walk")

func physics_process_state(delta):
    # Handle movement
    var is_moving = player.handle_movement()
    
    if not is_moving:
        print("No longer moving, transitioning to idle")
        transition_to("IdleState")
    else:
        # Update animation in case direction changed
        player.play_animation("walk")
