extends Control

@onready var out_margin = $OutMargin

func _ready():
	# Add self to CraftMenu group for easy access
	add_to_group("CraftMenu")
	
	# Make sure the crafting menu is initially hidden and doesn't block mouse
	if out_margin:
		out_margin.visible = false
		out_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make sure the entire control doesn't block mouse when not visible
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event):
	# Check if the open_crafting key was just pressed
	if event.is_action_pressed("open_crafting"):
		toggle_crafting_menu()

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
		else:
			# Ensure mouse events pass through when hidden
			out_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mouse_filter = Control.MOUSE_FILTER_IGNORE
