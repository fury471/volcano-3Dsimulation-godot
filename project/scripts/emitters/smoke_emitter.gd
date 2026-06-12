class_name SmokeEmitter
extends Node3D

const DEFAULT_MULTIMESH_PATH := ^"SmokeMM"

@export_group("Dependencies")
@export var target_multimesh_instance: MultiMeshInstance3D

@export_group("Spawn Settings")
@export var max_particles: int = 64
@export var spawn_radius: float = 1.0

@export_subgroup("Lifetime")
@export var lifetime_min: float = 2.0
@export var lifetime_max: float = 5.0

@export_subgroup("Size")
@export var size_start_min: float = 0.15
@export var size_start_max: float = 0.35
@export var size_end_multiplier: float = 2.5

@export_group("Physics")
@export_subgroup("Velocities")
@export var up_speed_min: float = 3.0
@export var up_speed_max: float = 8.0
@export var out_speed_min: float = 0.5
@export var out_speed_max: float = 3.0

@export_subgroup("Forces")
@export var buoyancy: float = 6.0
@export var gravity: float = -1.5
@export var drag_coefficient: float = 0.35

@export_subgroup("Wind")
@export var wind_strength: float = 1.2
@export var wind_speed_change: float = 2.0

var _positions := PackedVector3Array()
var _velocities := PackedVector3Array()
var _ages := PackedFloat32Array()
var _lifetimes := PackedFloat32Array()
var _start_sizes := PackedFloat32Array()

var _active_count := 0
var _wind_phase := 0.0
var _current_wind_force := Vector3.ZERO
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

	_update_global_wind(delta)
	_simulate_particles(delta)
	_update_render_instances()


func spawn_particles(amount: int) -> void:
	var available_slots := max_particles - _active_count
	var spawn_count := maxi(0, mini(amount, available_slots))

	for _i in range(spawn_count):
		_emit_particle()


func _resolve_multimesh_instance() -> void:
	if target_multimesh_instance == null:
		target_multimesh_instance = get_node_or_null(DEFAULT_MULTIMESH_PATH) as MultiMeshInstance3D


func _validate_dependencies() -> bool:
	if target_multimesh_instance == null:
		push_error("SmokeEmitter: No MultiMeshInstance3D assigned in Inspector.")
		set_physics_process(false)
		return false
	return true


func _initialize_multimesh() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.instance_count = max_particles
	_multimesh.visible_instance_count = 0

	if target_multimesh_instance.multimesh and target_multimesh_instance.multimesh.mesh:
		_multimesh.mesh = target_multimesh_instance.multimesh.mesh
	else:
		_multimesh.mesh = SphereMesh.new()

	target_multimesh_instance.multimesh = _multimesh


func _allocate_buffers() -> void:
	_positions.resize(max_particles)
	_velocities.resize(max_particles)
	_ages.resize(max_particles)
	_lifetimes.resize(max_particles)
	_start_sizes.resize(max_particles)

	_positions.fill(Vector3.ZERO)
	_velocities.fill(Vector3.ZERO)
	_active_count = 0


func _emit_particle() -> void:
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
	_start_sizes[idx] = _rng.randf_range(size_start_min, size_start_max)


func _update_global_wind(dt: float) -> void:
	_wind_phase += dt * wind_speed_change
	_current_wind_force = Vector3(
		sin(_wind_phase * 1.7),
		0.0,
		cos(_wind_phase * 1.3)
	) * wind_strength


func _simulate_particles(dt: float) -> void:
	var i := 0

	while i < _active_count:
		_ages[i] += dt

		if _ages[i] >= _lifetimes[i]:
			_remove_particle(i)
			continue

		var acceleration := Vector3.ZERO
		acceleration.y += buoyancy + gravity
		acceleration += _current_wind_force

		_velocities[i] -= _velocities[i] * drag_coefficient * dt
		_velocities[i] += acceleration * dt
		_positions[i] += _velocities[i] * dt

		i += 1


func _remove_particle(index: int) -> void:
	_active_count -= 1

	if index == _active_count:
		return

	var last := _active_count
	_positions[index] = _positions[last]
	_velocities[index] = _velocities[last]
	_ages[index] = _ages[last]
	_lifetimes[index] = _lifetimes[last]
	_start_sizes[index] = _start_sizes[last]


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

		var current_size := lerpf(
			_start_sizes[i],
			_start_sizes[i] * size_end_multiplier,
			life_ratio
		)

		var basis_scaled := Basis.IDENTITY.scaled(Vector3.ONE * current_size)
		var instance_transform := Transform3D(basis_scaled, _positions[i])

		_multimesh.set_instance_transform(i, instance_transform)
		_multimesh.set_instance_custom_data(i, Color(current_size, life_ratio, 0.0, 0.0))
