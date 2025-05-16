extends PanelContainer

# Reference to components
@onready var sprite = $CenterContainer/Panel/Sprite2D
@onready var label = $Label
@onready var button = $Button

func _ready():
	# Initialize the slot
	if sprite:
		sprite.texture = null
		sprite.region_enabled = false
	
	if label:
		label.text = ""

# Check if this slot has an item
func has_item() -> bool:
	return sprite.texture != null

# Get the item data from this slot
func get_item_data() -> Dictionary:
	if has_item():
		return {
			"texture": sprite.texture,
			"region_enabled": sprite.region_enabled,
			"region_rect": sprite.region_rect,
			"amount": label.text
		}
	return {}

# Set item data to this slot
func set_item_data(data: Dictionary) -> void:
	if data.has("texture"):
		sprite.texture = data.texture
		sprite.region_enabled = data.get("region_enabled", false)
		if data.has("region_rect"):
			sprite.region_rect = data.region_rect
	
	if data.has("amount"):
		label.text = data.amount
	
# Clear the slot
func clear() -> void:
	sprite.texture = null
	sprite.region_enabled = false
	label.text = ""
