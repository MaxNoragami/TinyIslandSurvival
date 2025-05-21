extends State
class_name IdleState

func enter():
	# Reset velocity when entering idle state
	player.velocity = Vector2.ZERO
	
	# Set idle animation based on the current facing direction
	print("Entering idle state with direction: " + player.facing_direction)
	player.play_animation("idle")

func physics_process_state(delta):
	# Check for movement input
	var is_moving = player.handle_movement()
	if is_moving:
		print("Starting to move, transitioning to move state")
		transition_to("MoveState")
