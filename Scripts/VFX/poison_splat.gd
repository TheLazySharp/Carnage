extends Node2D


@onready var shards: CPUParticles2D = $PoisonSplatter/Shards
@onready var poison_splatter: CPUParticles2D = $PoisonSplatter

var shards_finished : bool = false
var poison_finished : bool = false

func _ready() -> void:
	splat()

func splat() -> void : 
	poison_splatter.emitting = true
	shards.emitting = true
	
	

func _on_poison_splatter_finished() -> void:
	poison_finished = true
	if shards_finished:
		self.queue_free()


func _on_shards_finished() -> void:
	shards_finished = true
	if poison_finished:
		self.queue_free()
