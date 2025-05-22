extends PickupComponent
class_name ClueItem

@export var clue_text: String = "There's something strange about those rocks to the west..."
@export var related_location_id: String = ""
@export var is_one_time_clue: bool = true # If true, this item disappears after giving its clue

# Override the parent _ready function
func _ready():
	super._ready() # Call the parent _ready function
	
	# Override any parent properties
	if item_name == "":
		# Determine name from filename if not set
		var filename = get_parent().name.to_lower()
		if "map" in filename:
			item_name = "AncientMap"
		elif "compass" in filename:
			item_name = "MagicCompass"
		elif "key" in filename:
			item_name = "StrangeKey"
		elif "stone" in filename or "rune" in filename:
			item_name = "RuneStone"

# Override the parent trigger_pickup to add clue functionality
func trigger_pickup(collector = null):
	if not can_be_picked_up:
		return
		
	# Handle the clue behavior
	if collector and collector.is_in_group("Player"):
		# Show clue message
		var message_system = get_tree().get_first_node_in_group("MessageDisplay")
		if message_system:
			message_system.show_message("You found a clue item: " + item_name)
			
			# Show the actual clue after a delay
			await get_tree().create_timer(1.5).timeout
			message_system.show_message(clue_text)
		
		# Notify the clue system
		var clue_system = get_tree().get_first_node_in_group("ClueSystem")
		if clue_system:
			clue_system.emit_signal("clue_collected", related_location_id, clue_text)
		
		# If this is a one-time clue that doesn't add to inventory
		if is_one_time_clue:
			# Play pickup effects but don't add to inventory
			print("One-time clue item picked up: " + item_name)
			
			# Play pickup sound if specified
			if pickup_sound_path != "":
				var sound = load(pickup_sound_path)
				if sound and collector:
					var audio = AudioStreamPlayer.new()
					audio.stream = sound
					collector.add_child(audio)
					audio.play()
					audio.finished.connect(func(): audio.queue_free())
			
			# Free the parent object
			if parent_object and parent_object != get_tree().get_root():
				parent_object.queue_free()
				
			return
	
	# For inventory items, call the parent pickup method
	super.trigger_pickup(collector)
