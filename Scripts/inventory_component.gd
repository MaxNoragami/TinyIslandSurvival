extends Node
class_name InventoryComponent

# Inventory updated signal
signal inventory_updated

# Inventory data storage
var inventory = {}
@export var max_stack_size: int = 99

func _ready():
	# Initialize empty inventory
	pass

# Add items to the inventory
func add_item(item_name: String, amount: int = 1):
	print("DEBUG: InventoryComponent.add_item called with: ", item_name, " x", amount)
	
	# Check if the item name is valid and not empty
	if item_name.is_empty():
		push_error("InventoryComponent: Cannot add empty item name to inventory")
		return false
		
	# Add item to inventory
	if item_name in inventory:
		inventory[item_name] = min(inventory[item_name] + amount, max_stack_size)
	else:
		inventory[item_name] = amount
	
	print("Added to inventory: ", item_name, " x", amount)
	print("Inventory contents now: ", inventory)
	
	# Notify observers
	emit_signal("inventory_updated")
	return true
	
# Remove items from the inventory
func remove_item(item_name: String, amount: int = 1):
	if item_name in inventory:
		inventory[item_name] -= amount
		
		if inventory[item_name] <= 0:
			# Remove the item completely if amount is zero or negative
			inventory.erase(item_name)
		
		print("Removed from inventory: ", item_name, " x", amount)
		print("Inventory: ", inventory)
		
		# Notify observers 
		emit_signal("inventory_updated")
		return true
	return false

# Check if the inventory contains an item
func has_item(item_name: String, amount: int = 1):
	return item_name in inventory and inventory[item_name] >= amount
	
# Get the entire inventory
func get_inventory():
	return inventory
	
# Get the amount of a specific item
func get_item_amount(item_name: String):
	return inventory.get(item_name, 0)
