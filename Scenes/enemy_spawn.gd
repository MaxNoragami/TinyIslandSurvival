extends Node
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var num_enemies: int = 20
@export var min_distance_from_player: float = 100.0
@export var min_distance_between_enemies: float = 50.0  # Minimum distance between monsters
@export var position_randomization: float = 4.0
@export var strict_tile_placement: bool = true
@export var batch_size: int = 10

var player_position: Vector2
var spawn_positions = []
var active_enemies: Array = []

func _ready():
	# Check if enemy_scene is assigned
	if enemy_scene == null:
		push_error("EnemySpawner: enemy_scene is not assigned! Please set it in the Inspector.")
		return
		
	var player = get_node_or_null("/root/Game/Player")
	if player:
		player_position = player.global_position
	else:
		player_position = Vector2.ZERO
	
	# Clear manually placed enemies
	for child in get_children():
		child.queue_free()
	
	await get_tree().create_timer(0.1).timeout
	find_spawn_positions()
	spawn_enemies()

func find_spawn_positions():
	var world = get_node_or_null("/root/Game/World")
	if not world:
		push_error("EnemySpawner: World node not found")
		return
	
	var spawn_layer = world.get_node_or_null("EnemySpawn")
	if not spawn_layer:
		push_error("EnemySpawner: EnemySpawn layer not found")
		return
	
	var used_cells = []
	if spawn_layer is TileMap:
		used_cells = spawn_layer.get_used_cells(0)
	elif spawn_layer.has_method("get_used_cells"):
		used_cells = spawn_layer.get_used_cells()
	
	for cell_pos in used_cells:
		var world_pos = spawn_layer.map_to_local(cell_pos)
		world_pos += world.global_position
		spawn_positions.append(world_pos)
	
	spawn_positions.shuffle()

func spawn_enemies():
	# Check if enemy_scene is valid
	if enemy_scene == null:
		push_error("Cannot spawn enemies - enemy_scene is null")
		return
		
	var spawned = 0
	var max_attempts = num_enemies * 3  # Increased attempts to account for spacing constraints
	
	while spawned < num_enemies and max_attempts > 0 and spawn_positions.size() > 0:
		var batch_count = 0
		
		while batch_count < batch_size and spawned < num_enemies and max_attempts > 0 and spawn_positions.size() > 0:
			max_attempts -= 1
			batch_count += 1
			
			var idx = randi() % spawn_positions.size()
			var base_pos = spawn_positions[idx]
			var pos = base_pos if strict_tile_placement else base_pos + Vector2(
				randf_range(-position_randomization, position_randomization),
				randf_range(-position_randomization, position_randomization)
			)
			
			# Check if position meets distance requirements 
			if is_valid_spawn_position(pos):
				spawn_enemy_at(pos)
				spawned += 1
			
			# Always remove the used position from available positions
			spawn_positions.remove_at(idx)
		
		if batch_count >= batch_size and spawned < num_enemies:
			await get_tree().process_frame
			
	if spawned < num_enemies:
		print("Warning: Could only spawn", spawned, "out of", num_enemies, "enemies due to space constraints.")

func spawn_enemy_at(pos: Vector2):
	if enemy_scene == null:
		push_error("Enemy scene is null! Make sure to assign it in the Inspector.")
		return
		
	var enemy = enemy_scene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	
	# Make sure the enemy has the signal before connecting
	if enemy.has_signal("enemy_died"):
		# Connect with a simpler approach
		enemy.connect("enemy_died", _on_enemy_died)
		active_enemies.append(enemy)
		print("New enemy spawned and signal connected")
	else:
		push_error("Enemy scene doesn't have enemy_died signal")

# Simplified signature - no parameters needed since we can get the enemy from the signal
func _on_enemy_died():
	print("EnemySpawner: Enemy died signal received!")
	
	# Force a recount of actual enemies in the scene
	var enemies_in_scene = []
	for child in get_children():
		if child is CharacterBody2D and child.has_method("skeleton") and child.skeleton_alive:
			enemies_in_scene.append(child)
	
	# Update our tracking array with the actual living enemies
	active_enemies = enemies_in_scene
	
	print("EnemySpawner: Active enemies remaining:", active_enemies.size(), " out of target", num_enemies)
	
	# Wait a moment before spawning a replacement
	call_deferred("_spawn_replacement")

# Separate function to handle spawning with a delay
func _spawn_replacement():
	await get_tree().create_timer(1.0).timeout
	
	# Force another recount before deciding to spawn
	var current_count = 0
	for child in get_children():
		if child is CharacterBody2D and child.has_method("skeleton") and child.skeleton_alive:
			current_count += 1
	
	# Check again in case something changed during the wait
	if current_count < num_enemies:
		print("EnemySpawner: Spawning replacement enemy...(current:", current_count, "/", num_enemies, ")")
		spawn_random_enemy()
	else:
		print("EnemySpawner: Enemy cap reached, no respawn needed. (", current_count, "/", num_enemies, ")")

func spawn_random_enemy():
	# First check if we have a valid enemy scene
	if enemy_scene == null:
		push_error("Cannot spawn enemies - enemy_scene is null")
		return
		
	# Update player position before trying to spawn
	update_player_position()
	
	var tries = 15  # Increased tries since we have more restrictions now
	while tries > 0 and spawn_positions.size() > 0:
		var idx = randi() % spawn_positions.size()
		var pos = spawn_positions[idx]
		
		# Check against all distance requirements
		if is_valid_spawn_position(pos):
			spawn_enemy_at(pos)
			spawn_positions.remove_at(idx)
			print("Replacement enemy successfully spawned at ", pos.x, pos.y)
			return
		
		spawn_positions.remove_at(idx)
		tries -= 1
	
	# If we run out of predefined positions, try random positions near existing valid tiles
	if tries <= 0 and active_enemies.size() > 0:
		print("Trying alternative spawn positions...")
		tries = 10
		
		while tries > 0:
			# Pick a random active enemy and try to spawn at a safe distance from it
			var random_existing_enemy = active_enemies[randi() % active_enemies.size()]
			var angle = randf() * 2 * PI
			var distance = min_distance_between_enemies * 1.5
			var test_pos = random_existing_enemy.global_position + Vector2(cos(angle), sin(angle)) * distance
			
			if is_valid_spawn_position(test_pos):
				spawn_enemy_at(test_pos)
				print("Replacement enemy spawned using alternative position at ", test_pos.x, test_pos.y)
				return
				
			tries -= 1
	
	print("Failed to find suitable spawn position for replacement enemy")

func update_player_position():
	var player = get_node_or_null("/root/Game/Player")
	if player:
		player_position = player.global_position
		
func is_valid_spawn_position(pos: Vector2) -> bool:
	# Check distance from player
	if pos.distance_to(player_position) < min_distance_from_player:
		return false
		
	# Check distance from all other active enemies
	for enemy in get_children():
		if enemy is CharacterBody2D and enemy.has_method("skeleton") and enemy.skeleton_alive:
			if pos.distance_to(enemy.global_position) < min_distance_between_enemies:
				return false
				
	return true
