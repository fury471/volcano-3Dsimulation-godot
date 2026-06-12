class_name LavaChunksEmitter
extends Node3D

const DEFAULT_MULTIMESH_PATH := ^"LavaMM"

@export_group("Dependencies")
@export var target_multimesh_instance: MultiMeshInstance3D

@export_group("Spawn Settings")
@export var max_chunks: int = 256
@export var spawn_radius: float = 0.6

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

var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _sizes := PackedFloat32Array()
var _bases: Array[Basis] = []
var _angular_velocities := PackedVector3Array()
var _hit_counts := PackedByteArray()

var _active_count := 0
var _multimesh: MultiMesh
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_resolve_multimesh_instance()

	if not _validate_dependencies():
		return

	_initialize_multimesh()
	_allocate_buffers()


func _physics_process(delta: float) -> void:
	if _active_count == 0:
		return

	_simulate_chunks(delta)
	_update_render_instances()


func spawn_chunks(amount: int) -> void:
	var available_slots := max_chunks - _active_count
	var spawn_count := maxi(0, mini(amount, available_slots))

	for _i in range(spawn_count):
		_emit_chunk()


func _resolve_multimesh_instance() -> void:
	if target_multimesh_instance == null:
		target_multimesh_instance = get_node_or_null(DEFAULT_MULTIMESH_PATH) as MultiMeshInstance3D


func _validate_dependencies() -> bool:
	if target_multimesh_instance == null:
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

	if target_multimesh_instance.multimesh and target_multimesh_instance.multimesh.mesh:
		_multimesh.mesh = target_multimesh_instance.multimesh.mesh
	else:
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radial_segments = 8
		sphere_mesh.rings = 6
		_multimesh.mesh = sphere_mesh

	target_multimesh_instance.multimesh = _multimesh


func _allocate_buffers() -> void:
	_positions.resize(max_chunks)
	_velocities.resize(max_chunks)
	_ages.resize(max_chunks)
	_lifetimes.resize(max_chunks)
	_sizes.resize(max_chunks)

	_angular_velocities.resize(max_chunks)
	_hit_counts.resize(max_chunks)

	_bases.resize(max_chunks)
	for i in range(max_chunks):
		_bases[i] = Basis.IDENTITY

	_active_count = 0


func _emit_chunk() -> void:
	var idx := _active_count
	_active_count += 1

	var offset := _random_disc_offset()
	var radial_direction := _radial_direction_from(offset)

	_positions[idx] = offset
	_velocities[idx] = (
		Vector3.UP * _rng.randf_range(up_speed_min, up_speed_max)
		+ radial_direction * _rng.randf_range(out_speed_min, out_speed_max)
	)

	_ages[idx] = 0.0
	_lifetimes[idx] = _rng.randf_range(lifetime_min, lifetime_max)
	_sizes[idx] = _rng.randf_range(size_min, size_max)

	_bases[idx] = Basis.from_euler(Vector3(
		_rng.randf_range(0.0, TAU),
		_rng.randf_range(0.0, TAU),
		_rng.randf_range(0.0, TAU)
	))
	_angular_velocities[idx] = Vector3(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	).normalized() * _rng.randf_range(angular_speed_min, angular_speed_max)

	_hit_counts[idx] = 0


func _simulate_chunks(dt: float) -> void:
	var i := 0
	while i < _active_count:
		_ages[i] += dt
		if _ages[i] >= _lifetimes[i]:
			_remove_chunk(i)
			continue

		var acceleration := Vector3(0.0, gravity, 0.0)
		_velocities[i] -= _velocities[i] * drag_coefficient * dt

		_velocities[i] += acceleration * dt
		_positions[i] += _velocities[i] * dt

		if _handle_ground_collision(i):
			_remove_chunk(i)
			continue

		var euler_delta := _angular_velocities[i] * dt
		_bases[i] = _bases[i] * Basis.from_euler(euler_delta)

		i += 1


func _handle_ground_collision(index: int) -> bool:
	if not enable_ground_plane or _positions[index].y >= ground_y_local:
		return false

	_positions[index].y = ground_y_local

	if _velocities[index].y >= 0.0:
		return false

	_velocities[index].y = -_velocities[index].y * bounce
	_velocities[index].x *= 0.6
	_velocities[index].z *= 0.6

	_hit_counts[index] = mini(_hit_counts[index] + 1, 255)
	return kill_on_second_hit and _hit_counts[index] >= 2


func _remove_chunk(index: int) -> void:
	_active_count -= 1
	if index == _active_count:
		return

	var last := _active_count
	_positions[index] = _positions[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_sizes[index] = _sizes[last]

	_bases[index] = _bases[last]
	_angular_velocities[index] = _angular_velocities[last]
	_hit_counts[index] = _hit_counts[last]


func _random_disc_offset() -> Vector3:
	var radius := spawn_radius * sqrt(_rng.randf())
	var angle := _rng.randf() * TAU
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _radial_direction_from(offset: Vector3) -> Vector3:
	var direction := Vector3(offset.x, 0.0, offset.z)

	if direction.is_zero_approx():
		direction = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	if direction.is_zero_approx():
		return Vector3.FORWARD

	return direction.normalized()


func _update_render_instances() -> void:
	_multimesh.visible_instance_count = _active_count

	for i in range(_active_count):
		var life_ratio := clampf(_ages[i] / _lifetimes[i], 0.0, 1.0)
		var chunk_size := _sizes[i]
		var basis_scaled := _bases[i].scaled(Vector3.ONE * chunk_size)

		var instance_transform := Transform3D(basis_scaled, _positions[i])
		_multimesh.set_instance_transform(i, instance_transform)
		_multimesh.set_instance_custom_data(i, Color(life_ratio, 0.0, 0.0, 1.0))
