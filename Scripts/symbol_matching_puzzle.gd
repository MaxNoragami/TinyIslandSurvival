extends PuzzleMechanism
class_name SymbolMatchingPuzzle

# Each symbol has a matching pair
@export var symbol_count: int = 4
@export var symbols_to_match = [0, 1, 2, 3, 0, 1, 2, 3]  # Indices match in pairs
@export var match_timeout: float = 1.0  # Time to show pair before hiding if incorrect

# State tracking
var selected_symbols = []
var matched_pairs = []
var symbols = []
var is_checking = false

func _ready():
	super._ready()
	
	# Extend puzzle configuration
	puzzle_id = "symbol_matching_puzzle"
	
	# Initialize symbols
	symbols_to_match.shuffle()  # Randomize positions
	
	# Find all symbol nodes
	for i in range(8):  # Assuming 8 symbols total
		var symbol = get_node_or_null("Symbol" + str(i+1))
		if symbol:
			symbols.append(symbol)
			
			# Hide actual symbol initially
			var symbol_sprite = symbol.get_node_or_null("SymbolSprite")
			if symbol_sprite:
				symbol_sprite.visible = false
			
			# Set up interaction area for each symbol
			var area = symbol.get_node_or_null("InteractionArea")
			if area:
				# Use a lambda to capture the symbol index
				var symbol_index = i
				area.body_entered.connect(func(body): _on_symbol_area_entered(body, symbol_index))
	
	# Override hint
	emit_signal("show_message", get_puzzle_hint())

func get_puzzle_hint():
	return "Ancient symbols cover the wall. Perhaps they form pairs?"

func _on_symbol_area_entered(body, symbol_index):
	if body.is_in_group("Player") and not is_solved and not is_checking:
		select_symbol(symbol_index)

func select_symbol(index):
	if is_solved or index >= symbols.size() or is_checking:
		return
		
	var symbol = symbols[index]
	
	# Don't re-select already matched symbols
	if matched_pairs.has(index):
		return
		
	# Don't select already selected symbol
	if selected_symbols.has(index):
		return
		
	print("SymbolMatchingPuzzle: Selecting symbol " + str(index))
	
	# Show this symbol
	var symbol_sprite = symbol.get_node_or_null("SymbolSprite")
	if symbol_sprite:
		symbol_sprite.visible = true
		
		# Set the proper symbol
		var symbol_type = symbols_to_match[index]
		symbol_sprite.frame = symbol_type
	
	# Add to selected
	selected_symbols.append(index)
	
	# If we've selected 2, check for a match
	if selected_symbols.size() == 2:
		is_checking = true
		check_match()

func check_match():
	# Get the symbol values for the two selected
	var index1 = selected_symbols[0]
	var index2 = selected_symbols[1]
	
	var type1 = symbols_to_match[index1]
	var type2 = symbols_to_match[index2]
	
	var is_match = (type1 == type2)
	
	if is_match:
		# This is a match!
		_show_action_feedback(true)
		
		# Add to matched pairs
		matched_pairs.append(index1)
		matched_pairs.append(index2)
		
		# Clear selected
		selected_symbols.clear()
		
		# Show message
		emit_signal("show_message", "You found a matching pair!")
		
		# Update progress
		var progress = float(matched_pairs.size()) / float(symbols.size())
		emit_signal("puzzle_progress_changed", progress)
		
		# Check if all pairs are matched
		if matched_pairs.size() == symbols.size():
			await get_tree().create_timer(0.5).timeout
			solve_puzzle()
		
		is_checking = false
	else:
		# Not a match, hide both after a delay
		_show_action_feedback(false)
		emit_signal("show_message", "Those symbols don't match...")
		
		await get_tree().create_timer(match_timeout).timeout
		
		# Hide the symbols
		for index in selected_symbols:
			var symbol = symbols[index]
			var symbol_sprite = symbol.get_node_or_null("SymbolSprite")
			if symbol_sprite:
				symbol_sprite.visible = false
		
		# Clear selected
		selected_symbols.clear()
		is_checking = false

func _play_solution_effect():
	# Play a more elaborate effect for solving
	
	# Flash all symbols
	for symbol in symbols:
		var symbol_sprite = symbol.get_node_or_null("SymbolSprite")
		if symbol_sprite:
			var tween = create_tween()
			tween.tween_property(symbol_sprite, "modulate", Color(1, 1, 0), 0.2)
			tween.tween_property(symbol_sprite, "modulate", Color(0, 1, 1), 0.2)
			tween.tween_property(symbol_sprite, "modulate", Color(1, 1, 1), 0.3)
	
	# Then reveal the reward
	var reward = get_node_or_null("Reward")
	if reward:
		await get_tree().create_timer(1.0).timeout
		reward.visible = true
		var reward_tween = create_tween()
		reward_tween.tween_property(reward, "scale", Vector2(1.5, 1.5), 0.3)
		reward_tween.tween_property(reward, "scale", Vector2(1.0, 1.0), 0.2)
	
	emit_signal("show_message", "The symbols align and a hidden compartment opens!")
