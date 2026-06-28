extends CharacterBody3D

var xr_interface: XRInterface

@export var movement_speed: float = 5.0
@export var turn_speed: float = 2.0
@export var mouse_sensitivity: float = 0.002

@onready var camera = $XROrigin3D/XRCamera3D
@onready var maze = get_node("../maze")

func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate camera for pitch
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		# Rotate CharacterBody3D for yaw
		rotate_y(-event.relative.x * mouse_sensitivity)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	handle_movement(delta)

func handle_movement(delta: float) -> void:
	var direction = Vector3.ZERO
	var basis = transform.basis

	# PC WASD
	if Input.is_key_pressed(KEY_W): direction -= basis.z
	if Input.is_key_pressed(KEY_S): direction += basis.z
	if Input.is_key_pressed(KEY_A): direction -= basis.x
	if Input.is_key_pressed(KEY_D): direction += basis.x

	# VR Left Stick
	if $XROrigin3D/Left:
		var input_vector = $XROrigin3D/Left.get_vector2("primary")
		if input_vector.length() > 0.1:
			direction += (-basis.z * input_vector.y) + (basis.x * input_vector.x)

	# VR Right Stick (Turning)
	if $XROrigin3D/Right:
		var input_vector = $XROrigin3D/Right.get_vector2("primary")
		if abs(input_vector.x) > 0.1:
			rotate_y(-input_vector.x * turn_speed * delta)

	# PC Height
	if Input.is_key_pressed(KEY_Q): position.y += movement_speed * delta
	if Input.is_key_pressed(KEY_E): position.y -= movement_speed * delta

	if direction != Vector3.ZERO:
		direction.y = 0
		direction = direction.normalized()

	if maze and maze.collisions:
		velocity = direction * movement_speed
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		position += direction * movement_speed * delta
