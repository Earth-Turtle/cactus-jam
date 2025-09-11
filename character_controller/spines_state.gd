extends Node

signal change_state(state: String)
enum Player { LEFT, RIGHT, UP, DOWN }


func enter(prev_state: String) -> void:
	# do something here
	set_physics_process(true)
	pass


func exit(next_state: String) -> void:
	# do something here
	set_physics_process(false)
	pass


func _physics_process(delta: float) -> void:
	pass


func get_input() -> float:
	return Input.get_axis("move_left", "move_right")
