extends Node

var player_current_attack = false

# Sound management
func play_tool_sound(tool_type: String):
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
	
	var sound_node = null
	
	match tool_type:
		"Axe":
			sound_node = player.get_node_or_null("Sounds/WoodChop")
		"Pickaxe_Stone":
			sound_node = player.get_node_or_null("Sounds/StoneMine")
		"Pickaxe_Ore":
			sound_node = player.get_node_or_null("Sounds/OreMine")
	
	if sound_node:
		sound_node.play()
