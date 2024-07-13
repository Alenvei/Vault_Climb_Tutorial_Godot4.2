extends CharacterBody3D

@export var speed : float = 6.0
@export var jump_velocity : float = 8.0
@export var look_sensitivity : float = 0.001

@onready var camera : Camera3D = $Camera3D
@onready var head : Node3D = $Head
@onready var pivot : Node3D = $Head/Pivot
@onready var collision_shape = $CollisionShape3D


var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")*2
var velocity_y : float = 0
var update : bool = false
var gt_prev : Transform3D
var gt_current : Transform3D
var mesh_gt_prev : Transform3D
var mesh_gt_current : Transform3D

var obstacles : Array
var is_climbing : bool = false

func _ready():
	# Camera set up to prevent jitter.
	camera_setup()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
	
func _input(event):
	# Mouse movement.
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * look_sensitivity)
		
		head.rotate_x(-event.relative.y * look_sensitivity)
		
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)
		
# In-process func set up for preventing jitter.
func _process(delta):
	if update:
		update_transform()
		
		update = false
		
	var f = clamp(Engine.get_physics_interpolation_fraction(), 0 ,1)
	
	camera.global_transform = gt_prev.interpolate_with(gt_current, f)
	
func _physics_process(delta):
	update = true
	# Basic movement.
	var horizontal_velocity = Input.get_vector("left", "right", "forward", "backward").normalized() * speed
	
	velocity = horizontal_velocity.x * global_transform.basis.x + horizontal_velocity.y * global_transform.basis.z
	
	# Checking if the player is on the floor or climbing.
	if not is_on_floor() and not is_climbing:    
		velocity_y -= gravity * delta
		
	else:
		velocity_y = 0
		
	# Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity_y = jump_velocity 
		
	# Vaulting with place_to_land detection and animation.
	vaulting(delta)
	
	velocity.y = velocity_y
	move_and_slide()
	
# Camera set up to prevent jitter.
func camera_setup():
	camera.set_as_top_level(true)
	
	camera.global_transform = pivot.global_transform
	
	gt_prev = pivot.global_transform
	
	gt_current = pivot.global_transform
	
# Updating transform to interpolate the camera's movement for smoothness. 
func update_transform():
	gt_prev = gt_current
	
	gt_current = pivot.global_transform
	
# Creating RayCast via code.
func raycast(from: Vector3, to: Vector3):
	var space = get_world_3d().direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(from, to, 2)
	
	query.collide_with_areas = true
	
	return space.intersect_ray(query)

# Calculating the place_to_land position and initiating the vault animation.
func vaulting(delta):
	if Input.is_action_just_pressed("jump"):
		# Player's RayCast to detect climbable areas.
		var start_hit = raycast(camera.transform.origin, camera.to_global(Vector3(0, 0, -1)))
		
		if start_hit and obstacles.is_empty():
			# RayCast to detect the perfect place to land. (Not that special, I just exaggerate :D)
			var place_to_land = raycast(start_hit.position + self.to_global(Vector3.FORWARD) * collision_shape.shape.radius + 
			(Vector3.UP * collision_shape.shape.height), Vector3.DOWN * (collision_shape.shape.height))
			
			if place_to_land:
				# Playing the animation
				vault_animation(place_to_land)

# Animation for vaulting/climbing.
func vault_animation(place_to_land):
	# Player is climbing. This variable prevents hiccups along the process of climbing.
	is_climbing = true
	
	# First Tween animation will make player move up.
	var vertical_climb = Vector3(global_transform.origin.x, place_to_land.position.y, global_transform.origin.z)
	# If your player controller's pivot is located in the middle use this: 
	# var vertical_climb = Vector3(global_transform.origin.x, (place_to_land.position.y + collision_shape.shape.height / 2), global_transform.origin.z)
	var vertical_tween = get_tree().create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	vertical_tween.tween_property(self, "global_transform:origin", vertical_climb, 0.4)
	
	# We wait for the animation to finish.
	await vertical_tween.finished
	
	# Second Tween animation will make the player move forward where the player is facing.
	var forward = global_transform.origin + (-self.basis.z * 1.2)
	var forward_tween = get_tree().create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	forward_tween.tween_property(self, "global_transform:origin", forward, 0.3)
	
	# We wait for the animation to finish.
	await forward_tween.finished
	
	# Player isn't climbing anymore.
	is_climbing = false

# Obstacle detection above the head.
func _on_obstacle_detector_body_entered(body):
	if body != self:
		obstacles.append(body)

func _on_obstacle_detector_body_exited(body):
	if body != self :
		obstacles.remove_at(obstacles.find(body))








