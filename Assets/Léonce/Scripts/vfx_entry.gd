extends Resource
class_name VFXEntry

enum Type { ANIMATION, PARTICLES, SHADER }

@export var nom: String = "Effet sans nom"
@export var type: Type = Type.ANIMATION

# --- Pour le type ANIMATION ---
@export var variantes_animation: Array[NodePath] = []

# --- Pour le type PARTICLES ---
@export var particles: NodePath

# --- Pour le type SHADER ---
@export var shader_node: NodePath
@export var shader_duree: float = 0.5
@export var shader_uniform_progress: String = "progress"

# --- Commun à tous les types ---
@export var delay: float = 0.0
