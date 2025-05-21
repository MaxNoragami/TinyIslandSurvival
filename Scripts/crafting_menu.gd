extends Control

@onready var out_margin = $OutMargin
@onready var grid_container = $OutMargin/CraftBg/InMargin/MainHBoxContainer/GridContainer

# Track currently selected slot
var currently_selected_slot = null
var craft_slots = []
var player_ref = null

# For cycling through inventory items
var current_item_index = 0
var available_items = []

# Track used items across craft slots
var used_items = {}

# Resource textures and regions mapping (copied from inventory.gd for consistency)
const resource_data = {
	"Wood": {"texture": "res://Assets/Icons/16x16.png", "region": Rect2(144, 192, 16, 16)},
	"Rock": {"texture": "res://Assets/Icons/16x16.png", "region": Rect2(160, 304, 16, 16)},
	"StoneAxe": {"texture": "res://Assets/Icons/16x16.png", "region": Rect2(240, 1456, 16, 16)},
	"StoneSword": {"texture": "res://Assets/Icons/16x16.png", "region": Rect2(176, 1760, 16, 16)},
	"StonePickaxe": {"texture": "res://Assets/Icons/16x16.png", "region": Rect2(16, 1456, 16, 16)},
	# Add more resources here as needed
}

# Define crafting recipes - each recipe is a dictionary with:
# - pattern: a 3x3 grid of item names (empty string for empty slots)
# - result: the item that will be crafted
# - count: how many of the result item will be produced
var recipes = [
	{
		"pattern": [
			"Rock", "Rock", "",
			"Rock", "Wood", "",
			"", "Wood", ""
		],
		"result": "StoneAxe",
		"count": 1
	},
	{
		"pattern": [
			"", "Rock", "Rock",
			"", "Rock", "Wood",
			"", "", "Wood"
		],
		"result": "StoneAxe",
		"count": 1
	},
	{
		"pattern": [
			"", "Rock", "Rock",
			"", "Wood", "Rock",
			"", "Wood", ""
		],
		"result": "StoneAxe",
		"count": 1
	},
	{
		"pattern": [
			"Rock", "Rock", "",
			"Wood", "Rock", "",
			"Wood", "", ""
		],
		"result": "StoneAxe",
		"count": 1
	},
	{
		"pattern": [
			"Rock", "Rock", "Rock",
			"", "Wood", "",
			"", "Wood", ""
		],
		"result": "StonePickaxe",
		"count": 1
	}
]

# Reference to the result slot
var result_slot = null

func _ready():
	# Add self to CraftMenu group for easy access
	add_to_group("CraftMenu")
	
	# Make sure the crafting menu is initially hidden and doesn't block mouse
	if out_margin:
		out_margin.visible = false
		out_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make sure the entire control doesn't block mouse when not visible
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Get all craft slots and connect their toggle buttons
	if grid_container:
		for child in grid_container.get_children():
			if "CraftSlot" in child.name:
				craft_slots.append(child)
				
				# Connect the button toggled signal
				var button = child.get_node_or_null("Button")
				if button:
					button.toggled.connect(_on_craft_slot_toggled.bind(child))
	
	# Get reference to result slot
	result_slot = $OutMargin/CraftBg/InMargin/MainHBoxContainer/SubHBoxContainer/ResultSlot
	
	# Disable toggle mode for the result slot button
	if result_slot:
		var result_button = result_slot.get_node_or_null("Button")
		if result_button:
			result_button.toggle_mode = false
			# Connect to pressed signal instead of toggled
			result_button.pressed.connect(_on_result_slot_pressed)
		
		# Connect the drop button signal for the result slot
		var drop_button = result_slot.get_node_or_null("DropButton")
		if drop_button:
			drop_button.pressed.connect(_on_result_drop_button_pressed)
	
	# Find the player for inventory access
	find_player()

func find_player():
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("Player")
	
	if not player_ref:
		print("CraftMenu: Could not find player")

