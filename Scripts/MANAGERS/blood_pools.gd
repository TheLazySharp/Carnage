extends Node

@export var main_textures: Array[Texture2D] = []
@export var big_textures: Array[Texture2D] = []
@export var small_textures: Array[Texture2D] = []

@export_dir var main_folder: String = "res://Assets/VFX/BloodPools/BloodPoolMain/"
@export_dir var big_folder: String = "res://Assets/VFX/BloodPools/BloodPoolBig/"
@export_dir var small_folder: String = "res://Assets/VFX/BloodPools/BloodPoolSmall/"

func _ready() -> void:
	if main_textures.is_empty() or big_textures.is_empty() or small_textures.is_empty():
		push_error("BloodPools: textures manquantes (main=%d big=%d small=%d)"
			% [main_textures.size(), big_textures.size(), small_textures.size()])
