extends Node2D
class_name HiddenLocationExample

# This script demonstrates how to set up a complete hidden location instance

func _ready():
	# Set up our hidden location - this is an example of the Crystal Cave
	set_up_crystal_cave()
	
	# You would have different methods for different hidden locations
	# set_up_ancient_temple()
	# set_up_sunken_ship()
	# set_up_forest_shrine()

func set_up_crystal_cave():
	# 1. Create the hidden location node with script
	var crystal_cave = Node2D.new()
	crystal_cave.name = "CrystalCave"
	crystal_cave.script = load("res://Scripts/hidden_location.gd")
	
	# 2. Configure the hidden location properties
	crystal_cave.location_name = "Crystal Cave"
	crystal_cave.location_id = "cave_1"
	crystal_cave.required_time_of_day = "Night"
	crystal_cave.required_item = "StoneAxe"
	crystal_cave.required_puzzle_item = ""
	crystal_cave.reward_item = "MagicCompass"
	crystal_cave.clue_message = "A strange rock formation... seems to have a crack in it."
	crystal_cave.enter_message = "You discovered a hidden cave filled with glowing crystals!"
	crystal_cave.puzzle_message = "Ancient stone pillars form a circle in the center of the cave."
	crystal_cave.completion_message = "The pillars light up in unison, revealing a hidden compartment!"
	
	# 3. Create and add the entrance sprite
	var entrance_sprite = Sprite2D.new()
	entrance_sprite.name = "EntranceSprite"
	entrance_sprite.texture = load("res://Assets/cave_entrance.png")  # Replace with your texture
	crystal_cave.add_child(entrance_sprite)
	
	# 4. Add collision shape
	var entrance_collision = CollisionShape2D.new()
	entrance_collision.name = "EntranceCollision"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)  # Adjust to match your sprite
	entrance_collision.shape = shape
	crystal_cave.add_child(entrance_collision)
	
	# 5. Create interaction area
	var interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	
	var interaction_shape = CollisionShape2D.new()
	var interaction_circle = CircleShape2D.new()
	interaction_circle.radius = 50.0  # Detection radius for interaction
	interaction_shape.shape = interaction_circle
	interaction_area.add_child(interaction_shape)
	crystal_cave.add_child(interaction_area)
	
	# 6. Create puzzle area
	var puzzle_area = Area2D.new()
	puzzle_area.name = "PuzzleArea"
	
	var puzzle_shape = CollisionShape2D.new()
	var puzzle_circle = CircleShape2D.new()
	puzzle_circle.radius = 100.0  # Area where the puzzle is active
	puzzle_shape.shape = puzzle_circle
	puzzle_area.add_child(puzzle_shape)
	crystal_cave.add_child(puzzle_area)
	
	# 7. Add a reward sprite (initially hidden)
	var reward_sprite = Sprite2D.new()
	reward_sprite.name = "RewardSprite"
	reward_sprite.texture = load("res://Assets/Icons/16x16.png")  # Use your inventory icon sheet
	reward_sprite.region_enabled = true
	reward_sprite.region_rect = Rect2(80, 1056, 16, 16)  # Compass region from clue_system.gd
	reward_sprite.visible = false
	crystal_cave.add_child(reward_sprite)
	
	# 8. Add the TimeConditionedObject component for night-only visibility
	var time_condition = Node.new()
	time_condition.name = "TimeConditionedObject"
	time_condition.script = load("res://Scripts/time_conditioned_object.gd")
	time_condition.appears_during = "Night"
	time_condition.inactive_alpha = 0.0  # Completely invisible when inactive
	crystal_cave.add_child(time_condition)
	
	# 9. Set up the Stone Pillar Puzzle
	var stone_puzzle = Node2D.new()
	stone_puzzle.name = "StonePillarPuzzle"
	stone_puzzle.script = load("res://Scripts/stone_pillar_puzzle.gd")
	stone_puzzle.pillar_count = 4
	stone_puzzle.correct_sequence = [0, 2, 1, 3]  # Can be any order you want
	
	# 10. Add pillars to the puzzle
	for i in range(4):
		var pillar = Sprite2D.new()
		pillar.name = "Pillar" + str(i + 1)
		pillar.texture = load("res://Assets/stone_pillar.png")  # Replace with your texture
		
		# Position pillars in a circle
		var angle = i * PI/2  # 90 degree spacing
		var radius = 60.0
		pillar.position = Vector2(cos(angle) * radius, sin(angle) * radius)
		
		# Add interaction area to each pillar
		var pillar_area = Area2D.new()
		pillar_area.name = "InteractionArea"
		
		var pillar_shape = CollisionShape2D.new()
		var pillar_circle = CircleShape2D.new()
		pillar_circle.radius = 20.0
		pillar_shape.shape = pillar_circle
		pillar_area.add_child(pillar_shape)
		pillar.add_child(pillar_area)
		
		stone_puzzle.add_child(pillar)
	
	# 11. Add a center point for the reward to appear
	var center = Sprite2D.new()
	center.name = "Center"
	center.texture = load("res://Assets/Icons/16x16.png")
	center.region_enabled = true
	center.region_rect = Rect2(80, 1056, 16, 16)  # Compass icon
	center.visible = false
	stone_puzzle.add_child(center)
	
	# 12. Add the puzzle to the cave
	crystal_cave.add_child(stone_puzzle)
	
	# 13. Add the cave to the scene tree
	add_child(crystal_cave)
	
	# 14. Position the cave in the world
	crystal_cave.global_position = Vector2(500, 300)  # Adjust as needed

