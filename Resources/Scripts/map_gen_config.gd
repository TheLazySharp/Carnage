class_name MapGenConfig
extends Resource
## Generation parameters that vary per biome (or per test map).
## Applied by MapGenerator.configure(). cell_size and lane widths stay global:
## tilesets and road brushes depend on them everywhere.

@export var map_size_cells : Vector2i = Vector2i(96, 80)
## Must stay >= belt depth + sidewalk + half street (6 + 2 + 3 = 11) for the belt
@export var border_margin_cells : int = 11
@export var block_interior_min : int = 4
@export var block_interior_max : int = 12
@export_range(0.0, 0.8) var removal_ratio : float = 0.1
@export var artery_count_h : int = 1
@export var artery_count_v : int = 1
@export var sidewalk_cells : int = 2
@export var reserve_district_plot : bool = true
@export var district_plot_size : Vector2i = Vector2i(6, 6)
