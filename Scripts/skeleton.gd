extends CharacterBody2D

var speed = 25
var player_chase = false
var player = null
var health =60
var player_inattack_zone = false
var can_take_damage = true
var skeleton_alive = true
var death_animation_played = false
var knockback_velocity = Vector2.ZERO


func _ready():
	if $AnimatedSprite2D.has_node("detection_area"):
		var area = $AnimatedSprite2D/detection_area
		for body in area.get_overlapping_bodies():
			if body.is_in_group("Player"):
				_on_detection_area_body_entered(body)
	else:
		push_error("detection_area not found under AnimatedSprite2D")


func _physics_process(delta):
	if not skeleton_alive:
		return
	
	# Apply knockback if any
	if knockback_velocity.length() > 0.1:
		position += knockback_velocity * delta
		# Gradually reduce knockback (damping)
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
	else:
		knockback_velocity = Vector2.ZERO  # Stop completely if very small

	deal_with_damage()

	if not $AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != "death":
		if player_chase and player and skeleton_alive:
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

func die():
	if not skeleton_alive:
		return
	
	skeleton_alive = false
	print("Skeleton has died")

	$CollisionShape2D.disabled = true
	velocity = Vector2.ZERO

	# Only play the animation if not already done
	if not death_animation_played and $AnimatedSprite2D.sprite_frames.has_animation("death"):
		$AnimatedSprite2D.play("death")
		death_animation_played = true

	$death_cleanup_timer.start()


func _on_hitbox_component_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone =true


func _on_hitbox_component_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone =false
		
func deal_with_damage():
	if player_inattack_zone and Global.player_current_attack == true:
		if can_take_damage == true:
			health = health - 20
			var direction = (position - player.position).normalized()
			knockback_velocity = direction * 150  # Adjust strength as needed
			$take_damage_cooldown.start()
			can_take_damage = false
			print("Skeleton health - ", health)
			if health <=0:
				die()


func _on_death_cleanup_timer_timeout():
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.frame = $AnimatedSprite2D.sprite_frames.get_frame_count("death") - 1
	set_physics_process(false)
	queue_free()



func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true
