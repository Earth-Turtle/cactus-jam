extends CharacterBody2D

enum movementMode { ROLL, SPINY }

const GRAVITY: Vector2i = Vector2i(0.0, -650.0)
const ACCELERATION: float = 600.0
const MAX_VELOCITY: float = 500.0
const JUMP_STRENGTH: float = 300.0
const AIR_CONTROL_FACTOR: float = 0.4
const GROUND_FRICTION: float = 100.0

var move_state: movementMode = movementMode.ROLL
var is_grounded: bool = false

var circumference: float
var ang_velocity: float
const ANG_FRICTION: float = PI/16

@onready var body = $RollingCollisionBody
@onready var sprite = $Sprite2D


func _ready() -> void:
	circumference = 25 * 2 * PI # r * 2 * PI


func _physics_process(delta: float) -> void:
	# velocity calculation
	var velocity_direction: Vector2 = get_input()
	var velocity_rotation: float = Vector2.UP.angle_to(up_direction)
	velocity_direction = velocity_direction.rotated(velocity_rotation) # unit vector of velocity relative to current path
	
	if velocity_direction.angle_to(velocity) < (PI/2) and !is_grounded:
		velocity += velocity_direction * (ACCELERATION * delta) * AIR_CONTROL_FACTOR
	else:
		velocity += velocity_direction * (ACCELERATION * delta)
		
	velocity = velocity.clampf(-MAX_VELOCITY, MAX_VELOCITY)
	
	if velocity_direction.is_zero_approx() && is_grounded:
		velocity += velocity.direction_to(Vector2.ZERO) * GROUND_FRICTION * delta # apply friction
		if velocity.length() <= 6 and (up_direction.angle_to(Vector2.UP) < PI/4):
			velocity = Vector2.ZERO
		else:
			velocity -= GRAVITY * delta
	else:
		velocity -= GRAVITY * delta
	
	sprite_roll(velocity, delta)
	
	if move_and_slide():
		calculate_floor_angle()
	else:
		is_grounded = false
		up_direction = Vector2.UP
	


func calculate_floor_angle() -> void:
	if is_on_floor_only():
		up_direction = get_last_slide_collision().get_normal()
		is_grounded = true
	elif !is_grounded: #if in air and colliding with an object
		if get_last_slide_collision().get_collider().get_collision_layer() == 4:
			if get_last_slide_collision().get_normal().angle_to(Vector2.UP) < PI/8:
				up_direction = Vector2.UP
				is_grounded = false
		else:
			up_direction = get_last_slide_collision().get_normal()
			is_grounded = true
	else:
		up_direction = Vector2.UP


func sprite_roll(velocity: Vector2, delta: float) -> void:
	var distance: float = velocity.length() * delta
	if velocity.x < 0:
		distance = distance * -1
	if is_grounded:
		ang_velocity = distance / 25
	elif is_grounded and velocity.length() <= 2:
		ang_velocity = 0
	else:
		if ang_velocity > 0: # rotating clockwise
			ang_velocity = max(0, ang_velocity - ANG_FRICTION * delta)
		elif ang_velocity < 0: # rotating counterclockwise
			ang_velocity = min(0, ang_velocity + ANG_FRICTION * delta)
	
	sprite.rotate(ang_velocity)


func get_input() -> Vector2:
	if move_state == movementMode.ROLL:
		return Vector2(Input.get_axis("move_left", "move_right"), 0.0)
	
	return Vector2.ZERO


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("jump") and is_grounded:
		print("jump pressed")
		velocity += up_direction * JUMP_STRENGTH
