extends Node
class_name TimeConditionedObject

# Configure when the object should appear/disappear
@export_enum("Day", "Night", "Dawn", "Dusk") var appears_during: String = "Night"
@export var only_appears_once: bool = false
@export var only_appears_on_date: int = 0 # 0 = any date
@export var remains_after_interaction: bool = false
@export var inactive_alpha: float = 0.0 # How visible when inactive (0 = invisible)

# Internal state
var is_currently_active: bool = false
var has_been_active_before: bool = false
var has_been_interacted_with: bool = false
var parent_sprite = null
var parent_collision = null
var original_modulate = Color.WHITE

# Signal for game logic
signal object_became_active
signal object_became_inactive

func _ready():
	# Get parent nodes
	var parent = get_parent()
	
	# Try to find sprite in parent or its children
	parent_sprite = parent.get_node_or_null("Sprite2D")
	if not parent_sprite:
		parent_sprite = parent.get_node_or_null("AnimatedSprite2D")
	
	# Try to find collision in parent or its children
	parent_collision = parent.get_node_or_null("CollisionShape2D")
	if not parent_collision and parent.has_node("StaticBody2D"):
		parent_collision = parent.get_node("StaticBody2D").get_node_or_null("CollisionShape2D")
	
	# Store original color
	if parent_sprite:
		original_modulate = parent_sprite.modulate
	
	# Set initial state
	update_visibility()
	
	# Connect to the time system if available
	var time_system = get_tree().get_first_node_in_group("TimeSystem")
	if time_system:
		if time_system.has_signal("time_changed"):
			time_system.time_changed.connect(_on_time_changed)
		else:
			print("TimeConditionedObject: TimeSystem has no time_changed signal")
	# This would be in your time_conditioned_objects.gd script
	# Connect to the time system if available

func _on_time_changed(new_time_of_day, new_date):
	update_visibility(new_time_of_day, new_date)

func update_visibility(time_of_day = null, current_date = 0):
	# If we don't have time info and can't get it from the time system, assume inactive
	if time_of_day == null:
		var time_system = get_tree().get_first_node_in_group("TimeSystem")
		if time_system:
			time_of_day = time_system.current_time_of_day
			current_date = time_system.current_date
		else:
			time_of_day = "Day" # Default if no time system
	
	# Check if we should be active based on time
	var should_be_active = false
	
	# Time of day check
	if time_of_day == appears_during:
		should_be_active = true
	
	# Date-specific check
	if only_appears_on_date != 0 and current_date != only_appears_on_date:
		should_be_active = false
	
	# One-time appearance check
	if only_appears_once and has_been_active_before:
		should_be_active = false
	
	# Interaction override
	if has_been_interacted_with and remains_after_interaction:
		should_be_active = true
	
	# Apply the visibility change if it's different
	if should_be_active != is_currently_active:
		is_currently_active = should_be_active
		
		if is_currently_active:
			emit_signal("object_became_active")
			has_been_active_before = true
			_set_active(true)
		else:
			emit_signal("object_became_inactive")
			_set_active(false)

func _set_active(active):
	# Apply to sprite
	if parent_sprite:
		if active:
			parent_sprite.modulate = original_modulate
		else:
			var inactive_color = original_modulate
			inactive_color.a = inactive_alpha
			parent_sprite.modulate = inactive_color
			
		# Optionally make completely invisible
		parent_sprite.visible = active or inactive_alpha > 0
	
	# Apply to collision
	if parent_collision:
		parent_collision.disabled = !active

func mark_as_interacted():
	has_been_interacted_with = true
	update_visibility()

# Useful accessors
func is_active():
	return is_currently_active
	
func has_appeared_before():
	return has_been_active_before

func reset():
	has_been_active_before = false
	has_been_interacted_with = false
	update_visibility()
