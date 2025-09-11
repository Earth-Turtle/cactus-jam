extends CharacterBody2D

enum movementMode { ROLL, SPINY }

const GRAVITY: Vector2i = Vector2i(0.0, -650.0)
const ACCELERATION: float = 700.0
const MAX_VELOCITY: float = 800.0
const JUMP_STRENGTH: float = 300.0
const AIR_CONTROL_FACTOR: float = 0.4
const GROUND_FRICTION: float = 100.0
const UPSIDE_DOWN_STICK_THRESHOLD: float = 550.0

var move_state: movementMode = movementMode.ROLL
var is_grounded: bool = false
var is_jumping: bool = false

var is_falling_animation: bool = false
var speeding: bool = false
const SPEEDING_LIMIT: float = 550.0

var circumference: float
var ang_velocity: float
const ANG_FRICTION: float = PI/16

@onready var body = $RollingCollisionBody
@onready var sprite_mask = $Sprites
@onready var sprite = $Sprites/Sprite2D
@onready var spikes = $Sprites/SpikesSprite
@onready var face = $FaceSprite
@onready var sensor = $GroundSensorCast
@onready var snap_sensor = $AirborneSensorCast
@onready var anim_player = $Sprites/AnimationPlayer


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
	
	if velocity_direction.is_zero_approx() and is_grounded:
		velocity += velocity.direction_to(Vector2.ZERO) * GROUND_FRICTION * delta # apply friction
		if velocity.length() <= 6 and (abs(up_direction.angle_to(Vector2.UP)) < PI/16): 
			velocity = Vector2.ZERO
		else:
			velocity -= GRAVITY * delta
	else:
		velocity -= GRAVITY * delta
	
	if abs(up_direction.angle_to(Vector2.DOWN)) < PI/4 and is_grounded and velocity.length() > UPSIDE_DOWN_STICK_THRESHOLD: # if ball is on an upside down surface
		velocity += GRAVITY * delta
	
	sprite_roll(delta)
	sprite_speed()
	face_shift()
	
	if move_and_slide(): #if collision occurs
		calculate_floor_angle()
	else: # no collision occurred, but check to see if we are accidentally leaving the ground
		sensor_vector()
	
	$velvector.rotation = velocity.angle() + PI/2 ## TEMP


func calculate_floor_angle() -> void: # only called if a collision is happening
	if is_on_floor():
		up_direction = get_last_slide_collision().get_normal()
		sprite_land()
		is_grounded = true
		
	elif !is_grounded: #if in air but contacting a surface...
		if get_last_slide_collision().get_collider().get_collision_layer() == 4: #contacting "slippery" wall
			floor_snap_length = 1.0
			if get_last_slide_collision().get_normal().angle_to(Vector2.UP) < PI/8:
				up_direction = Vector2.UP
				is_grounded = false
		else: 
			sprite_land()
			is_grounded = true
	else: 
		up_direction = Vector2.UP
	
	sensor.rotation = up_direction.angle() + PI/2


func sensor_vector() -> void:
	if sensor.is_colliding() and !is_jumping: 
		# we must have disconnected from the ground on a concave curve
		
		up_direction = sensor.get_collision_normal()
		apply_floor_snap()
	elif !(sensor.is_colliding()) and is_jumping:
		is_jumping = false
		# we have cleared the ground by now, we can use the airborne sensor cast
		snap_sensor.rotation = velocity.angle()
		if velocity.x < 0:
			snap_sensor.rotate(1.5* PI)
		sprite_fall()
		sphere_snap()
	else: # we must either be jumping or went off an edge
		# follow velocity for future snapping
		up_direction = Vector2.UP
		is_grounded = false
		snap_sensor.rotation = velocity.angle()
		if velocity.x < 0:
			snap_sensor.rotate(1.5* PI)
		sprite_fall()
		sphere_snap()


func sphere_snap() -> void:
	if snap_sensor.is_colliding():
		if snap_sensor.get_collider().get_collision_layer() == 4:
			#slippery wall
			if snap_sensor.get_collision_normal().angle_to(Vector2.UP) < PI/8:
				up_direction = Vector2.UP
				is_grounded = false
			else:
				up_direction = snap_sensor.get_collision_normal()
				sprite_land()
				apply_floor_snap()
		else: # sticky wall
			up_direction = snap_sensor.get_collision_normal()
			sprite_land()
			apply_floor_snap()


func sprite_roll(delta: float) -> void:
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
	spikes.rotate(ang_velocity)
	
	if is_falling_animation:
		sprite_mask.rotation = velocity.angle()


func face_shift() -> void:
	var factor = velocity.length() / MAX_VELOCITY
	face.position = velocity.normalized() * factor * 5


func sprite_jump() -> void:
	sprite_mask.rotation = up_direction.angle()
	anim_player.play("jump")
	anim_player.queue("fall_loop")


func sprite_fall() -> void:
	if !is_falling_animation:
		anim_player.play("fall")
	anim_player.queue("fall_loop")
	is_falling_animation = true


func sprite_land() -> void:
	if is_falling_animation:
		sprite_mask.rotation = up_direction.angle() + PI/2
		anim_player.play("land")
		is_falling_animation = false


func sprite_speed() -> void:
	if velocity.length() > SPEEDING_LIMIT:
		speeding = true
		if velocity.x > 0:
			sprite_mask.skew = deg_to_rad(maxf(0.0, ((velocity.x - SPEEDING_LIMIT) / 25)))
		if velocity.x < 0:
			sprite_mask.skew = deg_to_rad(minf(0.0, (velocity.x + SPEEDING_LIMIT) / 25))
	else:
		speeding = false
		sprite_mask.skew = 0.0
	
	if speeding and abs(up_direction.angle_to(Vector2.DOWN)) < PI / 2:
		sprite_mask.skew = sprite_mask.skew * -1


func sprite_anim_changed(old_anim, new_anim) -> void:
	print("Animation changed: " + old_anim + " -> " + new_anim)
	if new_anim == "fall_loop":
		is_falling_animation = true
	
	if old_anim == "fall_loop":
		is_falling_animation = false
	
	if old_anim == "land":
		sprite_mask.rotation = 0;


func get_input() -> Vector2:
	if move_state == movementMode.ROLL:
		return Vector2(Input.get_axis("move_left", "move_right"), 0.0)
	
	return Vector2.ZERO


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("jump") and is_grounded:
		print("jump pressed")
		velocity += up_direction * JUMP_STRENGTH
		is_jumping = true
		sprite_jump()
