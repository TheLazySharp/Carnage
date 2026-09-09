extends Line2D
class_name TrailRibbon
## Ruban lumineux qui suit l'historique de position d'un orbe (ou de tout Node2D).
## La couleur est entièrement gérée par trail_ribbon.gdshader — ce script ne fait
## que gérer la géométrie (les points du ruban).
##
## Usage :
##   1. Attache ce script à un noeud Line2D.
##   2. Assigne "shader" = trail_ribbon.gdshader dans l'inspecteur.
##   3. Soit assigne "target" = chemin vers ton orbe (suivi automatique),
##      soit appelle push_trail_point(pos) toi-même depuis le script qui anime l'orbe.

@export var target: NodePath
@export var trail_length := 40
@export var line_width := 10.0
@export var shader: Shader

var _target_node: Node2D
var _points: PackedVector2Array = []


func _ready() -> void:
	# Empêche le Line2D d'hériter du transform de son parent (l'orbe) : les
	# points enregistrés sont en coordonnées globales, donc le ruban doit
	# rester ancré dans le monde, pas suivre l'orbe comme un enfant normal.
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
		material = mat
	else:
		push_warning("TrailRibbon: aucun shader assigné.")

	if target != NodePath():
		_target_node = get_node(target)


func _process(_delta: float) -> void:
	if _target_node:
		push_trail_point(_target_node.global_position)


## Appelle cette fonction manuellement si tu ne veux pas du suivi automatique
## via "target" (ex: pour n'ajouter un point que tous les X pixels parcourus).
## Renommée (au lieu de "add_point") pour ne pas entrer en collision avec la
## méthode native de Line2D, qui a une signature différente.
func push_trail_point(pos: Vector2) -> void:
	_points.append(pos)
	if _points.size() > trail_length:
		_points.remove_at(0)
	points = _points


## Hook reconnu par MousePointer.gd : quand ce noeud est mis dans la liste
## "followers" d'un MousePointer, c'est cette méthode qui est appelée au lieu
## d'un simple téléportage — laisse "target" vide dans ce cas, sinon les deux
## systèmes vont pousser des points en même temps.
func preview_follow(pos: Vector2) -> void:
	push_trail_point(pos)
