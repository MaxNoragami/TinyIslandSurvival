extends Node
class_name TreeSpawner

@export var tree_scene: PackedScene
@export var num_trees: int = 250
@export var min_distance_between_trees: float = 30.0
@export var min_distance_from_player: float = 150.0
@export var position_randomization: float = 4.0 # Reduced randomization
@export var strict_tile_placement: bool = true # When true, trees will be exactly in tile centers
@export var batch_size: int = 50 # Process tree spawning in batches for better performance
@export var max_spawn_percentage: float = 0.7 # Max percentage of available tiles to fill with trees

var player_position: Vector2
var spawn_positions = []

func _ready():
	# Get initial player position if player exists in scene
	var player = get_node_or_null("/root/Game/Player")
	if player:
		player_position = player.global_position
	else:
		player_position = Vector2.ZERO
	
	# Clear existing trees (those manually placed in editor)
	for child in get_children():
		child.queue_free()
	
	# Start spawning after a short delay to ensure scene is fully loaded
	await get_tree().create_timer(0.1).timeout
	find_spawn_positions()
	spawn_trees()

func find_spawn_positions():
	# Get the world node
	var world = get_node_or_null("/root/Game/World")
	if not world:
		push_error("TreeSpawner: Could not find World node")
		return
	
	# Find the TreeSpawn TileMapLayer in the world
	var tree_spawn_layer = world.get_node_or_null("TreeSpawn")
	if not tree_spawn_layer:
		push_error("TreeSpawner: Could not find TreeSpawn layer in World")
		return
	
	print("TreeSpawner: Found TreeSpawn layer")
	
	# Get used tiles from the layer
	var used_cells = []
	
	# Try to get cells using different methods depending on the node type
	if tree_spawn_layer is TileMap:
		used_cells = tree_spawn_layer.get_used_cells(0) # Layer 0
	elif tree_spawn_layer.has_method("get_used_cells"):
		used_cells = tree_spawn_layer.get_used_cells()
	else:
		push_error("TreeSpawner: Unable to get tiles from TreeSpawn layer")
		return
	
	if used_cells.size() == 0:
		push_warning("TreeSpawner: No spawn tiles found in TreeSpawn layer")
		return
	
	print("TreeSpawner: Found ", used_cells.size(), " potential tree spawn positions")
	
	# Adjust number of trees based on available positions and max percentage setting
	var max_trees = int(used_cells.size() * max_spawn_percentage)
	if num_trees > max_trees:
		print("TreeSpawner: Adjusting requested trees from ", num_trees, " to ", max_trees, " (max ",
			  max_spawn_percentage * 100, "% of available tiles)")
		num_trees = max_trees
	
	# Convert tile coordinates to world positions
	for cell_pos in used_cells:
		var world_pos = null
		
		if tree_spawn_layer is TileMap:
			# For Godot 4
			if cell_pos is Vector2i:
				world_pos = tree_spawn_layer.map_to_local(cell_pos)
			else:
				# Handle Vector2 if needed for compatibility
				world_pos = tree_spawn_layer.map_to_local(Vector2i(cell_pos.x, cell_pos.y))
		elif tree_spawn_layer.has_method("map_to_local"):
			world_pos = tree_spawn_layer.map_to_local(cell_pos)
		elif tree_spawn_layer.has_method("map_to_world"):
			world_pos = tree_spawn_layer.map_to_world(cell_pos)
		
		if world_pos:
			# Add the world's global position to get true world coordinates
			world_pos += world.global_position
			spawn_positions.append(world_pos)
	
	# Shuffle the spawn positions for better randomization
	spawn_positions.shuffle()
	
	print("TreeSpawner: Prepared ", spawn_positions.size(), " world positions for tree spawning")

func spawn_trees():
	var spawned_trees = 0
	var max_attempts = num_trees * 2 # Reduce max attempts to improve performance
	var used_positions = []
	
	# If no tree scene explicitly set, try to load the default one
	if not tree_scene:
		tree_scene = load("res://Scenes/tree.tscn")
		if not tree_scene:
			push_error("TreeSpawner: No tree scene available to spawn!")
			return
	
	# If no spawn positions were found, exit
	if spawn_positions.size() == 0:
		push_error("TreeSpawner: No spawn positions available")
		return
	
	print("TreeSpawner: Starting to spawn ", num_trees, " trees")
	
	# Process trees in batches to avoid freezing the game
	while spawned_trees < num_trees and max_attempts > 0 and spawn_positions.size() > 0:
		var batch_count = 0
		
		# Process a batch of trees
		while batch_count < batch_size and spawned_trees < num_trees and max_attempts > 0 and spawn_positions.size() > 0:
			max_attempts -= 1
			batch_count += 1
			# Pick a random position from the available spawn positions
			var pos_index = randi() % spawn_positions.size()
			var base_pos = spawn_positions[pos_index]
			
			var pos
			if strict_tile_placement:
				# Place trees exactly in the center of tiles
				pos = base_pos
			else:
				# Add a small random offset within the tile to make placement look more natural
				pos = base_pos + Vector2(
					randf_range(-position_randomization, position_randomization),
					randf_range(-position_randomization, position_randomization)
				)
			
			# Check if this position is too close to player
			if pos.distance_to(player_position) < min_distance_from_player:
				# Remove this position from list to avoid repeated checking
				spawn_positions.remove_at(pos_index)
				continue
				
			# Check if too close to other trees - use square distance for better performance
			var too_close = false
			var min_distance_squared = min_distance_between_trees * min_distance_between_trees
			for other_pos in used_positions:
				if pos.distance_squared_to(other_pos) < min_distance_squared:
					too_close = true
					break
					
			if too_close:
				# Remove this position from list to avoid repeated checking
				spawn_positions.remove_at(pos_index)
				continue
				
			# Position is good, spawn a tree here
			used_positions.append(pos)
			var tree_instance = tree_scene.instantiate()
			add_child(tree_instance)
			tree_instance.global_position = pos
			spawned_trees += 1
			
			# Remove this position from available positions to prevent duplicates
			spawn_positions.remove_at(pos_index)
		
		# Yield to allow the game to process other things
		if batch_count >= batch_size and spawned_trees < num_trees:
			await get_tree().process_frame
	
	print("TreeSpawner: Spawned ", spawned_trees, " trees out of ", num_trees, " requested")

# Optional: Add method to spawn additional trees during gameplay
func spawn_additional_trees(count: int, at_positions = []):
	if at_positions.size() > 0:
		# Use the provided positions
		var old_positions = spawn_positions
		spawn_positions = at_positions
		var old_num_trees = num_trees
		num_trees = count
		spawn_trees()
		spawn_positions = old_positions
		num_trees = old_num_trees
	else:
		# Use existing spawn positions
		var old_num_trees = num_trees
		num_trees = count
		spawn_trees()
		num_trees = old_num_trees
