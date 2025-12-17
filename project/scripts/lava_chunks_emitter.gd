class_name LavaChunksEmitter
extends Node3D

@export_group("Dependencies")
@export var target_multimesh_instance: MultiMeshInstance3D

@export_group("Spawn Settings")
@export var max_chunks: int = 256
@export var spawn_radius: float = 0.6
@export var initial_burst_count: int = 120

@export_subgroup("Lifetime")
@export var lifetime_min: float = 1.2
@export var lifetime_max: float = 3.5

@export_subgroup("Size")
@export var size_min: float = 0.08
@export var size_max: float = 0.22

@export_group("Ballistics")
@export_subgroup("Initial Velocity")
@export var up_speed_min: float = 10.0
@export var up_speed_max: float = 22.0
@export var out_speed_min: float = 2.0
@export var out_speed_max: float = 10.0

@export_subgroup("Forces")
@export var gravity: float = -28.0
@export var drag_coefficient: float = 0.08

@export_group("Rotation")
@export var angular_speed_min: float = 3.0
@export var angular_speed_max: float = 12.0

@export_group("Simple Collision")
@export var enable_ground_plane: bool = true
@export var ground_y_local: float = -2.0
@export var bounce: float = 0.05
@export var kill_on_second_hit: bool = false

# --- Internal State ---
var _p_positions := PackedVector3Array()
var _p_velocities := PackedVector3Array()
var _p_ages := PackedFloat32Array()
var _p_lifetimes := PackedFloat32Array()
var _p_sizes := PackedFloat32Array()

# rotation state
var _p_basis: Array[Basis] = []
var _p_ang_vel := PackedVector3Array()
var _p_hit_count := PackedByteArray()

var _active_count: int = 0
var _multimesh: MultiMesh
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()

	if not target_multimesh_instance:
		# child
		target_multimesh_instance = $LavaMM

	if not _validate_dependencies():
		return

	_initialize_multimesh()
	_allocate_buffers()
	# spawn_chunks(initial_burst_count)


func _physics_process(delta: float) -> void:
	if _active_count == 0:
		return

	_simulate_chunks(delta)
	_update_render_instances()


func _validate_dependencies() -> bool:
	if not target_multimesh_instance:
		push_error("LavaChunksEmitter: No MultiMeshInstance3D assigned.")
		set_physics_process(false)
		return false
	return true


func _initialize_multimesh() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.instance_count = max_chunks
	_multimesh.visible_instance_count = 0

	# Mesh fallback
	if target_multimesh_instance.multimesh and target_multimesh_instance.multimesh.mesh:
		_multimesh.mesh = target_multimesh_instance.multimesh.mesh
	else:
		var s := SphereMesh.new()
		s.radial_segments = 8
		s.rings = 6
		_multimesh.mesh = s

	target_multimesh_instance.multimesh = _multimesh


func _allocate_buffers() -> void:
	_p_positions.resize(max_chunks)
	_p_velocities.resize(max_chunks)
	_p_ages.resize(max_chunks)
	_p_lifetimes.resize(max_chunks)
	_p_sizes.resize(max_chunks)

	_p_ang_vel.resize(max_chunks)
	_p_hit_count.resize(max_chunks)

	_p_basis.resize(max_chunks)
	for i in range(max_chunks):
		_p_basis[i] = Basis.IDENTITY

	_active_count = 0


# --- Emission ---
func spawn_chunks(amount: int) -> void:
	for _i in range(amount):
		if _active_count >= max_chunks:
			break
		_emit_single_chunk()


func _emit_single_chunk() -> void:
	var idx := _active_count
	_active_count += 1

	# spawn in crater disk (local space)
	var r := spawn_radius * sqrt(_rng.randf())
	var theta := _rng.randf() * TAU
	var offset := Vector3(cos(theta) * r, 0.0, sin(theta) * r)
	_p_positions[idx] = offset

	# ballistic direction = up + radial
	var dir_radial := Vector3(offset.x, 0.0, offset.z)
	if dir_radial.length() > 0.0001:
		dir_radial = dir_radial.normalized()
	else:
		dir_radial = Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()

	var v_up := Vector3.UP * _rng.randf_range(up_speed_min, up_speed_max)
	var v_out := dir_radial * _rng.randf_range(out_speed_min, out_speed_max)
	_p_velocities[idx] = v_up + v_out

	_p_ages[idx] = 0.0
	_p_lifetimes[idx] = _rng.randf_range(lifetime_min, lifetime_max)
	_p_sizes[idx] = _rng.randf_range(size_min, size_max)

	# random rotation + angular velocity
	_p_basis[idx] = Basis.from_euler(Vector3(
		_rng.randf_range(0.0, TAU),
		_rng.randf_range(0.0, TAU),
		_rng.randf_range(0.0, TAU)
	))
	_p_ang_vel[idx] = Vector3(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	).normalized() * _rng.randf_range(angular_speed_min, angular_speed_max)

	_p_hit_count[idx] = 0


# --- Simulation ---
func _simulate_chunks(dt: float) -> void:
	var i := 0
	while i < _active_count:
		_p_ages[i] += dt
		if _p_ages[i] >= _p_lifetimes[i]:
			_swap_remove(i)
			continue

		# forces
		var acc := Vector3(0.0, gravity, 0.0)
		_p_velocities[i] -= _p_velocities[i] * drag_coefficient * dt

		# integrate
		_p_velocities[i] += acc * dt
		var prev_pos := _p_positions[i]
		_p_positions[i] += _p_velocities[i] * dt

		# simple collision against local y-plane
		if enable_ground_plane and _p_positions[i].y < ground_y_local:
			_p_positions[i].y = ground_y_local

			# bounce only if moving downward
			if _p_velocities[i].y < 0.0:
				_p_velocities[i].y = -_p_velocities[i].y * bounce
				_p_velocities[i].x *= 0.6
				_p_velocities[i].z *= 0.6

				_p_hit_count[i] = min(_p_hit_count[i] + 1, 255)
				if kill_on_second_hit and _p_hit_count[i] >= 2:
					_swap_remove(i)
					continue

		# rotation integration (small-angle Euler
		var euler_delta := _p_ang_vel[i] * dt
		_p_basis[i] = _p_basis[i] * Basis.from_euler(euler_delta)

		i += 1


func _swap_remove(index: int) -> void:
	_active_count -= 1
	if index == _active_count:
		return

	var last := _active_count
	_p_positions[index] = _p_positions[last]
	_p_velocities[index] = _p_velocities[last]
	_p_ages[index] = _p_ages[last]
	_p_lifetimes[index] = _p_lifetimes[last]
	_p_sizes[index] = _p_sizes[last]

	_p_basis[index] = _p_basis[last]
	_p_ang_vel[index] = _p_ang_vel[last]
	_p_hit_count[index] = _p_hit_count[last]


# --- Rendering ---
func _update_render_instances() -> void:
	_multimesh.visible_instance_count = _active_count

	for i in range(_active_count):
		# life ratio (0..1)
		var u := clampf(_p_ages[i] / _p_lifetimes[i], 0.0, 1.0)

		# scale
		var s := _p_sizes[i]
		var basis_scaled := _p_basis[i].scaled(Vector3.ONE * s)

		var t := Transform3D(basis_scaled, _p_positions[i])
		_multimesh.set_instance_transform(i, t)

		# custom data: use u for "cooling" later in shader
		_multimesh.set_instance_custom_data(i, Color(u, 0.0, 0.0, 1.0))
