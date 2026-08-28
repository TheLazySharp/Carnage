extends Resource
class_name BuildingData
## One entry of the building pool.
##
## AUTHORING CONVENTIONS:
## - the scene origin is its TOP-LEFT corner, so footprint_32 maps to the rect
##   [origin, origin + footprint_32]
## - NOTHING IS EVER ROTATED at placement time: every building bakes its own
##   drop shadow and all shadows must share the same direction across the map.
##   Each footprint you need must exist as its own asset.
## - belt pieces are plain roof blocks: the sidewalk shows up on its own, on
##   whatever cells stay free on the city side. A horizontal piece
##   (width x belt_depth) serves the TOP and BOTTOM belts, a vertical one
##   (belt_depth x height) serves LEFT and RIGHT.
##
## district_type is the district flag: N_A means a generic building, any other
## value makes it the mandatory building of that district (bank, gunshop...).

enum Kind {
	INTERIOR,    # inside a block
	PERIPHERAL,  # belt piece, one of its sides lies on the map border
	CORNER,      # belt corner
	FILLER,      # narrow solid piece used to pave the belt exactly
}

@export var name : String
@export var building_scene : PackedScene
@export var biome : GameMaster.BIOMES
## N_A = generic building. Any other type = mandatory building of that district
@export var district_type : DistrictsData.types
@export var footprint_32 : Vector2i  # 32x32 cells size, as drawn
@export var value : int
@export var spawnable : PackedScene
## Free space kept around the building so its interaction circle fits the map
@export var circle_margin : float = 80

# ---------------- PROCEDURAL PLACEMENT ----------------
@export_group("Procedural placement")
@export var kind : Kind = Kind.INTERIOR
## Relative spawn frequency among the candidates
@export_range(0.0, 10.0, 0.1) var weight : float = 1.0

## Which map corner a CORNER piece is drawn for. Ignored for the other kinds.
## Nothing is rotated, so each of the 4 map corners needs its own asset.
@export_enum("Top left:0", "Top right:1", "Bottom right:2", "Bottom left:3") var belt_corner : int = 0

## True when this building is the mandatory one of a district
func is_district_specific() -> bool:
	return district_type != DistrictsData.types.N_A
