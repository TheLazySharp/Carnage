class_name GeoTools


static func size_px(footprint : Vector2i, cell_size : float = 32.0) -> Vector2:
	return Vector2(footprint) * cell_size

static func inscribed_radius(footprint : Vector2i, cell_size : float = 32.0) -> float:
	var s : Vector2 = size_px(footprint, cell_size)
	return min(s.x, s.y) * 0.5

static func circumscribed_radius(footprint : Vector2i, cell_size : float = 32.0) -> float:
	return size_px(footprint, cell_size).length() * 0.5

static func interaction_radius(footprint : Vector2i, cell_size : float = 32.0, margin : float = 0.0) -> float:
	return circumscribed_radius(footprint, cell_size) + margin

static func is_circle_in_rect(center : Vector2, radius : float, rect : Rect2) -> bool:
	return center.x - radius >= rect.position.x and center.y - radius >= rect.position.y \
		and center.x + radius <= rect.end.x and center.y + radius <= rect.end.y

static func random_point_in_annulus(center : Vector2, r_min : float, r_max : float) -> Vector2:
	var angle : float = randf_range(0.0, TAU)
	var radius : float = sqrt(randf_range(r_min * r_min, r_max * r_max))
	return center + Vector2(cos(angle), sin(angle)) * radius
