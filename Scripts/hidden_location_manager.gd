extends Node
class_name HiddenLocationManager

# Configuration
@export var save_hidden_locations: bool = true

# Tracking
var discovered_locations = []
var completed_locations = []
var total_locations = 0

# Signals
signal all_locations_completed
signal location_discovered(location_id, location_name)
signal location_completed(location_id, location_name)
signal show_message(text)

func _ready():
	# Add to group for easy access
	add_to_group("HiddenLocationManager")
	
	# Find all hidden locations and connect signals
	await get_tree().process_frame
	_connect_locations()
	
	# Load saved state if enabled
	if save_hidden_locations:
		_load_state()

func _connect_locations():
	var locations = get_tree().get_nodes_in_group("HiddenLocations")
	total_locations = locations.size()
	
	print("HiddenLocationManager: Found " + str(total_locations) + " hidden locations")
	
	# Connect signals for each location
	for location in locations:
		location.location_discovered.connect(_on_location_discovered)
		location.location_completed.connect(_on_location_completed)
		location.show_message.connect(_on_show_message)

func _on_location_discovered(location_id, location_name):
	if location_id in discovered_locations:
		return
		
	discovered_locations.append(location_id)
	print("Location discovered: " + location_name + " (" + location_id + ")")
	
	# Forward the signal
	emit_signal("location_discovered", location_id, location_name)
	
	# Create a notification or HUD message
	_show_discovery_notification(location_name)
	
	# Save state if enabled
	if save_hidden_locations:
		_save_state()

func _on_location_completed(location_id, location_name):
	if location_id in completed_locations:
		return
		
	completed_locations.append(location_id)
	print("Location completed: " + location_name + " (" + location_id + ")")
	
	# Forward the signal
	emit_signal("location_completed", location_id, location_name)
	
	# Create a notification or HUD message
	_show_completion_notification(location_name)
	
	# Check if all locations are completed
	if completed_locations.size() >= total_locations:
		emit_signal("all_locations_completed")
		_show_all_completed_notification()
	
	# Save state if enabled
	if save_hidden_locations:
		_save_state()

func _on_show_message(text):
	# Forward the message to the UI system
	emit_signal("show_message", text)

func _show_discovery_notification(location_name):
	# Implement a nicer notification system
	var notification = "Discovered: " + location_name
	print(notification)
	# You would replace this with your game's notification system
	emit_signal("show_message", notification)

func _show_completion_notification(location_name):
	# Implement a nicer notification system
	var notification = "Completed: " + location_name
	print(notification)
	# You would replace this with your game's notification system
	emit_signal("show_message", notification)

func _show_all_completed_notification():
	var notification = "You have discovered all hidden locations!"
	print(notification)
	# You would replace this with your game's notification system
	emit_signal("show_message", notification)

# Count methods for UI display
func get_discovered_count():
	return discovered_locations.size()
	
func get_completed_count():
	return completed_locations.size()
	
func get_total_locations():
	return total_locations

# For game achievements or other special conditions
func has_discovered_location(location_id):
	return location_id in discovered_locations
	
func has_completed_location(location_id):
	return location_id in completed_locations
	
func has_discovered_all_locations():
	return discovered_locations.size() >= total_locations
	
func has_completed_all_locations():
	return completed_locations.size() >= total_locations

# Save/load location states (integrate with your save system)
func _save_state():
	var save_data = {
		"discovered_locations": discovered_locations,
		"completed_locations": completed_locations,
	}
	
	# This would need to be adapted to your save system
	print("HiddenLocationManager: Save state")
	# Example: SaveSystem.save_data("hidden_locations", save_data)

func _load_state():
	# This would need to be adapted to your save system
	print("HiddenLocationManager: Load state")
	# Example:
	# var save_data = SaveSystem.load_data("hidden_locations")
	# if save_data:
	#     discovered_locations = save_data.discovered_locations
	#     completed_locations = save_data.completed_locations
