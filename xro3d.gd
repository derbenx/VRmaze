extends XROrigin3D

var xr_interface: XRInterface

@export var movement_speed: float = 5.0
@export var turn_speed: float = 2.0
@export var mouse_sensitivity: float = 0.002

@onready var camera = $XRCamera3D

func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# PC Mouse look
		# Rotate the camera for pitch
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		# Rotate the origin for yaw
		rotate_y(-event.relative.x * mouse_sensitivity)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	handle_pc_movement(delta)
	handle_vr_movement(delta)

func handle_pc_movement(delta: float) -> void:
	var direction = Vector3.ZERO
	var basis = transform.basis

	if Input.is_key_pressed(KEY_W): direction -= basis.z
	if Input.is_key_pressed(KEY_S): direction += basis.z
	if Input.is_key_pressed(KEY_A): direction -= basis.x
	if Input.is_key_pressed(KEY_D): direction += basis.x

	if direction != Vector3.ZERO:
		# Keep movement on the ground
		direction.y = 0
		position += direction.normalized() * movement_speed * delta

func handle_vr_movement(delta: float) -> void:
	# Left Stick for Movement
	if $Left:
		var input_vector = $Left.get_vector2("primary")
		if input_vector.length() > 0.1:
			var basis = transform.basis
			var direction = (-basis.z * input_vector.y) + (basis.x * input_vector.x)
			direction.y = 0
			position += direction.normalized() * movement_speed * delta * input_vector.length()

	# Right Stick for Turning
	if $Right:
		var input_vector = $Right.get_vector2("primary")
		if abs(input_vector.x) > 0.1:
			rotate_y(-input_vector.x * turn_speed * delta)
