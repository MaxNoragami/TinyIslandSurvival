extends Control

@onready var progress_bar = $MarginContainer/ProgressBar

# The player has 200 HP but we display it as if it were 100%
const HEALTH_SCALE_FACTOR = 0.5

func _ready():
	# Initialize the progress bar
	progress_bar.max_value = 100
	progress_bar.value = 100
	
	# Find the player and connect to health signals
	call_deferred("connect_to_player")

# Using call_deferred to ensure all nodes are ready
func connect_to_player():
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Try to connect to health component signal first
		var health_component = player.get_node_or_null("HealthComponent")
		if health_component and health_component.has_signal("health_changed"):
			if not health_component.health_changed.is_connected(_on_player_health_changed):
				health_component.health_changed.connect(_on_player_health_changed)
				print("Health bar connected to player health component signal")
		else:
			# No health component or signal, fall back to process monitoring
			set_process(true)
			print("Health bar using process monitoring for player health")

func _process(delta):
	# Fallback method: directly monitor player health
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		update_health_display(player.health)

func _on_player_health_changed(new_health):
	# This handles the signal from the health component
	update_health_display(new_health)

func update_health_display(health_value):
	# Convert raw health value (0-200) to progress bar scale (0-100)
	var scaled_health = health_value * HEALTH_SCALE_FACTOR
	
	# Clamp to ensure we stay within progress bar range
	scaled_health = clamp(scaled_health, 0, 100)
	
	# Update the progress bar
	progress_bar.value = scaled_health
	
	# Optional: Update color based on health level
	if scaled_health < 25:
		# Low health - red
		progress_bar.get("theme_override_styles/fill").bg_color = Color(0.8, 0.2, 0.2)
	elif scaled_health < 50:
		# Medium health - orange/yellow
		progress_bar.get("theme_override_styles/fill").bg_color = Color(0.9, 0.7, 0.2)
	else:
		# Good health - green
		progress_bar.get("theme_override_styles/fill").bg_color = Color(0.47, 0.75, 0.21)
