extends Line2D
class_name TrailRibbon
## Ruban lumineux qui suit l'historique de position d'un orbe (ou de tout
## Node2D). Toute la couleur (bandes multiples + scintillement) est calculée
## dans trail_ribbon.gdshader — ce script gère la géométrie et transmet la
## config (pool de couleurs, nombre de bandes...) au shader.

@export var target: NodePath
@export var trail_length := 40
@export var line_width := 10.0
@export var shader: Shader

@export_group("Couleur")
@export var color_pool: Array[Color] = []
@export var band_count := 8        # nombre de bandes de couleur le long de la traînée
@export var flicker_speed := 2.0   # vitesse à laquelle chaque bande change de couleur
@export var edge_softness := 0.02  # proche de 0 = bord net/pixelisé
@export var fade_steps := 6        # paliers d'opacité (0 = fondu continu)

var _target_node: Node2D
var _points: PackedVector2Array = []


func _ready() -> void:
	# Empêche le Line2D d'hériter du transform de son parent : les points
	# enregistrés sont en coordonnées globales, le ruban doit rester ancré
	# dans le monde, pas suivre son parent comme un enfant normal.
	top_level = true
	texture_mode = Line2D.LINE_TEXTURE_STRETCH
	width = line_width
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND

	var width_curve := Curve.new()
	width_curve.add_point(Vector2(0.0, 0.15))  # queue fine
	width_curve.add_point(Vector2(1.0, 1.0))   # tête large, près de l'orbe
	self.width_curve = width_curve

	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_apply_color_config(mat)
		material = mat
	else:
		push_warning("TrailRibbon: aucun shader assigné.")

	if target != NodePath():
		_target_node = get_node(target)


func _apply_color_config(mat: ShaderMaterial) -> void:
	var padded := PackedColorArray()
	for i in range(8):
		if i < color_pool.size():
			padded.append(color_pool[i])
		else:
			padded.append(Color.BLACK)  # slot inutilisé (jamais choisi grâce au modulo pool_size)
	mat.set_shader_parameter("color_pool", padded)
	mat.set_shader_parameter("pool_size", max(color_pool.size(), 1))
	mat.set_shader_parameter("band_count", band_count)
	mat.set_shader_parameter("flicker_speed", flicker_speed)
	mat.set_shader_parameter("edge_softness", edge_softness)
	mat.set_shader_parameter("fade_steps", fade_steps)


func _process(_delta: float) -> void:
	if _target_node:
		push_trail_point(_target_node.global_position)


## Appelle cette fonction manuellement si tu ne veux pas du suivi automatique
## via "target" (ex: pour n'ajouter un point que tous les X pixels parcourus).
func push_trail_point(pos: Vector2) -> void:
	_points.append(pos)
	if _points.size() > trail_length:
		_points.remove_at(0)
	points = _points


## Hook reconnu par MousePointer.gd.
func preview_follow(pos: Vector2) -> void:
	push_trail_point(pos)