func _input(event):
	# Check if the open_crafting key was just pressed
	if event.is_action_pressed("open_crafting"):
		toggle_crafting_menu()
	
	# Handle item cycling for the selected craft slot
	if currently_selected_slot and out_margin.visible:
		if event.is_action_pressed("next_item"):
			cycle_to_next_item()
		elif event.is_action_pressed("prev_item"):
			cycle_to_prev_item()

func toggle_crafting_menu():
	# Toggle the visibility of the OutMargin
	if out_margin:
		out_margin.visible = !out_margin.visible
		
		# Update mouse filters based on visibility
		if out_margin.visible:
			# If we're opening the crafting menu, close the inventory if it's open
			var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
			if inventory_ui and inventory_ui.out_margin.visible:
				inventory_ui.toggle_inventory()
			
			# Set appropriate mouse filters when visible
			out_margin.mouse_filter = Control.MOUSE_FILTER_STOP
			mouse_filter = Control.MOUSE_FILTER_STOP
			
			# Refresh available items when opening
			if currently_selected_slot:
				refresh_available_items()
			
			# Check if any recipe matches the current pattern
			check_crafting_pattern()
		else:
			# Ensure mouse events pass through when hidden
			out_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			# Clear selection when closing the menu
			clear_all_selections()

# Handle craft slot toggle
func _on_craft_slot_toggled(button_pressed, slot):
	if button_pressed:
		# Untoggle all other slots to ensure only one is selected
		for other_slot in craft_slots:
			if other_slot != slot:
				var other_button = other_slot.get_node_or_null("Button")
				if other_button and other_button.button_pressed:
					# Disconnect temporarily to avoid recursive toggling
					other_button.toggled.disconnect(_on_craft_slot_toggled.bind(other_slot))
					other_button.button_pressed = false
					# Reconnect the signal
					other_button.toggled.connect(_on_craft_slot_toggled.bind(other_slot))
		
		# Update the currently selected slot
		currently_selected_slot = slot
		
		# Refresh items available for cycling
		refresh_available_items()
	else:
		# If this was the selected slot, clear selection
		if currently_selected_slot == slot:
			currently_selected_slot = null
			available_items = []
			current_item_index = 0

# Refresh the list of available items from player inventory
func refresh_available_items():
	available_items = []
	current_item_index = 0
	
	# Add a "nothing" option (represented by empty string) as the first item
	available_items.append("")
	
	if player_ref:
		var inventory = player_ref.get_inventory()
		
		# Recalculate used items to ensure accuracy
		recalculate_used_items()
		
		# Create a list of items for cycling
		for item_name in inventory:
			if resource_data.has(item_name):
				# Only add if we have some available after accounting for used items
				var used = get_used_count(item_name)
				var total = inventory[item_name]
				var available_count = total - used
				
				if available_count > 0:
					available_items.append(item_name)
		
		# If we have a previous item in this slot, try to retain it
		if currently_selected_slot and currently_selected_slot.has_meta("item_name"):
			var current_item = currently_selected_slot.get_meta("item_name")
			if current_item != "":
				# Check if we still have this item available
				if current_item in inventory:
					var count = inventory[current_item] - get_used_count(current_item, currently_selected_slot)
					if count > 0:
						# Move the current item to the front of the list (after "nothing")
						if current_item in available_items:
							available_items.erase(current_item)
						available_items.insert(1, current_item)  # Insert after "nothing"
						current_item_index = 1  # Select the item
						update_craft_slot_display(current_item)
						return
				
				# If the item is no longer available, clear this slot
				clear_craft_slot_display()
				return
		
		# Otherwise start with "nothing" selected
		current_item_index = 0
		clear_craft_slot_display()
	else:
		print("CraftMenu: No player reference to get inventory from")

