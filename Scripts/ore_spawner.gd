extends Node
class_name OreSpawner

@export var stone_scene: PackedScene
@export var iron_scene: PackedScene
@export var gold_scene: PackedScene
@export var num_ores: int = 150
@export var stone_percentage: float = 0.7 # 70% of ores will be stone
@export var iron_percentage: float = 0.25 # 25% of ores will be iron
@export var gold_percentage: float = 0.05 # 5% of ores will be gold
@export var min_distance_between_ores: float = 20.0
@export var min_distance_from_player: float = 100.0
@export var position_randomization: float = 3.0
@export var strict_tile_placement: bool = true
@export var batch_size: int = 50
@export var max_spawn_percentage: float = 0.8

var player_position: Vector2
var spawn_positions = []

func _ready():
    # Get initial player position if player exists in scene
    var player = get_node_or_null("/root/Game/Player")
    if player:
        player_position = player.global_position
    else:
        player_position = Vector2.ZERO
    
    # Clear existing ores (those manually placed in editor)
    for child in get_children():
        child.queue_free()
    
    # Start spawning after a short delay to ensure scene is fully loaded
    await get_tree().create_timer(0.1).timeout
    find_spawn_positions()
    spawn_ores()

func find_spawn_positions():
    # Get the world node
    var world = get_node_or_null("/root/Game/World")
    if not world:
        push_error("OreSpawner: Could not find World node")
        return
    
    # Find the OreSpawn TileMapLayer in the world
    var ore_spawn_layer = world.get_node_or_null("OreSpawn")
    if not ore_spawn_layer:
        push_error("OreSpawner: Could not find OreSpawn layer in World")
        return
    
    print("OreSpawner: Found OreSpawn layer")
    
    # Get used tiles from the layer
    var used_cells = []
    
    # Try to get cells using different methods depending on the node type
    if ore_spawn_layer is TileMap:
        used_cells = ore_spawn_layer.get_used_cells(0) # Layer 0
    elif ore_spawn_layer.has_method("get_used_cells"):
        used_cells = ore_spawn_layer.get_used_cells()
    else:
        push_error("OreSpawner: Unable to get tiles from OreSpawn layer")
        return
    
    if used_cells.size() == 0:
        push_warning("OreSpawner: No spawn tiles found in OreSpawn layer")
        return
    
    print("OreSpawner: Found ", used_cells.size(), " potential ore spawn positions")
    
    # Adjust number of ores based on available positions and max percentage setting
    var max_ores = int(used_cells.size() * max_spawn_percentage)
    if num_ores > max_ores:
        print("OreSpawner: Adjusting requested ores from ", num_ores, " to ", max_ores, " (max ",
              max_spawn_percentage * 100, "% of available tiles)")
        num_ores = max_ores
    
    # Convert tile coordinates to world positions
    for cell_pos in used_cells:
        var world_pos = null
        
        if ore_spawn_layer is TileMap:
            # For Godot 4
            if cell_pos is Vector2i:
                world_pos = ore_spawn_layer.map_to_local(cell_pos)
            else:
                # Handle Vector2 if needed for compatibility
                world_pos = ore_spawn_layer.map_to_local(Vector2i(cell_pos.x, cell_pos.y))
        elif ore_spawn_layer.has_method("map_to_local"):
            world_pos = ore_spawn_layer.map_to_local(cell_pos)
        elif ore_spawn_layer.has_method("map_to_world"):
            world_pos = ore_spawn_layer.map_to_world(cell_pos)
        
        if world_pos:
            # Add the world's global position to get true world coordinates
            world_pos += world.global_position
            spawn_positions.append(world_pos)
    
    # Shuffle the spawn positions for better randomization
    spawn_positions.shuffle()
    
    print("OreSpawner: Prepared ", spawn_positions.size(), " world positions for ore spawning")

