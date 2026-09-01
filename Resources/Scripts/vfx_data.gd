extends Resource
class_name VFXData

enum Type { ANIMATION, PARTICLES, SHADER }

@export var name: String = "New Effect"
@export var type: Type = Type.ANIMATION

@export_group("Animations")
@export var variantes_animation: Array[NodePath] = []

@export_group("Particles")
@export var particles: NodePath

@export_group("Shaders")
@export var shader_node: NodePath
@export var shader_duree: float = 0.5
@export var shader_uniform_progress: String = "progress"
@export var shader_uniform_center: String = ""

@export_group("Global")
@export var delay: float = 0.0
