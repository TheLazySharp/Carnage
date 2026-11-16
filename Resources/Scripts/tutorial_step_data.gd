class_name TutorialStepData
extends Resource
## One phase 1 tutorial step: a maneuver to perform N times

@export var maneuver_type: ManeuverManager.Type = ManeuverManager.Type.SHORT_DRIFT
@export var required_count: int = 3
@export var title_key: String = ""  # translation key
@export var hint_key: String = ""   # translation key: how to perform it
## Pages shown before the step (key = title, key + "_BODY" = text)
@export var page_keys : PackedStringArray = []
## Any maneuver counts as long as it is amplified (dash). maneuver_type then only picks the demo clip
@export var require_amplified : bool = false
