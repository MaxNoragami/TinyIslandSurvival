extends Node

# For fixing the inventory display of RuneStone
# This should be attached to a new node in your Game scene

func _ready():
	# Wait a moment for other nodes to initialize
	await get_tree().create_timer(0.5).timeout
	fix_inventory_display()

func fix_inventory_display():
	# Get the inventory UI
	var inventory_ui = get_tree().get_first_node_in_group("InventoryUI")
	if not inventory_ui:
		print("Could not find InventoryUI!")
		return
	
	# Get the player
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		print("Could not find Player!")
		return
	
	# Check if player has RuneStone
	var inventory = player.get_inventory()
	if not "RuneStone" in inventory:
		print("Player does not have RuneStone yet")
		return
	
	print("Fixing inventory display for RuneStone...")
	
	# Find all InventorySlot nodes
	var slots = []
	var grid_container = inventory_ui.get_node_or_null("OutMargin/InventoryBg/InMargin/GridContainer")
	if grid_container:
		for child in grid_container.get_children():
			if "InventorySlot" in child.name:
				slots.append(child)
	
	# Look for the RuneStone slot
	for slot in slots:
		if slot.has_meta("item_name") and slot.get_meta("item_name") == "RuneStone":
			print("Found RuneStone slot, fixing its display...")
			
			# Get the sprite in this slot
			var sprite = slot.get_node_or_null("CenterContainer/Panel/Sprite2D")
			if sprite:
				# Set texture directly
				var texture = load("res://Assets/Outdoor decoration/ancient_tablet.png")
				if texture:
					sprite.texture = texture
					sprite.region_enabled = false  # Don't use region rect
					print("Fixed RuneStone texture in inventory slot")
				else:
					print("Failed to load RuneStone texture!")
			else:
				print("Could not find Sprite2D in inventory slot!")
				
# You can call this manually with a key press
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		print("Manual inventory fix triggered...")
		fix_inventory_display()
