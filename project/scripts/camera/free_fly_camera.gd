class_name FreeFlyCamera
extends Camera3D

const MIN_PITCH := deg_to_rad(-90.0)
const MAX_PITCH := deg_to_rad(90.0)

@export_group("Movement")
@export var move_speed: float = 10.0
@export var boost_multiplier: float = 2.5

@export_group("Look")
@export var mouse_sensitivity: float = 0.002
@export var capture_mouse_on_start: bool = true

var _mouse_captured := false


func _ready() -> void:
	if capture_mouse_on_start:
		_capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		var mouse_event := event as InputEventMouseMotion
		_rotate_camera(mouse_event.relative)
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			_handle_key_press(key_event.keycode)


func _process(delta: float) -> void:
	if not _mouse_captured:
		return

	var current_speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= boost_multiplier

	var movement := _get_local_movement_direction()
	var vertical := _get_vertical_axis()

	global_position += global_basis * movement * current_speed * delta
	global_position.y += vertical * current_speed * delta


func _handle_key_press(keycode: int) -> void:
	match keycode:
		KEY_ESCAPE:
			_release_mouse()
		KEY_TAB:
			_capture_mouse()


func _get_local_movement_direction() -> Vector3:
	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction += Vector3.FORWARD
	if Input.is_key_pressed(KEY_S):
		direction += Vector3.BACK
	if Input.is_key_pressed(KEY_A):
		direction += Vector3.LEFT
	if Input.is_key_pressed(KEY_D):
		direction += Vector3.RIGHT

	return direction.normalized()


func _get_vertical_axis() -> float:
	var axis := 0.0

	if Input.is_key_pressed(KEY_Q):
		axis += 1.0
	if Input.is_key_pressed(KEY_E):
		axis -= 1.0

	return axis


func _rotate_camera(mouse_delta: Vector2) -> void:
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	rotate_object_local(Vector3.RIGHT, -mouse_delta.y * mouse_sensitivity)
	rotation.x = clampf(rotation.x, MIN_PITCH, MAX_PITCH)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_captured = true


func _release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_captured = false
