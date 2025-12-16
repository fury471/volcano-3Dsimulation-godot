extends Node3D

@export var smoke_emitter: Node
@export var lava_emitter: Node

@export var smoke_burst_count: int = 600
@export var lava_burst_count: int = 120

func _ready() -> void:
	
	# Optional: auto-wire by name if you forgot to assign in Inspector
	if smoke_emitter == null and has_node("SmokeEmitter"):
		smoke_emitter = $SmokeEmitter
	if lava_emitter == null and has_node("LavaChunksEmitter"):
		lava_emitter = $LavaChunksEmitter

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			trigger_eruption()

func trigger_eruption() -> void:
	# Smoke
	print("SPACE eruption triggered")

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
