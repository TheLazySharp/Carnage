extends Resource
class_name BuildingData

enum Kind {
	INTERIOR,    # inside a block
	PERIPHERAL,  # belt piece, one of its sides lies on the map border
	CORNER,      # belt corner
	FILLER,      # narrow solid piece used to pave the belt exactly
}

@export var name : String
@export var building_scene : PackedScene
@export var biome : GameMaster.BIOMES
@export var district_type : DistrictsData.types
@export var footprint_32 : Vector2i  # 32x32 cells size, as drawn
@export var value : int
@export var spawnable : PackedScene
@export var circle_margin : float = 80

# ---------------- PROCEDURAL PLACEMENT ----------------
@export_group("Procedural placement")
@export var kind : Kind = Kind.INTERIOR
@export_range(0.0, 10.0, 0.1) var weight : float = 1.0

@export_enum("Top left:0", "Top right:1", "Bottom right:2", "Bottom left:3") var belt_corner : int = 0
## Visual height tier. A building receives the shadows of buildings from a
## STRICTLY higher tier only. 0 = flat roof; raise it for the ones you drew
## with a longer drop shadow.
@export_range(0, 3, 1) var height_level : int = 0

func is_district_specific() -> bool:
	return district_type != DistrictsData.types.N_A