func spawn_ores():
    var spawned_ores = 0
    var max_attempts = num_ores * 2
    var used_positions = []
    
    # Load scenes if not explicitly set
    if not stone_scene:
        stone_scene = load("res://Scenes/stone.tscn")
    if not iron_scene:
        iron_scene = load("res://Scenes/iron.tscn")
    if not gold_scene:
        gold_scene = load("res://Scenes/gold.tscn")
        
    if not stone_scene or not iron_scene or not gold_scene:
        push_error("OreSpawner: One or more ore scenes not available!")
        return
    
    # If no spawn positions were found, exit
    if spawn_positions.size() == 0:
        push_error("OreSpawner: No spawn positions available")
        return
    
    print("OreSpawner: Starting to spawn ", num_ores, " ores")
    
    var stone_count = 0
    var iron_count = 0
    var gold_count = 0
    
    # Process ores in batches to avoid freezing the game
    while spawned_ores < num_ores and max_attempts > 0 and spawn_positions.size() > 0:
        var batch_count = 0
        
        # Process a batch of ores
        while batch_count < batch_size and spawned_ores < num_ores and max_attempts > 0 and spawn_positions.size() > 0:
            max_attempts -= 1
            batch_count += 1
            
            # Pick a random position from the available spawn positions
            var pos_index = randi() % spawn_positions.size()
            var base_pos = spawn_positions[pos_index]
            
            # Place strictly in tile center if configured that way
            var pos
            if strict_tile_placement:
                pos = base_pos
            else:
                pos = base_pos + Vector2(
                    randf_range(-position_randomization, position_randomization),
                    randf_range(-position_randomization, position_randomization)
                )
            
            # Check if this position is too close to player
            if pos.distance_to(player_position) < min_distance_from_player:
                # Remove this position from list to avoid repeated checking
                spawn_positions.remove_at(pos_index)
                continue
                
            # Check if too close to other ores - use square distance for better performance
            var too_close = false
            var min_distance_squared = min_distance_between_ores * min_distance_between_ores
            for other_pos in used_positions:
                if pos.distance_squared_to(other_pos) < min_distance_squared:
                    too_close = true
                    break
                    
            if too_close:
                # Remove this position from list to avoid repeated checking
                spawn_positions.remove_at(pos_index)
                continue
                
            # Position is good, determine which ore to spawn based on percentages
            var ore_type = randf()
            var ore_instance
            var variant
            
            if ore_type < stone_percentage:
                # Stone - most common
                ore_instance = stone_scene.instantiate()
                variant = randi() % 2 # 0 or 1 (for x=16 or x=32)
                var region_x = 16 + variant * 16
                ore_instance.get_node("Sprite2D").region_rect.position.x = region_x
                stone_count += 1
            elif ore_type < stone_percentage + iron_percentage:
                # Iron - less common
                ore_instance = iron_scene.instantiate()
                variant = randi() % 3 # 0, 1, or 2 (for x=0, x=16, or x=32)
                var region_x = variant * 16
                ore_instance.get_node("Sprite2D").region_rect.position.x = region_x
                iron_count += 1
            else:
                # Gold - least common
                ore_instance = gold_scene.instantiate()
                variant = randi() % 3 # 0, 1, or 2 (for x=0, x=16, or x=32)
                var region_x = variant * 16
                ore_instance.get_node("Sprite2D").region_rect.position.x = region_x
                gold_count += 1
            
            # Add the ore to the scene
            add_child(ore_instance)
            ore_instance.global_position = pos
            spawned_ores += 1
            
            # Add this position to used positions list
            used_positions.append(pos)
            
            # Remove this position from available positions to prevent duplicates
            spawn_positions.remove_at(pos_index)
        
        # Yield to allow the game to process other things
        if batch_count >= batch_size and spawned_ores < num_ores:
            await get_tree().process_frame
    
    print("OreSpawner: Spawned ", spawned_ores, " ores (", stone_count, " stone, ",
          iron_count, " iron, ", gold_count, " gold)")

# Optional: Add method to spawn additional ores during gameplay
func spawn_additional_ores(count: int, at_positions = []):
    if at_positions.size() > 0:
        # Use the provided positions
        var old_positions = spawn_positions
        spawn_positions = at_positions
        var old_num_ores = num_ores
        num_ores = count
        spawn_ores()
        spawn_positions = old_positions
        num_ores = old_num_ores
    else:
        # Use existing spawn positions
        var old_num_ores = num_ores
        num_ores = count
        spawn_ores()
        num_ores = old_num_ores
