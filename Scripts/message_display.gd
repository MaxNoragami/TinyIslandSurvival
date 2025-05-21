extends Control
class_name MessageDisplay

@export var display_duration: float = 3.0
@export var fade_duration: float = 0.5

@onready var message_label = $MessageLabel
@onready var panel = $Panel

var messages_queue = []
var is_displaying = false

func _ready():
	add_to_group("MessageDisplay")
	# Hide initially
	message_label.text = ""
	panel.modulate.a = 0.0
	panel.visible = false
	
	# Connect to hidden location manager if available
	await get_tree().process_frame
	var location_manager = get_tree().get_first_node_in_group("HiddenLocationManager")
	if location_manager:
		location_manager.show_message.connect(_on_show_message)
	
	# Connect to any HiddenLocation nodes directly
	var locations = get_tree().get_nodes_in_group("HiddenLocations")
	for location in locations:
		location.show_message.connect(_on_show_message)

func _on_show_message(text):
	# Add message to queue
	messages_queue.append(text)
	
	# Start displaying if not already
	if not is_displaying:
		_display_next_message()

func _display_next_message():
	if messages_queue.size() == 0:
		is_displaying = false
		return
		
	is_displaying = true
	var message = messages_queue.pop_front()
	
	# Set text
	message_label.text = message
	
	# Make visible with fade
	panel.visible = true
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, fade_duration)
	
	# Wait for display duration
	await get_tree().create_timer(display_duration).timeout
	
	# Fade out
	tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func(): panel.visible = false)
	
	# Slight delay before next message
	await get_tree().create_timer(0.2).timeout
	
	# Display next message if any
	_display_next_message()
func show_message(text):
	# Add message to queue
	messages_queue.append(text)
	
	# Start displaying if not already
	if not is_displaying:
		_display_next_message()
