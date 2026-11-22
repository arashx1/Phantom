extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_speed: float = 7.0
@export var gravity_strength: float = 20.0
@export var mouse_sensitivity: float = 0.002

@onready var head: Node3D = $Head

var previous_movement := Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Player controller started")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(
				head.rotation.x,
				deg_to_rad(-85.0),
				deg_to_rad(85.0)
			)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity_strength * delta

	var movement := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	# Print only when movement input changes.
	if movement != previous_movement:
		print("Movement input: ", movement)
		previous_movement = movement

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var direction := global_transform.basis * Vector3(
			movement.x,
			0.0,
			movement.y
		)

		var speed := walk_speed
		if Input.is_action_pressed("sprint"):
			speed = sprint_speed

		velocity.x = direction.x * speed
		velocity.z = direction.z * speed

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	if global_position.y < -30.0:
		get_tree().reload_current_scene()
