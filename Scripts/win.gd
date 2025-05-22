extends Control

@export var visible_ui: Control  # Assign your main win Panel here
@export var animation_player: AnimationPlayer
var show_timer := Timer.new()

func _ready():
	# Hide this UI node and allow input to pass through
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if visible_ui:
		visible_ui.hide()
		visible_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set up the timer to delay showing the win panel
	show_timer.wait_time = 2.0
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(show_timer)
	
	# Delay finding the player to ensure the scene is fully loaded
	await get_tree().create_timer(0.5).timeout
	connect_to_player()
	
	# Also add self to WinScreen group for easier access
	add_to_group("WinScreen")

# Try to connect to the player
func connect_to_player():
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_signal("inventory_updated"):
		# Connect only if not already connected
		if not player.inventory_updated.is_connected(_check_for_crystal):
			player.inventory_updated.connect(_check_for_crystal)
			print("WinUI: Successfully connected to player's inventory_updated signal")
			
			# Check immediately in case player already has Crystal
			_check_for_crystal()
	else:
		print("WinUI: Player not found yet, will try again later")
		# Try again after a delay
		await get_tree().create_timer(1.0).timeout
		connect_to_player()

# Check if the player has acquired a Crystal
func _check_for_crystal():
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("has_item"):
		if player.has_item("Crystal"):
			_on_game_win()

func _on_game_win():
	# Don't trigger multiple times
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_signal("inventory_updated"):
		if player.inventory_updated.is_connected(_check_for_crystal):
			player.inventory_updated.disconnect(_check_for_crystal)
	
	# Show a congratulatory message
	var message_system = get_tree().get_first_node_in_group("MessageDisplay")
	if message_system and message_system.has_method("show_message"):
		message_system.show_message("You've found the Crystal! You win!")
	
	# Start the timer to show the win screen
	show_timer.start()

func _on_show_timer_timeout():
	# Enable this Control to capture input
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP

	if visible_ui:
		visible_ui.show()
		visible_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Play a fade-in animation
	if animation_player and animation_player.has_animation("show"):
		animation_player.play("show")
