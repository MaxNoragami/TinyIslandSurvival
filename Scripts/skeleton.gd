extends CharacterBody2D

var speed = 25
var player_chase = false
var player = null
var health = 100
var player_inattack_zone = false
func _ready():
	if $AnimatedSprite2D.has_node("detection_area"):
		var area = $AnimatedSprite2D/detection_area
		for body in area.get_overlapping_bodies():
			if body.is_in_group("Player"):
				_on_detection_area_body_entered(body)
	else:
		push_error("detection_area not found under AnimatedSprite2D")


func _physics_process(delta):
	deal_with_damage()
	if player_chase and player:
		position += (player.position - position) / speed

		if (player.position.y - position.y) < -10:
			$AnimatedSprite2D.play("back_walking")
		elif (player.position.y - position.y) < 30:
			$AnimatedSprite2D.play("walk")
			$AnimatedSprite2D.flip_h = player.position.x < position.x
		elif (player.position.y - position.y) > 30:
			$AnimatedSprite2D.play("front_walking")
	else:
		$AnimatedSprite2D.play("idle")

func _on_detection_area_body_entered(body):
	if body.is_in_group("Player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
		player_chase = false

func skeleton():
	pass



func _on_hitbox_component_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone =true


func _on_hitbox_component_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone =true
		
func deal_with_damage():
	if player_inattack_zone and Global.player_current_attack == true:
		health = health - 20
		print("Skeleton health - ", health)
		if health <=0:
			self.queue_free()
