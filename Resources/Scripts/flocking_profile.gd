class_name FlockingProfile
extends Resource

## Gregarious behaviour settings, assigned per enemy type in EnemyData (one for chase, one for idle).

## Weight of the goal direction (flow field in chase, formation slot in idle).
@export var seek_weight: float = 1.0
## Neighbors farther than this are ignored (px).
@export var neighbor_radius: float = 70.0
## Max neighbors read per update (bounds the cost in huge packs).
@export var max_neighbors: int = 12
## Pull toward the local pack centre -> compact ball.
@export var cohesion_weight: float = 0.5
## Below this distance to the pack centre, no cohesion pull (px).
@export var cohesion_dead_zone: float = 10.0
## Copy the neighbors' heading -> the pack moves as one block.
@export var alignment_weight: float = 0.35
## Below this distance, neighbors push each other away (px). Under the sprite size = overlapping bodies.
@export var separation_radius: float = 22.0
@export var separation_weight: float = 1.4
## 0 = own speed, 1 = neighbors' average speed. Stops speed variation from stringing the pack out.
@export_range(0.0, 1.0, 0.05) var speed_matching: float = 0.6
## Behind the pack centre -> faster, ahead -> slower (ratio). Turns a line into a ball.
@export_range(0.0, 0.8, 0.05) var catch_up_strength: float = 0.25
## Final speed limits, as a ratio of the base speed.
@export_range(0.0, 1.0, 0.05) var min_speed_ratio: float = 0.6
@export_range(1.0, 2.0, 0.05) var max_speed_ratio: float = 1.4
## Below this steering strength (0..1) the enemy stops: settled packs cost nothing to move or render.
@export_range(0.0, 0.5, 0.01) var rest_threshold: float = 0.2