func set_up_ancient_temple():
	# Similar structure to crystal_cave, but with a SymbolMatchingPuzzle
	var temple = Node2D.new()
	temple.name = "AncientTemple"
	temple.script = load("res://Scripts/hidden_location.gd")
	
	# Configure properties
	temple.location_name = "Ancient Temple"
	temple.location_id = "ancient_temple"
	temple.required_time_of_day = ""  # Any time
	temple.required_item = "RuneStone"
	temple.required_puzzle_item = ""
	temple.reward_item = "AncientScroll"  # Could be a special crafting recipe
	temple.clue_message = "A weathered stone structure hidden behind a waterfall."
	temple.enter_message = "You've discovered an ancient temple with strange symbols!"
	temple.puzzle_message = "Matching symbols are carved into stone tablets."
	temple.completion_message = "The temple reveals its secrets!"
	
	# Add your sprite, collision, and areas similar to crystal_cave
	
	# Set up symbol matching puzzle
	var symbol_puzzle = Node2D.new()
	symbol_puzzle.name = "SymbolMatchingPuzzle"
	symbol_puzzle.script = load("res://Scripts/symbol_matching_puzzle.gd")
	
	# Add symbols to the puzzle (8 total for 4 pairs)
	for i in range(8):
		var symbol = Sprite2D.new()
		symbol.name = "Symbol" + str(i + 1)
		symbol.texture = load("res://Assets/symbol_back.png")  # Back of symbol "card"
		
		# Position in a grid pattern
		var col = i % 4
		var row = i / 4
		symbol.position = Vector2(col * 40 - 60, row * 40 - 20)
		
		# Add the actual symbol sprite (hidden initially)
		var symbol_sprite = AnimatedSprite2D.new()
		symbol_sprite.name = "SymbolSprite"
		
		# Create frames for different symbols
		var frames = SpriteFrames.new()
		frames.add_animation("default")
		frames.set_animation_speed("default", 0)
		# Add frames from your texture
		symbol_sprite.frames = frames
		symbol_sprite.visible = false
		
		symbol.add_child(symbol_sprite)
		
		# Add interaction area
		var symbol_area = Area2D.new()
		symbol_area.name = "InteractionArea"
		
		var symbol_shape = CollisionShape2D.new()
		var symbol_rect = RectangleShape2D.new()
		symbol_rect.size = Vector2(30, 30)
		symbol_shape.shape = symbol_rect
		symbol_area.add_child(symbol_shape)
		symbol.add_child(symbol_area)
		
		symbol_puzzle.add_child(symbol)
	
	# Add reward sprite
	var reward = Sprite2D.new()
	reward.name = "Reward"
	reward.texture = load("res://Assets/Icons/16x16.png")
	reward.region_enabled = true
	reward.region_rect = Rect2(112, 432, 16, 16)  # Ancient scroll
	reward.visible = false
	symbol_puzzle.add_child(reward)
	
	# Add puzzle to temple
	temple.add_child(symbol_puzzle)
	
	# Add temple to the scene tree
	add_child(temple)
	
	# Position in the world
	temple.global_position = Vector2(800, 500)  # Adjust as needed

func set_up_sunken_ship():
	# Implementation of the shipwreck location with a sequence puzzle
	var ship = Node2D.new()
	ship.name = "SunkenShip"
	ship.script = load("res://Scripts/hidden_location.gd")
	
	# Configure properties
	ship.location_name = "Sunken Ship"
	ship.location_id = "sunken_ship"
	ship.required_time_of_day = "Day"  # Only visible during day (low tide)
	ship.required_item = "StrangeKey"
	ship.required_puzzle_item = ""
	ship.reward_item = "CaptainsSextant"  # Special navigation tool
	ship.clue_message = "The outline of a ship's hull can be seen at low tide."
	ship.enter_message = "You've discovered the remains of an ancient ship!"
	ship.puzzle_message = "The captain's quarters are locked with a strange mechanism."
	ship.completion_message = "The captain's quarters open, revealing hidden treasures!"
	
	# Add sprites, collision and areas like before
	
	# Add time condition for low tide
	var time_condition = Node.new()
	time_condition.name = "TimeConditionedObject"
	time_condition.script = load("res://Scripts/time_conditioned_object.gd")
	time_condition.appears_during = "Day"  # Low tide during day
	time_condition.inactive_alpha = 0.3  # Slightly visible at high tide
	ship.add_child(time_condition)
	
	# Set up sequence puzzle
	var seq_puzzle = Node2D.new()
	seq_puzzle.name = "SequencePuzzle"
	seq_puzzle.script = load("res://Scripts/sequence_puzzle.gd")
	seq_puzzle.correct_sequence = ["up", "up", "right", "down", "left", "action"]
	seq_puzzle.display_input_feedback = true
	
	# Add feedback container for inputs
	var feedback = Node2D.new()
	feedback.name = "FeedbackContainer"
	seq_puzzle.add_child(feedback)
	
	# Add reward sprite
	var reward = Sprite2D.new()
	reward.name = "Reward"
	reward.texture = load("res://Assets/Icons/16x16.png")
	reward.region_enabled = true
	reward.region_rect = Rect2(128, 1056, 16, 16)  # Sextant icon
	reward.visible = false
	seq_puzzle.add_child(reward)
	
	# Add puzzle to ship
	ship.add_child(seq_puzzle)
	
	# Add ship to scene tree
	add_child(ship)
	
	# Position in world
	ship.global_position = Vector2(200, 800)  # Adjust as needed

# This example shows how you would set these up programmatically
# For real development, you would typically create scene files (.tscn)
# in the editor instead, which is easier than doing it all in code
