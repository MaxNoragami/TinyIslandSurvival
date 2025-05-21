extends Node
class_name InteractComponent

# Interaction settings
@export var interaction_message: String = "Press E to interact"
@export var interaction_range: float = 40.0
@export var show_interaction_prompt: bool = true
@export var single_use_interaction: bool = false

# State tracking
var player_in_range: bool = false
var has_been_interacted_with: bool = false
var player_ref = null

# Callback for when interaction happens
signal interaction_triggered(player)
signal player_entered_range(player)
signal player_exited_range(player)

func _ready():
	# Try to automatically find an Area2D child to use
	var interaction_area = get_node_or_null("InteractionArea")
	if interaction_area is Area2D:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)
	else:
		# If no Area2D found, create one
		create_interaction_area()
		
	# Add to Interactable group
	get_parent().add_to_group("Interactable")

func create_interaction_area():
	var area = Area2D.new()
	area.name = "InteractionArea"
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = interaction_range
	collision.shape = shape
	
	area.add_child(collision)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	add_child(area)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true
		player_ref = body
		emit_signal("player_entered_range", body)
		
		# Show interaction message
		if show_interaction_prompt and not has_been_interacted_with:
			var message_system = get_tree().get_first_node_in_group("MessageDisplay")
			if message_system:
				message_system.show_message(interaction_message)

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		player_ref = null
		emit_signal("player_exited_range", body)

func _input(event):
	# Process input only when player is in range
	if player_in_range and not has_been_interacted_with and event.is_action_pressed("interact"):
		interact()

func interact():
	if single_use_interaction and has_been_interacted_with:
		return
		
	emit_signal("interaction_triggered", player_ref)
	
	if single_use_interaction:
		has_been_interacted_with = true

# Call this from outside to trigger interaction
func external_interact(player=null):
	if player:
		player_ref = player
	interact()
	
# Reset interaction state (for reusable interactions)
func reset_interaction():
	has_been_interacted_with = false
