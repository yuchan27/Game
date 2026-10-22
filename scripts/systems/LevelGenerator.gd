extends RefCounted
class_name LevelGenerator

static func seeded_positions(count: int, bounds: Rect2, seed_value: int, spacing := 72.0, blocked_regions: Array[Rect2] = []) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var positions: Array[Vector2] = []
	var attempts := 0
	while positions.size() < count and attempts < count * 30:
		attempts += 1
		var candidate := Vector2(
			rng.randf_range(bounds.position.x, bounds.end.x),
			rng.randf_range(bounds.position.y, bounds.end.y)
		)
		var valid := true
		for blocked_region: Rect2 in blocked_regions:
			if blocked_region.has_point(candidate):
				valid = false
				break
		if not valid:
			continue
		for p in positions:
			if p.distance_to(candidate) < spacing:
				valid = false
				break
		if valid:
			positions.append(candidate)
	return positions
