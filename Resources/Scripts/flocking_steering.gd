class_name FlockingSteering
extends RefCounted


## goal: direction to follow (length 0..1, ZERO = no goal). Returns the new velocity.
static func compute_velocity(enemy: Enemy, goal: Vector2, base_speed: float, profile: FlockingProfile) -> Vector2:
	if base_speed <= 0.0:
		return Vector2.ZERO   # frozen / stopped: never dragged by the pack
	var own_position: Vector2 = enemy.global_position
	var neighbor_radius_squared: float = profile.neighbor_radius * profile.neighbor_radius
	var separation_radius_squared: float = profile.separation_radius * profile.separation_radius
	var inverse_separation_radius: float = 1.0 / profile.separation_radius

	var separation: Vector2 = Vector2.ZERO
	var centroid: Vector2 = Vector2.ZERO
	var heading_sum: Vector2 = Vector2.ZERO
	var speed_sum: float = 0.0
	var moving_count: int = 0
	var neighbor_count: int = 0

	# Bounded cost: at most max_neighbors entries read, from a random start so every neighbor counts over time
	var neighbors: Array = enemy.horde_neighbors
	var neighbor_total: int = neighbors.size()
	var reads: int = mini(neighbor_total, profile.max_neighbors)
	var start: int = randi() % neighbor_total if neighbor_total > 0 else 0
	for read: int in range(reads):
		var candidate: Variant = neighbors[(start + read) % neighbor_total]
		if !is_instance_valid(candidate):
			continue
		var other: Enemy = candidate
		if other == enemy or other.is_dead or other.air_duration > 0.0:
			continue
		var offset: Vector2 = own_position - other.global_position
		var distance_squared: float = offset.length_squared()
		if distance_squared > neighbor_radius_squared:
			continue
		neighbor_count += 1
		centroid += other.global_position
		# Thrown neighbors do not steer the pack
		if other.knockback_velocity.length_squared() < 100.0:
			var other_speed_squared: float = other.velocity.length_squared()
			if other_speed_squared > 1.0:
				var other_speed: float = sqrt(other_speed_squared)
				heading_sum += other.velocity / other_speed
				speed_sum += other_speed
				moving_count += 1
		if distance_squared < separation_radius_squared and distance_squared > 0.0001:
			var distance: float = sqrt(distance_squared)
			# Linear falloff: 1 at contact, 0 at separation_radius
			separation += (offset / distance) * (1.0 - distance * inverse_separation_radius)

	var steering: Vector2 = goal * profile.seek_weight
	var speed: float = base_speed
	if neighbor_count > 0:
		centroid /= float(neighbor_count)
		var to_centroid: Vector2 = centroid - own_position
		var centroid_distance: float = to_centroid.length()
		if centroid_distance > profile.cohesion_dead_zone:
			steering += (to_centroid / centroid_distance) * profile.cohesion_weight
		# Capped: several overlapping neighbors never add up to a full-speed shove (no oscillation)
		steering += separation.limit_length(1.0) * profile.separation_weight
		if moving_count > 0:
			steering += heading_sum.normalized() * profile.alignment_weight
			speed = lerpf(base_speed, speed_sum / float(moving_count), profile.speed_matching)
		# Catch-up along the travel direction: behind the pack centre -> faster, ahead -> slower
		if goal.length_squared() > 0.0001:
			var behind: float = to_centroid.dot(goal.normalized()) / profile.neighbor_radius
			speed *= 1.0 + clampf(behind, -1.0, 1.0) * profile.catch_up_strength
	speed = clampf(speed, base_speed * profile.min_speed_ratio, base_speed * profile.max_speed_ratio)

	var strength: float = steering.length()
	# Settled: residual pack forces are ignored, so update_move and the renderer skip this enemy
	if strength < profile.rest_threshold:
		return Vector2.ZERO
	# Full speed when the steering is strong (goal), slower when only small pack corrections remain
	return steering / strength * speed * minf(strength, 1.0)
