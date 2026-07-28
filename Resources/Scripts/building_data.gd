extends Resource
class_name BuildingData

@export var name : String
@export var building_scene: PackedScene
@export var biome : GameMaster.BIOMES
@export var district_type : DistrictsData.types
@export var footprint_32 : Vector2i #32x32 cells size
@export var value : int
@export var spawnable : PackedScene
@export var circle_margin : float = 80
