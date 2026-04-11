extends Node2D

@onready var layers : Array = self.get_children()
@export var grey_scale : bool = true

func _ready() -> void:
	if !grey_scale : 
		return
	var shader : Shader = load("res://Shaders/greyscale.gdshader")
	for layer : TileMapLayer in  layers:
		var mat: = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("intensity", 1.0)
		layer.material = mat
	#set_greyscale(1)
#
#
#func set_greyscale(value: float) -> void:
	#for layer : TileMapLayer in layers:
		#layer.material.set_shader_parameter("intensity", value)
