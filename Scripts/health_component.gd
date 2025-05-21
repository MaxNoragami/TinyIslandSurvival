extends Node
class_name HealthComponent

@export var max_health: float = 100.0
@export var current_health: float = 100.0

signal health_changed(new_health)
signal health_depleted()

func _ready():
	current_health = max_health

func take_damage(amount):
	current_health = max(0, current_health - amount)
	emit_signal("health_changed", current_health)
	
	if current_health <= 0:
		emit_signal("health_depleted")

func heal(amount):
	current_health = min(max_health, current_health + amount)
	emit_signal("health_changed", current_health)
	
func is_alive():
	return current_health > 0
	
func get_health_percent():
	return current_health / max_health
