extends CharacterBody3D

var xr_interface: XRInterface

@export var movement_speed: float = 5.0
@export var turn_speed: float = 2.0
@export var mouse_sensitivity: float = 0.002
@export var climb_speed: float = 3.0

@onready var camera = $XROrigin3D/XRCamera3D
@onready var maze = get_node("../maze")
@onready var rope_detector = $RopeDetector

var near_rope: bool = false
var was_near_rope: bool = false
var climbing_rope_floor: int = -1

func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		rotate_y(-event.relative.x * mouse_sensitivity)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	check_rope()
	handle_movement(delta)

	if was_near_rope and not near_rope:
		on_leave_rope()
	was_near_rope = near_rope

func check_rope() -> void:
	near_rope = false
	for area in rope_detector.get_overlapping_areas():
		if area.name == "RopeArea":
			near_rope = true
			if area.has_meta("leads_to"):
				climbing_rope_floor = area.get_meta("leads_to")
			break

func on_leave_rope() -> void:
	if maze and climbing_rope_floor != -1:
		# DECISION: decide which floor we land on based on eye level
		var y_per = maze.y_per_floor
		var target_floor = floor((position.y + 1.6) / y_per)
		var floor_y_base = target_floor * y_per
		#snap
		position.y = floor_y_base + maze.slab_thickness + (maze.wall_height * 0.65) - 1.7
		velocity = Vector3.ZERO
		climbing_rope_floor = -1

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

	# PC Height (Z/X)
	if Input.is_key_pressed(KEY_Z): position.y += movement_speed * delta
	if Input.is_key_pressed(KEY_X): position.y -= movement_speed * delta

	# PC Climb/Descend (Q/E)
	var climb_dir = 0.0
	if near_rope:
		if Input.is_key_pressed(KEY_Q): climb_dir += 1.0
		if Input.is_key_pressed(KEY_E): climb_dir -= 1.0

		# VR Climb (A/X) and Descend (B/Y)
		if $XROrigin3D/Left:
			if $XROrigin3D/Left.is_button_pressed("ax_button"): climb_dir += 1.0
			if $XROrigin3D/Left.is_button_pressed("by_button"): climb_dir -= 1.0
		if $XROrigin3D/Right:
			if $XROrigin3D/Right.is_button_pressed("ax_button"): climb_dir += 1.0
			if $XROrigin3D/Right.is_button_pressed("by_button"): climb_dir -= 1.0

	if direction != Vector3.ZERO:
		direction.y = 0
		direction = direction.normalized()

	if maze and maze.collisions:
		velocity = (direction * movement_speed) + (Vector3.UP * climb_dir * climb_speed)
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		position += (direction * movement_speed * delta) + (Vector3.UP * climb_dir * climb_speed * delta)

	# Clamp height while climbing to prevent floor skipping
	if near_rope and maze and climbing_rope_floor != -1:
		var y_per = maze.y_per_floor

		# Allow climbing from eye-level of current floor to eye-level of target floor
		# Feet can travel from base of current floor to base of target floor + eyes
		var min_feet = (climbing_rope_floor - 1) * y_per + maze.slab_thickness + 0.2
		var max_feet = (climbing_rope_floor) * y_per + maze.slab_thickness + (maze.wall_height * 0.5)

		position.y = clamp(position.y, min_feet, max_feet)
