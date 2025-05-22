extends Node
class_name ClueSystem

# Configuration
@export var clue_items = {
	"AncientMap": {
		"texture": "res://Assets/Icons/16x16.png", 
		"region": Rect2(176, 304, 16, 16), # Adjust region for map icon
		"scene": "res://Scenes/ancient_map.tscn"
	},
	"MagicCompass": {
		"texture": "res://Assets/Icons/16x16.png", 
		"region": Rect2(80, 1056, 16, 16), # Adjust region for compass icon
		"scene": "res://Scenes/magic_compass.tscn"
	},
	"StrangeKey": {
		"texture": "res://Assets/Icons/16x16.png", 
		"region": Rect2(48, 1104, 16, 16), # Adjust region for key icon
		"scene": "res://Scenes/strange_key.tscn"
	},
	"RuneStone": {
		"texture": "res://Assets/Icons/16x16.png", 
		"region": Rect2(112, 432, 16, 16), # Adjust region for stone icon
		"scene": "res://Scenes/rune_stone.tscn"
	}
}

# Riddles and clues to different locations
@export var location_clues = {
	"cave_1": [
		"Where sun casts shadows twice at noon, the entrance will reveal itself.",
		"Look for strange rock formations near the western shore.",
		"The cave of echoes only opens to those who wield tools of stone."
	],
	"ancient_temple": [
		"Four stones in a circle mark the place of old worship.",
		"Only when the moon is high will the temple stones glow.",
		"The path opens for those who bring offerings of gold."
	],
	"abandoned_mine": [
		"Birds fear to nest where the earth once bled iron.",
		"The mine entrance is hidden behind a waterfall to the east.",
		"Only the sound of pickaxe on stone will awaken the tunnel."
	],
	"sunken_ship": [
		"Half-buried in sand where tides no longer reach.",
		"The ship's mast points to the morning star.",
		"Treasures await those who can breathe beneath the waves."
	]
}

# Signals
signal clue_collected(clue_id, text)

func _ready():
	# Register to the inventory system to know when clue items are picked up
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_signal("inventory_updated"):
		player.inventory_updated.connect(_check_for_new_clue_items)
	
	# Add all clue items to the inventory system's resource data
	_register_clue_items_with_inventory()

func _register_clue_items_with_inventory():
	# Get the inventory system
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if not inventory_ui:
		print("ClueSystem: Couldn't find InventoryUI")
		return
	
	# Add our clue items to their resource_data dictionary
	# NOTE: This assumes their resource_data is accessible, which might not be the case
	# Alternatively, you could modify the inventory.gd file directly to include these items
	
	print("ClueSystem: Registering clue items with inventory")
	
	# Example of how you WOULD add them if resource_data was accessible:
	# for item_name in clue_items:
	#     var item_data = clue_items[item_name]
	#     inventory_ui.resource_data[item_name] = {
	#         "texture": item_data.texture,
	#         "region": item_data.region
	#     }
	#     
	#     # Also add to item_scenes
	#     if "scene" in item_data:
	#         inventory_ui.item_scenes[item_name] = item_data.scene
	
	# Since we can't modify their dictionaries at runtime, you should manually add
	# these items to inventory.gd's resource_data and item_scenes dictionaries

func _check_for_new_clue_items():
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
		
	var inventory = player.get_inventory()
	
	# Check for clue items
	for item_name in clue_items.keys():
		if inventory.has(item_name) and inventory[item_name] > 0:
			_process_clue_item(item_name)

func _process_clue_item(item_name):
	print("ClueSystem: Processing clue item " + item_name)
	
	# Determine which location this item gives clues for
	var location_id = ""
	match item_name:
		"AncientMap":
			location_id = "cave_1"
		"MagicCompass":
			location_id = "ancient_temple"
		"StrangeKey":
			location_id = "abandoned_mine"
		"RuneStone":
			location_id = "sunken_ship"
	
	if location_id == "":
		return
		
	# Get a random clue for this location
	if location_clues.has(location_id) and location_clues[location_id].size() > 0:
		var clues = location_clues[location_id]
		var clue_text = clues[randi() % clues.size()]
		
		# Emit signal for UI to display
		emit_signal("clue_collected", location_id, clue_text)
		
		# Display the clue
		var message_system = get_tree().get_first_node_in_group("MessageDisplay")
		if message_system:
			message_system.show_message("Clue discovered: " + clue_text)
		else:
			print("ClueSystem: Clue discovered - " + clue_text)

# Function to directly give a hint about a specific location
func give_hint_for_location(location_id):
	if not location_clues.has(location_id) or location_clues[location_id].size() == 0:
		return
		
	var clues = location_clues[location_id]
	var clue_text = clues[randi() % clues.size()]
	
	# Emit signal for UI
	emit_signal("clue_collected", location_id, clue_text)
	
	# Display the clue
	var message_system = get_tree().get_first_node_in_group("MessageDisplay")
	if message_system:
		message_system.show_message("Hint: " + clue_text)
	else:
		print("ClueSystem: Hint - " + clue_text)

# Add method to place a clue item in the world at a specific position
func spawn_clue_item(item_name, position):
	if not clue_items.has(item_name):
		print("ClueSystem: Unknown clue item " + item_name)
		return null
		
	var scene_path = clue_items[item_name].get("scene", "")
	if scene_path == "":
		print("ClueSystem: No scene defined for " + item_name)
		return null
		
	var scene = load(scene_path)
	if not scene:
		print("ClueSystem: Failed to load scene for " + item_name)
		return null
		
	var instance = scene.instantiate()
	instance.global_position = position
	
	# Add to appropriate parent
	var world = get_tree().get_first_node_in_group("World") 
	if world:
		var pickable_items = world.get_node_or_null("PickableItems")
		if pickable_items:
			pickable_items.add_child(instance)
		else:
			world.add_child(instance)
	
	return instance
