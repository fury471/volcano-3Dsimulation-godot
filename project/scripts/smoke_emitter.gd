class_name SmokeEmitter
extends Node3D

# --- Configuration ---
@export_group("Dependencies")
@export var target_multimesh_instance: MultiMeshInstance3D

@export_group("Spawn Settings")
@export var max_particles: int = 64
@export var spawn_radius: float = 1.0
@export var initial_burst_count: int = 64

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

# --- Internal State ---
# Particle data arrays
var _p_positions := PackedVector3Array()
var _p_velocities := PackedVector3Array()
var _p_ages := PackedFloat32Array()
var _p_lifetimes := PackedFloat32Array()
var _p_start_sizes := PackedFloat32Array()

# System state
var _active_count: int = 0
var _wind_phase: float = 0.0
var _current_wind_force := Vector3.ZERO
var _multimesh: MultiMesh

var _rng := RandomNumberGenerator.new()


# --- Lifecycle ---
func _ready() -> void:
	_rng.randomize()
	# Try to find the child if the export is empty
	if not target_multimesh_instance:
		target_multimesh_instance = $SmokeMM # child node is named "SmokeMM"

	if not _validate_dependencies():
		return

	_initialize_multimesh()
	_allocate_buffers()
	# spawn_particles(initial_burst_count)


func _physics_process(delta: float) -> void:
	if _active_count == 0:
		return

	_update_global_wind(delta)
	_simulate_particles(delta)
	_update_render_instances()

# --- Initialization & Setup ---
func _validate_dependencies() -> bool:
	if not target_multimesh_instance:
		push_error("SmokeEmitter: No MultiMeshInstance3D assigned in Inspector.")
		set_physics_process(false)
		return false
	return true


func _initialize_multimesh() -> void:
	# Create a new MultiMesh resource for the instance
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = false # Enable if you need vertex colors
	_multimesh.use_custom_data = true # Used for shader fading
	_multimesh.instance_count = max_particles
	_multimesh.visible_instance_count = 0
	
	# Assign a SphereMesh if none exists (fallback)
	if target_multimesh_instance.multimesh and target_multimesh_instance.multimesh.mesh:
		_multimesh.mesh = target_multimesh_instance.multimesh.mesh
	else:
		_multimesh.mesh = SphereMesh.new()

	target_multimesh_instance.multimesh = _multimesh


func _allocate_buffers() -> void:
	# Resizing arrays once avoids costly re-allocations during runtime
	_p_positions.resize(max_particles)
	_p_velocities.resize(max_particles)
	_p_ages.resize(max_particles)
	_p_lifetimes.resize(max_particles)
	_p_start_sizes.resize(max_particles)
	
	# Fill with defaults (optional, but safe)
	_p_positions.fill(Vector3.ZERO)
	_p_velocities.fill(Vector3.ZERO)
	_active_count = 0

# --- Simulation Logic ---
func spawn_particles(amount: int) -> void:
	for i in range(amount):
		if _active_count >= max_particles:
			break # Buffer full
		_emit_single_particle()


func _emit_single_particle() -> void:
	var idx := _active_count
	_active_count += 1
	
	# 1. Random Point (Spawn location)
	var r := spawn_radius * sqrt(_rng.randf())
	var theta := _rng.randf() * TAU
	var offset := Vector3(cos(theta) * r, 0.0, sin(theta) * r)
	
	_p_positions[idx] = offset # Position is local to Node3D
	
	# 2. Velocity Calculation (Upward + Radial Outward)
	var dir_radial := Vector3(offset.x, 0.0, offset.z).normalized()
	if dir_radial.is_zero_approx():
		dir_radial = Vector3(_rng.randf_range(-1,1), 0, _rng.randf_range(-1,1)).normalized()
		
	var v_up := Vector3.UP * _rng.randf_range(up_speed_min, up_speed_max)
	var v_out := dir_radial * _rng.randf_range(out_speed_min, out_speed_max)
	
	_p_velocities[idx] = v_up + v_out
	
	# 3. Properties
	_p_ages[idx] = 0.0
	_p_lifetimes[idx] = _rng.randf_range(lifetime_min, lifetime_max)
	_p_start_sizes[idx] = _rng.randf_range(size_start_min, size_start_max)


func _update_global_wind(dt: float) -> void:
	_wind_phase += dt * wind_speed_change
	# Simple swirling wind pattern
	_current_wind_force = Vector3(
		sin(_wind_phase * 1.7),
		0.0,
		cos(_wind_phase * 1.3)
	) * wind_strength


func _simulate_particles(dt: float) -> void:
	var i := 0
	
	# Loop through only active particles
	while i < _active_count:
		_p_ages[i] += dt
		
		# Check for death
		if _p_ages[i] >= _p_lifetimes[i]:
			_swap_remove_particle(i)
			continue # Don't increment 'i', checking the swapped particle next
		
		# Calculate Forces
		var acceleration := Vector3.ZERO
		acceleration.y += buoyancy + gravity
		acceleration += _current_wind_force
		
		# Drag (Air resistance)
		_p_velocities[i] -= _p_velocities[i] * drag_coefficient * dt
		
		# Integration
		_p_velocities[i] += acceleration * dt
		_p_positions[i] += _p_velocities[i] * dt
		
		i += 1


func _swap_remove_particle(index: int) -> void:
	# Standard "Fast Remove" (Swap with last element, then decrement count)
	# This avoids shifting the entire array, keeping removal O(1).
	_active_count -= 1
	
	if index == _active_count:
		return # It is the last one
		
	var last := _active_count
	_p_positions[index] = _p_positions[last]
	_p_velocities[index] = _p_velocities[last]
	_p_ages[index] = _p_ages[last]
	_p_lifetimes[index] = _p_lifetimes[last]
	_p_start_sizes[index] = _p_start_sizes[last]

# --- Rendering ---
func _update_render_instances() -> void:
	_multimesh.visible_instance_count = _active_count
	
	for i in range(_active_count):
		# Normalized life (0.0 to 1.0)
		var life_ratio := clampf(_p_ages[i] / _p_lifetimes[i], 0.0, 1.0)
		
		# Interpolate size
		var current_size := lerpf(
			_p_start_sizes[i],
			_p_start_sizes[i] * size_end_multiplier,
			life_ratio
		)
		
		# Construct Transform
		var basis_scaled := Basis.IDENTITY.scaled(Vector3.ONE * current_size)# Basis.IDENTITY has no rotation
		var t := Transform3D(basis_scaled, _p_positions[i])
		
		_multimesh.set_instance_transform(i, t)
		
		# Send Custom Data to Shader (Color.r = size, Color.g = life_ratio)
		# It allows the shader to handle fading opacity.
		_multimesh.set_instance_custom_data(i, Color(current_size, life_ratio, 0.0, 0.0))
