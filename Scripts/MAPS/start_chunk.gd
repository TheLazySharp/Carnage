extends Node2D

@export var INTRO_CHUNK : PackedScene
@export var TRANSITION_CHUNK : PackedScene

@onready var next_chunk_origin: Node2D = $NextChunkOrigin
@onready var chunks: Node2D = $"../Chunks"

var nb_chunk : int = 0
var max_chunks : int = 1


func _ready() -> void:
	SignalManager.instantiate_new_chunk.connect(_instantiate_new_chunk)

func _on_end_of_chunk_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_instantiate_new_chunk(next_chunk_origin.global_position)

func _instantiate_new_chunk(pos : Vector2) -> void : 
	if nb_chunk < max_chunks:
		var new_chunk : Node2D 
		new_chunk = INTRO_CHUNK.instantiate()
		chunks.call_deferred("add_child",new_chunk)
		new_chunk.global_position = pos
		nb_chunk += 1
	else : 
		nb_chunk = 0
		var transition_chunk : Node2D 
		transition_chunk = TRANSITION_CHUNK.instantiate()
		chunks.call_deferred("add_child",transition_chunk)
		transition_chunk.global_position = pos
