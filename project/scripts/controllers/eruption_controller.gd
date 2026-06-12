class_name EruptionController
extends Node3D

const DEFAULT_SMOKE_EMITTER_PATH := ^"SmokeEmitter"
const DEFAULT_LAVA_EMITTER_PATH := ^"LavaChunksEmitter"

@export_group("Scene References")
@export var animated_root: Node3D
@export var smoke_emitter: SmokeEmitter
@export var lava_emitter: LavaChunksEmitter

@export_group("Animation")
@export var hidden_y: float = -20.0
@export var visible_y: float = 12.0
@export var travel_time_seconds: float = 1.6
@export var ease_type := Tween.EASE_OUT
@export var transition_type := Tween.TRANS_SINE

@export_group("Burst Counts")
@export var smoke_burst_count: int = 600
@export var lava_burst_count: int = 60

var _animation_tween: Tween


func _ready() -> void:
	_resolve_emitters()
	_place_animated_root(hidden_y)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_pressed_key(event):
		return

	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_SPACE:
			trigger_eruption()
		KEY_V:
			hide_eruption()


func trigger_eruption() -> void:
	if animated_root:
		animated_root.visible = true
		_tween_animated_root_to(visible_y)

	if smoke_emitter:
		smoke_emitter.spawn_particles(smoke_burst_count)
	if lava_emitter:
		lava_emitter.spawn_chunks(lava_burst_count)


func hide_eruption() -> void:
	_tween_animated_root_to(hidden_y)


func _resolve_emitters() -> void:
	if smoke_emitter == null:
		smoke_emitter = get_node_or_null(DEFAULT_SMOKE_EMITTER_PATH) as SmokeEmitter
	if lava_emitter == null:
		lava_emitter = get_node_or_null(DEFAULT_LAVA_EMITTER_PATH) as LavaChunksEmitter


func _place_animated_root(target_y: float) -> void:
	if animated_root == null:
		return

	var position := animated_root.position
	position.y = target_y
	animated_root.position = position


func _tween_animated_root_to(target_y: float) -> void:
	if animated_root == null:
		return

	if _animation_tween != null and _animation_tween.is_running():
		_animation_tween.kill()

	var target_position := animated_root.position
	target_position.y = target_y

	_animation_tween = create_tween()
	_animation_tween.set_trans(transition_type)
	_animation_tween.set_ease(ease_type)
	_animation_tween.tween_property(animated_root, "position", target_position, travel_time_seconds)


func _is_pressed_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo
