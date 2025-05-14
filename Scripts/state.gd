extends Node
class_name State

var state_machine = null
var player = null

func enter():
    pass

func exit():
    pass

func process_state(delta):
    pass

func physics_process_state(delta):
    pass

func transition_to(new_state):
    state_machine.change_state(new_state)
