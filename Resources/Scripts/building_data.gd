extends Resource
class_name BuildingData
## One entry of the building pool.
##
## ORIENTATION CONVENTION (important when authoring the scenes):
## the scene origin is its TOP-LEFT corner, so a footprint of footprint_32
## maps to the rect [origin, origin + footprint_32].
## At rotation 0:
##   - PERIPHERAL has its sidewalk face pointing DOWN (+Y): it is authored as
##     if it belonged to the TOP belt, city below
##   - CORNER has its two sidewalk faces pointing DOWN and RIGHT: it is
##     authored as the TOP-LEFT corner
## The placement pass rotates them so those faces always look at the city.
## INTERIOR has sidewalks on every face and may be rotated freely.
##
## district_type is the district flag: N_A means a generic building, any other
## value makes it the mandatory building of that district (bank, gunshop...).

enum Kind {
	INTERIOR,    # inside a block, sidewalks on all four faces
	PERIPHERAL,  # belt building, sidewalk on one face only
	CORNER,      # belt corner, sidewalks on two adjacent faces
	FILLER,      # 1-3 cells solid piece used to pave the belt exactly (fence, bins, wall)
}

## Which side of the map a belt building sits on (city is on the opposite side)
enum Side { TOP, RIGHT, BOTTOM, LEFT }

## Which corner of the belt a CORNER building sits on, clockwise from the
## authored TOP_LEFT
enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT }

@export var name : String
@export var building_scene : PackedScene
@export var biome : GameMaster.BIOMES
## N_A = generic building. Any other type = mandatory building of that district
@export var district_type : DistrictsData.types
@export var footprint_32 : Vector2i  # 32x32 cells size, at rotation 0
@export var value : int
@export var spawnable : PackedScene
## Free space kept around the building so its interaction circle fits the map
@export var circle_margin : float = 80

# ---------------- PROCEDURAL PLACEMENT ----------------
@export_group("Procedural placement")
@export var kind : Kind = Kind.INTERIOR
## Relative spawn frequency among the candidates of the same size
@export_range(0.0, 10.0, 0.1) var weight : float = 1.0
## INTERIOR only: allow 90 degree turns (needs a footprint that still fits)
@export var allow_quarter_turns : bool = true


## True when this building is the mandatory one of a district
func is_district_specific() -> bool:
	return district_type != DistrictsData.types.N_A


## Rotation (radians) to apply so the sidewalk face looks at the city.
## Local down (0,1) rotated by the result points away from the map border.
## side is a Side value (typed int: enums declared in a class cannot be used
## as a parameter type from another file)
static func rotation_for_side(side : int) -> float:
	match side:
		Side.TOP:
			return 0.0        # city below  -> sidewalk down
		Side.LEFT:
			return -PI * 0.5  # city right  -> sidewalk right
		Side.RIGHT:
			return PI * 0.5   # city left   -> sidewalk left
		_:
			return PI         # BOTTOM: city above -> sidewalk up


## Same, expressed in quarter turns (for rotated_size / rotation_offset)
static func quarter_turns_for_side(side : int) -> int:
	match side:
		Side.TOP:
			return 0
		Side.LEFT:
			return 3   # -90 deg
		Side.RIGHT:
			return 1   # +90 deg
		_:
			return 2   # BOTTOM


## Rotation (radians) for a belt corner. The enum is ordered clockwise from
## the authored TOP_LEFT, so it is simply a quarter turn per step.
static func rotation_for_corner(corner : int) -> float:
	return float(int(corner)) * PI * 0.5


static func quarter_turns_for_corner(corner : int) -> int:
	return corner


## Footprint after quarter_turns 90 degree rotations (x and y swap on odd turns)
static func rotated_size(size : Vector2i, quarter_turns : int) -> Vector2i:
	if quarter_turns % 2 == 0:
		return size
	return Vector2i(size.y, size.x)


## Offset to add to the placement rect origin so the rotated scene, whose own
## origin is its top-left corner, still covers that rect.
## A Node2D rotated around its origin moves its content: this compensates it.
static func rotation_offset(size : Vector2i, quarter_turns : int, cell_size : int) -> Vector2:
	var w : float = float(size.x * cell_size)
	var h : float = float(size.y * cell_size)
	match posmod(quarter_turns, 4):
		1:
			return Vector2(h, 0.0)   # +90 deg
		2:
			return Vector2(w, h)     # 180 deg
		3:
			return Vector2(0.0, w)   # -90 deg
		_:
			return Vector2.ZERO
