extends Control

@export var visible_ui: Control  # Assign your main game over Panel here
@export var animation_player: AnimationPlayer
var show_timer := Timer.new()

func _ready():
	# Hide this UI node and allow input to pass through
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if visible_ui:
		visible_ui.hide()
		visible_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set up the timer to delay showing the game over panel
	show_timer.wait_time = 3.0
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(show_timer)
	
	# Connect to the player's game_over signal
	var player = get_node_or_null("/root/Game/Player")
	if player:
		player.game_over.connect(_on_game_over)
	else:
		push_error("GameOverUI: Player not found in the scene tree")

func _on_game_over():
	show_timer.start()

func _on_show_timer_timeout():
	# Enable this Control to capture input
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP

	if visible_ui:
		visible_ui.show()
		visible_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Optionally play a fade-in animation
	if animation_player and animation_player.has_animation("show"):
		animation_player.play("show")