# Update the display of the selected craft slot with an item
func update_craft_slot_display(item_name):
	if currently_selected_slot:
		# If changing from an existing item, update used_items tracking
		if currently_selected_slot.has_meta("item_name"):
			var old_item = currently_selected_slot.get_meta("item_name")
			if old_item != "":
				remove_used_item(old_item)
		
		var sprite = currently_selected_slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
		var label = currently_selected_slot.get_node_or_null("Label")
		
		if item_name == "":
			# Empty slot case
			if sprite:
				sprite.texture = null
				sprite.region_enabled = false
			
			if label:
				label.text = ""
			
			currently_selected_slot.set_meta("item_name", "")
		elif resource_data.has(item_name):
			# Item case
			if sprite:
				sprite.texture = load(resource_data[item_name]["texture"])
				sprite.region_enabled = true
				sprite.region_rect = resource_data[item_name]["region"]
			
			if label:
				# Always show "1" for the quantity in this slot (representing 1 item used here)
				label.text = "1"
			
			# Store item name in the slot and track it as used
			currently_selected_slot.set_meta("item_name", item_name)
			add_used_item(item_name)
		
		# Update all slot displays to show correct counts and check availability
		update_all_slot_displays()
		
		# Check if the new pattern creates a valid recipe
		check_crafting_pattern()

# Clear the display of the selected craft slot
func clear_craft_slot_display():
	if currently_selected_slot:
		# If slot had an item, remove it from used tracking
		if currently_selected_slot.has_meta("item_name"):
			var old_item = currently_selected_slot.get_meta("item_name")
			if old_item != "":
				remove_used_item(old_item)
		
		var sprite = currently_selected_slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
		var label = currently_selected_slot.get_node_or_null("Label")
		
		if sprite:
			sprite.texture = null
			sprite.region_enabled = false
		
		if label:
			label.text = ""
		
		currently_selected_slot.set_meta("item_name", "")
		
		# Update all other slots to show correct counts
		update_all_slot_displays()
		
		# Check if the pattern still creates a valid recipe
		check_crafting_pattern()

# Cycle to the next item in the inventory
func cycle_to_next_item():
	if available_items.size() > 0:
		current_item_index = (current_item_index + 1) % available_items.size()
		var item = available_items[current_item_index]
		
		if item == "":
			clear_craft_slot_display()
		else:
			update_craft_slot_display(item)

# Cycle to the previous item in the inventory
func cycle_to_prev_item():
	if available_items.size() > 0:
		current_item_index = (current_item_index - 1 + available_items.size()) % available_items.size()
		var item = available_items[current_item_index]
		
		if item == "":
			clear_craft_slot_display()
		else:
			update_craft_slot_display(item)

# Clear all slot selections
func clear_all_selections():
	for slot in craft_slots:
		var button = slot.get_node_or_null("Button")
		if button and button.button_pressed:
			button.button_pressed = false
		
		# Also clear the item from the slot completely
		if slot.has_meta("item_name"):
			var sprite = slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
			var label = slot.get_node_or_null("Label")
			
			if sprite:
				sprite.texture = null
				sprite.region_enabled = false
			
			if label:
				label.text = ""
			
			slot.set_meta("item_name", "")
	
	# Reset used items tracking
	used_items.clear()
	
	# Clear the result slot too
	clear_result_slot()
	
	currently_selected_slot = null
	available_items = []
	current_item_index = 0

# Add an item to the used items tracking
func add_used_item(item_name):
	if item_name != "":
		if item_name in used_items:
			used_items[item_name] += 1
		else:
			used_items[item_name] = 1

# Remove an item from used items tracking
func remove_used_item(item_name):
	if item_name != "":
		if item_name in used_items:
			used_items[item_name] -= 1
			if used_items[item_name] <= 0:
				used_items.erase(item_name)

# Get count of how many of an item are used in craft slots
# Optionally exclude a specific slot from the count
func get_used_count(item_name, exclude_slot = null):
	if item_name == "":
		return 0
		
	var count = 0
	
	# Count from our usage tracking
	if item_name in used_items:
		count = used_items[item_name]
	
	# If we're excluding a slot and it has this item, reduce the count
	if exclude_slot and exclude_slot.has_meta("item_name") and exclude_slot.get_meta("item_name") == item_name:
		count -= 1
		
	return max(0, count) # Ensure we don't return negative values

# Recalculate used items by scanning all craft slots
func recalculate_used_items():
	# Clear and rebuild the used_items dictionary
	used_items.clear()
	
	for slot in craft_slots:
		if slot.has_meta("item_name"):
			var item_name = slot.get_meta("item_name")
			if item_name != "":
				add_used_item(item_name)

