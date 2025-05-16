extends Node

@onready var out_margin = $OutMargin
@onready var grid_container = $OutMargin/InventoryBg/InMargin/GridContainer

# Resource textures and regions mapping
const resource_data = {
	"Wood": {"texture": "res://Assets/Icons/16x16.png", "region": Rect2(144, 192, 16, 16)},
	# Add more resources here as needed
}

# Store references to our inventory slots
var inventory_slots = []
var player_ref = null
var find_player_attempts = 0
var max_find_attempts = 5

func _ready():
	# Make sure the inventory is initially hidden
	if out_margin:
		out_margin.visible = false
	
	# Get references to all inventory slots
	if grid_container:
		for child in grid_container.get_children():
			if "InventorySlot" in child.name:
				inventory_slots.append(child)
	
	# Start looking for the player
	find_player()

func find_player():
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("Player")
	
	if player_ref:
		print("DEBUG: Player found in group!")
		# Connect to player inventory updates
		if player_ref.has_signal("inventory_updated"):
			player_ref.inventory_updated.connect(_on_player_inventory_updated)
			print("DEBUG: Connected to player's inventory_updated signal")
		else:
			push_warning("Player has no inventory_updated signal. Check player.gd")
		# Initial update
		_update_inventory_display()
	else:
		find_player_attempts += 1
		if find_player_attempts < max_find_attempts:
			print("DEBUG: Player not found. Retrying... (Attempt " + str(find_player_attempts) + ")")
			# Wait a bit longer and try again
			await get_tree().create_timer(0.5).timeout
			find_player()
		else:
			push_warning("Inventory: Player not found after " + str(max_find_attempts) + " attempts!")

func _input(event):
	# Check if the open_inventory key was just pressed
	if event.is_action_pressed("open_inventory"):
		toggle_inventory()
		if out_margin.visible:
			_update_inventory_display()  # Update display when opening

func toggle_inventory():
	# Toggle the visibility of the OutMargin
	if out_margin:
		out_margin.visible = !out_margin.visible

# Called when player inventory changes
func _on_player_inventory_updated():
	_update_inventory_display()

# Update the UI to display player inventory
func _update_inventory_display():
	if !player_ref:
		player_ref = get_tree().get_first_node_in_group("Player")
		if !player_ref:
			push_warning("Inventory: Player not found in group!")
			return
	
	var inventory = player_ref.get_inventory()
	print("DEBUG: Updating inventory display with: ", inventory)
	print("DEBUG: Number of inventory slots available: ", inventory_slots.size())
	var slot_index = 0
	
	# Clear all slots first
	for slot in inventory_slots:
		var sprite = slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
		var label = slot.get_node_or_null("Label")
		
		if sprite:
			sprite.texture = null
			sprite.region_enabled = false
		
		if label:
			label.text = ""
	
	# Fill slots with inventory items
	for item_name in inventory:
		var amount = inventory[item_name]
		
		if slot_index < inventory_slots.size():
			var slot = inventory_slots[slot_index]
			var sprite = slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
			var label = slot.get_node_or_null("Label")
			
			if sprite and resource_data.has(item_name):
				sprite.texture = load(resource_data[item_name]["texture"])
				sprite.region_enabled = true
				sprite.region_rect = resource_data[item_name]["region"]
			
			if label:
				label.text = str(amount)
			
			slot_index += 1
