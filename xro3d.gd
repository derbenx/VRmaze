extends XROrigin3D

var xr_interface: XRInterface

@export var movement_speed: float = 2.0
@export var turn_speed: float = 1.5
@export var mouse_sensitivity: float = 0.005

var is_right_click_pressed: bool = false
var selected_node: MeshInstance3D = null
var is_dragging: bool = false
var drag_offset: Vector3
var dragging_controller: Node = null

@onready var camera = $XRCamera3D
@onready var maze = get_parent().get_node("maze")

func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true

	setup_vr_controller($Left)
	setup_vr_controller($Right)

func setup_vr_controller(controller: XRController3D) -> void:
	var ray = RayCast3D.new()
	ray.name = "RayCast"
	ray.target_position = Vector3(0, 0, -10)
	ray.enabled = true
	controller.add_child(ray)

	var laser = MeshInstance3D.new()
	laser.name = "Laser"
	var laser_mesh = BoxMesh.new()
	laser_mesh.size = Vector3(0.005, 0.005, 10.0)
	laser.mesh = laser_mesh
	laser.position.z = -5.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.5)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	laser.material_override = mat
	controller.add_child(laser)

func _process(delta: float) -> void:
	handle_pc_movement(delta)
	handle_vr_movement(delta)

func handle_pc_movement(delta: float) -> void:
	var direction = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S): direction += transform.basis.z
	if Input.is_key_pressed(KEY_Q): direction += transform.basis.y
	if Input.is_key_pressed(KEY_E): direction -= transform.basis.y
	if Input.is_key_pressed(KEY_UP): direction += transform.basis.y
	if Input.is_key_pressed(KEY_DOWN): direction -= transform.basis.y
	if Input.is_key_pressed(KEY_LEFT): direction -= transform.basis.x
	if Input.is_key_pressed(KEY_RIGHT): direction += transform.basis.x

	if direction != Vector3.ZERO:
		position += direction.normalized() * movement_speed * delta

	if Input.is_key_pressed(KEY_A): rotate_y(turn_speed * delta)
	if Input.is_key_pressed(KEY_D): rotate_y(-turn_speed * delta)

func handle_vr_movement(delta: float) -> void:
	if $Left:
		var p = $Left.get_vector2("primary")
		position -= transform.basis.z * p.y * movement_speed * delta
	if $Right:
		var p = $Right.get_vector2("primary")
		position += transform.basis.y * p.y * movement_speed * delta