# Update the displays of all craft slots to show correct counts
func update_all_slot_displays():
	if !player_ref:
		return
		
	var inventory = player_ref.get_inventory()
	
	# Make sure our used items tracking is accurate
	recalculate_used_items()
	
	# First check which slots need to be emptied due to insufficient items
	for slot in craft_slots:
		if slot.has_meta("item_name"):
			var item_name = slot.get_meta("item_name")
			if item_name != "" and item_name in inventory:
				# Calculate total remaining not counting this slot
				var total_available = inventory[item_name]
				var total_used = get_used_count(item_name)
				var slot_has_item = 1
				
				# If we're using more than we have, this slot must be emptied
				if total_used > total_available and slot != currently_selected_slot:
					# Clear this slot
					var button = slot.get_node_or_null("Button")
					if button and button.button_pressed:
						button.button_pressed = false
					
					var sprite = slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
					var label = slot.get_node_or_null("Label")
					
					if sprite:
						sprite.texture = null
						sprite.region_enabled = false
					
					if label:
						label.text = ""
					
					remove_used_item(item_name)
					slot.set_meta("item_name", "")
	
	# Now display the remaining counter in the bottom right of each slot
	var remaining_items = {}
	for item_name in inventory:
		remaining_items[item_name] = inventory[item_name] - get_used_count(item_name)
	
	# Update slot displays with remaining item counts
	for slot in craft_slots:
		# Skip slot if it's empty or invalid
		if !slot.has_meta("item_name") or slot.get_meta("item_name") == "":
			continue
			
		var item_name = slot.get_meta("item_name")
		if item_name in inventory:
			var remaining = remaining_items[item_name]
			var label = slot.get_node_or_null("Label")
			
			# Show actually used slots with "1" and add a subtle indicator for remaining items
			if label:
				label.text = "1"

# Check if the current pattern of items in craft slots matches any known recipes
func check_crafting_pattern():
	if !result_slot:
		return
	
	# Get current pattern of items in the crafting grid
	var current_pattern = []
	for slot in craft_slots:
		var item_name = ""
		if slot.has_meta("item_name"):
			item_name = slot.get_meta("item_name")
		current_pattern.append(item_name)
	
	# Check if current pattern matches any recipe
	var matched_recipe = null
	for recipe in recipes:
		var matches = true
		for i in range(recipe.pattern.size()):
			if i >= current_pattern.size():
				matches = false
				break
			
			# If recipe requires an item but slot is empty, not a match
			if recipe.pattern[i] != "" and current_pattern[i] == "":
				matches = false
				break
			
			# If recipe requires a specific item and slot has a different item, not a match
			if recipe.pattern[i] != "" and recipe.pattern[i] != current_pattern[i]:
				matches = false
				break
		
		if matches:
			matched_recipe = recipe
			break
	
	# Update the result slot based on whether a recipe was matched
	if matched_recipe:
		update_result_slot(matched_recipe.result, matched_recipe.count)
	else:
		clear_result_slot()

# Update the result slot with a crafted item
func update_result_slot(item_name, count):
	if !result_slot:
		return
	
	var sprite = result_slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
	var label = result_slot.get_node_or_null("Label")
	var drop_button = result_slot.get_node_or_null("DropButton")
	
	if sprite and resource_data.has(item_name):
		sprite.texture = load(resource_data[item_name]["texture"])
		sprite.region_enabled = true
		sprite.region_rect = resource_data[item_name]["region"]
	
	if label:
		label.text = str(count)
	
	# Store the result item data in the slot for reference when crafting
	result_slot.set_meta("item_name", item_name)
	result_slot.set_meta("item_count", count)
	
	# Show the drop button
	if drop_button:
		drop_button.visible = true

# Clear the result slot
func clear_result_slot():
	if !result_slot:
		return
	
	var sprite = result_slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
	var label = result_slot.get_node_or_null("Label")
	var drop_button = result_slot.get_node_or_null("DropButton")
	
	if sprite:
		sprite.texture = null
		sprite.region_enabled = false
	
	if label:
		label.text = ""
	
	# Clear item data
	if result_slot.has_meta("item_name"):
		result_slot.remove_meta("item_name")
	if result_slot.has_meta("item_count"):
		result_slot.remove_meta("item_count")
	
	# Hide drop button
	if drop_button:
		drop_button.visible = false

