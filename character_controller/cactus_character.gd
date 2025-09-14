extends CharacterBody2D

enum movementMode { ROLL, SPINY }
enum Player { LEFT, RIGHT, UP, DOWN }

const GRAVITY: Vector2i = Vector2i(0.0, -650.0)
const ACCELERATION: float = 700.0
const MAX_VELOCITY: float = 800.0
const JUMP_STRENGTH: float = 300.0
const AIR_CONTROL_FACTOR: float = 0.4
const GROUND_FRICTION: float = 100.0
const UPSIDE_DOWN_STICK_THRESHOLD: float = 400.0
const BOUNCE_VELOCITY_THRESHOLD: float = 150.0

var move_state: movementMode
var is_grounded: bool = false
var is_jumping: bool = false
var is_bouncing: bool = false
var prev_frame_velocity: Vector2

var is_falling_animation: bool = false
var is_bouncing_animation: bool = false
var is_blurred: bool = false
var speeding: bool = false
const SPEEDING_LIMIT: float = 550.0

var circumference: float
var ang_velocity: float
const ANG_FRICTION: float = PI/16

var camera_target_position: Vector2 = Vector2(0,0)

@onready var body = $RollingCollisionBody
@onready var sprite_mask = $Sprites
@onready var sprite = $Sprites/Sprite2D
@onready var spikes = $Sprites/SpikesSprite
@onready var face = $FaceSprite
@onready var sensor = $GroundSensorCast
@onready var snap_sensor = $AirborneSensorCast
@onready var anim_player = $Sprites/AnimationPlayer
@onready var state_machine = $StateMachine
@onready var camera = $Camera2D
@onready var jump_effects_player = $JumpEffectsPlayer2D
@onready var landing_effects_player = $LandingEffectsPlayer2D


func _ready() -> void:
	circumference = 25 * 2 * PI # r * 2 * PI

#region physics

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
	
	prev_frame_velocity = velocity
	
	if move_and_slide(): #if collision occurs
		if should_bounce():
			play_land_sound() # TODO: scale volume based on speed
			bounce()
		else:
			calculate_floor_angle()
	else: # no collision occurred, but check to see if we are accidentally leaving the ground
		sensor_vector()
	
	$velvector.rotation = velocity.angle() + PI/2 ## TEMP


func calculate_floor_angle() -> void: # only called if a collision is happening
	if is_on_floor_only():
		up_direction = get_last_slide_collision().get_normal()
		sprite_land()
		is_grounded = true
		is_bouncing = false
		
	elif !is_grounded: #if in air but contacting a surface...
		if get_last_slide_collision().get_collider().get_collision_layer() == 4: #contacting "slippery" wall
			floor_snap_length = 1.0
			if get_last_slide_collision().get_normal().angle_to(Vector2.UP) < PI/8:
				up_direction = Vector2.UP
				is_grounded = false
		else: 
			play_land_sound()
			sprite_land()
			is_grounded = true
			is_bouncing = false
	else: 
		up_direction = Vector2.UP
	
	sensor.rotation = up_direction.angle() + PI/2


func should_bounce() -> bool:
	var normal = get_last_slide_collision().get_normal()
	var velocity_to_normal = prev_frame_velocity.bounce(normal).project(normal)
	return abs(prev_frame_velocity.bounce(normal).angle_to(normal)) < PI/4 and velocity_to_normal.length() > BOUNCE_VELOCITY_THRESHOLD


func should_bounce_ray(collision: RayCast2D) -> bool:
	var normal = collision.get_collision_normal()
	var velocity_to_normal = velocity.bounce(normal).project(normal)
	return (abs(velocity.bounce(normal).angle_to(normal)) < PI/4) and velocity.length() > BOUNCE_VELOCITY_THRESHOLD


func bounce() -> void:
	# Project velocity onto normal vector and tangent vector
	var normal = get_last_slide_collision().get_normal()
	var tangent
	if prev_frame_velocity.x < 0:
		tangent = normal.rotated(PI/4)
	else:
		tangent = normal.rotated(-(PI/4))
	var normal_vector = prev_frame_velocity.project(normal)
	var tangent_vector = prev_frame_velocity.project(tangent)
	
	# Determine if the bounce is a hard bounce (within PI/12 or 15 degrees either direction)
	if abs(prev_frame_velocity.bounce(normal).angle_to(normal)) < PI/12: # Hard bounce
		print("Hard bounce")
		normal_vector *= -0.5 # bounce off of normal hard
		tangent_vector *= 0.4 # kill tangent speed for a thumpier bounce
	else: # Soft bounce
		print("Soft bounce")
		normal_vector *= -0.9 # bounce off of normal, number is high because velocity going into the bounce is usually low
		tangent_vector *= 0.95 # maintain tangent speed
	
	var bounce_vector = normal_vector + tangent_vector
	
	is_grounded = false
	is_bouncing = true
	velocity = bounce_vector
	


func sensor_vector() -> void:
	if sensor.is_colliding() and !is_jumping and !is_bouncing: 
		# we must have disconnected from the ground on a concave curve
		
		up_direction = sensor.get_collision_normal()
		apply_floor_snap()
	elif !(sensor.is_colliding()) and (is_jumping or is_bouncing):
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
	if snap_sensor.is_colliding() and !should_bounce_ray(snap_sensor):
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
			
#endregion

#region sprite manipulation

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
	
	if !(ang_velocity > -0.2 and ang_velocity < 0.2): # 0.37 is speeding ang_velocity
		blur(true)
	else:
		blur(false)
	
	sprite.rotate(ang_velocity)
	spikes.rotate(ang_velocity)
	
	if is_falling_animation:
		sprite_mask.rotation = velocity.angle()
	if is_bouncing_animation:
		sprite_mask.rotation = velocity.angle() - PI/2


func face_shift() -> void:
	var factor = velocity.length() / MAX_VELOCITY
	face.position = velocity.normalized() * factor * 5
	camera.position = velocity.normalized() * factor * 100


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


func blur(blur: bool) -> void:
	if is_blurred != blur:
		is_blurred = blur
		var tween = create_tween()
		if blur:
			tween.tween_method(set_param, 0.0, 0.1, 0.5)
		else:
			tween.tween_method(set_param, 0.1, 0.0, 0.5)
		await tween.finished
		tween.kill()


func set_param(val: float) -> void:
	spikes.material.set_shader_parameter("amount", val)
	sprite.material.set_shader_parameter("amount", val)


func sprite_anim_changed(old_anim, new_anim) -> void:
	if new_anim == "fall_loop":
		is_falling_animation = true
	
	if old_anim == "fall_loop":
		is_falling_animation = false
	
	if old_anim == "land":
		sprite_mask.rotation = 0;
	
	if old_anim == "bounce":
		is_bouncing_animation = false

#endregion

#region sound effects

func play_jump_sound() -> void:
	jump_effects_player.play()
	
func play_land_sound(impact_strength: float = 0.5):
	landing_effects_player.play()
	


#endregion


func get_input() -> Vector2:
	if move_state == movementMode.ROLL:
		return Vector2(Input.get_axis("move_left", "move_right"), 0.0)
	
	return Vector2.ZERO


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("jump") and is_grounded:
		print("jump pressed while grounded")
		velocity += up_direction * JUMP_STRENGTH
		is_jumping = true
		play_jump_sound()
		sprite_jump()
	
