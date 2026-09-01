extends Resource
class_name CrackData
## One family of cracks. Every numeric field expressed as a Vector2 / Vector2i is
## a MIN/MAX range rolled per instance: that is what makes two cracks of the same
## family look related without looking cloned.
##
## Suggested families: "hairline" (long, thin, few branches, along the road),
## "transverse" (short, thick, across the road), "alligator" (short, very
## branchy, random angle, placed at intersections).

enum Orientation {
	ALONG_ROAD,   # longitudinal cracking, follows the traffic direction
	ACROSS_ROAD,  # transverse cracking, typical of joints and cold seams
	RANDOM,
}

@export var name : String = "crack"
## Relative frequency among the profiles
@export_range(0.0, 10.0, 0.1) var weight : float = 1.0

@export_group("Generator")
## Optional per-family generator scene. Empty = the pass's own crack_scene.
## This is what lets one profile use the serpentine generator and another the
## network one.
@export var crack_scene : PackedScene = null
## Serpentine only, ignored by the network generator
@export_range(0.0, 0.95, 0.01) var turn_smoothing : float = 0.5

@export_group("Shape")
## Virtual pixel of the crack. Bigger = chunkier, more damaged look.
@export var pixel_size : int = 4
## Total walked length, in grid steps (real length = value x pixel_size)
@export var total_length : Vector2i = Vector2i(30, 90)
@export var segment_length : Vector2i = Vector2i(2, 5)
@export var max_turn_degrees : Vector2 = Vector2(12.0, 30.0)
## Thickness range of the main branch, in virtual pixels
@export var thickness : Vector2i = Vector2i(1, 3)
@export_range(0.0, 2.0, 0.1) var thickness_variation_step : float = 0.4

@export_group("Branching")
@export var branch_chance : Vector2 = Vector2(0.05, 0.20)
@export_range(0.05, 1.0, 0.01) var branch_chance_falloff : float = 0.35
@export_range(0.1, 1.0, 0.05) var branch_length_ratio : float = 0.5
@export var branch_angle_spread_degrees : float = 45.0
@export var max_branch_depth : Vector2i = Vector2i(1, 3)
@export_range(0, 3, 1) var thickness_falloff_per_depth : int = 1

@export_group("Placement")
@export var orientation := Orientation.ALONG_ROAD
## Random rotation added to the base orientation
@export var angle_jitter_degrees : float = 20.0
## Share of this family placed at an intersection instead of along a road run
@export_range(0.0, 1.0, 0.05) var intersection_ratio : float = 0.0
## Keeps the crack away from the road edge, in pixels
@export var edge_margin_px : float = 24.0

@export_group("Appearance")
@export var color : Color = Color(0, 0, 0, 1)
## Random alpha variation, so a group of cracks does not read as one flat layer
@export_range(0.0, 1.0, 0.05) var alpha_jitter : float = 0.0

@export_group("Pulse")
## Share of this family that pulses. A pulsing crack is NEVER baked: it stays a
## live node with its own tween, so keep this low.
@export_range(0.0, 1.0, 0.05) var pulse_ratio : float = 0.0
## Dim and bright ends of the cycle. Components above 1.0 are HDR values: that
## is what the WorldEnvironment glow pass blooms.
@export var pulse_color_low : Color = Color(0.35, 0.02, 0.02, 1.0)
@export var pulse_color_high : Color = Color(4.0, 0.35, 0.15, 1.0)
## Seconds for one half-cycle (low -> high), rolled per crack
@export var pulse_duration : Vector2 = Vector2(0.8, 1.8)
## Random delay before the first cycle, so the cracks never breathe in sync
@export var pulse_start_delay : Vector2 = Vector2(0.0, 2.0)
