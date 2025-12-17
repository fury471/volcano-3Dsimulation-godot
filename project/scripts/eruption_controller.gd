extends Node3D

@export var move_node: Node3D
@export var y_hidden: float = -20.0
@export var y_shown: float = 12.0
@export var travel_time: float = 1.6  # seconds
@export var ease_type := Tween.EASE_OUT
@export var trans_type := Tween.TRANS_SINE
var _tween: Tween

@export var smoke_emitter: Node
@export var lava_emitter: Node

@export var smoke_burst_count: int = 600
@export var lava_burst_count: int = 60

func _ready() -> void:
	if move_node:
		var p := move_node.position
		p.y = y_hidden
		move_node.position = p
		
	# auto-wire by name if you forgot to assign in Inspector
	if smoke_emitter == null and has_node("SmokeEmitter"):
		smoke_emitter = $SmokeEmitter
	if lava_emitter == null and has_node("LavaChunksEmitter"):
		lava_emitter = $LavaChunksEmitter
	

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			trigger_eruption()
			_move_to_y(y_shown)
		elif event.keycode == KEY_V:
			_move_to_y(y_hidden)


func trigger_eruption() -> void:
	# Smoke
	print("SPACE eruption triggered")
	if move_node:
		move_node.visible = true
	if smoke_emitter != null:
		if smoke_emitter.has_method("spawn_particles"):
			smoke_emitter.call("spawn_particles", smoke_burst_count)
		elif smoke_emitter.has_method("burst"):
			smoke_emitter.call("burst", smoke_burst_count)

	# Lava
	if lava_emitter != null:
		if lava_emitter.has_method("spawn_chunks"):
			lava_emitter.call("spawn_chunks", lava_burst_count)
		elif lava_emitter.has_method("burst"):
			lava_emitter.call("burst", lava_burst_count)


func _move_to_y(target_y: float) -> void:
	if move_node == null:
		return

	# Cancel any previous animation
	if _tween and _tween.is_running():
		_tween.kill()

	var start_pos := move_node.position
	var end_pos := start_pos
	end_pos.y = target_y

	_tween = create_tween()
	_tween.set_trans(trans_type)
	_tween.set_ease(ease_type)
	_tween.tween_property(move_node, "position", end_pos, travel_time)
