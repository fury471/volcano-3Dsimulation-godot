extends Camera3D

# Configuration
@export_group("Speeds")
@export var move_speed: float = 10.0
@export var boost_multiplier: float = 2.5 # Hold Shift to go faster
@export var mouse_sensitivity: float = 0.003

var _mouse_captured: bool = false

func _ready() -> void:
	# Start with mouse captured immediately
	_capture_mouse()

func _unhandled_input(event: InputEvent) -> void:
	# 1. Handle Mouse Rotation
	if event is InputEventMouseMotion and _mouse_captured:
		_rotate_camera(event.relative)
	
	# 2. Toggle Mouse Capture (Tab to capture, Esc to free)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_release_mouse()
		elif event.keycode == KEY_TAB:
			_capture_mouse()

func _process(delta: float) -> void:
	if not _mouse_captured:
		return

	# 1. Determine Speed
	var current_speed = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= boost_multiplier

	# 2. WASD Movement (Relative to where you are looking)
	var input_dir = Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W): input_dir += Vector3.FORWARD
	if Input.is_key_pressed(KEY_S): input_dir += Vector3.BACK
	if Input.is_key_pressed(KEY_A): input_dir += Vector3.LEFT
	if Input.is_key_pressed(KEY_D): input_dir += Vector3.RIGHT
	
	# Transform input direction by camera's rotation to move "locally"
	# Normalized ensures diagonal movement isn't faster
	var velocity = global_basis * input_dir.normalized()
	
	# 3. Q/E Vertical Movement (Global Up/Down)
	# We do this separately so looking down + pressing E doesn't move you backwards
	var vertical_dir = 0.0
	if Input.is_key_pressed(KEY_Q): vertical_dir += 1.0 # Up
	if Input.is_key_pressed(KEY_E): vertical_dir -= 1.0 # Down
	
	# Apply
	global_position += velocity * current_speed * delta
	global_position.y += vertical_dir * current_speed * delta

# Helpers
func _rotate_camera(mouse_delta: Vector2) -> void:
	# Rotate Left/Right (Y-axis)
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	
	# Rotate Up/Down (X-axis) - Clamped to prevent flipping upside down
	rotate_object_local(Vector3.RIGHT, -mouse_delta.y * mouse_sensitivity)
	
	# Clamp pitch so you can't break your neck
	rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true

func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false
