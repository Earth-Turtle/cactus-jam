class_name GravityComponent
extends Node

@export_subgroup("Settings")
@export var gravityStrength: float = 1000.0

var is_falling: bool = false

func handle_gravity(body: CharacterBody2D, delta: float) -> void:
	if not body.is_on_floor():
		# Larger Y is lower on the screen
		body.velocity.y += gravityStrength * delta
		
	is_falling = body.velocity.y > 0 and not body.is_on_floor()