# Handle result slot button press (add to inventory)
func _on_result_slot_pressed():
	if !result_slot or !result_slot.has_meta("item_name") or !player_ref:
		return
	
	var item_name = result_slot.get_meta("item_name")
	var count = 1
	if result_slot.has_meta("item_count"):
		count = result_slot.get_meta("item_count")
	
	# Add the crafted item to inventory
	if player_ref.has_method("add_to_inventory"):
		var success = player_ref.add_to_inventory(item_name, count)
		
		if success:
			# Remove used materials from inventory
			consume_crafting_materials()
			
			# Clear the result slot
			clear_result_slot()
			
			# Update the craft grid display
			update_all_slot_displays()
			
			print("Crafted and added to inventory: ", item_name, " x", count)

# Handle result slot drop button press (drop in world)
func _on_result_drop_button_pressed():
	if !result_slot or !result_slot.has_meta("item_name") or !player_ref:
		return
	
	var item_name = result_slot.get_meta("item_name")
	
	# Spawn the crafted item in the world
	spawn_crafted_item(item_name)
	
	# Remove used materials from inventory
	consume_crafting_materials()
	
	# Clear the result slot
	clear_result_slot()
	
	# Update the craft grid display
	update_all_slot_displays()
	
	print("Crafted and dropped: ", item_name)

# Consume materials used in crafting
func consume_crafting_materials():
	if !player_ref:
		return
	
	# Get the items used in the crafting grid
	var items_to_consume = {}
	for slot in craft_slots:
		if slot.has_meta("item_name"):
			var item_name = slot.get_meta("item_name")
			if item_name != "":
				if item_name in items_to_consume:
					items_to_consume[item_name] += 1
				else:
					items_to_consume[item_name] = 1
	
	# Remove used items from inventory
	for item_name in items_to_consume:
		var amount = items_to_consume[item_name]
		if player_ref.has_method("remove_from_inventory"):
			player_ref.remove_from_inventory(item_name, amount)
	
	# Clear the crafting grid
	for slot in craft_slots:
		if slot.has_meta("item_name"):
			var item_name = slot.get_meta("item_name")
			if item_name != "":
				var sprite = slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
				var label = slot.get_node_or_null("Label")
				
				if sprite:
					sprite.texture = null
					sprite.region_enabled = false
				
				if label:
					label.text = ""
				
				slot.set_meta("item_name", "")

# Spawn a crafted item in the world
func spawn_crafted_item(item_name):
	if !player_ref:
		return
	
	# Get the scene path from inventory
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if !inventory_ui or !inventory_ui.item_scenes.has(item_name):
		push_warning("Could not find scene for item: " + item_name)
		return
	
	var scene_path = inventory_ui.item_scenes[item_name]
	var item_scene = load(scene_path)
	if !item_scene:
		push_warning("Failed to load scene for item: " + item_name)
		return
	
	# Instance the scene
	var item_instance = item_scene.instantiate()
	
	# Calculate random position around player
	var random_angle = randf() * 2 * PI
	var random_distance = randf_range(20, 40)
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	
	# Set the position
	item_instance.position = player_ref.global_position + offset
	
	# Add to the world
	var world = player_ref.get_parent()
	if world:
		var pickable_items = world.get_node_or_null("PickableItems")
		
		if pickable_items:
			var category_name = item_name + "Items"
			var category = pickable_items.get_node_or_null(category_name)
			
			if category:
				category.add_child(item_instance)
			else:
				var other_items = pickable_items.get_node_or_null("OtherItems")
				if other_items:
					other_items.add_child(item_instance)
				else:
					pickable_items.add_child(item_instance)
		else:
			world.add_child(item_instance)
			
		print("Spawned crafted " + item_name + " at position " + str(item_instance.position))
	else:
		push_warning("Could not find a valid parent for crafted item")
		item_instance.queue_free()
