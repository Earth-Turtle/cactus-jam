extends CharacterBody2D

enum movementMode { ROLL, SPINY }

const GRAVITY: Vector2i = Vector2i(0.0, -500.0)
const ACCELERATION: float = 600.0
const MAX_VELOCITY: float = 500.0
const JUMP_STRENGTH: float = 300.0
const AIR_BRAKE_FACTOR: float = 1.5

var move_state: movementMode = movementMode.ROLL
var is_grounded: bool = false

@onready var body = $RollingCollisionBody

func _physics_process(delta: float) -> void:
	# velocity calculation
	var velocity_direction: Vector2 = get_input()
	var velocity_rotation: float = Vector2.UP.angle_to(up_direction)
	velocity_direction = velocity_direction.rotated(velocity_rotation) # unit vector of velocity relative to current path
	
	if velocity_direction.angle_to(velocity) > (PI/2) and !is_grounded:
		velocity += velocity_direction * (ACCELERATION * delta) * AIR_BRAKE_FACTOR
	else:
		velocity += velocity_direction * (ACCELERATION * delta)
	
	
	velocity -= GRAVITY * delta
	velocity = velocity.clampf(-MAX_VELOCITY, MAX_VELOCITY)
	
	if move_and_slide():
		calculate_floor_angle()
		print(up_direction)
	else:
		is_grounded = false


func calculate_floor_angle() -> void:
	if is_on_floor_only():
		up_direction = get_last_slide_collision().get_normal()
		is_grounded = true
	elif !is_grounded: #if in air and colliding with an o(bject
		up_direction = get_last_slide_collision().get_normal()
		is_grounded = true
	else:
		up_direction = Vector2.UP
		is_grounded = false
	


func get_input() -> Vector2:
	if move_state == movementMode.ROLL:
		return Vector2(Input.get_axis("move_left", "move_right"), 0.0)
	
	return Vector2.ZERO


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("jump") and is_grounded:
		print("jump pressed")
		velocity += up_direction * JUMP_STRENGTH
