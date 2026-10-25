class_name ManeuverData
extends Resource
## A maneuver sold at the shop (the car base maneuvers are owned from the start)

@export var maneuver_type : ManeuverManager.Type = ManeuverManager.Type.SHORT_DRIFT
@export var icon : Texture2D
@export var name_key : String = ""         # translation key
@export var description_key : String = ""  # translation key
@export var base_price : int = 150         # blood
@export var demo_video : VideoStream
