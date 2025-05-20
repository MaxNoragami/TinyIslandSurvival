
extends Control

@export var visible_ui: Control  # Drag your Panel here in the editor
@export var animation_player :AnimationPlayer
var show_timer := Timer.new()

func _ready():
	# Hide initially and ignore input
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if visible_ui:
		visible_ui.hide()
		visible_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Timer to delay UI
	show_timer.wait_time = 3.0
	show_timer.one_shot = true
	show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(show_timer)
	
	# Connect to player game_over
	var player = get_node_or_null("/root/Game/Player")
	if player:
		player.game_over.connect(_on_game_over)
	else:
		push_error("GameOverUI: Player not found.")

func _on_game_over():
	show_timer.start()

func _on_show_timer_timeout():
	show()
	animation_player.play("show")
	if visible_ui:
		visible_ui.show()
		visible_ui.mouse_filter = Control.MOUSE_FILTER_STOP  # Now allow interaction
